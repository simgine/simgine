pub(crate) mod history;
pub(crate) mod request;

use bevy::{
    ecs::{
        entity::{EntityHashMap, MapEntities},
        system::SystemParam,
    },
    prelude::*,
};
use serde::{Deserialize, Serialize};
use smallvec::SmallVec;

use history::{CommandHistory, CommandRecord, HistoryCommand};

pub(super) fn plugin(app: &mut App) {
    app.init_resource::<CommandHistory>()
        .init_resource::<CommandIdAllocator>();
}

#[derive(SystemParam, Deref, DerefMut)]
pub struct HistoryCommands<'w, 's> {
    #[deref]
    commands: Commands<'w, 's>,
    allocator: ResMut<'w, CommandIdAllocator>,
}

impl HistoryCommands<'_, '_> {
    /// Triggers a command that can be undone.
    #[allow(unused, reason = "not used in the project yet")]
    pub(crate) fn queue_reversible<C: ReversibleCommand>(&mut self, command: C) {
        self.queue(ApplyReverisbleCommand {
            command: Box::new(command),
            entities: Default::default(),
            source: CommandSource::User,
        });
    }

    /// Like [`Self::queue_reversible`], but requires confirmation before the command is added to the history.
    #[allow(unused, reason = "not used in the project yet")]
    pub(crate) fn queue_confirmable<C: ConfirmableCommand>(&mut self, command: C) -> CommandId {
        let id = self.allocator.alloc();
        self.queue(ApplyConfirmableCommand {
            id,
            command: Box::new(command),
            entities: Default::default(),
            source: CommandSource::User,
        });
        id
    }

    /// Reverses the most recent command queued with [`Self::queue_reversible`].
    pub fn undo(&mut self) {
        self.queue(|world: &mut World| {
            let mut history = world.resource_mut::<CommandHistory>();
            if let Some(record) = history.pop_undo() {
                info!("undo");
                apply_record(world, record, CommandSource::Undo);
            }
        });
    }

    /// Reapplies the most recently undone command, if any.
    pub fn redo(&mut self) {
        self.queue(|world: &mut World| {
            let mut history = world.resource_mut::<CommandHistory>();
            if let Some(record) = history.pop_redo() {
                info!("redo");
                apply_record(world, record, CommandSource::Redo);
            }
        });
    }
}

fn apply_record(world: &mut World, record: CommandRecord, source: CommandSource) {
    match record.command {
        HistoryCommand::Reversible(command) => {
            let command = ApplyReverisbleCommand {
                command,
                entities: record.entities,
                source,
            };
            command.apply(world);
        }
        HistoryCommand::Confirmable(command) => {
            let mut allocator = world.resource_mut::<CommandIdAllocator>();
            let id = allocator.alloc();
            let command = ApplyConfirmableCommand {
                id,
                command,
                entities: record.entities,
                source,
            };
            command.apply(world);
        }
    }
}

/// Counter for [`CommandId`] values used by [`ConfirmableCommand`].
#[derive(Resource, Default)]
struct CommandIdAllocator {
    next_id: CommandId,
}

impl CommandIdAllocator {
    fn alloc(&mut self) -> CommandId {
        let current = self.next_id;
        self.next_id.0 += 1;
        current
    }
}

/// ID for a [`ConfirmableCommand`].
#[derive(Component, Default, Debug, Serialize, Deserialize, Hash, PartialEq, Eq, Clone, Copy)]
pub struct CommandId(u64);

/// Applies a command that will be tracked in [`CommandHistory`].
struct ApplyReverisbleCommand {
    /// Command to apply.
    command: Box<dyn ReversibleCommand>,

    /// Entities created by the previous inverted command, if any.
    entities: RecordedEntities,

    /// Who triggered the command.
    source: CommandSource,
}

impl Command for ApplyReverisbleCommand {
    fn apply(mut self, world: &mut World) {
        let name = self.command.dyn_name();
        debug!("applying `{name}`");

        let mut recorder = EntityRecorder::new(&mut self.entities);
        let Some(inverted) = self.command.apply(&mut recorder, world) else {
            debug!("unable to apply `{name}`");
            return;
        };

        let mut history = world.resource_mut::<CommandHistory>();
        history.flush_entity_mappings(&mut recorder.queued_mappings);
        history.push_reversible(inverted, self.entities, self.source);
    }
}

/// Like [`ApplyReverisbleCommand`], but applies a command that requires
/// confirmation before it becomes tracked in [`CommandHistory`].
struct ApplyConfirmableCommand {
    id: CommandId,

    /// Command to apply.
    command: Box<dyn ConfirmableCommand>,

    /// Entities created by the previous inverted command, if any.
    entities: RecordedEntities,

    /// Who triggered the command.
    source: CommandSource,
}

impl Command for ApplyConfirmableCommand {
    fn apply(mut self, world: &mut World) {
        let name = self.command.dyn_name();
        debug!("applying `{name}` with `{:?}`", self.id);

        let mut recorder = EntityRecorder::new(&mut self.entities);
        let Some(inverted) = self.command.apply(self.id, &mut recorder, world) else {
            debug!("unable to apply `{name}`");
            return;
        };

        let mut history = world.resource_mut::<CommandHistory>();
        history.flush_entity_mappings(&mut recorder.queued_mappings);
        history.push_confirmable(self.id, inverted, self.entities, self.source);
    }
}

#[derive(PartialEq, Clone, Copy)]
enum CommandSource {
    User,
    Undo,
    Redo,
}

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

    use bevy::ecs::{entity::MapEntities, system::SystemState};
    use test_log::test;

    use super::*;

    #[test]
    fn translate() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin));

        let mut state = SystemState::<HistoryCommands>::new(app.world_mut());

        let entity = app.world_mut().spawn(Transform::default()).id();
        state.get_mut(app.world_mut()).queue_reversible(Translate {
            entity,
            translation: Vec3::ONE,
        });
        state.apply(app.world_mut());

        let transform = app.world_mut().get::<Transform>(entity).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);

        state.get_mut(app.world_mut()).undo();
        state.apply(app.world_mut());

        let transform = app.world_mut().get::<Transform>(entity).unwrap();
        assert_eq!(transform.translation, Vec3::ZERO);

        state.get_mut(app.world_mut()).redo();
        state.apply(app.world_mut());

        let transform = app.world_mut().get::<Transform>(entity).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);
    }

    #[test]
    fn spawn_despawn() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin));

        let mut state = SystemState::<HistoryCommands>::new(app.world_mut());

        state
            .get_mut(app.world_mut())
            .queue_reversible(Spawn::default());
        state.apply(app.world_mut());

        let mut transforms = app.world_mut().query::<&Transform>();
        assert_eq!(transforms.iter(app.world()).len(), 1);

        state.get_mut(app.world_mut()).undo();
        state.apply(app.world_mut());

        assert_eq!(transforms.iter(app.world()).count(), 0);

        state.get_mut(app.world_mut()).redo();
        state.apply(app.world_mut());

        assert_eq!(transforms.iter(app.world()).len(), 1);
    }

    #[test]
    fn spawn_translate_despawn() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin));

        let mut state = SystemState::<HistoryCommands>::new(app.world_mut());

        state
            .get_mut(app.world_mut())
            .queue_reversible(Spawn::default());
        state.apply(app.world_mut());

        let mut transforms = app.world_mut().query::<(Entity, &Transform)>();
        let (entity, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ZERO);

        state.get_mut(app.world_mut()).queue_reversible(Translate {
            entity,
            translation: Vec3::ONE,
        });
        state.apply(app.world_mut());

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);

        state
            .get_mut(app.world_mut())
            .queue_reversible(Despawn { entity });
        state.apply(app.world_mut());

        assert_eq!(transforms.iter(app.world()).count(), 0);

        state.get_mut(app.world_mut()).undo();
        state.apply(app.world_mut());

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);

        state.get_mut(app.world_mut()).undo();
        state.apply(app.world_mut());

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ZERO);

        state.get_mut(app.world_mut()).undo();
        state.apply(app.world_mut());

        assert_eq!(transforms.iter(app.world()).count(), 0);

        state.get_mut(app.world_mut()).redo();
        state.apply(app.world_mut());

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ZERO);

        state.get_mut(app.world_mut()).redo();
        state.apply(app.world_mut());

        let (_, transform) = transforms.single(app.world()).unwrap();
        assert_eq!(transform.translation, Vec3::ONE);

        state.get_mut(app.world_mut()).redo();
        state.apply(app.world_mut());

        assert_eq!(transforms.iter(app.world()).count(), 0);
    }

    #[test]
    fn pending_spawn_despawn() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin))
            .init_resource::<LastUndoId>();

        let mut state = SystemState::<HistoryCommands>::new(app.world_mut());

        state
            .get_mut(app.world_mut())
            .queue_confirmable(PendingSpawn::default());
        state.apply(app.world_mut());

        let mut transforms = app.world_mut().query::<&Transform>();
        assert_eq!(transforms.iter(app.world()).len(), 1);

        state.get_mut(app.world_mut()).undo();
        state.apply(app.world_mut());

        assert_eq!(transforms.iter(app.world()).len(), 1);

        let spawn_id = **app.world().resource::<LastUndoId>();
        let mut history = app.world_mut().resource_mut::<CommandHistory>();
        history.confirm(spawn_id);

        state.get_mut(app.world_mut()).undo();
        state.apply(app.world_mut());

        assert_eq!(transforms.iter(app.world()).count(), 0);

        let despawn_id = **app.world().resource::<LastUndoId>();
        assert_ne!(spawn_id, despawn_id);

        let mut history = app.world_mut().resource_mut::<CommandHistory>();
        history.deny(despawn_id);

        state.get_mut(app.world_mut()).redo();
        state.apply(app.world_mut());

        assert_eq!(transforms.iter(app.world()).count(), 0);
    }

    #[test]
    fn max_len() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, plugin))
            .insert_resource(CommandHistory::new(1));

        let mut state = SystemState::<HistoryCommands>::new(app.world_mut());

        let mut commands = state.get_mut(app.world_mut());
        commands.queue_reversible(Spawn::default());
        commands.queue_reversible(Spawn::default());
        state.apply(app.world_mut());

        let mut transforms = app.world_mut().query::<&Transform>();
        assert_eq!(transforms.iter(app.world()).len(), 2);

        let mut commands = state.get_mut(app.world_mut());
        commands.undo();
        commands.undo();
        state.apply(app.world_mut());

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
