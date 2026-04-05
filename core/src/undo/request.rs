use bevy::{ecs::entity::MapEntities, prelude::*};
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize, de::DeserializeOwned};

use super::{CommandId, ConfirmableCommand};

#[allow(dead_code, reason = "not used in the codebase yet")]
pub(crate) trait RemoteConfirmableAppExt {
    fn add_remote_confirmable<C>(&mut self) -> &mut Self
    where
        C: ConfirmableCommand + Serialize + DeserializeOwned + MapEntities + Clone;
}

impl RemoteConfirmableAppExt for App {
    fn add_remote_confirmable<C>(&mut self) -> &mut Self
    where
        C: ConfirmableCommand + Serialize + DeserializeOwned + MapEntities + Clone,
    {
        self.add_mapped_client_event::<CommandRequest<C>>(Channel::Ordered)
    }
}

/// Generic event to send a confirmable command with its ID.
#[derive(Event, Clone, Copy, Serialize, Deserialize)]
pub(crate) struct CommandRequest<C> {
    pub(crate) id: CommandId,
    pub(crate) command: C,
}

impl<C: MapEntities> MapEntities for CommandRequest<C> {
    fn map_entities<T: EntityMapper>(&mut self, entity_mapper: &mut T) {
        self.command.map_entities(entity_mapper);
    }
}
