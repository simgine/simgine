pub mod asset_manifest;
mod city;
mod combined_collider;
pub mod component_res;
mod cursor;
pub mod error_event;
pub mod game_paths;
mod layer;
pub mod network;
pub mod object;
mod player_camera;
mod preview;
mod sky;
pub mod speed;
pub mod state;
pub mod time;
mod tint;
pub mod undo;
pub mod world;

use bevy::prelude::*;

pub struct SimgineCorePlugin;

impl Plugin for SimgineCorePlugin {
    fn build(&self, app: &mut App) {
        app.insert_resource(GlobalAmbientLight::NONE)
            .add_plugins((
                state::plugin,
                asset_manifest::plugin,
                city::plugin,
                combined_collider::plugin,
                time::plugin,
                tint::plugin,
                component_res::plugin,
                cursor::plugin,
                undo::plugin,
                game_paths::plugin,
            ))
            .add_plugins((
                preview::plugin,
                network::plugin,
                object::plugin,
                player_camera::plugin,
                sky::plugin,
                speed::plugin,
                world::plugin,
            ));
    }
}
