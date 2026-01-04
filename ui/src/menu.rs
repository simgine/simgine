mod camera;
mod main_menu;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((camera::plugin, main_menu::plugin));
}
