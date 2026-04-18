mod connection_dialog;
mod error_dialog;
mod hud;
mod menu;
mod thumbnail;
mod widget;

use bevy::prelude::*;

pub struct SimgineUiPlugin;

impl Plugin for SimgineUiPlugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((
            connection_dialog::plugin,
            error_dialog::plugin,
            hud::plugin,
            menu::plugin,
            thumbnail::plugin,
            widget::plugin,
        ));
    }
}
