use std::{mem, path::PathBuf};

use bevy::prelude::*;

use crate::{error_event::trigger_error, state::GameState};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(load_world.pipe(trigger_error));
}

fn load_world(mut load: On<LoadWorld>, mut commands: Commands) -> Result<()> {
    if !load.path.exists() {
        return Err(format!("{:?} doesn't exist", load.path).into());
    }

    commands.insert_resource(WorldPath(mem::take(&mut load.path)));
    commands.set_state(GameState::World);

    Ok(())
}

#[derive(Event)]
pub struct LoadWorld {
    pub path: PathBuf,
}

#[derive(Resource, Deref)]
struct WorldPath(PathBuf);
