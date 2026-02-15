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

use crate::widget::{
    button::style::ButtonStyle,
    dialog::{Dialog, DialogButton, DialogCloseButton, DialogTitle},
    text_edit::TextEdit,
    theme::{GAP, HUGE_TEXT, LARGE_TEXT, NORMAL_TEXT, SCREEN_OFFSET},
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
            parent
                .spawn((WorldBrowserButton, Text::new("Create")))
                .observe(|_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.spawn(create_dialog());
                });
            parent
                .spawn((WorldBrowserButton, Text::new("Join")))
                .observe(|_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.spawn(join_dialog());
                });
        })),
    ));
}

fn create_dialog() -> impl Bundle {
    (
        Dialog,
        DespawnOnExit(MenuState::WorldBrowser),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent.spawn((DialogTitle, Text::new("Create world")));
            let name_edit = parent.spawn(TextEdit).id();
            parent.spawn((
                Node {
                    align_self: AlignSelf::Center,
                    column_gap: GAP,
                    ..Default::default()
                },
                Children::spawn(SpawnWith(move |parent: &mut RelatedSpawner<_>| {
                    parent.spawn((DialogCloseButton, Text::new("Cancel")));
                    parent.spawn((DialogButton, Text::new("Create"))).observe(
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
        Dialog,
        DespawnOnExit(MenuState::WorldBrowser),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent.spawn((DialogTitle, Text::new("Join game")));
            parent.spawn((Text::new("Address"), TextFont::from_font_size(NORMAL_TEXT)));
            let addr_edit = parent
                .spawn((
                    TextEdit,
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
                    parent.spawn((DialogCloseButton, Text::new("Cancel")));
                    parent
                        .spawn((DialogButton, Text::new("Connect")))
                        .observe(connect.pipe(trigger_error));
                });
        })),
    )
}

#[derive(Component)]
#[require(ButtonStyle, TextFont::from_font_size(LARGE_TEXT))]
struct WorldBrowserButton;
