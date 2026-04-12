use avian3d::prelude::*;
use bevy::{ecs::system::SystemParam, input::InputSystems, prelude::*};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(PreUpdate, cast_ray.pipe(update).after(InputSystems));
}

fn cast_ray(query: CursorQuery, cast_mask: Single<&CursorCastMask>) -> Option<(Entity, Vec3)> {
    query.cast_ray(***cast_mask)
}

fn update(
    input: In<Option<(Entity, Vec3)>>,
    mut commands: Commands,
    caster_camera: Single<(Entity, &CursorTarget, &mut CursorHit)>,
) {
    let (caster_entity, target, mut hit) = caster_camera.into_inner();
    let (new_target, new_hit) = input.unzip();
    let mut caster_entity = commands.entity(caster_entity);

    if **target != new_target {
        caster_entity.insert(CursorTarget(new_target));
    }

    hit.0 = new_hit;
}

#[derive(SystemParam)]
pub(crate) struct CursorQuery<'w, 's> {
    spatial_query: SpatialQuery<'w, 's>,
    window: Single<'w, 's, &'static Window>,
    caster_camera: Single<'w, 's, (&'static Camera, &'static GlobalTransform), With<CursorCaster>>,
}

impl CursorQuery<'_, '_> {
    pub(crate) fn cast_ray(&self, mask: impl Into<LayerMask>) -> Option<(Entity, Vec3)> {
        let cursor_pos = self.window.cursor_position()?;
        let (camera, transform) = *self.caster_camera;
        let ray = camera.viewport_to_world(transform, cursor_pos).ok()?;
        let hit = self.spatial_query.cast_ray(
            ray.origin,
            ray.direction,
            f32::MAX,
            true,
            &SpatialQueryFilter::from_mask(mask),
        )?;

        Some((hit.entity, ray.get_point(hit.distance)))
    }
}

#[derive(Component)]
#[require(CursorTarget, CursorHit, CursorCastMask)]
pub(crate) struct CursorCaster;

#[derive(Component, Deref, DerefMut)]
pub(crate) struct CursorCastMask(LayerMask);

impl Default for CursorCastMask {
    fn default() -> Self {
        Self(LayerMask::ALL)
    }
}

#[derive(Component, Deref, Default)]
#[component(immutable)]
pub(crate) struct CursorTarget(Option<Entity>);

#[derive(Component, Deref, Default)]
pub(crate) struct CursorHit(Option<Vec3>);
