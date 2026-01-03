use std::fmt::Write;

use bevy::{
    color::palettes::tailwind::{RED_50, RED_400, RED_500},
    ecs::relationship::RelatedSpawner,
    prelude::*,
};
use bevy_enhanced_input::prelude::*;
use simgine_core::{
    component_res::InsertComponentResExt,
    speed::{GameSpeed, Paused},
    state::FamilyMode,
    time::{Clock, Weekday},
};

use crate::{
    button_bindings,
    widget::{
        SCREEN_OFFSET,
        button::{
            action::{Activate, ButtonContext},
            exclusive_group::ExclusiveGroup,
            icon::ButtonIcon,
            style::ButtonStyle,
            toggled::Toggled,
        },
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(update_weekday)
        .add_observer(update_clock)
        .add_observer(toggle_pause)
        .add_observer(set_speed)
        .add_observer(update_pause_button)
        .add_observer(update_speed_button)
        .add_systems(OnEnter(FamilyMode::Life), spawn);
}

fn spawn(mut commands: Commands) {
    trace!("spawning time node");

    commands.spawn((
        Node {
            flex_direction: FlexDirection::Column,
            margin: UiRect::all(SCREEN_OFFSET),
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
                        (PauseButton, button_bindings![KeyCode::Digit0]),
                        (
                            Node::default(),
                            ExclusiveGroup::default(),
                            children![
                                (
                                    ButtonIcon::new("base/ui/icons/normal_speed.png"),
                                    SpeedButton(GameSpeed::Normal),
                                    button_bindings![KeyCode::Digit1]
                                ),
                                (
                                    ButtonIcon::new("base/ui/icons/fast_speed.png"),
                                    SpeedButton(GameSpeed::Fast),
                                    button_bindings![KeyCode::Digit2]
                                ),
                                (
                                    ButtonIcon::new("base/ui/icons/ultra_speed.png"),
                                    SpeedButton(GameSpeed::Ultra),
                                    button_bindings![KeyCode::Digit3]
                                ),
                            ]
                        )
                    ],
                ))
                .insert(SpeedNode); // Workaround to react on insertion after hierarchy spawn.
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

fn toggle_pause(
    activate: On<Fire<Activate>>,
    mut commands: Commands,
    buttons: Query<(), With<PauseButton>>,
    paused: Single<&Paused>,
) {
    if buttons.get(activate.context).is_ok() {
        commands.insert_component_resource(paused.toggled());
    }
}

fn set_speed(
    activate: On<Fire<Activate>>,
    mut commands: Commands,
    paused: Single<&Paused>,
    mut buttons: Query<&SpeedButton>,
) {
    if let Ok(&speed) = buttons.get_mut(activate.context) {
        commands.insert_component_resource(*speed);
        if ***paused {
            commands.insert_component_resource(Paused(false));
        }
    }
}

fn update_pause_button(
    _on: On<Insert, (Paused, PauseButton)>,
    mut commands: Commands,
    pause_button: Single<(Entity, &Toggled), With<PauseButton>>,
    paused: Single<&Paused>,
) {
    let (entity, &toggled) = pause_button.into_inner();
    if *toggled != ***paused {
        commands.entity(entity).insert(Toggled(***paused));
    }
}

fn update_speed_button(
    _on: On<Insert, (GameSpeed, SpeedNode)>,
    mut commands: Commands,
    game_speed: Single<&GameSpeed>,
    buttons: Query<(Entity, &Toggled, &SpeedButton)>,
) {
    if let Some((entity, &toggled, _)) = buttons.iter().find(|&(.., s)| **s == **game_speed)
        && !*toggled
    {
        commands.entity(entity).insert(Toggled(true));
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
#[require(
    ButtonContext,
    ButtonIcon::new("base/ui/icons/pause.png"),
    ButtonStyle {
        hovered_pressed: RED_400.into(),
        pressed: RED_500.into(),
        hovered: RED_50.into(),
        ..Default::default()
    },
    Toggled
)]
struct PauseButton;

#[derive(Component)]
struct SpeedNode;

#[derive(Component, Deref, Clone, Copy)]
#[component(immutable)]
#[require(ButtonContext, ButtonStyle, Toggled)]
struct SpeedButton(GameSpeed);
