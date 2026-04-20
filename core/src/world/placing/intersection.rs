use avian3d::prelude::*;
use bevy::prelude::*;

use super::{BlockerId, BlockerRegistry, PlacingBlockers};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(Update, update_blocks);
}

fn update_blocks(
    id: Local<IntersectionId>,
    placing: Single<(&CollidingEntities, &mut PlacingBlockers), With<BlockOnIntersection>>,
) {
    let (collisions, mut blockers) = placing.into_inner();
    if collisions.is_empty() {
        if blockers.remove(&**id) {
            debug!("intersection no longer blocking placement");
        }
    } else if blockers.insert(**id) {
        debug!("blocking placement due to intersection");
    }
}

#[derive(Component)]
#[require(CollidingEntities, PlacingBlockers)]
#[component(immutable)]
pub(crate) struct BlockOnIntersection;

#[derive(Deref)]
struct IntersectionId(BlockerId);

impl FromWorld for IntersectionId {
    fn from_world(world: &mut World) -> Self {
        let mut registry = world.resource_mut::<BlockerRegistry>();
        Self(registry.register("Can't intersect others"))
    }
}
