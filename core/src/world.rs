use std::{fs, mem};

use bevy::{prelude::*, scene::serde::SceneDeserializer};
use bevy_replicon::{prelude::*, scene};
use serde::{Deserialize, Serialize, de::DeserializeSeed};

use crate::{
    component_res::{ComponentResExt, InsertComponentResExt},
    error_event::trigger_error,
    game_paths::GamePaths,
    state::GameState,
};

pub(super) fn plugin(app: &mut App) {
    app.register_resource_component::<WorldName>()
        .replicate::<WorldName>()
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

    let mut scene = DynamicScene::default();
    scene::replicate_into(&mut scene, world);
    let bytes = scene
        .serialize(&registry.read())
        .expect("world should be serializable");

    fs::write(&path, bytes).map_err(|e| format!("unable to save game to {path:?}: {e}"))?;

    Ok(())
}

fn load(
    load: On<LoadWorld>,
    mut scene_spawner: ResMut<SceneSpawner>,
    mut scenes: ResMut<Assets<DynamicScene>>,
    registry: Res<AppTypeRegistry>,
    game_paths: Res<GamePaths>,
) -> Result<()> {
    let path = game_paths.world_path(&load.name);
    info!("loading {path:?}");

    let bytes = fs::read(&path).map_err(|e| format!("unable to load {path:?}: {e}"))?;
    let mut deserializer = ron::Deserializer::from_bytes(&bytes)
        .map_err(|e| format!("unable to parse {path:?}: {e}"))?;
    let scene_deserializer = SceneDeserializer {
        type_registry: &registry.read(),
    };
    let scene = scene_deserializer
        .deserialize(&mut deserializer)
        .map_err(|e| format!("unable to deserialize {path:?}: {e}"))?;

    scene_spawner.spawn_dynamic(scenes.add(scene));

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
#[require(Replicated, DespawnOnExit::<GameState>(GameState::World))]
#[reflect(Component)]
struct WorldName(String);
