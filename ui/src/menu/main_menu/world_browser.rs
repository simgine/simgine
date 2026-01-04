mod world_nodes;

use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use simgine_core::state::MenuState;

use crate::widget::{
    button::style::ButtonStyle,
    theme::{GAP, HUGE_TEXT, LARGE_TEXT, SCREEN_OFFSET},
};
use world_nodes::WorldNodes;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(world_nodes::plugin)
        .add_systems(OnEnter(MenuState::WorldBrowser), spawn);
}

fn spawn(mut commands: Commands) {
    info!("entering world browser");

    commands.spawn((
        Node {
            flex_direction: FlexDirection::Column,
            justify_self: JustifySelf::Center,
            margin: SCREEN_OFFSET,
            row_gap: GAP,
            ..Default::default()
        },
        DespawnOnExit(MenuState::WorldBrowser),
        children![
            (
                Node {
                    align_self: AlignSelf::Center,
                    ..Default::default()
                },
                Text::new("World browser"),
                TextFont::from_font_size(HUGE_TEXT),
            ),
            WorldNodes,
        ],
    ));
    commands.spawn((
        Node {
            align_self: AlignSelf::End,
            margin: SCREEN_OFFSET,
            ..Default::default()
        },
        DespawnOnExit(MenuState::WorldBrowser),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent
                .spawn((WorldBrowserButton, Text::new("Back")))
                .observe(|_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.set_state(MenuState::MainMenu)
                });
        })),
    ));
    commands.spawn((
        Node {
            align_self: AlignSelf::End,
            justify_self: JustifySelf::End,
            column_gap: GAP,
            margin: SCREEN_OFFSET,
            ..Default::default()
        },
        DespawnOnExit(MenuState::WorldBrowser),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent.spawn((WorldBrowserButton, Text::new("Create")));
            parent.spawn((WorldBrowserButton, Text::new("Host")));
        })),
    ));
}

#[derive(Component)]
#[require(ButtonStyle, TextFont::from_font_size(LARGE_TEXT))]
struct WorldBrowserButton;
