use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

use crate::player_camera::PlayerCamera;

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<CursorFollower>()
        .add_observer(cancel)
        .add_systems(
            Update,
            update_position.run_if(any_with_component::<CursorFollower>),
        );
}

fn cancel(cancel: On<Fire<Cancel>>, mut commands: Commands) {
    commands.entity(cancel.context).despawn();
}

fn update_position(
    window: Single<&Window>,
    camera: Single<(&GlobalTransform, &Camera), With<PlayerCamera>>,
    follower: Single<(&mut Transform, &CursorFollower)>,
) {
    let (&transform, camera) = *camera;
    let Some(cursor_pos) = window.cursor_position() else {
        return;
    };
    let Ok(ray) = camera.viewport_to_world(&transform, cursor_pos) else {
        return;
    };
    let Some(distance) = ray.intersect_plane(Vec3::ZERO, InfinitePlane3d::new(Vec3::Y)) else {
        return;
    };
    let point = ray.get_point(distance);

    let (mut transform, follower) = follower.into_inner();
    transform.translation = point + follower.offset;
}

pub fn cursor_follower(offset: Vec3) -> impl Bundle {
    (
        CursorFollower { offset },
        ContextPriority::<CursorFollower>::new(100),
        actions!(CursorFollower[
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
                bindings![KeyCode::Escape, GamepadButton::East]
            )
        ]),
    )
}

#[derive(Component, Default)]
struct CursorFollower {
    offset: Vec3,
}

#[derive(InputAction)]
#[action_output(bool)]
pub(crate) struct Place;

#[derive(InputAction)]
#[action_output(bool)]
struct Cancel;
