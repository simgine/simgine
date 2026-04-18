mod moving;
pub mod spawning;

use bevy::prelude::*;
use bevy_enhanced_input::prelude::{Press, *};

use crate::{
    cursor::{caster::CursorMask, follower::CursorFollower},
    layer::GameLayer,
};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((spawning::plugin, moving::plugin))
        .add_input_context::<PlacingObject>()
        .add_observer(cancel);
}

fn cancel(cancel: On<Fire<Cancel>>, mut commands: Commands) {
    info!("cancelling");
    commands.entity(cancel.context).despawn();
}

#[derive(Component)]
#[require(CursorFollower)]
struct PlacingObject;

pub fn placing_object() -> impl Bundle {
    (
        PlacingObject,
        ContextPriority::<PlacingObject>::new(100),
        CursorMask::new(GameLayer::Ground),
        actions!(
            PlacingObject[(
                Action::<Cancel>::new(),
                Press::default(),
                ActionSettings {
                    consume_input: true,
                    require_reset: true,
                    ..Default::default()
                },
                bindings![KeyCode::Escape, KeyCode::Delete, GamepadButton::East]
            )]
        ),
    )
}

#[derive(InputAction)]
#[action_output(bool)]
struct Cancel;
