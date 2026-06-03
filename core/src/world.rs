pub mod character;
mod city;
mod combined_collider;
pub mod cursor;
pub mod family;
mod layer;
pub mod object;
mod placing;
mod player_camera;
mod preview;
mod sky;
pub mod time;

use std::{fs, mem};

use bevy::{prelude::*, world_serialization::serde::WorldDeserializer};
use bevy_replicon::{prelude::*, world_serialization};
use serde::{Deserialize, Serialize, de::DeserializeSeed};

use crate::{
    component_res::{ComponentResExt, InsertComponentResExt},
    error_event::trigger_error,
    game_paths::GamePaths,
    state::GameState,
};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((
        character::plugin,
        city::plugin,
        combined_collider::plugin,
        cursor::plugin,
        family::plugin,
        object::plugin,
        placing::plugin,
        player_camera::plugin,
        preview::plugin,
        sky::plugin,
        time::plugin,
    ))
    .register_resource_component::<WorldName>()
    .replicate::<WorldName>()
    .replicate::<Transform>()
    .add_observer(create)
    .add_observer(save.pipe(trigger_error))
    .add_observer(load.pipe(trigger_error))
    .add_observer(update_state);
}

fn create(mut create: On<CreateWorld>, mut commands: Commands) {
    commands.insert_component_resource(WorldName(mem::take(&mut create.name)));
}

fn save(
    mut _on: On<SaveWorld>,
    world: &World,
    registry: Res<AppTypeRegistry>,
    world_name: Single<&WorldName>,
    game_paths: Res<GamePaths>,
) -> Result<()> {
    let path = game_paths.world_path(*world_name);
    info!("saving to {path:?}");

    fs::create_dir_all(&game_paths.worlds)
        .map_err(|e| format!("unable to create {path:?}: {e}"))?;

    let mut dyn_world = DynamicWorld::default();
    world_serialization::replicate_into(&mut dyn_world, world);
    let bytes = dyn_world
        .serialize(&registry.read())
        .expect("world should be serializable");

    fs::write(&path, bytes).map_err(|e| format!("unable to save game to {path:?}: {e}"))?;

    Ok(())
}

fn load(
    load: On<LoadWorld>,
    mut scene_spawner: ResMut<WorldInstanceSpawner>,
    mut dyn_worlds: ResMut<Assets<DynamicWorld>>,
    asset_server: Res<AssetServer>,
    registry: Res<AppTypeRegistry>,
    game_paths: Res<GamePaths>,
) -> Result<()> {
    let path = game_paths.world_path(&load.name);
    info!("loading {path:?}");

    let bytes = fs::read(&path).map_err(|e| format!("unable to load {path:?}: {e}"))?;
    let mut deserializer = ron::Deserializer::from_bytes(&bytes)
        .map_err(|e| format!("unable to parse {path:?}: {e}"))?;
    let world_deserializer = WorldDeserializer {
        type_registry: &registry.read(),
        load_from_path: &mut asset_server.clone(),
    };
    let dyn_world = world_deserializer
        .deserialize(&mut deserializer)
        .map_err(|e| format!("unable to deserialize {path:?}: {e}"))?;

    scene_spawner.spawn_dynamic(dyn_worlds.add(dyn_world));

    Ok(())
}

fn update_state(_on: On<Add, WorldName>, mut commands: Commands, world_name: Single<&WorldName>) {
    info!("entering '{}'", ***world_name);
    commands.set_state(GameState::World);
}

#[derive(Event)]
pub struct CreateWorld {
    pub name: String,
}

#[derive(Event)]
pub struct SaveWorld;

#[derive(Event)]
pub struct LoadWorld {
    pub name: String,
}

#[derive(Component, Deref, Reflect, Serialize, Deserialize)]
#[require(
    Replicated,
    DespawnOnExit::<_>(GameState::World)
)]
#[reflect(Component)]
pub struct WorldName(String);
