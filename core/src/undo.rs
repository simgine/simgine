pub(crate) mod history;
pub(crate) mod request;

use bevy::{
    ecs::entity::{EntityHashMap, MapEntities},
    prelude::*,
};
use serde::{Deserialize, Serialize};
use smallvec::SmallVec;

use history::CommandHistory;

pub(super) fn plugin(app: &mut App) {
    app.init_resource::<CommandHistory>();
}

pub trait HistoryCommandsExt {
    /// Triggers a command that can be undone.
    fn queue_reversible<C: ReversibleCommand>(&mut self, command: C);

    /// Like [`Self::queue_reversible`], but requires confirmation before the command is added to the history.
    fn queue_confirmable<C: ConfirmableCommand>(&mut self, command: C);

    /// Reverses the most recent command queued with [`Self::queue_reversible`].
    fn undo(&mut self);

    /// Reapplies the most recently undone command, if any.
    fn redo(&mut self);

    /// Confirms a pending [`ConfirmableCommand`].
    ///
    /// Moves the command from the pending state into the undo/redo history.
    fn confirm(&mut self, id: CommandId);

    /// Denies a pending [`ConfirmableCommand`].
    ///
    /// Cancels the command and removes it from the pending state without
    /// adding it to the undo/redo history.
    fn deny(&mut self, id: CommandId);
}

impl HistoryCommandsExt for Commands<'_, '_> {
    fn queue_reversible<C: ReversibleCommand>(&mut self, command: C) {
        self.queue(ApplyHistoryCommand {
            command: HistoryCommand::Reversible(Box::new(command)),
            entities: Default::default(),
            source: CommandSource::User,
        });
    }

    fn queue_confirmable<C: ConfirmableCommand>(&mut self, command: C) {
        self.queue(ApplyHistoryCommand {
            command: HistoryCommand::Confirmable(Box::new(command)),
            entities: Default::default(),
            source: CommandSource::User,
        });
    }

    fn undo(&mut self) {
        self.queue(|world: &mut World| {
            let mut history = world.resource_mut::<CommandHistory>();
            if let Some(record) = history.pop_undo() {
                info!("undo");
                let command = ApplyHistoryCommand {
                    command: record.command,
                    entities: record.entities,
                    source: CommandSource::Undo,
                };
                command.apply(world);
            }
        });
    }

    fn redo(&mut self) {
        self.queue(|world: &mut World| {
            let mut history = world.resource_mut::<CommandHistory>();
            if let Some(record) = history.pop_redo() {
                info!("redo");
                let command = ApplyHistoryCommand {
                    command: record.command,
                    entities: record.entities,
                    source: CommandSource::Redo,
                };
                command.apply(world);
            }
        });
    }

    fn confirm(&mut self, id: CommandId) {
        self.queue(move |world: &mut World| {
            let mut history = world.resource_mut::<CommandHistory>();
            history.confirm(id);
        });
    }

    fn deny(&mut self, id: CommandId) {
        self.queue(move |world: &mut World| {
            let mut history = world.resource_mut::<CommandHistory>();
            history.deny(id);
        });
    }
}

/// Applies a command that will be tracked in [`CommandHistory`].
struct ApplyHistoryCommand {
    /// Command to apply.
    command: HistoryCommand,

    /// Entities created by the previous inverted command, if any.
    entities: RecordedEntities,

    /// Who triggered the command.
    source: CommandSource,
}

impl Command for ApplyHistoryCommand {
    fn apply(mut self, world: &mut World) {
        let name = self.command.name();
        debug!("applying `{name}`");

        let world_cell = world.as_unsafe_world_cell();
        // SAFETY: access is disjoint since the state resource is private and can't be accessed during apply.
        let history = unsafe { &mut *world_cell.get_resource_mut::<CommandHistory>().unwrap() };
        let world = unsafe { world_cell.world_mut() };
        let mut recorder = EntityRecorder::new(&mut self.entities);

        let (id, inverted) = match self.command {
            HistoryCommand::Reversible(command) => {
                (None, command.apply(&mut recorder, world).map(Into::into))
            }
            HistoryCommand::Confirmable(command) => {
                let id = history.next_id();
                (
                    Some(id),
                    command.apply(id, &mut recorder, world).map(Into::into),
                )
            }
        };

        history.flush_entity_mappings(&mut recorder.queued_mappings);

        let Some(inverted) = inverted else {
            debug!("unable to apply `{name}`");
            return;
        };

        if let Some(id) = id {
            self.command = inverted;
            history.push_pending(id, self);
        } else {
            history.push(inverted, self.entities, self.source);
        }
    }
}

enum HistoryCommand {
    Reversible(Box<dyn ReversibleCommand>),
    Confirmable(Box<dyn ConfirmableCommand>),
}

impl HistoryCommand {
    fn name(&self) -> ShortName<'static> {
        match self {
            HistoryCommand::Reversible(command) => command.dyn_name(),
            HistoryCommand::Confirmable(command) => command.dyn_name(),
        }
    }

    fn map_entities(&mut self, map: &mut EntityHashMap<Entity>) {
        match self {
            HistoryCommand::Reversible(command) => command.dyn_map_entities(map),
            HistoryCommand::Confirmable(command) => command.dyn_map_entities(map),
        }
    }
}

impl From<Box<dyn ReversibleCommand>> for HistoryCommand {
    fn from(value: Box<dyn ReversibleCommand>) -> Self {
        Self::Reversible(value)
    }
}

impl From<Box<dyn ConfirmableCommand>> for HistoryCommand {
    fn from(value: Box<dyn ConfirmableCommand>) -> Self {
        Self::Confirmable(value)
    }
}

#[derive(PartialEq, Clone, Copy)]
enum CommandSource {
    User,
    Undo,
    Redo,
}

/// ID for a [`ConfirmableCommand`].
#[derive(Component, Default, Debug, Serialize, Deserialize, Hash, PartialEq, Eq, Clone, Copy)]
pub struct CommandId(u64);

/// Records entity changes in commands.
///
/// Needed to correctly handle entity references in commands that spawn/despawn entities.
pub struct EntityRecorder<'a> {
    entities: &'a mut RecordedEntities,
    queued_mappings: EntityHashMap<Entity>,
    index: usize,
}

impl<'a> EntityRecorder<'a> {
    fn new(entities: &'a mut RecordedEntities) -> Self {
        Self {
            entities,
            queued_mappings: Default::default(),
            index: 0,
        }
    }

    /// Record command entity that may change during the undo/redo.
    ///
    /// Entities between commands that spawn and despawn entities are
    /// matched by their index, so their order should be deterministic.
    ///
    /// For example:
    /// - A command despawns entity X and records it.
    /// - On undo, the inverted command spawns a new entity Y and records it.
    ///
    /// This creates a mapping from X to Y, which is applied to commands
    /// stored in the undo and redo history.
    #[allow(unused, reason = "not used in the project yet")]
    pub(crate) fn record(&mut self, entity: Entity) {
        trace!("recording `{entity}`");
        if let Some(old_entity) = self.entities.get_mut(self.index) {
            trace!("mapping `{old_entity}` to `{entity}`");
            self.queued_mappings.insert(*old_entity, entity);
            *old_entity = entity;
        } else {
            self.entities.push(entity);
        }

        self.index += 1;
    }
}

/// Most commands operate on a single entity, so this uses
/// [`SmallVec`] to avoid heap allocations in the common case.
type RecordedEntities = SmallVec<[Entity; 1]>;

/// Like [`Command`], but can be undone.
pub trait ReversibleCommand: DynReversible + Send + Sync + 'static {
    /// Applies the command and returns the inverted command to store in history.
    ///
    /// Returns [`None`] if the command is no longer valid,
    /// for example if the world changed externally.
    fn apply(
        self: Box<Self>,
        recorder: &mut EntityRecorder,
        world: &mut World,
    ) -> Option<Box<dyn ReversibleCommand>>;
}

/// Like [`ReversibleCommand`], but requires confirmation before being considered applied.
pub trait ConfirmableCommand: DynReversible + Send + Sync + 'static {
    /// Like [`ReversibleCommand::apply`], but also accepts associated ID that needs
    /// to be stored somewhere by implementor in order to confirm or deny the command using
    /// this ID later.
    fn apply(
        self: Box<Self>,
        id: CommandId,
        recorder: &mut EntityRecorder,
        world: &mut World,
    ) -> Option<Box<dyn ConfirmableCommand>>;
}

/// Helper for [`ReversibleCommand`] to auto-implement name info and entity mapping
/// without requiring [`MapEntities`] (which is not dyn-compatible).
pub trait DynReversible {
    fn dyn_name(&self) -> ShortName<'static>;
    fn dyn_map_entities(&mut self, map: &mut EntityHashMap<Entity>);
}

impl<T: MapEntities> DynReversible for T {
    fn dyn_name(&self) -> ShortName<'static> {
        ShortName::of::<T>()
    }

    fn dyn_map_entities(&mut self, mapper: &mut EntityHashMap<Entity>) {
        self.map_entities(mapper);
    }
}

#[cfg(test)]
mod tests {
    use std::mem;

    use bevy::ecs::entity::MapEntities;
    use test_log::test;

    use super::*;

    #[test]
    fn translate() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin));

        let entity = app.world_mut().spawn(Transform::default()).id();
        app.world_mut().commands().queue_reversible(Translate {
            entity,
            translation: Vec3::ONE,
        });
        app.world_mut().flush();

        let transform = app.world_mut().get::<Transform>(entity).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);

        app.world_mut().commands().undo();
        app.world_mut().flush();

        let transform = app.world_mut().get::<Transform>(entity).unwrap();
        assert_eq!(transform.translation, Vec3::ZERO);

        app.world_mut().commands().redo();
        app.world_mut().flush();

        let transform = app.world_mut().get::<Transform>(entity).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);
    }

    #[test]
    fn spawn_despawn() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin));

        app.world_mut()
            .commands()
            .queue_reversible(Spawn::default());
        app.world_mut().flush();

        let mut transforms = app.world_mut().query::<&Transform>();
        assert_eq!(transforms.iter(app.world()).len(), 1);

        app.world_mut().commands().undo();
        app.world_mut().flush();

        assert_eq!(transforms.iter(app.world()).count(), 0);

        app.world_mut().commands().redo();
        app.world_mut().flush();

        assert_eq!(transforms.iter(app.world()).len(), 1);
    }

    #[test]
    fn spawn_translate_despawn() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin));

        app.world_mut()
            .commands()
            .queue_reversible(Spawn::default());
        app.world_mut().flush();

        let mut transforms = app.world_mut().query::<(Entity, &Transform)>();
        let (entity, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ZERO);

        app.world_mut().commands().queue_reversible(Translate {
            entity,
            translation: Vec3::ONE,
        });
        app.world_mut().flush();

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);

        app.world_mut()
            .commands()
            .queue_reversible(Despawn { entity });
        app.world_mut().flush();

        assert_eq!(transforms.iter(app.world()).count(), 0);

        app.world_mut().commands().undo();
        app.world_mut().flush();

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);

        app.world_mut().commands().undo();
        app.world_mut().flush();

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ZERO);

        app.world_mut().commands().undo();
        app.world_mut().flush();

        assert_eq!(transforms.iter(app.world()).count(), 0);

        app.world_mut().commands().redo();
        app.world_mut().flush();

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ZERO);

        app.world_mut().commands().redo();
        app.world_mut().flush();

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);

        app.world_mut().commands().redo();
        app.world_mut().flush();

        assert_eq!(transforms.iter(app.world()).count(), 0);
    }

    #[test]
    fn pending_spawn_despawn() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin))
            .init_resource::<LastUndoId>();

        app.world_mut()
            .commands()
            .queue_confirmable(PendingSpawn::default());
        app.world_mut().flush();

        let mut transforms = app.world_mut().query::<&Transform>();
        assert_eq!(transforms.iter(app.world()).len(), 1);

        app.world_mut().commands().undo();
        app.world_mut().flush();

        assert_eq!(transforms.iter(app.world()).len(), 1);

        let spawn_id = **app.world().resource::<LastUndoId>();
        let mut history = app.world_mut().resource_mut::<CommandHistory>();
        history.confirm(spawn_id);

        app.world_mut().commands().undo();
        app.world_mut().flush();

        assert_eq!(transforms.iter(app.world()).count(), 0);

        let despawn_id = **app.world().resource::<LastUndoId>();
        assert_ne!(spawn_id, despawn_id);

        let mut history = app.world_mut().resource_mut::<CommandHistory>();
        history.deny(despawn_id);

        app.world_mut().commands().redo();
        app.world_mut().flush();

        assert_eq!(transforms.iter(app.world()).count(), 0);
    }

    #[test]
    fn max_len() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin))
            .insert_resource(CommandHistory::new(1));

        app.world_mut()
            .commands()
            .queue_reversible(Spawn::default());
        app.world_mut()
            .commands()
            .queue_reversible(Spawn::default());
        app.world_mut().flush();

        let mut transforms = app.world_mut().query::<&Transform>();
        assert_eq!(transforms.iter(app.world()).len(), 2);

        app.world_mut().commands().undo();
        app.world_mut().commands().undo();
        app.world_mut().flush();

        assert_eq!(
            transforms.iter(app.world()).len(),
            1,
            "first spawn should be dropped from history"
        );
    }

    #[derive(MapEntities)]
    struct Translate {
        #[entities]
        entity: Entity,
        translation: Vec3,
    }

    impl ReversibleCommand for Translate {
        fn apply(
            self: Box<Self>,
            _ctx: &mut EntityRecorder,
            world: &mut World,
        ) -> Option<Box<dyn ReversibleCommand>> {
            let mut transform = world.get_mut::<Transform>(self.entity)?;
            let original_translation = mem::replace(&mut transform.translation, self.translation);

            Some(Box::new(Self {
                entity: self.entity,
                translation: original_translation,
            }))
        }
    }

    #[derive(MapEntities, Default)]
    struct Spawn {
        translation: Vec3,
    }

    impl ReversibleCommand for Spawn {
        fn apply(
            self: Box<Self>,
            ctx: &mut EntityRecorder,
            world: &mut World,
        ) -> Option<Box<dyn ReversibleCommand>> {
            let entity = world
                .spawn(Transform::from_translation(self.translation))
                .id();
            ctx.record(entity);

            Some(Box::new(Despawn { entity }))
        }
    }

    #[derive(MapEntities)]
    struct Despawn {
        #[entities]
        entity: Entity,
    }

    impl ReversibleCommand for Despawn {
        fn apply(
            self: Box<Self>,
            ctx: &mut EntityRecorder,
            world: &mut World,
        ) -> Option<Box<dyn ReversibleCommand>> {
            let transform = *world.get::<Transform>(self.entity)?;
            world.entity_mut(self.entity).despawn();
            ctx.record(self.entity);

            Some(Box::new(Spawn {
                translation: transform.translation,
            }))
        }
    }

    #[derive(MapEntities, Default)]
    struct PendingSpawn {
        translation: Vec3,
    }

    impl ConfirmableCommand for PendingSpawn {
        fn apply(
            self: Box<Self>,
            id: CommandId,
            recorder: &mut EntityRecorder,
            world: &mut World,
        ) -> Option<Box<dyn ConfirmableCommand>> {
            let mut last_id = world.resource_mut::<LastUndoId>();
            **last_id = id;

            let entity = world
                .spawn(Transform::from_translation(self.translation))
                .id();
            recorder.record(entity);

            Some(Box::new(PendingDespawn { entity }))
        }
    }

    #[derive(MapEntities)]
    struct PendingDespawn {
        #[entities]
        entity: Entity,
    }

    impl ConfirmableCommand for PendingDespawn {
        fn apply(
            self: Box<Self>,
            id: CommandId,
            recorder: &mut EntityRecorder,
            world: &mut World,
        ) -> Option<Box<dyn ConfirmableCommand>> {
            let mut last_id = world.resource_mut::<LastUndoId>();
            **last_id = id;

            let transform = *world.get::<Transform>(self.entity)?;
            world.entity_mut(self.entity).despawn();
            recorder.record(self.entity);

            Some(Box::new(PendingSpawn {
                translation: transform.translation,
            }))
        }
    }

    #[derive(Resource, Default, Deref, DerefMut, Clone, Copy)]
    struct LastUndoId(CommandId);
}
