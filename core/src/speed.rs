use bevy::prelude::*;
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::{
    component_res::{ComponentResExt, InsertComponentResExt},
    state::GameState,
    world::CreateWorld,
};

pub(super) fn plugin(app: &mut App) {
    app.register_resource_component::<GameSpeed>()
        .register_resource_component::<Paused>()
        .add_client_event::<SetPaused>(Channel::Ordered)
        .add_client_event::<SetSpeed>(Channel::Ordered)
        .replicate::<GameSpeed>()
        .replicate::<Paused>()
        .add_observer(spawn)
        .add_observer(set_paused)
        .add_observer(set_speed)
        .add_observer(apply_speed)
        .add_observer(apply_paused);
}

fn spawn(_on: On<CreateWorld>, mut commands: Commands) {
    commands.spawn(GameSpeed::default());
    commands.spawn(Paused::default());
}

fn set_paused(paused: On<FromClient<SetPaused>>, mut commands: Commands) {
    commands.insert_component_resource(Paused(***paused));
}

fn set_speed(speed: On<FromClient<SetSpeed>>, mut commands: Commands, paused: Single<&Paused>) {
    commands.insert_component_resource(***speed);
    if ***paused {
        commands.insert_component_resource(Paused(false));
    }
}

fn apply_paused(
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

fn apply_speed(
    _on: On<Insert, GameSpeed>,
    mut time: ResMut<Time<Virtual>>,
    paused: Single<&Paused>,
    game_speed: Single<&GameSpeed>,
) {
    info!("setting speed to `{:?}`", *game_speed);
    if !***paused {
        time.set_relative_speed(game_speed.multiplier());
    }
}

#[derive(Event, Deref, Serialize, Deserialize)]
pub struct SetPaused(pub bool);

#[derive(Component, Deref, DerefMut, Reflect, Serialize, Deserialize)]
#[require(
    Name::new("Paused"),
    Replicated,
    DespawnOnExit::<_>(GameState::World)
)]
#[component(immutable)]
#[reflect(Component)]
pub struct Paused(bool);

impl Default for Paused {
    fn default() -> Self {
        Self(true)
    }
}

#[derive(Event, Deref, Serialize, Deserialize)]
pub struct SetSpeed(pub GameSpeed);

#[derive(Component, Reflect, Default, Serialize, Deserialize, Debug, PartialEq, Clone, Copy)]
#[require(
    Name::new("Game speed"),
    Replicated,
    DespawnOnExit::<_>(GameState::World)
)]
#[component(immutable)]
#[reflect(Component)]
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
