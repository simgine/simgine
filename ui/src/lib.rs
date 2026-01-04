mod error_dialog;
mod hud;
mod menu;
mod preview;
mod widget;

use bevy::prelude::*;

pub struct SimgineUiPlugin;

impl Plugin for SimgineUiPlugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((
            error_dialog::plugin,
            hud::plugin,
            menu::plugin,
            preview::plugin,
            widget::plugin,
        ));
    }
}
