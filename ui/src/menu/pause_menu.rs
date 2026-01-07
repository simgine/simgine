use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use bevy_enhanced_input::prelude::{Release, *};
use simgine_core::{component_res::InsertComponentResExt, speed::Paused, state::GameState};

use crate::widget::{
    button::style::ButtonStyle,
    dialog::{Dialog, DialogButton, DialogTitle},
};

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<PauseMenu>()
        .add_observer(pause_unpause)
        .add_systems(OnEnter(GameState::World), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        PauseMenu::default(),
        DespawnOnExit(GameState::World),
        actions!(
            PauseMenu[(
                Action::<PauseUnpause>::new(),
                Release::default(),
                bindings![KeyCode::Escape]
            )]
        ),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            let dialog = parent.target_entity();
            parent.spawn((DialogTitle, Text::new("Menu")));
            parent
                .spawn((PauseMenuButton, Text::new("Resume")))
                .observe(
                    move |_on: On<Pointer<Click>>, mut visibility: Query<&mut Visibility>| {
                        let mut visibility = visibility.get_mut(dialog).unwrap();
                        *visibility = Visibility::Hidden;
                    },
                );
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

fn pause_unpause(
    _on: On<Fire<PauseUnpause>>,
    mut commands: Commands,
    pause_menu: Single<(&mut Visibility, &mut PauseMenu), With<PauseMenu>>,
    paused: Single<&Paused>,
) {
    let (mut visibility, mut pause_menu) = pause_menu.into_inner();

    match *visibility {
        Visibility::Inherited | Visibility::Visible => {
            info!("hiding pause menu");
            if pause_menu.unpause_on_hide {
                pause_menu.unpause_on_hide = false;
                commands.insert_component_resource(Paused(false));
            }
            *visibility = Visibility::Hidden;
        }
        Visibility::Hidden => {
            info!("showing pause menu");
            if !***paused {
                pause_menu.unpause_on_hide = true;
                commands.insert_component_resource(Paused(true));
            }
            *visibility = Visibility::Inherited;
        }
    };
}

#[derive(Component, Default)]
#[require(Name::new("Ingame menu"), Dialog, Visibility::Hidden)]
struct PauseMenu {
    unpause_on_hide: bool,
}

#[derive(InputAction)]
#[action_output(bool)]
struct PauseUnpause;

#[derive(Component)]
#[require(DialogButton, ButtonStyle)]
struct PauseMenuButton;
