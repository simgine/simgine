use bevy::prelude::*;

use crate::world::cursor::caster::CursorCastSystems;

use super::{caster::CursorHit, outline::OutlineDisabler};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(PreUpdate, update_position.after(CursorCastSystems));
}

fn update_position(
    follower: Single<(&mut Transform, Option<&mut CursorOffset>), With<CursorFollower>>,
    cursor_hit: Single<&CursorHit>,
) {
    let (mut transform, offset) = follower.into_inner();

    let Some(hit) = ***cursor_hit else {
        return;
    };

    let offset = match offset {
        Some(mut offset) => *offset.get_or_insert_with(|| transform.translation - hit),
        None => Vec3::ZERO,
    };

    transform.translation = hit + offset;
}

#[derive(Component, Default)]
#[require(OutlineDisabler)]
pub(crate) struct CursorFollower;

#[derive(Component, Deref, DerefMut, Default)]
pub(crate) struct CursorOffset(Option<Vec3>);
