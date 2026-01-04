use std::{any::TypeId, env, marker::PhantomData, path::Path, sync::Arc};

use bevy::{
    asset::{AssetLoader, AssetPath, AsyncReadExt, LoadContext, LoadedUntypedAsset, io::Reader},
    prelude::*,
    reflect::{TypeRegistry, TypeRegistryArc, serde::TypedReflectDeserializer},
};
use serde::{Deserialize, de::DeserializeSeed};
use walkdir::WalkDir;

use crate::state::GameState;

pub(super) fn plugin(app: &mut App) {
    app.init_asset::<ObjectManifest>()
        .init_asset_loader::<ManifestLoader<ObjectManifest>>()
        .init_resource::<AssetManifests>()
        .add_systems(
            Update,
            wait_for_loading.run_if(in_state(GameState::ManifestsLoading)),
        );
}

fn wait_for_loading(
    mut commands: Commands,
    manifests: Res<AssetManifests>,
    asset_server: Res<AssetServer>,
) {
    if manifests
        .iter()
        .all(|handle| asset_server.is_loaded(handle))
    {
        info!("finished loading asset manifests");
        commands.set_state(GameState::Menu);
    }
}

/// Resource that keeps manifests loaded.
#[derive(Resource, Deref)]
struct AssetManifests(Vec<Handle<LoadedUntypedAsset>>);

impl FromWorld for AssetManifests {
    fn from_world(world: &mut World) -> Self {
        let current_dir = env::var("CARGO_MANIFEST_DIR").unwrap_or_default();
        let assets_dir = Path::new(&current_dir).join("assets");
        debug!("searching for manifests in {assets_dir:?}");

        let mut manifests = AssetManifests(Vec::new());
        let asset_server = world.resource::<AssetServer>();
        for path in WalkDir::new(&assets_dir)
            .into_iter()
            .filter_map(|e| e.ok())
            .map(|e| e.into_path())
            .filter(|p| p.extension().is_some_and(|e| e == "ron"))
        {
            let relative_path = path
                .strip_prefix(&assets_dir)
                .unwrap_or_else(|e| panic!("entries should start with {assets_dir:?}: {e}"));

            debug!("loading manifest {relative_path:?}");

            let handle = asset_server.load_untyped(AssetPath::from_path(relative_path));
            manifests.0.push(handle);
        }

        manifests
    }
}

#[derive(TypePath)]
struct ManifestLoader<M: AssetManifest> {
    registry: TypeRegistryArc,
    marker: PhantomData<M>,
}

impl<M: AssetManifest> AssetLoader for ManifestLoader<M> {
    type Asset = M;
    type Settings = ();
    type Error = BevyError;

    async fn load(
        &self,
        reader: &mut dyn Reader,
        _settings: &Self::Settings,
        load_context: &mut LoadContext<'_>,
    ) -> Result<Self::Asset, Self::Error> {
        let mut string = String::new();
        reader.read_to_string(&mut string).await?;

        let registry = self.registry.read();
        let registration = registry.get(TypeId::of::<ObjectManifest>()).unwrap();

        let mut deserializer = ron::Deserializer::from_str(&string)?;
        let reflect_deserializer = TypedReflectDeserializer::new(registration, &registry);
        let reflect = reflect_deserializer.deserialize(&mut deserializer)?;
        let mut manifest = M::take_from_reflect(reflect).unwrap();
        manifest.resolve_paths(&registry, load_context.path());

        Ok(manifest)
    }

    fn extensions(&self) -> &'static [&'static str] {
        &[M::EXTENSION]
    }
}

impl<M: AssetManifest> FromWorld for ManifestLoader<M> {
    fn from_world(world: &mut World) -> Self {
        Self {
            registry: world.resource::<AppTypeRegistry>().0.clone(),
            marker: PhantomData,
        }
    }
}

trait AssetManifest: Asset + FromReflect {
    const EXTENSION: &'static str;

    fn resolve_paths(&mut self, registry: &TypeRegistry, manifest_path: &AssetPath);
}

#[derive(Asset, Reflect)]
pub struct ObjectManifest {
    pub info: ManifestInfo,
    pub scene: AssetPath<'static>,
    pub category: ObjectCategory,
    pub components: Vec<Arc<dyn PartialReflect>>,
}

impl AssetManifest for ObjectManifest {
    const EXTENSION: &'static str = "object.ron";

    fn resolve_paths(&mut self, registry: &TypeRegistry, manifest_path: &AssetPath) {
        // TODO: Avoid `to_string`, asked in https://github.com/bevyengine/bevy/issues/22239.
        self.scene = manifest_path
            .resolve_embed(&self.scene.to_string())
            .unwrap();

        for component in &mut self.components {
            let type_path = component.reflect_type_path();
            let Some(registration) = registry.get_with_type_path(type_path) else {
                continue;
            };
            if let Some(resolve_path) =
                registry.get_type_data::<ReflectResolvePaths>(registration.type_id())
                && let Some(component) = resolve_path.get_mut(component)
            {
                component.resolve_paths(manifest_path);
            }
        }
    }
}

#[derive(Deserialize, Reflect, PartialEq, Clone, Copy)]
pub enum ObjectCategory {
    Furniture,
}

#[derive(Deserialize, Reflect)]
pub struct ManifestInfo {
    pub name: String,
    pub author: String,
    pub license: String,
}

/// Maps paths inside reflected components.
#[reflect_trait]
trait ResolvePaths {
    /// Converts all relative paths into absolute paths.
    fn resolve_paths(&mut self, manifest_path: &AssetPath);
}
