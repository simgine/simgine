use std::mem;

use bevy::prelude::*;
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::{
    component_res::{ComponentResExt, InsertComponentResExt},
    error_event::trigger_error,
    game_paths::GamePaths,
    state::GameState,
};

pub(super) fn plugin(app: &mut App) {
    app.register_resource_component::<WorldName>()
        .replicate::<WorldName>()
        .add_observer(load_world.pipe(trigger_error))
        .add_observer(update_state);
}

fn load_world(
    mut load: On<LoadWorld>,
    mut commands: Commands,
    game_paths: Res<GamePaths>,
) -> Result<()> {
    let path = game_paths.world_path(&load.name);
    info!("loading {path:?}");

    if !path.exists() {
        return Err(format!("{path:?} doesn't exist").into());
    }

    commands.insert_component_resource(WorldName(mem::take(&mut load.name)));

    Ok(())
}

fn update_state(
    _on: On<Insert, WorldName>,
    mut commands: Commands,
    world_name: Single<&WorldName>,
) {
    info!("entering '{}'", ***world_name);
    commands.set_state(GameState::World);
}

#[derive(Event)]
pub struct LoadWorld {
    pub name: String,
}

#[derive(Component, Deref, Serialize, Deserialize)]
#[require(Replicated, DespawnOnExit::<GameState>(GameState::World))]
struct WorldName(String);
