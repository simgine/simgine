use bevy::prelude::*;
use bevy_enhanced_input::prelude::{Press, *};
use strum::EnumIter;

use crate::GameState;

pub(crate) fn plugin(app: &mut App) {
    app.init_resource::<GameSpeed>()
        .add_input_context::<SpeedControls>()
        .add_observer(set_speed::<TogglePause>)
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

fn set_speed<A: SpeedAction>(_on: On<Fire<A>>, mut speed: ResMut<GameSpeed>) {
    if *speed == GameSpeed::Pause && A::SPEED == GameSpeed::Pause {
        // Toggle if already paused.
        *speed = GameSpeed::Normal;
    } else {
        speed.set_if_neq(A::SPEED);
    }
}

fn set_time(speed: Res<GameSpeed>, mut time: ResMut<Time<Virtual>>) {
    debug!("setting game speed to `{:?}`", *speed);
    time.set_relative_speed(speed.multiplier());
}

#[derive(Resource, EnumIter, Default, Debug, PartialEq)]
pub enum GameSpeed {
    Pause,
    #[default]
    Normal,
    Fast,
    Ultra,
}

impl GameSpeed {
    fn multiplier(&self) -> f32 {
        match self {
            GameSpeed::Pause => 0.0,
            GameSpeed::Normal => 1.0,
            GameSpeed::Fast => 3.0,
            GameSpeed::Ultra => 8.0,
        }
    }
}

#[derive(Component)]
struct SpeedControls;

#[derive(InputAction)]
#[action_output(bool)]
struct TogglePause;

impl SpeedAction for TogglePause {
    const SPEED: GameSpeed = GameSpeed::Pause;
}

#[derive(InputAction)]
#[action_output(bool)]
struct SetNormal;

impl SpeedAction for SetNormal {
    const SPEED: GameSpeed = GameSpeed::Normal;
}

#[derive(InputAction)]
#[action_output(bool)]
struct SetFast;

impl SpeedAction for SetFast {
    const SPEED: GameSpeed = GameSpeed::Fast;
}

#[derive(InputAction)]
#[action_output(bool)]
struct SetUltra;

impl SpeedAction for SetUltra {
    const SPEED: GameSpeed = GameSpeed::Ultra;
}

trait SpeedAction: InputAction {
    const SPEED: GameSpeed;
}
