use std::fmt::Debug;

use bevy::{
    color::palettes::tailwind::{BLUE_500, RED_500},
    prelude::*,
};
use bevy_enhanced_input::prelude::{Press, *};
use simgine_core::{
    FamilyMode,
    component_res::InsertComponentResExt,
    speed::{GameSpeed, Paused},
};

use crate::{action_button::ActionButton, button_bindings};

pub(crate) fn plugin(app: &mut App) {
    app.add_observer(toggle_pause)
        .add_observer(set_speed::<SetNormal>)
        .add_observer(set_speed::<SetFast>)
        .add_observer(set_speed::<SetUltra>)
        .add_observer(update_pause_button)
        .add_observer(reset_speed_button)
        .add_observer(update_speed_button)
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
            children![
                (
                    ImageNode::new(pause),
                    button_bindings!(TogglePause[KeyCode::Digit0]),
                ),
                (
                    ImageNode::new(normal_speed),
                    button_bindings!(SetNormal[KeyCode::Digit1])
                ),
                (
                    ImageNode::new(fast_speed),
                    button_bindings!(SetFast[KeyCode::Digit2])
                ),
                (
                    ImageNode::new(ultra_speed),
                    button_bindings!(SetUltra[KeyCode::Digit3])
                ),
            ],
        ))
        .insert(SpeedPanel); // Workaround to react on insertion after hierarchy spawn.
}

fn toggle_pause(_on: On<Fire<TogglePause>>, mut commands: Commands, paused: Single<&Paused>) {
    commands.insert_component_resource(paused.toggled());
}

fn set_speed<A: SpeedAction>(_on: On<Fire<A>>, mut commands: Commands, paused: Single<&Paused>) {
    commands.insert_component_resource(A::SPEED);
    if ***paused {
        commands.insert_component_resource(Paused(false));
    }
}

fn update_pause_button(
    _on: On<Insert, (Paused, SpeedPanel)>,
    speed_buttons: Single<&Children, With<SpeedPanel>>,
    paused: Single<&Paused>,
    mut nodes: Query<&mut ImageNode>,
) {
    let pause_button = speed_buttons[0];
    let mut node = nodes.get_mut(pause_button).unwrap();
    let color = if ***paused {
        RED_500.into()
    } else {
        Color::WHITE
    };
    node.color = color;
}

fn reset_speed_button(
    _on: On<Replace, GameSpeed>,
    game_speed: Single<&GameSpeed>,
    speed_buttons: Single<&Children, With<SpeedPanel>>,
    mut nodes: Query<&mut ImageNode>,
) {
    let speed_button = speed_buttons[**game_speed as usize + 1];
    let mut node = nodes.get_mut(speed_button).unwrap();
    node.color = Color::WHITE;
}

fn update_speed_button(
    _on: On<Insert, (GameSpeed, SpeedPanel)>,
    game_speed: Single<&GameSpeed>,
    speed_buttons: Single<&Children, With<SpeedPanel>>,
    mut nodes: Query<&mut ImageNode>,
) {
    let speed_button = speed_buttons[**game_speed as usize + 1];
    let mut node = nodes.get_mut(speed_button).unwrap();
    node.color = BLUE_500.into();
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
    const SPEED: GameSpeed = GameSpeed::Normal;
}

#[derive(InputAction)]
#[action_output(bool)]
pub struct SetFast;

impl SpeedAction for SetFast {
    const SPEED: GameSpeed = GameSpeed::Fast;
}

#[derive(InputAction)]
#[action_output(bool)]
pub struct SetUltra;

impl SpeedAction for SetUltra {
    const SPEED: GameSpeed = GameSpeed::Ultra;
}

trait SpeedAction: InputAction {
    const SPEED: GameSpeed;
}
