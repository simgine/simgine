mod moving;
pub mod spawning;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((spawning::plugin, moving::plugin));
}
