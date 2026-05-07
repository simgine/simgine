mod camera;
mod main_menu;
mod pause_menu;

use bevy::prelude::*;
use simgine_core::state::GameState;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((camera::plugin, pause_menu::plugin, main_menu::plugin))
        .add_sub_state::<MenuState>();
}

#[derive(SubStates, Clone, PartialEq, Eq, Hash, Debug, Default)]
#[source(GameState = GameState::Menu)]
#[states(state_scoped = true)]
enum MenuState {
    #[default]
    MainMenu,
    WorldBrowser,
}
