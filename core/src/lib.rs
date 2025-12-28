mod asset_manifest;
mod city;
pub mod clock;
pub mod component_res;
mod player_camera;
mod sky;
pub mod speed;

use bevy::prelude::*;

pub struct SimgineCorePlugin;

impl Plugin for SimgineCorePlugin {
    fn build(&self, app: &mut App) {
        app.init_state::<GameState>()
            .add_sub_state::<FamilyMode>()
            .insert_resource(ClearColor(Color::BLACK))
            .insert_resource(GlobalAmbientLight::NONE)
            .add_plugins((
                asset_manifest::plugin,
                city::plugin,
                clock::plugin,
                component_res::plugin,
                player_camera::plugin,
                sky::plugin,
                speed::plugin,
            ));
    }
}

#[derive(States, Default, Debug, PartialEq, Eq, Hash, Clone)]
#[states(state_scoped = true)]
pub enum GameState {
    #[default]
    ManifestsLoading,
    InGame,
}

#[derive(SubStates, Default, Debug, PartialEq, Eq, Hash, Clone, Copy)]
#[source(GameState = GameState::InGame)]
#[states(state_scoped = true)]
pub enum FamilyMode {
    #[default]
    Life,
    Building,
}
