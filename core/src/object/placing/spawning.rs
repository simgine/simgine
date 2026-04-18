use bevy::prelude::*;
use bevy_enhanced_input::prelude::{Press, *};

use crate::{
    asset_manifest::object::ObjectManifest,
    cursor::follower::CursorFollower,
    object::BuyObject,
    undo::{HistoryCommands, client_command::DespawnOnResponse},
};

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<SpawningObject>()
        .add_observer(init)
        .add_observer(place)
        .add_observer(cancel);
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

fn place(
    place: On<Fire<Place>>,
    mut commands: HistoryCommands,
    asset_server: Res<AssetServer>,
    spawning_object: Single<(&SpawningObject, &Transform)>,
) {
    let (spawning, transform) = *spawning_object;
    let manifest = asset_server.get_path(spawning.id).unwrap();

    info!("spawning '{manifest}'");

    let id = commands.queue_confirmable(BuyObject {
        manifest: manifest.clone_owned(),
        translation: transform.translation,
        rotation: transform.rotation,
    });

    commands
        .entity(place.context)
        .remove_with_requires::<(CursorFollower, SpawningObject)>()
        .despawn_related::<Actions<SpawningObject>>()
        .insert(DespawnOnResponse { id });
}

fn cancel(cancel: On<Fire<Cancel>>, mut commands: Commands) {
    info!("cancelling");
    commands.entity(cancel.context).despawn();
}

pub fn spawning_object(id: AssetId<ObjectManifest>) -> impl Bundle {
    (
        Name::new("spawning object"),
        CursorFollower,
        SceneRoot::default(),
        SpawningObject { id },
        ContextPriority::<SpawningObject>::new(100),
        actions!(SpawningObject[
            (
                Action::<Place>::new(),
                Press::default(),
                ActionSettings {
                    consume_input: true,
                    require_reset: true,
                    ..Default::default()
                },
                bindings![MouseButton::Left, GamepadButton::South]
            ),
            (
                Action::<Cancel>::new(),
                Press::default(),
                ActionSettings {
                    consume_input: true,
                    require_reset: true,
                    ..Default::default()
                },
                bindings![KeyCode::Escape, KeyCode::Delete, GamepadButton::East]
            )
        ]),
    )
}

#[derive(Component)]
#[component(immutable)]
pub(super) struct SpawningObject {
    id: AssetId<ObjectManifest>,
}

#[derive(InputAction)]
#[action_output(bool)]
struct Place;

#[derive(InputAction)]
#[action_output(bool)]
struct Cancel;
