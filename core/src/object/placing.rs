use bevy::{asset::AssetPath, prelude::*};
use bevy_enhanced_input::prelude::*;

use crate::{cursor_follower::CursorFollower, object::Object};

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<PlacingObject>()
        .add_observer(place)
        .add_observer(cancel);
}

fn place(cancel: On<Fire<Place>>, mut commands: Commands, objects: Query<&Object>) {
    commands.entity(cancel.context).despawn();
    let object = objects.get(cancel.context).unwrap();
    info!("placing '{}'", object.path);
}

fn cancel(cancel: On<Fire<Cancel>>, mut commands: Commands) {
    info!("cancelling");
    commands.entity(cancel.context).despawn();
}

pub fn placing_object(path: AssetPath<'static>) -> impl Bundle {
    (
        Object { path },
        CursorFollower::default(),
        PlacingObject,
        ContextPriority::<PlacingObject>::new(100),
        actions!(PlacingObject[
            (
                Action::<Place>::new(),
                ActionSettings {
                    consume_input: true,
                    require_reset: true,
                    ..Default::default()
                },
                bindings![MouseButton::Left, GamepadButton::South]
            ),
            (
                Action::<Cancel>::new(),
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
struct PlacingObject;

#[derive(InputAction)]
#[action_output(bool)]
struct Place;

#[derive(InputAction)]
#[action_output(bool)]
struct Cancel;
