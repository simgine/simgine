pub mod placing;

use avian3d::prelude::*;
use bevy::{
    asset::AssetPath,
    ecs::{entity::MapEntities, reflect::ReflectCommandExt},
    prelude::*,
};
use bevy_mod_outline::{AsyncSceneInheritOutline, OutlineVolume};
use bevy_replicon::{prelude::*, shared::backend::connected_client::NetworkId};
use bevy_replicon_renet::netcode::NetcodeClientTransport;
use serde::{Deserialize, Serialize};

use crate::{
    asset_manifest::object::ObjectManifest,
    state::GameState,
    undo::{
        CommandId, ConfirmableCommand, EntityRecorder,
        client_command::{
            ClientCommand, ClientCommandAppExt, ClientCommandExt, CommandRequest, Deny,
        },
    },
    world::{
        combined_collider::CombinedCollider, cursor::outline::OUTLINE_VOLUME, layer::GameLayer,
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_client_command::<MoveObject>()
        .add_client_command::<BuyObject>()
        .add_client_command::<SellObject>()
        .add_plugins(placing::plugin)
        .add_observer(init)
        .add_observer(move_command)
        .add_observer(buy)
        .add_observer(buy_deny)
        .add_observer(sell)
        .add_systems(OnEnter(GameState::World), spawn);
}

/// Spawns object for testing.
fn spawn(mut commands: Commands) {
    commands.spawn(Object {
        manifest: "base/objects/test/test.object.ron".into(),
    });
}

fn init(
    insert: On<Insert, Object>,
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    manifests: Res<Assets<ObjectManifest>>,
    mut objects: Query<(&Object, &mut Name, &mut SceneRoot)>,
) {
    let (object, mut name, mut scene_root) = objects.get_mut(insert.entity).unwrap();

    let Some(manifest_handle) = asset_server.get_handle(&object.manifest) else {
        error!("'{}' is missing, ignoring", object.manifest);
        return;
    };

    debug!(
        "initializing object '{}' for `{}`",
        &object.manifest, insert.entity
    );

    let manifest = manifests
        .get(&manifest_handle)
        .unwrap_or_else(|| panic!("'{:?}' should be loaded", object.manifest));

    *name = manifest.info.name.clone();
    **scene_root = asset_server.load(manifest.scene.clone());

    let mut entity = commands.entity(insert.entity);
    for component in &manifest.components {
        entity.insert_reflect(component.as_ref().reflect_clone().unwrap());
    }
}

fn move_command(
    move_command: On<ClientCommand<MoveObject>>,
    mut commands: Commands,
    mut objects: Query<&mut Transform, With<Object>>,
) {
    match objects.get_mut(move_command.object) {
        Ok(mut transform) => {
            info!(
                "`{:?}` moves `{}`",
                move_command.client_id, move_command.object
            );
            transform.translation = move_command.translation;
            transform.rotation = move_command.rotation;
            commands.server_trigger(move_command.confirm());
        }
        Err(e) => {
            info!(
                "denying `{:?}` to move `{}`: {e}",
                move_command.client_id, move_command.object
            );
            commands.server_trigger(move_command.deny());
        }
    }
}

fn buy(
    buy: On<ClientCommand<BuyObject>>,
    mut commands: Commands,
    clients: Query<&NetworkId>,
    pending_objects: Query<(Entity, &PendingObject), Without<Object>>,
) {
    let bundle = (
        Object {
            manifest: buy.manifest.clone(),
        },
        Transform::from_translation(buy.translation).with_rotation(buy.rotation),
    );

    if let ClientId::Client(client) = buy.client_id {
        let network_id = clients.get(client).unwrap();
        commands.spawn((bundle, Signature::from((buy.id, network_id))));
    } else {
        // While it's O(n), it's usually a single entity.
        let Some((object, _)) = pending_objects.iter().find(|(_, o)| o.id == buy.id) else {
            debug!("ignoring buy for non-existing `{:?}`", buy.id);
            commands.server_trigger(buy.deny());
            return;
        };

        commands.entity(object).insert(bundle);
    };

    info!("`{:?}` buys '{:?}'", buy.client_id, buy.manifest);

    commands.server_trigger(buy.confirm());
}

fn buy_deny(
    buy: On<Deny<BuyObject>>,
    mut commands: Commands,
    pending_objects: Query<(Entity, &PendingObject), Without<Object>>,
) {
    if let Some((object, _)) = pending_objects.iter().find(|(_, o)| o.id == buy.id) {
        debug!("despawning `{object}` from denied buy");
        commands.entity(object).despawn();
    }
}

fn sell(
    sell: On<ClientCommand<SellObject>>,
    mut commands: Commands,
    objects: Query<(), With<Object>>,
) {
    match objects.get(sell.object) {
        Ok(()) => {
            info!("`{:?}` sells `{}`", sell.client_id, sell.object);
            commands.entity(sell.object).despawn();
            commands.server_trigger(sell.confirm());
        }
        Err(e) => {
            info!(
                "denying `{:?}` to sell `{}`: {e}",
                sell.client_id, sell.object
            );
            commands.server_trigger(sell.deny());
        }
    }
}

#[derive(Component, Serialize, Deserialize)]
#[require(
    Name,
    Replicated,
    SceneRoot,
    AsyncSceneInheritOutline,
    RigidBody::Kinematic,
    OutlineVolume = OUTLINE_VOLUME,
    CombinedCollider::Aabb,
    CollisionLayers::new(GameLayer::Object, LayerMask::ALL),
)]
#[component(immutable)]
pub struct Object {
    pub manifest: AssetPath<'static>,
}

#[derive(Serialize, Deserialize, MapEntities, Clone, Copy)]
struct MoveObject {
    #[entities]
    object: Entity,
    translation: Vec3,
    rotation: Quat,
}

impl ConfirmableCommand for MoveObject {
    fn apply(
        self: Box<Self>,
        id: CommandId,
        _recorder: &mut EntityRecorder,
        world: &mut World,
    ) -> Option<Box<dyn ConfirmableCommand>> {
        let transform = *world.get::<Transform>(self.object)?;

        world.client_trigger(CommandRequest { id, command: *self });

        Some(Box::new(Self {
            object: self.object,
            translation: transform.translation,
            rotation: transform.rotation,
        }))
    }
}

#[derive(Serialize, Deserialize, MapEntities, Clone)]
struct BuyObject {
    manifest: AssetPath<'static>,
    translation: Vec3,
    rotation: Quat,
}

impl ConfirmableCommand for BuyObject {
    fn apply(
        self: Box<Self>,
        id: CommandId,
        _recorder: &mut EntityRecorder,
        world: &mut World,
    ) -> Option<Box<dyn ConfirmableCommand>> {
        // Spawns a placeholder entity immediately so undo has something to point at.
        // The entity will be matched by hash if spawned by client or manually matched by ID on the server.
        let pending_object = PendingObject { id };
        let object = if let Some(transport) = world.get_resource::<NetcodeClientTransport>() {
            world
                .spawn((
                    pending_object,
                    Signature::from((id, NetworkId::new(transport.client_id()))),
                ))
                .id()
        } else {
            world.spawn(pending_object).id()
        };

        world.client_trigger(CommandRequest { id, command: *self });

        Some(Box::new(SellObject { object }))
    }
}

#[derive(Component)]
struct PendingObject {
    id: CommandId,
}

#[derive(Serialize, Deserialize, MapEntities, Clone, Copy)]
struct SellObject {
    object: Entity,
}

impl ConfirmableCommand for SellObject {
    fn apply(
        self: Box<Self>,
        id: CommandId,
        recorder: &mut EntityRecorder,
        world: &mut World,
    ) -> Option<Box<dyn ConfirmableCommand>> {
        let entity = world.get_entity(self.object).ok()?;
        let object = entity.get::<Object>()?;
        let transform = *entity.get::<Transform>()?;
        let manifest = object.manifest.clone();

        world.client_trigger(CommandRequest { id, command: *self });
        recorder.record(self.object);

        Some(Box::new(BuyObject {
            manifest,
            translation: transform.translation,
            rotation: transform.rotation,
        }))
    }
}
