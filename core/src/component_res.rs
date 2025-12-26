//! Component-backed resources.
//!
//! Lets a [`Component`] as a singleton "resource" by storing it on
//! a dedicated entity and tracking that entity by component type.
//!
//! Used when support for observers or hooks is needed for a resource.
//!
//! Resources as entities are planned for Bevy 0.19.

use bevy::{
    prelude::*,
    utils::{TypeIdMap, TypeIdMapExt},
};

pub(crate) fn plugin(app: &mut App) {
    app.init_resource::<ResEntities>();
}

pub trait ComponentResExt {
    fn register_resource_component<C: Component>(&mut self) -> &mut Self;
}

impl ComponentResExt for App {
    fn register_resource_component<C: Component>(&mut self) -> &mut Self {
        self.add_observer(register::<C>)
            .add_observer(unregister::<C>)
    }
}

struct InsertComponentRes<C: Component>(C);

impl<C: Component> Command for InsertComponentRes<C> {
    fn apply(self, world: &mut World) {
        let entities = world.resource::<ResEntities>();
        if let Some(&entity) = entities.get_type::<C>() {
            world.entity_mut(entity).insert(self.0);
        } else {
            // Registration happens via the `Add` observer.
            world.spawn(self.0);
        }
    }
}

pub trait InsertComponentResExt {
    fn insert_component_resource<C: Component>(&mut self, component: C);
}

impl InsertComponentResExt for Commands<'_, '_> {
    fn insert_component_resource<C: Component>(&mut self, component: C) {
        self.queue(InsertComponentRes(component));
    }
}

fn register<C: Component>(add: On<Add, C>, mut resource_entities: ResMut<ResEntities>) {
    if resource_entities.insert_type::<C>(add.entity).is_some() {
        error!(
            "entity with resource component `{}` spawned twice",
            ShortName::of::<C>()
        );
    }
}

fn unregister<C: Component>(_on: On<Remove, C>, mut resource_entities: ResMut<ResEntities>) {
    resource_entities.remove_type::<C>();
}

/// Maps types with entities marked as resources to entities on which they are stored.
#[derive(Resource, Default, Deref, DerefMut)]
struct ResEntities(TypeIdMap<Entity>);
