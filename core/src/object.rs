pub mod placing;

use avian3d::prelude::*;
use bevy::{
    asset::AssetPath,
    ecs::{entity::MapEntities, reflect::ReflectCommandExt},
    prelude::*,
};
use bevy_mod_outline::{AsyncSceneInheritOutline, OutlineVolume};
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::{
    asset_manifest::ObjectManifest,
    outline::OUTLINE_VOLUME,
    state::GameState,
    undo::{
        CommandConfirmation, CommandId, CommandStatus, ConfirmableCommand, EntityRecorder,
        HistoryCommand,
        request::{ClientCommand, ClientCommandAppExt, CommandRequest},
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_client_command::<MoveObject>()
        .add_observer(apply_move)
        .add_plugins(placing::plugin)
        .add_observer(init)
        .add_systems(OnEnter(GameState::World), spawn);
}

/// Spawns object for testing.
fn spawn(mut commands: Commands) {
    commands.spawn(Object {
        path: "base/objects/test/test.object.ron".into(),
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

    let Some(manifest_handle) = asset_server.get_handle(&object.path) else {
        error!("'{}' is missing, ignoring", &object.path);
        return;
    };

    debug!(
        "initializing object '{}' for `{}`",
        &object.path, insert.entity
    );

    let manifest = manifests
        .get(&manifest_handle)
        .unwrap_or_else(|| panic!("'{:?}' should be loaded", &object.path));

    *name = manifest.info.name.clone();
    scene_root.0 = asset_server.load(manifest.scene.clone());

    let mut entity = commands.entity(insert.entity);
    for component in &manifest.components {
        entity.insert_reflect(component.as_ref().reflect_clone().unwrap());
    }
}

fn apply_move(
    move_command: On<ClientCommand<MoveObject>>,
    mut commands: Commands,
    mut objects: Query<&mut Transform, With<Object>>,
) {
    match objects.get_mut(move_command.object) {
        Ok(mut transform) => {
            info!(
                "`{:?}` moves object `{}`",
                move_command.client_id, move_command.object
            );
            transform.translation = move_command.translation;
            transform.rotation = move_command.rotation;
            commands.client_trigger(CommandConfirmation {
                id: move_command.id,
                status: CommandStatus::Confirmed,
            });
        }
        Err(e) => {
            error!("unable to move object: {e}");
            commands.client_trigger(CommandConfirmation {
                id: move_command.id,
                status: CommandStatus::Denied,
            });
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
    ColliderConstructorHierarchy {
        default_constructor: Some(ColliderConstructor::ConvexHullFromMesh),
        ..Default::default()
    }
)]
#[component(immutable)]
pub struct Object {
    pub path: AssetPath<'static>,
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
    ) -> Option<HistoryCommand> {
        world.client_trigger(CommandRequest { id, command: *self });

        let transform = *world.get::<Transform>(self.object)?;
        Some(HistoryCommand::confirmable(Self {
            object: self.object,
            translation: transform.translation,
            rotation: transform.rotation,
        }))
    }
}
