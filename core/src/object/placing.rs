use bevy::prelude::*;
use bevy_enhanced_input::prelude::{Press, *};

use crate::{
    asset_manifest::ObjectManifest,
    cursor_follower::CursorFollower,
    object::BuyObject,
    undo::{HistoryCommands, request::DespawnOnResponse},
};

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<PlacingObject>()
        .add_observer(init)
        .add_observer(place)
        .add_observer(cancel);
}

fn init(
    insert: On<Insert, PlacingObject>,
    asset_server: Res<AssetServer>,
    manifests: Res<Assets<ObjectManifest>>,
    mut placing_objects: Query<(&PlacingObject, &mut SceneRoot)>,
) {
    let (placing, mut scene_root) = placing_objects.get_mut(insert.entity).unwrap();
    let manifest = manifests
        .get(placing.id)
        .expect("manifests should be preloaded");

    debug!("loading scene `{}`", manifest.scene);

    **scene_root = asset_server.load(manifest.scene.clone());
}

fn place(
    place: On<Fire<Place>>,
    mut commands: HistoryCommands,
    asset_server: Res<AssetServer>,
    placing_object: Single<(&PlacingObject, &Transform)>,
) {
    let (placing, transform) = *placing_object;
    let manifest = asset_server.get_path(placing.id).unwrap();

    info!("placing '{manifest}'");

    let id = commands.queue_confirmable(BuyObject {
        manifest: manifest.clone_owned(),
        translation: transform.translation,
        rotation: transform.rotation,
    });

    commands
        .entity(place.context)
        .remove_with_requires::<(CursorFollower, PlacingObject)>()
        .despawn_related::<Actions<PlacingObject>>()
        .insert(DespawnOnResponse::<BuyObject>::new(id));
}

fn cancel(cancel: On<Fire<Cancel>>, mut commands: Commands) {
    info!("cancelling");
    commands.entity(cancel.context).despawn();
}

pub fn placing_object(id: AssetId<ObjectManifest>) -> impl Bundle {
    (
        Name::new("Placing object"),
        CursorFollower::default(),
        SceneRoot::default(),
        PlacingObject { id },
        ContextPriority::<PlacingObject>::new(100),
        actions!(PlacingObject[
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
struct PlacingObject {
    id: AssetId<ObjectManifest>,
}

#[derive(InputAction)]
#[action_output(bool)]
struct Place;

#[derive(InputAction)]
#[action_output(bool)]
struct Cancel;
