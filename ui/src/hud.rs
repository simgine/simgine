mod family;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(family::plugin);
}
