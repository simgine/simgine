use std::fmt::Write;

use bevy::{
    color::palettes::tailwind::{BLUE_500, RED_500},
    ecs::relationship::RelatedSpawner,
    prelude::*,
};
use bevy_enhanced_input::prelude::*;
use simgine_core::{
    FamilyMode,
    component_res::InsertComponentResExt,
    speed::{GameSpeed, Paused},
    time::{Clock, Weekday},
};

use crate::button_bindings;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(update_weekday)
        .add_observer(update_clock)
        .add_observer(toggle_pause)
        .add_observer(set_speed)
        .add_observer(update_pause_button)
        .add_observer(reset_speed_button)
        .add_observer(update_speed_button)
        .add_systems(OnEnter(FamilyMode::Life), spawn);
}

fn spawn(mut commands: Commands, asset_server: Res<AssetServer>) {
    let pause = asset_server.load("base/ui/icons/pause.png");
    let normal_speed = asset_server.load("base/ui/icons/normal_speed.png");
    let fast_speed = asset_server.load("base/ui/icons/fast_speed.png");
    let ultra_speed = asset_server.load("base/ui/icons/ultra_speed.png");

    commands.spawn((
        Node {
            flex_direction: FlexDirection::Column,
            position_type: PositionType::Absolute,
            left: px(16.0),
            top: px(16.0),
            ..Default::default()
        },
        DespawnOnExit(FamilyMode::Life),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent.spawn(WeekdayLabel);
            parent.spawn(ClockLabel);
            parent
                .spawn((
                    Node::default(),
                    children![
                        (
                            ImageNode::new(pause),
                            PauseButton,
                            button_bindings!(TogglePause[KeyCode::Digit0]),
                        ),
                        (
                            ImageNode::new(normal_speed),
                            SpeedButton(GameSpeed::Normal),
                            button_bindings!(SetSpeed[KeyCode::Digit1])
                        ),
                        (
                            ImageNode::new(fast_speed),
                            SpeedButton(GameSpeed::Fast),
                            button_bindings!(SetSpeed[KeyCode::Digit2])
                        ),
                        (
                            ImageNode::new(ultra_speed),
                            SpeedButton(GameSpeed::Ultra),
                            button_bindings!(SetSpeed[KeyCode::Digit3])
                        ),
                    ],
                ))
                .insert(SpeedPanel); // Workaround to react on insertion after hierarchy spawn.
        })),
    ));
}

fn update_weekday(
    _on: On<Insert, (Weekday, WeekdayLabel)>,
    weekday: Single<&Weekday>,
    mut text: Single<&mut Text, With<WeekdayLabel>>,
) {
    text.clear();
    write!(text, "{}", *weekday).unwrap();
}

fn update_clock(
    _on: On<Insert, (Clock, ClockLabel)>,
    clock: Single<&Clock>,
    mut text: Single<&mut Text, With<ClockLabel>>,
) {
    text.clear();
    write!(text, "{}", *clock).unwrap();
}

fn toggle_pause(_on: On<Fire<TogglePause>>, mut commands: Commands, paused: Single<&Paused>) {
    commands.insert_component_resource(paused.toggled());
}

fn set_speed(
    set_speed: On<Fire<SetSpeed>>,
    mut commands: Commands,
    paused: Single<&Paused>,
    mut speed_buttons: Query<&SpeedButton>,
) {
    let speed = **speed_buttons.get_mut(set_speed.context).unwrap();
    commands.insert_component_resource(speed);
    if ***paused {
        commands.insert_component_resource(Paused(false));
    }
}

fn update_pause_button(
    _on: On<Insert, (Paused, SpeedPanel)>,
    mut pause_node: Single<&mut ImageNode, With<PauseButton>>,
    paused: Single<&Paused>,
) {
    let color = if ***paused {
        RED_500.into()
    } else {
        Color::WHITE
    };
    pause_node.color = color;
}

fn reset_speed_button(
    _on: On<Replace, GameSpeed>,
    game_speed: Single<&GameSpeed>,
    mut speed_buttons: Query<(&mut ImageNode, &SpeedButton)>,
) {
    if let Some((mut node, _)) = speed_buttons.iter_mut().find(|&(_, s)| **s == **game_speed) {
        node.color = Color::WHITE;
    }
}

fn update_speed_button(
    _on: On<Insert, (GameSpeed, SpeedPanel)>,
    game_speed: Single<&GameSpeed>,
    mut speed_buttons: Query<(&mut ImageNode, &SpeedButton)>,
) {
    if let Some((mut node, _)) = speed_buttons.iter_mut().find(|&(_, s)| **s == **game_speed) {
        node.color = BLUE_500.into();
    }
}

#[derive(Component)]
#[require(
    Text,
    TextFont { font_size: 20.0, ..Default::default() },
)]
struct WeekdayLabel;

#[derive(Component)]
#[require(
    Text,
    TextFont { font_size: 28.0, ..Default::default() },
)]
struct ClockLabel;

#[derive(Component)]
struct PauseButton;

#[derive(Component)]
struct SpeedPanel;

#[derive(Component, Deref, Clone, Copy)]
struct SpeedButton(GameSpeed);

#[derive(InputAction)]
#[action_output(bool)]
pub struct TogglePause;

#[derive(InputAction)]
#[action_output(bool)]
pub struct SetSpeed;
