use bevy::{asset::AssetPath, prelude::*, reflect::TypeRegistry};
use serde::Deserialize;

use super::{
    AssetManifest, ManifestInfo, ReflectResolvePaths, reflected_component::ReflectedComponent,
};

#[derive(Asset, Reflect)]
pub struct ObjectManifest {
    pub info: ManifestInfo,
    pub scene: AssetPath<'static>,
    pub category: ObjectCategory,
    pub components: Vec<ReflectedComponent>,
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
    Foliage,
}
