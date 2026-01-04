mod world_browser;

use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use simgine_core::state::MenuState;

use crate::widget::{
    button::style::ButtonStyle,
    theme::{GAP, HUGE_TEXT, SCREEN_OFFSET},
};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(world_browser::plugin)
        .add_systems(OnEnter(MenuState::MainMenu), spawn);
}

fn spawn(mut commands: Commands) {
    info!("entering main menu");

    commands.spawn((
        DespawnOnExit(MenuState::MainMenu),
        Node {
            flex_direction: FlexDirection::Column,
            align_self: AlignSelf::Center,
            row_gap: GAP,
            margin: SCREEN_OFFSET,
            ..Default::default()
        },
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent.spawn((MainMenuButton, Text::new("Play"))).observe(
                |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.set_state(MenuState::WorldBrowser)
                },
            );
            parent.spawn((MainMenuButton, Text::new("Exit"))).observe(
                |_on: On<Pointer<Click>>, mut exit: MessageWriter<AppExit>| {
                    exit.write(AppExit::Success);
                },
            );
        })),
    ));
}

#[derive(Component)]
#[require(TextFont::from_font_size(HUGE_TEXT), ButtonStyle)]
struct MainMenuButton;
