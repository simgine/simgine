use std::fmt::Write;

use bevy::prelude::*;
use bevy_replicon::prelude::*;
use simgine_core::{state::GameState, world::WorldName};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(OnEnter(GameState::World), update)
        .add_systems(OnEnter(ServerState::Running), update)
        .add_systems(OnExit(ServerState::Running), update)
        .add_systems(OnExit(GameState::World), update)
        .add_systems(Startup, update);
}

fn update(
    mut window: Single<&mut Window>,
    client_state: Res<State<ClientState>>,
    server_state: Res<State<ServerState>>,
    world_name: Option<Single<&WorldName>>,
) {
    window.title.clear();

    if let Some(world_name) = world_name {
        let mode = match (**client_state, **server_state) {
            (_, ServerState::Running) => " (Server)",
            (ClientState::Connected, _) => " (Client)",
            _ => "",
        };

        write!(&mut window.title, "Simgine - {}{mode}", ***world_name).unwrap();
    } else {
        write!(&mut window.title, "Simgine").unwrap();
    }
}
