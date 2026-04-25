mod moving;
pub mod spawning;

use std::f32::consts::FRAC_PI_4;

use avian3d::prelude::*;
use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

use crate::world::{
    combined_collider::CombinedCollider,
    cursor::{caster::CursorMask, follower::CursorFollower},
    layer::GameLayer,
    placing::intersection::BlockOnIntersection,
    player_camera::HOLD_TO_PAN,
};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((spawning::plugin, moving::plugin))
        .add_input_context::<PlacingObject>()
        .add_observer(rotate)
        .add_observer(cancel);
}

fn rotate(_on: On<Fire<Rotate>>, mut transform: Single<&mut Transform, With<PlacingObject>>) {
    transform.rotation *= Quat::from_axis_angle(Vec3::Y, FRAC_PI_4);

    let (yaw, _, _) = transform.rotation.to_euler(EulerRot::YXZ);
    info!("rotating to '{}'", yaw.to_degrees());
}

fn cancel(cancel: On<Start<Cancel>>, mut commands: Commands) {
    info!("cancelling");
    commands.entity(cancel.context).despawn();
}

#[derive(Component, Default)]
#[require(CursorFollower)]
struct PlacingObject;

pub fn placing_object() -> impl Bundle {
    (
        PlacingObject,
        BlockOnIntersection,
        RigidBody::Static,
        Sensor,
        CombinedCollider::Aabb,
        CollisionLayers::new(GameLayer::Preview, GameLayer::Object),
        CursorMask::new(GameLayer::Ground),
        actions!(
            PlacingObject[
                (
                    Action::<Rotate>::new(),
                    Tap::new(HOLD_TO_PAN), // Rotate if released quicker than pan.
                    Bindings::spawn((
                        Bidirectional::new(KeyCode::Comma, KeyCode::Period),
                        Spawn(Binding::from(MouseButton::Right)),
                        Spawn(Binding::from(GamepadButton::West)),
                    )),
                ),
                (
                    Action::<Cancel>::new(),
                    ActionSettings {
                        consume_input: true,
                        require_reset: true,
                        ..Default::default()
                    },
                    bindings![KeyCode::Escape, KeyCode::Delete, GamepadButton::East]
                ),
            ]
        ),
    )
}

#[derive(InputAction)]
#[action_output(f32)]
struct Rotate;

#[derive(InputAction)]
#[action_output(bool)]
struct Cancel;
