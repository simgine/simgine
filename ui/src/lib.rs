pub(crate) mod action_button;
mod hud;

use bevy::prelude::*;

pub struct SimgineUiPlugin;

impl Plugin for SimgineUiPlugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((action_button::plugin, hud::plugin));
    }
}
