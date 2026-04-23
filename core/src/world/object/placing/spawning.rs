use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

use super::PlacingObject;
use crate::{
    asset_manifest::object::ObjectManifest,
    undo::{HistoryCommands, client_command::DespawnOnResponse},
    world::{
        object::{BuyObject, placing::placing_object},
        placing::PlacingBlockers,
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<SpawningObject>()
        .add_observer(init)
        .add_observer(buy);
}

fn init(
    insert: On<Insert, SpawningObject>,
    asset_server: Res<AssetServer>,
    manifests: Res<Assets<ObjectManifest>>,
    mut spawning_objects: Query<(&SpawningObject, &mut SceneRoot)>,
) {
    let (spawning, mut scene_root) = spawning_objects.get_mut(insert.entity).unwrap();
    let manifest = manifests
        .get(spawning.id)
        .expect("manifests should be preloaded");

    debug!("loading scene `{}`", manifest.scene);

    **scene_root = asset_server.load(manifest.scene.clone());
}

fn buy(
    buy: On<Start<Buy>>,
    mut commands: HistoryCommands,
    asset_server: Res<AssetServer>,
    spawning_object: Single<(&SpawningObject, &Transform, &PlacingBlockers)>,
) {
    let (spawning, transform, blockers) = *spawning_object;
    if !blockers.is_empty() {
        return;
    }

    let manifest = asset_server.get_path(spawning.id).unwrap();

    info!("spawning '{manifest}'");

    let id = commands.queue_confirmable(BuyObject {
        manifest: manifest.clone_owned(),
        translation: transform.translation,
        rotation: transform.rotation,
    });

    commands
        .entity(buy.context)
        .remove_with_requires::<SpawningObject>()
        .despawn_related::<Actions<PlacingObject>>()
        .despawn_related::<Actions<SpawningObject>>()
        .insert(DespawnOnResponse { id });
}

pub fn spawning_object(id: AssetId<ObjectManifest>) -> impl Bundle {
    (
        Name::new("Spawning object"),
        placing_object(),
        SpawningObject { id },
        ContextPriority::<SpawningObject>::new(100),
        SceneRoot::default(),
        actions!(SpawningObject[
            (
                Action::<Buy>::new(),
                ActionSettings {
                    consume_input: true,
                    require_reset: true,
                    ..Default::default()
                },
                bindings![MouseButton::Left, GamepadButton::South]
            ),
        ]),
    )
}

#[derive(Component)]
#[component(immutable)]
#[require(PlacingObject)]
pub(super) struct SpawningObject {
    id: AssetId<ObjectManifest>,
}

#[derive(InputAction)]
#[action_output(bool)]
struct Buy;
