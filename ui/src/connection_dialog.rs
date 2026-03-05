use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use bevy_enhanced_input::prelude::*;
use bevy_replicon::prelude::ClientState;
use simgine_core::{network::Disconnect, state::GameState};

use crate::widget::{
    button::action::Activate,
    dialog::{dialog, dialog_close_button, dialog_title},
};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(OnEnter(ClientState::Connecting), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        dialog(),
        // Despawn only after the first replication message with the world is received.
        DespawnOnEnter(GameState::World),
        DespawnOnEnter(ClientState::Disconnected),
        Children::spawn(SpawnWith(move |parent: &mut RelatedSpawner<_>| {
            parent.spawn(dialog_title("Connecting to server"));
            parent.spawn(dialog_close_button("Cancel")).observe(
                |_on: On<Fire<Activate>>, mut commands: Commands| commands.trigger(Disconnect),
            );
        })),
    ));
}
