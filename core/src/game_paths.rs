use std::{
    fs::{self, DirEntry},
    path::PathBuf,
};

use bevy::prelude::*;
use directories::ProjectDirs;

pub(super) fn plugin(app: &mut App) {
    app.init_resource::<GamePaths>();
}

const WORLD_EXTENSION: &str = "ron";

#[derive(Resource)]
pub struct GamePaths {
    pub worlds: PathBuf,
}

impl GamePaths {
    pub fn world_path(&self, name: &str) -> PathBuf {
        let mut path = self.worlds.join(name);
        path.set_extension(WORLD_EXTENSION);
        path
    }

    pub fn world_names(&self) -> Result<Vec<String>> {
        let entries = self
            .worlds
            .read_dir()
            .map_err(|e| format!("unable to read {:?}: {e}", self.worlds))?;
        let mut worlds = Vec::new();
        for entry in entries.filter_map(Result::ok) {
            if let Some(name) = world_name(&entry) {
                worlds.push(name);
            }
        }
        Ok(worlds)
    }
}

fn world_name(entry: &DirEntry) -> Option<String> {
    let file_type = entry.file_type().ok()?;
    if !file_type.is_file() {
        return None;
    }

    let path = entry.path();
    let extension = path.extension()?;
    if extension != WORLD_EXTENSION {
        return None;
    }

    path.file_stem()?.to_str().map(|stem| stem.to_string())
}

impl Default for GamePaths {
    fn default() -> Self {
        let dirs = ProjectDirs::from("io", "Simgine", "Simgine")
            .expect("project directories should be accessible");

        let config_dir = dirs.config_dir();
        info!("using {config_dir:?} config directory");

        let worlds = config_dir.join("world");
        fs::create_dir_all(&worlds)
            .unwrap_or_else(|e| panic!("{worlds:?} should be writable: {e}"));

        Self { worlds }
    }
}
