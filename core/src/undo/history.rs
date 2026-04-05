use std::collections::VecDeque;

use bevy::{ecs::entity::EntityHashMap, platform::collections::HashMap, prelude::*};

use super::{ApplyHistoryCommand, CommandId, CommandSource, HistoryCommand, RecordedEntities};

#[derive(Resource)]
pub(super) struct CommandHistory {
    undo: VecDeque<CommandRecord>,
    redo: VecDeque<CommandRecord>,
    pending: HashMap<CommandId, ApplyHistoryCommand>,
    max_len: usize,

    /// Entity map for [`EntityRecorder`](super::EntityRecorder).
    ///
    /// Cleared after each use. Stored to reuse allocated memory.
    queued_mappings: EntityHashMap<Entity>,

    /// Counter for [`CommandId`] values used by [`ConfirmableCommand`](super::ConfirmableCommand).
    next_id: CommandId,
}

impl CommandHistory {
    pub(super) fn new(max_len: usize) -> Self {
        Self {
            undo: Default::default(),
            redo: Default::default(),
            pending: Default::default(),
            max_len,
            queued_mappings: Default::default(),
            next_id: Default::default(),
        }
    }

    /// Queues a mapping from an old entity to a new one.
    ///
    /// Pending mappings are applied by [`Self::flush_entity_mappings`].
    pub(super) fn queue_entity_map(&mut self, old_entity: Entity, new_entity: Entity) {
        trace!("mapping `{old_entity}` to `{new_entity}`");
        self.queued_mappings.insert(old_entity, new_entity);
    }

    /// Applies queued entity mappings to commands in undo and redo history.
    pub(super) fn flush_entity_mappings(&mut self) {
        if self.queued_mappings.is_empty() {
            return;
        }

        for record in self.undo.iter_mut().chain(&mut self.redo) {
            record.command.map_entities(&mut self.queued_mappings);
        }
        trace!(
            "updated {} entities inside commands",
            self.queued_mappings.len()
        );

        self.queued_mappings.clear();
    }

    pub(super) fn next_id(&mut self) -> CommandId {
        let current = self.next_id;
        self.next_id.0 += 1;
        current
    }

    pub(super) fn push_pending(&mut self, id: CommandId, apply: ApplyHistoryCommand) {
        self.pending.insert(id, apply);
    }

    pub(super) fn push(
        &mut self,
        command: HistoryCommand,
        entities: RecordedEntities,
        source: CommandSource,
    ) {
        let name = command.name();
        let record = CommandRecord { command, entities };
        match source {
            CommandSource::User => {
                debug!("adding `{name}` to undo and clearing redo");
                self.redo.clear();
                push_to_stack(&mut self.undo, record, self.max_len);
            }
            CommandSource::Undo => {
                debug!("adding `{name}` to redo");
                push_to_stack(&mut self.redo, record, self.max_len);
            }
            CommandSource::Redo => {
                debug!("adding `{name}` to undo");
                push_to_stack(&mut self.undo, record, self.max_len);
            }
        }
    }

    pub(super) fn confirm(&mut self, id: CommandId) {
        let Some(apply) = self.pending.remove(&id) else {
            debug!("ignoring confirmation for non-existing `{id:?}`");
            return;
        };

        debug!("confirming `{id:?}` with `{}`", apply.command.name());
        self.push(apply.command, apply.entities, apply.source);
    }

    pub(super) fn deny(&mut self, id: CommandId) {
        if let Some(apply) = self.pending.remove(&id) {
            debug!("denying `{id:?}` with `{}`", apply.command.name());
        } else {
            debug!("ignoring deny for non-existing `{id:?}`");
        }
    }

    pub(super) fn pop_undo(&mut self) -> Option<CommandRecord> {
        self.undo.pop_back()
    }

    pub(super) fn pop_redo(&mut self) -> Option<CommandRecord> {
        self.redo.pop_back()
    }
}

impl Default for CommandHistory {
    fn default() -> Self {
        Self::new(25)
    }
}

fn push_to_stack(stack: &mut VecDeque<CommandRecord>, record: CommandRecord, max_len: usize) {
    stack.push_back(record);
    if stack.len() > max_len {
        stack.pop_front();
    }
}

/// A command stored in the undo or redo history.
pub(super) struct CommandRecord {
    pub(super) command: HistoryCommand,

    /// Entities produced by the previous inverted command, if any.
    ///
    /// Used to update entity references in other commands once [`Self::command`]
    /// executes and produces new entities.
    pub(super) entities: RecordedEntities,
}
