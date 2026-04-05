use bevy::{ecs::entity::MapEntities, prelude::*};
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize, de::DeserializeOwned};

use super::{CommandId, ConfirmableCommand};

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
    }
}

/// Command request from a client.
pub(crate) type ClientCommand<C> = FromClient<CommandRequest<C>>;

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
