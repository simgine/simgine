use avian3d::prelude::*;
use bevy::{
    ecs::{lifecycle::HookContext, world::DeferredWorld},
    input::InputSystems,
    prelude::*,
};
use bevy_enhanced_input::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.init_resource::<CursorMaskEntities>().add_systems(
        PreUpdate,
        cast_ray
            .pipe(update)
            .after(InputSystems)
            .after(EnhancedInputSystems::Apply)
            .in_set(CursorCastSystems),
    );
}

fn cast_ray(
    query: SpatialQuery,
    window: Single<&Window>,
    mask_entities: Res<CursorMaskEntities>,
    caster_camera: Single<(&Camera, &GlobalTransform), With<CursorCaster>>,
    masks: Query<&CursorMask>,
    disablers: Query<&CursorCastDisabler>,
) -> Option<(Entity, Vec3)> {
    if !disablers.is_empty() {
        return None;
    }

    let cursor_pos = window.cursor_position()?;
    let mask_entity = *mask_entities.last()?;
    let mask = **masks.get(mask_entity).ok()?;
    let (camera, transform) = *caster_camera;
    let ray = camera.viewport_to_world(transform, cursor_pos).ok()?;
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

/// List of entities with masks in their spawn order.
#[derive(Resource, Default, Deref, DerefMut)]
struct CursorMaskEntities(Vec<Entity>);

#[derive(Component, Default)]
#[require(CursorTarget, CursorHit)]
pub(crate) struct CursorCaster;

#[derive(Component, Deref, Default)]
#[component(immutable)]
pub(crate) struct CursorTarget(Option<Entity>);

#[derive(Component, Deref, Default)]
pub(crate) struct CursorHit(Option<Vec3>);

/// Configures [`CursorCaster`].
///
/// Can be inserted on any entity. Last inserted mask takes priority.
#[derive(Component, Deref)]
#[component(on_add = on_mask_add, on_remove = on_mask_remove)]
pub(crate) struct CursorMask(LayerMask);

impl CursorMask {
    pub(crate) fn new(mask: impl Into<LayerMask>) -> Self {
        Self(mask.into())
    }
}

fn on_mask_add(mut world: DeferredWorld, context: HookContext) {
    let mut caster = world.resource_mut::<CursorMaskEntities>();
    caster.push(context.entity);
}

fn on_mask_remove(mut world: DeferredWorld, context: HookContext) {
    let mut caster = world.resource_mut::<CursorMaskEntities>();
    let index = caster.iter().position(|&e| e == context.entity).unwrap();
    caster.remove(index);
}

#[derive(Component)]
pub struct CursorCastDisabler;
