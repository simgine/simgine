use bevy::prelude::*;
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::state::GameState;

pub(super) fn plugin(app: &mut App) {
    app.replicate::<MemberOf>();
}

#[derive(Component, Deref, DerefMut, Reflect, Serialize, Deserialize)]
#[relationship(relationship_target = Family)]
pub struct MemberOf(pub Entity);

#[derive(Component, Deref)]
#[require(
    Name,
    DespawnOnExit::<_>(GameState::World),
)]
#[relationship_target(relationship = MemberOf, linked_spawn)]
pub struct Family(Vec<Entity>);
