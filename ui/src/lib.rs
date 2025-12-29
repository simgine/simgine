pub(crate) mod button_action;
mod hud;

use bevy::prelude::*;

pub struct SimgineUiPlugin;

impl Plugin for SimgineUiPlugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((button_action::plugin, hud::plugin));
    }
}
