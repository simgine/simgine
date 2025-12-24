use bevy::prelude::*;
use bevy_enhanced_input::prelude::{Press, *};

use crate::GameState;

pub(crate) fn plugin(app: &mut App) {
    app.init_resource::<GameSpeed>()
        .add_input_context::<SpeedControls>()
        .add_observer(toggle_pause)
        .add_observer(set_speed::<SetNormal>)
        .add_observer(set_speed::<SetFast>)
        .add_observer(set_speed::<SetUltra>)
        .add_systems(OnEnter(GameState::InGame), spawn)
        .add_systems(Update, set_time.run_if(resource_changed::<GameSpeed>));
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        SpeedControls,
        DespawnOnExit(GameState::InGame),
        actions!(SpeedControls[
            (Action::<TogglePause>::new(), Press::default(), bindings![KeyCode::Digit0]),
            (Action::<SetNormal>::new(), Press::default(), bindings![KeyCode::Digit1]),
            (Action::<SetFast>::new(), Press::default(), bindings![KeyCode::Digit2]),
            (Action::<SetUltra>::new(), Press::default(), bindings![KeyCode::Digit3]),
        ]),
    ));
}

fn toggle_pause(_on: On<Fire<TogglePause>>, mut speed: ResMut<GameSpeed>) {
    *speed = match *speed {
        GameSpeed::Running { speed } => GameSpeed::Paused { previous: speed },
        GameSpeed::Paused { previous } => GameSpeed::Running { speed: previous },
    };
}

fn set_speed<A: SpeedAction>(_on: On<Fire<A>>, mut speed: ResMut<GameSpeed>) {
    *speed = GameSpeed::Running { speed: A::SPEED };
}

fn set_time(speed: Res<GameSpeed>, mut time: ResMut<Time<Virtual>>) {
    debug!("setting game speed to `{:?}`", *speed);
    time.set_relative_speed(speed.multiplier());
}

#[derive(Resource, Debug, Clone, Copy)]
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

#[derive(Component)]
struct SpeedControls;

#[derive(InputAction)]
#[action_output(bool)]
struct TogglePause;

#[derive(InputAction)]
#[action_output(bool)]
struct SetNormal;

impl SpeedAction for SetNormal {
    const SPEED: RunSpeed = RunSpeed::Normal;
}

#[derive(InputAction)]
#[action_output(bool)]
struct SetFast;

impl SpeedAction for SetFast {
    const SPEED: RunSpeed = RunSpeed::Fast;
}

#[derive(InputAction)]
#[action_output(bool)]
struct SetUltra;

impl SpeedAction for SetUltra {
    const SPEED: RunSpeed = RunSpeed::Ultra;
}

trait SpeedAction: InputAction {
    const SPEED: RunSpeed;
}
