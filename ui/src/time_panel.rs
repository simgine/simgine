use std::fmt::Debug;

use bevy::{
    color::palettes::tailwind::{BLUE_500, RED_500},
    prelude::*,
};
use bevy_enhanced_input::prelude::{Press, *};
use simgine_core::{
    FamilyMode,
    component_res::InsertComponentResExt,
    speed::{GameSpeed, RunSpeed},
};

use crate::utils;

pub(crate) fn plugin(app: &mut App) {
    app.add_input_context::<SpeedPanel>()
        .add_observer(toggle_pause)
        .add_observer(set_speed::<SetNormal>)
        .add_observer(set_speed::<SetFast>)
        .add_observer(set_speed::<SetUltra>)
        .add_observer(reset_speed_buttons)
        .add_observer(update_speed_buttons)
        .add_systems(OnEnter(FamilyMode::Family), spawn);
}

fn spawn(mut commands: Commands, asset_server: Res<AssetServer>) {
    let pause = asset_server.load("base/ui/icons/pause.png");
    let normal_speed = asset_server.load("base/ui/icons/normal_speed.png");
    let fast_speed = asset_server.load("base/ui/icons/fast_speed.png");
    let ultra_speed = asset_server.load("base/ui/icons/ultra_speed.png");

    commands
        .spawn((
            Node {
                position_type: PositionType::Absolute,
                height: px(50.0),
                width: px(50.0),
                left: px(16.0),
                top: px(16.0),
                ..Default::default()
            },
            DespawnOnExit(FamilyMode::Family),
            actions!(SpeedPanel[
                (Action::<TogglePause>::new(), Press::default(), bindings![KeyCode::Digit0]),
                (Action::<SetNormal>::new(), Press::default(), bindings![KeyCode::Digit1]),
                (Action::<SetFast>::new(), Press::default(), bindings![KeyCode::Digit2]),
                (Action::<SetUltra>::new(), Press::default(), bindings![KeyCode::Digit3]),
            ]),
            children![
                (Button, ImageNode::new(pause)),
                (Button, ImageNode::new(normal_speed)),
                (Button, ImageNode::new(fast_speed)),
                (Button, ImageNode::new(ultra_speed)),
            ],
        ))
        .insert(SpeedPanel) // Workaround to react on insertion after hierarchy spawn.
        .observe(utils::mock_action::<SpeedPanel>);
}

fn toggle_pause(
    _on: On<Fire<TogglePause>>,
    mut commands: Commands,
    game_speed: Single<&GameSpeed>,
) {
    let new_speed = match **game_speed {
        GameSpeed::Running { speed } => GameSpeed::Paused { previous: speed },
        GameSpeed::Paused { previous } => GameSpeed::Running { speed: previous },
    };
    commands.insert_component_resource(new_speed);
}

fn set_speed<A: SpeedAction>(_on: On<Fire<A>>, mut commands: Commands) {
    commands.insert_component_resource(GameSpeed::Running { speed: A::SPEED });
}

fn reset_speed_buttons(
    _on: On<Replace, GameSpeed>,
    game_speed: Single<&GameSpeed>,
    speed_buttons: Single<&Children, With<SpeedPanel>>,
    mut nodes: Query<&mut ImageNode>,
) {
    match **game_speed {
        GameSpeed::Paused { previous } => {
            let mut pause = nodes.get_mut(speed_buttons[0]).unwrap();
            pause.color = Color::WHITE;
            let mut previous = nodes.get_mut(speed_buttons[previous as usize + 1]).unwrap();
            previous.color = Color::WHITE;
        }
        GameSpeed::Running { speed } => {
            let mut button = nodes.get_mut(speed_buttons[speed as usize + 1]).unwrap();
            button.color = Color::WHITE;
        }
    }
}

fn update_speed_buttons(
    _on: On<Insert, (GameSpeed, SpeedPanel)>,
    game_speed: Single<&GameSpeed>,
    speed_buttons: Single<&Children, With<SpeedPanel>>,
    mut nodes: Query<&mut ImageNode>,
) {
    match **game_speed {
        GameSpeed::Paused { previous } => {
            let mut pause = nodes.get_mut(speed_buttons[0]).unwrap();
            pause.color = RED_500.into();
            let mut previous = nodes.get_mut(speed_buttons[previous as usize + 1]).unwrap();
            previous.color = BLUE_500.into();
        }
        GameSpeed::Running { speed } => {
            let mut button = nodes.get_mut(speed_buttons[speed as usize + 1]).unwrap();
            button.color = BLUE_500.into();
        }
    }
}

#[derive(Component, Debug)]
struct SpeedPanel;

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
