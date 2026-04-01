pub mod asset_manifest;
mod city;
pub mod component_res;
mod cursor_follower;
pub mod error_event;
pub mod game_paths;
pub mod network;
pub mod object;
mod outline;
mod player_camera;
mod sky;
pub mod speed;
pub mod state;
pub mod time;
pub mod undo;
pub mod world;

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
            cursor_follower::plugin,
            undo::plugin,
            game_paths::plugin,
            network::plugin,
            object::plugin,
            outline::plugin,
            player_camera::plugin,
            sky::plugin,
            speed::plugin,
            world::plugin,
        ));
    }
}
