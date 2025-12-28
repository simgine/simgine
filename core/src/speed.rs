use bevy::prelude::*;

use crate::{GameState, component_res::ComponentResExt};

pub(crate) fn plugin(app: &mut App) {
    app.register_resource_component::<GameSpeed>()
        .register_resource_component::<Paused>()
        .add_observer(set_speed)
        .add_observer(pause_unpause)
        .add_systems(OnEnter(GameState::InGame), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        GameSpeed::default(),
        Paused::default(),
        DespawnOnExit(GameState::InGame),
    ));
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

#[derive(Component, Deref, DerefMut)]
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

#[derive(Component, Default, Debug, PartialEq, Clone, Copy)]
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
