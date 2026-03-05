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
            parent.spawn(button("Play")).observe(
                |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.set_state(MenuState::WorldBrowser)
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

fn button(text: &str) -> impl Bundle {
    (
        ButtonStyle::default(),
        TextFont::from_font_size(HUGE_TEXT),
        Text::new(text),
    )
}
