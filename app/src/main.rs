use bevy::{prelude::*, render::RenderPlugin};
use bevy_enhanced_input::EnhancedInputPlugin;
use simgine_core::SimgineCorePlugin;
use simgine_ui::SimgineUiPlugin;

fn main() {
    let mut app = App::new();
    app.add_plugins((
        DefaultPlugins
            .set(WindowPlugin {
                primary_window: Some(Window {
                    title: "Simgine".to_string(),
                    ..Default::default()
                }),
                ..Default::default()
            })
            .set(RenderPlugin {
                synchronous_pipeline_compilation: true,
                ..Default::default()
            }),
        EnhancedInputPlugin,
        SimgineCorePlugin,
        SimgineUiPlugin,
    ));

    app.run();
}
