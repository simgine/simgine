use bevy::prelude::*;
use bevy_enhanced_input::EnhancedInputPlugin;
use simgine_core::SimgineCorePlugin;

fn main() {
    let mut app = App::new();
    app.add_plugins((
        DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "Simgine".to_string(),
                ..Default::default()
            }),
            ..Default::default()
        }),
        EnhancedInputPlugin,
        SimgineCorePlugin,
    ));

    app.run();
}
