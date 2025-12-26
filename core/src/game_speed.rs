use bevy::prelude::*;

use crate::GameState;

pub(crate) fn plugin(app: &mut App) {
    app.add_observer(set_time)
        .add_systems(OnEnter(GameState::InGame), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((GameSpeed::default(), DespawnOnExit(GameState::InGame)));
}

fn set_time(
    _on: On<Insert, GameSpeed>,
    mut time: ResMut<Time<Virtual>>,
    game_speed: Single<&GameSpeed>,
) {
    debug!("setting game speed to `{:?}`", *game_speed);
    time.set_relative_speed(game_speed.multiplier());
}

#[derive(Component, Debug, Clone, Copy)]
#[component(immutable)]
pub enum GameSpeed {
    Paused { previous: RunSpeed },
    Running { speed: RunSpeed },
}

impl GameSpeed {
    fn multiplier(&self) -> f32 {
        match self {
            GameSpeed::Paused { .. } => 0.0,
            GameSpeed::Running { speed } => speed.multiplier(),
        }
    }
}

impl Default for GameSpeed {
    fn default() -> Self {
        Self::Paused {
            previous: RunSpeed::Normal,
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum RunSpeed {
    Normal,
    Fast,
    Ultra,
}

impl RunSpeed {
    fn multiplier(&self) -> f32 {
        match self {
            RunSpeed::Normal => 1.0,
            RunSpeed::Fast => 3.0,
            RunSpeed::Ultra => 8.0,
        }
    }
}
