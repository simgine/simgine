mod asset_manifest;
mod city;
pub mod game_speed;
mod player_camera;
mod sky;

use bevy::prelude::*;

pub struct SimgineCorePlugin;

impl Plugin for SimgineCorePlugin {
    fn build(&self, app: &mut App) {
        app.init_state::<GameState>()
            .insert_resource(ClearColor(Color::BLACK))
            .insert_resource(GlobalAmbientLight::NONE)
            .add_plugins((
                asset_manifest::plugin,
                city::plugin,
                game_speed::plugin,
                player_camera::plugin,
                sky::plugin,
            ));
    }
}

#[derive(States, Default, Debug, PartialEq, Eq, Hash, Clone)]
#[states(state_scoped = true)]
enum GameState {
    #[default]
    ManifestsLoading,
    InGame,
}
