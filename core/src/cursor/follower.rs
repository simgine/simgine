use bevy::prelude::*;

use super::{caster::CursorHit, outline::OutlineDisabler};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(Update, update_position);
}

fn update_position(
    follower: Single<(&mut Transform, &CursorFollower)>,
    cursor_hit: Single<&CursorHit>,
) {
    if let Some(hit) = ***cursor_hit {
        let (mut transform, follower) = follower.into_inner();
        transform.translation = hit + follower.offset;
    }
}

#[derive(Component, Default)]
#[require(OutlineDisabler)]
pub(crate) struct CursorFollower {
    pub(crate) offset: Vec3,
}
