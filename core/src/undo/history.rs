use std::collections::VecDeque;

use bevy::{ecs::entity::EntityHashMap, platform::collections::HashMap, prelude::*};

use super::{ApplyHistoryCommand, CommandId, CommandSource, HistoryCommand, RecordedEntities};

#[derive(Resource)]
pub(crate) struct CommandHistory {
    undo: VecDeque<CommandRecord>,
    redo: VecDeque<CommandRecord>,
    pending: HashMap<CommandId, ApplyHistoryCommand>,
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

    /// Updates entity IDs inside commands stored in the undo and redo history.
    ///
    /// Clears the map afterwards.
    pub(super) fn map_entities(&mut self, map: &mut EntityHashMap<Entity>) {
        if map.is_empty() {
            return;
        }

        for record in self.undo.iter_mut().chain(&mut self.redo) {
            record.command.map_entities(map);
        }
        debug!("updated {} entities inside commands", map.len());

        map.clear();
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

    #[allow(unused, reason = "not used in the project yet")]
    pub(crate) fn confirm(&mut self, id: CommandId) {
        let Some(apply) = self.pending.remove(&id) else {
            debug!("ignoring confirmation for non-existing `{id:?}`");
            return;
        };

        debug!("confirming `{id:?}` with `{}`", apply.command.name());
        self.push(apply.command, apply.entities, apply.source);
    }

    #[allow(unused, reason = "not used in the project yet")]
    pub(crate) fn deny(&mut self, id: CommandId) {
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
