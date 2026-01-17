use std::mem;

use bevy::prelude::*;

use crate::{error_event::trigger_error, game_paths::GamePaths, state::GameState};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(load_world.pipe(trigger_error));
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

    commands.insert_resource(WorldName(mem::take(&mut load.name)));
    commands.set_state(GameState::World);

    Ok(())
}

#[derive(Event)]
pub struct LoadWorld {
    pub name: String,
}

#[derive(Resource, Deref)]
struct WorldName(String);
