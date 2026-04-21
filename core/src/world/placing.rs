pub(super) mod intersection;
mod tint;

use bevy::{
    color::palettes::tailwind::{BLUE_600, RED_600},
    platform::collections::{HashMap, HashSet},
    prelude::*,
};

use tint::Tint;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((tint::plugin, intersection::plugin))
        .init_resource::<BlockerRegistry>()
        .add_systems(PostUpdate, update_tint);
}

fn update_tint(mut commands: Commands, mut placing: Query<(Entity, &PlacingBlockers, &Tint)>) {
    for (placing_entity, blockers, tint) in &mut placing {
        let color = if blockers.is_empty() {
            ALLOWED.into()
        } else {
            BLOCKED.into()
        };

        if tint.color != color {
            commands.entity(placing_entity).insert(Tint { color });
        }
    }
}

const ALLOWED: Srgba = BLUE_600;
const BLOCKED: Srgba = RED_600;

#[derive(Component, Deref, DerefMut, Default)]
#[require(Tint { color: ALLOWED.into() })]
pub(super) struct PlacingBlockers(HashSet<BlockerId>);

#[derive(Resource, Default)]
pub(super) struct BlockerRegistry {
    next_id: BlockerId,
    descriptions: HashMap<BlockerId, String>,
}

impl BlockerRegistry {
    pub(super) fn register(&mut self, description: impl Into<String>) -> BlockerId {
        let id = self.next_id;
        self.next_id.0 += 1;
        self.descriptions.insert(id, description.into());
        id
    }
}

#[derive(Default, Debug, Hash, PartialEq, Eq, Clone, Copy)]
pub(super) struct BlockerId(u64);
