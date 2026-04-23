use std::fmt::Write;

use bevy::{
    color::palettes::tailwind::{RED_50, RED_400, RED_500},
    ecs::relationship::RelatedSpawner,
    prelude::*,
};
use bevy_enhanced_input::prelude::*;
use bevy_replicon::prelude::ClientTriggerExt;
use simgine_core::{
    state::FamilyMode,
    world::time::{
        Clock, Weekday,
        speed::{GameSpeed, Paused, SetPaused, SetSpeed},
    },
};

use crate::{
    button_bindings,
    widget::{
        button::{
            action::{Activate, ButtonContext},
            exclusive_group::ExclusiveGroup,
            icon::ButtonIcon,
            style::ButtonStyle,
            toggled::Toggled,
        },
        theme::{LARGE_TEXT, SCREEN_OFFSET, SMALL_TEXT},
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(update_weekday)
        .add_observer(update_clock)
        .add_observer(update_pause_button)
        .add_observer(update_speed_buttons)
        .add_systems(OnEnter(FamilyMode::Life), spawn);
}

fn spawn(mut commands: Commands) {
    trace!("spawning time node");

    commands.spawn((
        Node {
            flex_direction: FlexDirection::Column,
            margin: SCREEN_OFFSET,
            ..Default::default()
        },
        DespawnOnExit(FamilyMode::Life),
        children![
            (
                Name::new("Weekday"),
                WeekdayLabel,
                Text::default(),
                TextFont::from_font_size(SMALL_TEXT)
            ),
            (
                Name::new("Clock"),
                ClockLabel,
                Text::default(),
                TextFont::from_font_size(LARGE_TEXT)
            ),
            (
                Node::default(),
                Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
                    parent
                        .spawn((
                            Name::new("Pause"),
                            Button,
                            PauseButton,
                            ButtonIcon::new("base/ui/icons/pause.png"),
                            ButtonStyle {
                                hovered_pressed: RED_400.into(),
                                pressed: RED_500.into(),
                                hovered: RED_50.into(),
                                ..Default::default()
                            },
                            Toggled::default(),
                            ButtonContext,
                            button_bindings![KeyCode::Digit0],
                        ))
                        .observe(
                            |_on: On<Fire<Activate>>,
                             mut commands: Commands,
                             paused: Single<&Paused>| {
                                commands.client_trigger(SetPaused(!***paused));
                            },
                        );

                    parent
                        .spawn((
                            Node::default(),
                            ExclusiveGroup::default(),
                            Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
                                parent.spawn(speed_button(GameSpeed::Normal)).observe(
                                    |_on: On<Fire<Activate>>, mut commands: Commands| {
                                        commands.client_trigger(SetSpeed(GameSpeed::Normal));
                                    },
                                );
                                parent.spawn(speed_button(GameSpeed::Fast)).observe(
                                    |_on: On<Fire<Activate>>, mut commands: Commands| {
                                        commands.client_trigger(SetSpeed(GameSpeed::Fast));
                                    },
                                );
                                parent.spawn(speed_button(GameSpeed::Ultra)).observe(
                                    |_on: On<Fire<Activate>>, mut commands: Commands| {
                                        commands.client_trigger(SetSpeed(GameSpeed::Ultra));
                                    },
                                );
                            })),
                        ))
                        .insert(SpeedNode); // Workaround to react on insertion after hierarchy spawn.
                })),
            ),
        ],
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

fn update_speed_buttons(
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

fn speed_button(speed: GameSpeed) -> impl Bundle {
    let (icon, key) = match speed {
        GameSpeed::Normal => ("base/ui/icons/normal_speed.png", KeyCode::Digit1),
        GameSpeed::Fast => ("base/ui/icons/fast_speed.png", KeyCode::Digit2),
        GameSpeed::Ultra => ("base/ui/icons/fast_speed.png", KeyCode::Digit3),
    };

    (
        Name::new(format!("{speed:?}")),
        Button,
        SpeedButton(speed),
        ButtonIcon::new(icon),
        ButtonStyle::default(),
        Toggled::default(),
        ButtonContext,
        button_bindings![key],
    )
}

#[derive(Component)]
struct WeekdayLabel;

#[derive(Component)]
struct ClockLabel;

#[derive(Component)]
struct PauseButton;

#[derive(Component)]
struct SpeedNode;

#[derive(Component, Deref, Clone, Copy)]
#[component(immutable)]
struct SpeedButton(GameSpeed);
