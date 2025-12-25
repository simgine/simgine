use bevy::prelude::*;
use bevy_enhanced_input::prelude::{Press, *};

use crate::GameState;

pub(crate) fn plugin(app: &mut App) {
    app.add_input_context::<GameSpeed>()
        .add_observer(toggle_pause)
        .add_observer(set_speed::<SetNormal>)
        .add_observer(set_speed::<SetFast>)
        .add_observer(set_speed::<SetUltra>)
        .add_observer(set_time)
        .add_systems(OnEnter(GameState::InGame), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        GameSpeed::default(),
        DespawnOnExit(GameState::InGame),
        actions!(GameSpeed[
            (Action::<TogglePause>::new(), Press::default(), bindings![KeyCode::Digit0]),
            (Action::<SetNormal>::new(), Press::default(), bindings![KeyCode::Digit1]),
            (Action::<SetFast>::new(), Press::default(), bindings![KeyCode::Digit2]),
            (Action::<SetUltra>::new(), Press::default(), bindings![KeyCode::Digit3]),
        ]),
    ));
}

fn toggle_pause(
    toggle_pause: On<Fire<TogglePause>>,
    mut commands: Commands,
    game_speed: Single<&GameSpeed>,
) {
    let new_speed = match **game_speed {
        GameSpeed::Running { speed } => GameSpeed::Paused { previous: speed },
        GameSpeed::Paused { previous } => GameSpeed::Running { speed: previous },
    };
    commands.entity(toggle_pause.context).insert(new_speed);
}

fn set_speed<A: SpeedAction>(fire: On<Fire<A>>, mut commands: Commands) {
    commands
        .entity(fire.context)
        .insert(GameSpeed::Running { speed: A::SPEED });
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

#[derive(InputAction)]
#[action_output(bool)]
pub struct TogglePause;

#[derive(InputAction)]
#[action_output(bool)]
pub struct SetNormal;

impl SpeedAction for SetNormal {
    const SPEED: RunSpeed = RunSpeed::Normal;
}

#[derive(InputAction)]
#[action_output(bool)]
pub struct SetFast;

impl SpeedAction for SetFast {
    const SPEED: RunSpeed = RunSpeed::Fast;
}

#[derive(InputAction)]
#[action_output(bool)]
pub struct SetUltra;

impl SpeedAction for SetUltra {
    const SPEED: RunSpeed = RunSpeed::Ultra;
}

trait SpeedAction: InputAction {
    const SPEED: RunSpeed;
}
