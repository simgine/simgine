pub mod asset_manifest;
pub mod component_res;
pub mod error_event;
pub mod game_paths;
pub mod network;
pub mod state;
pub mod undo;
pub mod world;

use bevy::prelude::*;

pub struct SimgineCorePlugin;

impl Plugin for SimgineCorePlugin {
    fn build(&self, app: &mut App) {
        app.insert_resource(GlobalAmbientLight::NONE).add_plugins((
            asset_manifest::plugin,
            component_res::plugin,
            game_paths::plugin,
            network::plugin,
            state::plugin,
            undo::plugin,
            world::plugin,
        ));
    }
}
