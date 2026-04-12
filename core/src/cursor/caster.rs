use avian3d::prelude::*;
use bevy::{ecs::system::SystemParam, prelude::*};

use crate::player_camera::PlayerCamera;

#[derive(SystemParam)]
pub(crate) struct CursorCaster<'w, 's> {
    query: SpatialQuery<'w, 's>,
    window: Single<'w, 's, &'static Window>,
    player_camera: Single<'w, 's, (&'static Camera, &'static GlobalTransform), With<PlayerCamera>>,
}

impl CursorCaster<'_, '_> {
    pub(crate) fn cast_ray(&self, mask: impl Into<LayerMask>) -> Option<Vec3> {
        let cursor_pos = self.window.cursor_position()?;
        let (camera, transform) = *self.player_camera;
        let ray = camera.viewport_to_world(transform, cursor_pos).ok()?;
        let hit = self.query.cast_ray(
            ray.origin,
            ray.direction,
            f32::MAX,
            true,
            &SpatialQueryFilter::from_mask(mask),
        )?;

        Some(ray.get_point(hit.distance))
    }
}
