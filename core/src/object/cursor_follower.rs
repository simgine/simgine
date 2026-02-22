use bevy::prelude::*;

use crate::player_camera::PlayerCamera;

pub(super) fn plugin(app: &mut App) {
    app.add_systems(
        Update,
        update_position.run_if(any_with_component::<CursorFollower>),
    );
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

#[derive(Component)]
pub(super) struct CursorFollower {
    pub(super) offset: Vec3,
}
