use bevy::prelude::*;

use crate::{cursor::caster::CursorCaster, layer::GameLayer};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(
        Update,
        update_position.run_if(any_with_component::<CursorFollower>),
    );
}

fn update_position(caster: CursorCaster, follower: Single<(&mut Transform, &CursorFollower)>) {
    let Some(point) = caster.cast_ray(GameLayer::Ground) else {
        return;
    };

    let (mut transform, follower) = follower.into_inner();
    transform.translation = point + follower.offset;
}

#[derive(Component, Default)]
pub(crate) struct CursorFollower {
    offset: Vec3,
}
