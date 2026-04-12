pub(crate) mod caster;
pub(crate) mod follower;
pub(crate) mod outline;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((follower::plugin, caster::plugin, outline::plugin));
}
