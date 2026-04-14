use avian3d::prelude::*;
use bevy::{input::InputSystems, prelude::*};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(
        PreUpdate,
        cast_ray
            .pipe(update)
            .after(InputSystems)
            .in_set(CursorCastSystems),
    );
}

fn cast_ray(
    query: SpatialQuery,
    window: Single<&Window>,
    caster_camera: Single<(&Camera, &GlobalTransform, &CursorCaster)>,
    mask_override: Option<Single<&CursorMaskOverride>>,
) -> Option<(Entity, Vec3)> {
    let cursor_pos = window.cursor_position()?;
    let (camera, transform, caster) = *caster_camera;
    let ray = camera.viewport_to_world(transform, cursor_pos).ok()?;
    let mask = mask_override.map(|m| m.0).unwrap_or(caster.mask);
    let hit = query.cast_ray(
        ray.origin,
        ray.direction,
        f32::MAX,
        true,
        &SpatialQueryFilter::from_mask(mask),
    )?;

    Some((hit.entity, ray.get_point(hit.distance)))
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

#[derive(SystemSet, Debug, PartialEq, Eq, Hash, Clone)]
pub(super) struct CursorCastSystems;

#[derive(Component)]
#[require(CursorTarget, CursorHit)]
pub(crate) struct CursorCaster {
    mask: LayerMask,
}

impl Default for CursorCaster {
    fn default() -> Self {
        Self {
            mask: LayerMask::ALL,
        }
    }
}

#[derive(Component, Deref, Default)]
#[component(immutable)]
pub(crate) struct CursorTarget(Option<Entity>);

#[derive(Component, Deref, Default)]
pub(crate) struct CursorHit(Option<Vec3>);

#[derive(Component)]
pub(crate) struct CursorMaskOverride(LayerMask);

impl CursorMaskOverride {
    pub(crate) fn new(mask: impl Into<LayerMask>) -> Self {
        Self(mask.into())
    }
}
