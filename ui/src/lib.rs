pub(crate) mod action_button;
mod time_panel;

use bevy::prelude::*;

pub struct SimgineUiPlugin;

impl Plugin for SimgineUiPlugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((action_button::plugin, time_panel::plugin));
    }
}
