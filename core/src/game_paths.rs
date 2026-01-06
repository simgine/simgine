use std::{fs, path::PathBuf};

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
    /// Returns iterator over world files.
    pub fn iter_worlds(&self) -> Result<impl Iterator<Item = PathBuf>> {
        let entries = self
            .worlds
            .read_dir()
            .map_err(|e| format!("unable to read {:?}: {e}", self.worlds))?;

        let iter = entries.filter_map(Result::ok).filter_map(|entry| {
            let file_type = entry.file_type().ok()?;
            if !file_type.is_file() {
                return None;
            }

            let path = entry.path();
            let extension = path.extension()?;
            if extension != WORLD_EXTENSION {
                return None;
            }

            Some(path)
        });

        Ok(iter)
    }
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
