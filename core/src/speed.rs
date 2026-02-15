use bevy::prelude::*;
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::{component_res::ComponentResExt, state::GameState};

pub(super) fn plugin(app: &mut App) {
    app.register_resource_component::<GameSpeed>()
        .register_resource_component::<Paused>()
        .replicate::<GameSpeed>()
        .replicate::<Paused>()
        .add_observer(set_speed)
        .add_observer(pause_unpause)
        .add_systems(
            OnEnter(GameState::World),
            spawn.run_if(not(in_state(ClientState::Connected))),
        );
}

fn spawn(mut commands: Commands) {
    commands.spawn(GameSpeed::default());
    commands.spawn(Paused::default());
}

fn set_speed(
    _on: On<Insert, GameSpeed>,
    mut time: ResMut<Time<Virtual>>,
    paused: Single<&Paused>,
    game_speed: Single<&GameSpeed>,
) {
    if !***paused {
        info!("setting speed to `{:?}`", *game_speed);
        time.set_relative_speed(game_speed.multiplier());
    }
}

fn pause_unpause(
    _on: On<Insert, Paused>,
    mut time: ResMut<Time<Virtual>>,
    paused: Single<&Paused>,
    game_speed: Single<&GameSpeed>,
) {
    if ***paused {
        info!("pausing the game");
        time.set_relative_speed(0.0);
    } else {
        info!("unpausing game");
        time.set_relative_speed(game_speed.multiplier());
    }
}

#[derive(Component, Deref, DerefMut, Serialize, Deserialize)]
#[require(
    Name::new("Paused"),
    Replicated,
    DespawnOnExit::<_>(GameState::World)
)]
#[component(immutable)]
pub struct Paused(pub bool);

impl Paused {
    pub fn toggled(&self) -> Self {
        Self(!self.0)
    }
}

impl Default for Paused {
    fn default() -> Self {
        Self(true)
    }
}

#[derive(Component, Default, Serialize, Deserialize, Debug, PartialEq, Clone, Copy)]
#[require(
    Name::new("Game speed"),
    Replicated,
    DespawnOnExit::<_>(GameState::World)
)]
#[component(immutable)]
pub enum GameSpeed {
    #[default]
    Normal,
    Fast,
    Ultra,
}

impl GameSpeed {
    fn multiplier(&self) -> f32 {
        match self {
            GameSpeed::Normal => 1.0,
            GameSpeed::Fast => 3.0,
            GameSpeed::Ultra => 8.0,
        }
    }
}
