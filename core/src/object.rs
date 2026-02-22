mod cursor_follower;

use bevy::{asset::AssetPath, ecs::reflect::ReflectCommandExt, prelude::*};
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::{asset_manifest::ObjectManifest, state::GameState};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(cursor_follower::plugin)
        .add_observer(init)
        .add_systems(OnEnter(GameState::World), spawn);
}

/// Spawns object for testing.
fn spawn(mut commands: Commands) {
    commands.spawn(Object {
        path: "base/objects/test/test.object.ron".into(),
    });
}

fn init(
    insert: On<Insert, Object>,
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    manifests: Res<Assets<ObjectManifest>>,
    mut objects: Query<(&Object, &mut Name, &mut SceneRoot)>,
) {
    let (object, mut name, mut scene_root) = objects.get_mut(insert.entity).unwrap();

    let Some(manifest_handle) = asset_server.get_handle(&object.path) else {
        error!("'{}' is missing, ignoring", &object.path);
        return;
    };

    debug!(
        "initializing object '{}' for `{}`",
        &object.path, insert.entity
    );

    let manifest = manifests
        .get(&manifest_handle)
        .unwrap_or_else(|| panic!("'{:?}' should be loaded", &object.path));

    *name = Name::new(manifest.info.name.clone());
    scene_root.0 = asset_server.load(manifest.scene.clone());

    let mut entity = commands.entity(insert.entity);
    for component in &manifest.components {
        entity.insert_reflect(component.reflect_clone().unwrap());
    }
}

#[derive(Component, Serialize, Deserialize)]
#[require(Replicated, SceneRoot, Name)]
#[component(immutable)]
pub struct Object {
    pub path: AssetPath<'static>,
}
