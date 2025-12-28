pub(crate) mod action_button;
mod building_mode_panel;
mod family_mode_panel;
mod time_panel;

use bevy::prelude::*;

pub struct SimgineUiPlugin;

impl Plugin for SimgineUiPlugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((
            action_button::plugin,
            building_mode_panel::plugin,
            family_mode_panel::plugin,
            time_panel::plugin,
        ));
    }
}
