mod multiplayer;

use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use bevy_enhanced_input::prelude::{Release, *};
use bevy_replicon::prelude::*;
use simgine_core::{
    speed::{Paused, SetPaused},
    state::GameState,
    world::SaveWorld,
};

use crate::{
    menu::pause_menu::multiplayer::multiplayer_menu,
    widget::{
        button::style::ButtonStyle,
        dialog::{Dialog, DialogButton, DialogCloseButton, DialogTitle},
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(multiplayer::plugin)
        .add_input_context::<PauseMenuContext>()
        .add_observer(open)
        .add_observer(pause)
        .add_observer(unpause)
        .add_systems(OnEnter(GameState::World), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        PauseMenuContext,
        DespawnOnExit(GameState::World),
        actions!(
            PauseMenuContext[(
                Action::<OpenPauseMenu>::new(),
                Release::default(),
                bindings![KeyCode::Escape]
            )]
        ),
    ));
}

fn open(_on: On<Fire<OpenPauseMenu>>, mut commands: Commands) {
    commands.spawn((
        Name::new("Pause menu"),
        PauseMenu::default(),
        Dialog,
        DespawnOnExit(GameState::World),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            let dialog = parent.target_entity();
            parent.spawn((DialogTitle, Text::new("Menu")));
            parent.spawn((button("Resume"), DialogCloseButton));
            parent.spawn(button("Save")).observe(
                move |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.trigger(SaveWorld);
                    commands.entity(dialog).despawn();
                },
            );
            parent.spawn(button("Multiplayer")).observe(
                |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.spawn(multiplayer_menu());
                },
            );
            parent.spawn(button("Main menu")).observe(
                |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.set_state(GameState::Menu);
                },
            );
            parent.spawn(button("Exit")).observe(
                |_on: On<Pointer<Click>>, mut exit: MessageWriter<AppExit>| {
                    exit.write(AppExit::Success);
                },
            );
        })),
    ));
}

fn pause(
    _on: On<Insert, PauseMenu>,
    mut commands: Commands,
    paused: Single<&Paused>,
    mut pause_menu: Single<&mut PauseMenu>,
) {
    if !***paused {
        pause_menu.unpause_on_hide = true;
        commands.client_trigger(SetPaused(true));
    }
}

fn unpause(_on: On<Remove, PauseMenu>, mut commands: Commands, pause_menu: Single<&PauseMenu>) {
    if pause_menu.unpause_on_hide {
        commands.client_trigger(SetPaused(false));
    }
}

fn button(text: &str) -> impl Bundle {
    (Text::new(text), DialogButton, ButtonStyle::default())
}

#[derive(Component)]
struct PauseMenuContext;

#[derive(InputAction)]
#[action_output(bool)]
struct OpenPauseMenu;

#[derive(Component, Default)]
struct PauseMenu {
    unpause_on_hide: bool,
}
