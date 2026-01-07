mod camera;
mod main_menu;
mod pause_menu;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((camera::plugin, pause_menu::plugin, main_menu::plugin));
}
