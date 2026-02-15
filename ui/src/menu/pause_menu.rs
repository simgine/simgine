mod multiplayer;

use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use bevy_enhanced_input::prelude::{Release, *};
use simgine_core::{component_res::InsertComponentResExt, speed::Paused, state::GameState};

use crate::{
    menu::pause_menu::multiplayer::multiplayer_menu,
    widget::{
        button::style::ButtonStyle,
        dialog::{Dialog, DialogButton, DialogCloseButton, DialogTitle},
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(multiplayer::plugin)
        .add_input_context::<PauseMenuController>()
        .add_observer(open)
        .add_observer(pause)
        .add_observer(unpause)
        .add_systems(OnEnter(GameState::World), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        PauseMenuController,
        actions!(
            PauseMenuController[(
                Action::<OpenPauseMenu>::new(),
                Release::default(),
                bindings![KeyCode::Escape]
            )]
        ),
    ));
}

fn open(_on: On<Fire<OpenPauseMenu>>, mut commands: Commands) {
    commands.spawn((
        PauseMenu::default(),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent.spawn((DialogTitle, Text::new("Menu")));
            parent.spawn((PauseMenuButton, DialogCloseButton, Text::new("Resume")));
            parent
                .spawn((PauseMenuButton, Text::new("Multiplayer")))
                .observe(|_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.spawn(multiplayer_menu());
                });
            parent
                .spawn((PauseMenuButton, Text::new("Main menu")))
                .observe(|_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.set_state(GameState::Menu);
                });
            parent.spawn((PauseMenuButton, Text::new("Exit"))).observe(
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
        commands.insert_component_resource(Paused(true));
    }
}

fn unpause(_on: On<Remove, PauseMenu>, mut commands: Commands, pause_menu: Single<&PauseMenu>) {
    if pause_menu.unpause_on_hide {
        commands.insert_component_resource(Paused(false));
    }
}

#[derive(Component)]
#[require(DespawnOnExit::<_>(GameState::World))]
struct PauseMenuController;

#[derive(InputAction)]
#[action_output(bool)]
struct OpenPauseMenu;

#[derive(Component, Default)]
#[require(
    Name::new("Pause menu"),
    Dialog,
    DespawnOnExit::<_>(GameState::World),
)]
struct PauseMenu {
    unpause_on_hide: bool,
}

#[derive(Component)]
#[require(DialogButton, ButtonStyle)]
struct PauseMenuButton;
