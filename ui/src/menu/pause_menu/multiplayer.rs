use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use bevy_replicon::prelude::*;
use bevy_simple_text_input::TextInputValue;
use simgine_core::{
    error_event::trigger_error,
    network::{DEFAULT_PORT, Host, StopServer},
    state::GameState,
};

use crate::widget::{
    button::style::ButtonStyle,
    dialog::{Dialog, DialogButton, DialogTitle},
    text_edit::TextEdit,
    theme::{GAP, NORMAL_TEXT},
};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(PostUpdate, update_start_stop);
}

fn update_start_stop(
    mut text: Single<&mut Text, With<StartStopButton>>,
    server_state: Res<State<ServerState>>,
) {
    if text.is_changed() || server_state.is_changed() {
        text.clear();
        match **server_state {
            ServerState::Stopped => text.push_str("Start"),
            ServerState::Running => text.push_str("Stop"),
        }
    }
}

pub(super) fn multiplayer_menu() -> impl Bundle {
    (
        Dialog,
        DespawnOnExit(GameState::World),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            let dialog = parent.target_entity();
            parent.spawn((DialogTitle, Text::new("Multiplayer")));
            parent.spawn((
                Node {
                    column_gap: GAP,
                    align_items: AlignItems::Center,
                    ..Default::default()
                },
                Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
                    parent.spawn((Text::new("Port"), TextFont::from_font_size(NORMAL_TEXT)));
                    let port_edit = parent
                        .spawn((TextEdit, TextInputValue(DEFAULT_PORT.to_string())))
                        .id();
                    let start_stop = move |_on: On<Pointer<Click>>,
                                           mut commands: Commands,
                                           server_state: Res<State<ServerState>>,
                                           edit_values: Query<&TextInputValue>|
                          -> Result<()> {
                        match **server_state {
                            ServerState::Stopped => {
                                let port = edit_values.get(port_edit).unwrap();
                                let port: u16 = port
                                    .0
                                    .parse()
                                    .map_err(|e| format!("invalid port {}: {e}", port.0))?;
                                commands.trigger(Host { port })
                            }
                            ServerState::Running => commands.trigger(StopServer),
                        };

                        Ok(())
                    };
                    parent
                        .spawn(StartStopButton)
                        .observe(start_stop.pipe(trigger_error));
                })),
            ));
            parent.spawn((DialogButton, Text::new("Close"))).observe(
                move |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.entity(dialog).despawn();
                },
            );
        })),
    )
}

#[derive(Component)]
#[require(ButtonStyle, Text, TextFont::from_font_size(NORMAL_TEXT))]
struct StartStopButton;
