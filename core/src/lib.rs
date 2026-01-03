pub mod asset_manifest;
mod city;
pub mod component_res;
pub mod game_paths;
mod player_camera;
mod sky;
pub mod speed;
pub mod state;
pub mod time;

use bevy::prelude::*;

pub struct SimgineCorePlugin;

impl Plugin for SimgineCorePlugin {
    fn build(&self, app: &mut App) {
        app.insert_resource(GlobalAmbientLight::NONE).add_plugins((
            state::plugin,
            asset_manifest::plugin,
            city::plugin,
            time::plugin,
            component_res::plugin,
            game_paths::plugin,
            player_camera::plugin,
            sky::plugin,
            speed::plugin,
        ));
    }
}
