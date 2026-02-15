mod cli;
mod window_name;

use bevy::{input_focus::InputDispatchPlugin, prelude::*, render::RenderPlugin};
use bevy_enhanced_input::EnhancedInputPlugin;
use bevy_replicon::prelude::*;
use bevy_replicon_renet::RepliconRenetPlugins;
use bevy_simple_text_input::TextInputPlugin;
use simgine_core::SimgineCorePlugin;
use simgine_ui::SimgineUiPlugin;

fn main() {
    let mut app = App::new();
    app.add_plugins((cli::plugin, window_name::plugin))
        .add_plugins((
            DefaultPlugins.set(RenderPlugin {
                synchronous_pipeline_compilation: true,
                ..Default::default()
            }),
            EnhancedInputPlugin,
            InputDispatchPlugin,
            RepliconPlugins.set(ServerPlugin {
                tick_schedule: None,
                ..Default::default()
            }),
            RepliconRenetPlugins,
            TextInputPlugin,
            SimgineCorePlugin,
            SimgineUiPlugin,
        ));

    app.run();
}
