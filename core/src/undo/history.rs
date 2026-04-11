use std::collections::VecDeque;

use bevy::{ecs::entity::EntityHashMap, platform::collections::HashMap, prelude::*};

use super::{CommandId, CommandSource, ConfirmableCommand, RecordedEntities, ReversibleCommand};

#[derive(Resource)]
pub(crate) struct CommandHistory {
    undo: VecDeque<CommandRecord>,
    redo: VecDeque<CommandRecord>,
    pending: HashMap<CommandId, PendingCommandRecord>,
    max_len: usize,
}

impl CommandHistory {
    pub(super) fn new(max_len: usize) -> Self {
        Self {
            undo: Default::default(),
            redo: Default::default(),
            pending: Default::default(),
            max_len,
        }
    }

    /// Applies queued entity mappings to commands in undo and redo history.
    pub(super) fn flush_entity_mappings(&mut self, queued: &mut EntityHashMap<Entity>) {
        if queued.is_empty() {
            return;
        }

        for record in self.undo.iter_mut().chain(&mut self.redo) {
            match &mut record.command {
                HistoryCommand::Reversible(command) => command.dyn_map_entities(queued),
                HistoryCommand::Confirmable(command) => command.dyn_map_entities(queued),
            }
        }
        trace!("updated {} entities inside commands", queued.len());
    }

    pub(super) fn push_confirmable(
        &mut self,
        id: CommandId,
        command: Box<dyn ConfirmableCommand>,
        entities: RecordedEntities,
        source: CommandSource,
    ) {
        self.pending.insert(
            id,
            PendingCommandRecord {
                command,
                entities,
                source,
            },
        );
    }

    pub(super) fn push_reversible(
        &mut self,
        command: Box<dyn ReversibleCommand>,
        entities: RecordedEntities,
        source: CommandSource,
    ) {
        self.push(
            CommandRecord {
                command: HistoryCommand::Reversible(command),
                entities,
            },
            source,
        );
    }

    /// Confirms a pending [`ConfirmableCommand`].
    ///
    /// Moves the command from the pending state into the undo/redo history.
    pub(crate) fn confirm(&mut self, id: CommandId) {
        let Some(record) = self.pending.remove(&id) else {
            debug!("ignoring confirmation for non-existing `{id:?}`");
            return;
        };

        debug!("confirming `{id:?}` with `{}`", record.command.dyn_name());
        self.push(
            CommandRecord {
                command: HistoryCommand::Confirmable(record.command),
                entities: record.entities,
            },
            record.source,
        );
    }

    /// Denies a pending [`ConfirmableCommand`].
    ///
    /// Cancels the command and removes it from the pending state without
    /// adding it to the undo/redo history.
    pub(crate) fn deny(&mut self, id: CommandId) {
        if let Some(record) = self.pending.remove(&id) {
            debug!("denying `{id:?}` with `{}`", record.command.dyn_name());
        } else {
            debug!("ignoring deny for non-existing `{id:?}`");
        }
    }

    fn push(&mut self, record: CommandRecord, source: CommandSource) {
        let name = match &record.command {
            HistoryCommand::Reversible(command) => command.dyn_name(),
            HistoryCommand::Confirmable(command) => command.dyn_name(),
        };

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

struct PendingCommandRecord {
    command: Box<dyn ConfirmableCommand>,
    entities: RecordedEntities,
    source: CommandSource,
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

pub(super) enum HistoryCommand {
    Reversible(Box<dyn ReversibleCommand>),
    Confirmable(Box<dyn ConfirmableCommand>),
}
