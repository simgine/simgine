mod world_nodes;

use std::net::SocketAddr;

use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use bevy_simple_text_input::TextInputValue;
use simgine_core::{
    error_event::trigger_error,
    network::{Connect, DEFAULT_PORT},
    state::MenuState,
    world::CreateWorld,
};

use crate::{
    menu::main_menu::world_browser::world_nodes::world_nodes,
    widget::{
        button::style::ButtonStyle,
        dialog::{dialog, dialog_button, dialog_close_button, dialog_title},
        text_edit::text_edit,
        theme::{GAP, HUGE_TEXT, LARGE_TEXT, NORMAL_TEXT, SCREEN_OFFSET},
    },
};

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
            world_nodes(),
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
            parent.spawn(bottom_button("Back")).observe(
                |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.set_state(MenuState::MainMenu)
                },
            );
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
            parent.spawn(bottom_button("Create")).observe(
                |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.spawn(create_dialog());
                },
            );
            parent.spawn(bottom_button("Join")).observe(
                |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.spawn(join_dialog());
                },
            );
        })),
    ));
}

fn bottom_button(text: &str) -> impl Bundle {
    (
        Button,
        Text::new(text),
        TextFont::from_font_size(LARGE_TEXT),
        ButtonStyle::default(),
    )
}

fn create_dialog() -> impl Bundle {
    (
        dialog(),
        DespawnOnExit(MenuState::WorldBrowser),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent.spawn(dialog_title("Create world"));
            let name_edit = parent.spawn(text_edit()).id();
            parent.spawn((
                Node {
                    align_self: AlignSelf::Center,
                    column_gap: GAP,
                    ..Default::default()
                },
                Children::spawn(SpawnWith(move |parent: &mut RelatedSpawner<_>| {
                    parent.spawn(dialog_close_button("Cancel"));
                    parent.spawn(dialog_button("Create")).observe(
                        move |_on: On<Pointer<Click>>,
                              mut commands: Commands,
                              input_values: Query<&TextInputValue>| {
                            let name = input_values.get(name_edit).unwrap();
                            commands.trigger(CreateWorld {
                                name: name.0.clone(),
                            });
                        },
                    );
                })),
            ));
        })),
    )
}

fn join_dialog() -> impl Bundle {
    (
        dialog(),
        DespawnOnExit(MenuState::WorldBrowser),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent.spawn(dialog_title("Join game"));
            parent.spawn((Text::new("Address"), TextFont::from_font_size(NORMAL_TEXT)));
            let addr_edit = parent
                .spawn((
                    text_edit(),
                    TextInputValue(format!("127.0.0.1:{DEFAULT_PORT}")),
                ))
                .id();
            let connect = move |_on: On<Pointer<Click>>,
                                mut commands: Commands,
                                input_values: Query<&TextInputValue>|
                  -> Result<()> {
                let text = input_values.get(addr_edit).unwrap();
                let addr: SocketAddr = text
                    .0
                    .parse()
                    .map_err(|e| format!("invalid address {}: {e}", text.0))?;
                commands.trigger(Connect {
                    ip: addr.ip(),
                    port: addr.port(),
                });

                Ok(())
            };

            parent
                .spawn(Node {
                    align_self: AlignSelf::Center,
                    column_gap: GAP,
                    ..Default::default()
                })
                .with_children(|parent: &mut RelatedSpawner<_>| {
                    parent.spawn(dialog_close_button("Cancel"));
                    parent
                        .spawn(dialog_button("Connect"))
                        .observe(connect.pipe(trigger_error));
                });
        })),
    )
}
