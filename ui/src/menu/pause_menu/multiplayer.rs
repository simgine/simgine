use bevy::{ecs::relationship::RelatedSpawner, prelude::*, text::EditableText};
use bevy_replicon::prelude::*;
use simgine_core::{
    error_event::trigger_error,
    network::{DEFAULT_PORT, Host, StopServer},
    state::GameState,
};

use crate::widget::{
    button::style::ButtonStyle,
    dialog::{dialog, dialog_close_button, dialog_title},
    text_edit::text_edit,
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
        dialog(),
        DespawnOnExit(GameState::World),
        children![
            dialog_title("Multiplayer"),
            (
                Node {
                    column_gap: GAP,
                    align_items: AlignItems::Center,
                    ..Default::default()
                },
                Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
                    parent.spawn((Text::new("Port"), TextFont::from_font_size(NORMAL_TEXT)));
                    let port_edit = parent.spawn(text_edit(DEFAULT_PORT.to_string())).id();
                    let start_stop = move |_on: On<Pointer<Click>>,
                                           mut commands: Commands,
                                           server_state: Res<State<ServerState>>,
                                           texts: Query<&EditableText>|
                          -> Result<()> {
                        match **server_state {
                            ServerState::Stopped => {
                                let text = texts.get(port_edit).unwrap();
                                let port: u16 =
                                    text.value().to_string().parse().map_err(|e| {
                                        format!("invalid port {}: {e}", text.value())
                                    })?;
                                commands.trigger(Host { port })
                            }
                            ServerState::Running => commands.trigger(StopServer),
                        };

                        Ok(())
                    };
                    parent
                        .spawn((
                            Button,
                            StartStopButton,
                            Text::default(),
                            TextFont::from_font_size(NORMAL_TEXT),
                            ButtonStyle::default(),
                        ))
                        .observe(start_stop.pipe(trigger_error));
                })),
            ),
            dialog_close_button("Close")
        ],
    )
}

#[derive(Component)]
struct StartStopButton;
