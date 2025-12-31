mod hud;
mod preview;
mod widget;

use bevy::prelude::*;

pub struct SimgineUiPlugin;

impl Plugin for SimgineUiPlugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((hud::plugin, preview::plugin, widget::plugin));
    }
}
