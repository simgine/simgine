pub(crate) mod caster;
pub(crate) mod follower;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(follower::plugin);
}
