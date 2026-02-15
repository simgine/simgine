use std::fmt::Write;

use bevy::prelude::*;
use bevy_replicon::prelude::*;
use simgine_core::{state::GameState, world::WorldName};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(OnEnter(GameState::World), update);
    app.add_systems(OnExit(GameState::World), reset);
    app.add_systems(Startup, reset);
}

fn update(
    mut window: Single<&mut Window>,
    client_state: Res<State<ClientState>>,
    server_state: Res<State<ServerState>>,
    world_name: Single<&WorldName>,
) {
    let mode = match (**client_state, **server_state) {
        (_, ServerState::Running) => " (Server)",
        (ClientState::Connected, _) => " (Client)",
        _ => "",
    };

    window.title.clear();
    write!(&mut window.title, "Simgine - {}{mode}", ***world_name).unwrap();
}

fn reset(mut window: Single<&mut Window>) {
    window.title.clear();
    write!(&mut window.title, "Simgine").unwrap();
}
