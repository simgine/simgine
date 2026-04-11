use std::marker::PhantomData;

use bevy::{ecs::entity::MapEntities, prelude::*};
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize, de::DeserializeOwned};

use super::{CommandId, ConfirmableCommand, history::CommandHistory};

pub(crate) trait ClientCommandAppExt {
    fn add_client_command<C>(&mut self) -> &mut Self
    where
        C: ConfirmableCommand + Serialize + DeserializeOwned + MapEntities + Clone;
}

impl ClientCommandAppExt for App {
    fn add_client_command<C>(&mut self) -> &mut Self
    where
        C: ConfirmableCommand + Serialize + DeserializeOwned + MapEntities + Clone,
    {
        self.add_mapped_client_event::<CommandRequest<C>>(Channel::Ordered)
            .add_server_event::<Confirm<C>>(Channel::Ordered)
            .add_server_event::<Deny<C>>(Channel::Ordered)
            .add_observer(confirm::<C>)
            .add_observer(deny::<C>)
    }
}

fn confirm<C: ConfirmableCommand>(
    confirm: On<Confirm<C>>,
    mut commands: Commands,
    mut history: ResMut<CommandHistory>,
    despawn_entities: Query<(Entity, &DespawnOnResponse<C>)>,
) {
    history.confirm(confirm.id);

    for (entity, despawn) in despawn_entities {
        if despawn.id == confirm.id {
            debug!("despawning `{entity}` on response for `{:?}`", despawn.id);
            commands.entity(entity).despawn();
        }
    }
}

fn deny<C: ConfirmableCommand>(
    deny: On<Deny<C>>,
    mut commands: Commands,
    mut history: ResMut<CommandHistory>,
    despawn_entities: Query<(Entity, &DespawnOnResponse<C>)>,
) {
    history.deny(deny.id);

    for (entity, despawn) in despawn_entities {
        if despawn.id == deny.id {
            debug!("despawning `{entity}` on response for `{:?}`", despawn.id);
            commands.entity(entity).despawn();
        }
    }
}

/// Command request from a client.
pub(crate) type ClientCommand<C> = FromClient<CommandRequest<C>>;

pub(crate) trait ClientCommandExt<C> {
    fn confirm(&self) -> ToClients<Confirm<C>>;
    fn deny(&self) -> ToClients<Deny<C>>;
}

impl<C> ClientCommandExt<C> for ClientCommand<C> {
    fn confirm(&self) -> ToClients<Confirm<C>> {
        ToClients {
            mode: SendMode::Direct(self.client_id),
            message: Confirm {
                id: self.id,
                marker: PhantomData,
            },
        }
    }

    fn deny(&self) -> ToClients<Deny<C>> {
        ToClients {
            mode: SendMode::Direct(self.client_id),
            message: Deny {
                id: self.id,
                marker: PhantomData,
            },
        }
    }
}

/// Generic event to send a confirmable command with its ID to server.
#[derive(Event, Deref, DerefMut, Serialize, Deserialize, Clone, Copy)]
pub(crate) struct CommandRequest<C> {
    pub(crate) id: CommandId,

    #[deref]
    pub(crate) command: C,
}

impl<C: MapEntities> MapEntities for CommandRequest<C> {
    fn map_entities<T: EntityMapper>(&mut self, entity_mapper: &mut T) {
        self.command.map_entities(entity_mapper);
    }
}

#[derive(Event, Serialize, Deserialize)]
pub(crate) struct Confirm<C> {
    pub(crate) id: CommandId,
    marker: PhantomData<C>,
}

#[derive(Event, Serialize, Deserialize)]
pub(crate) struct Deny<C> {
    pub(crate) id: CommandId,
    marker: PhantomData<C>,
}

#[derive(Component)]
pub(crate) struct DespawnOnResponse<C: ConfirmableCommand> {
    id: CommandId,
    marker: PhantomData<C>,
}

impl<C: ConfirmableCommand> DespawnOnResponse<C> {
    pub(crate) fn new(id: CommandId) -> Self {
        Self {
            id,
            marker: PhantomData,
        }
    }
}
