use bevy::prelude::*;
use simgine_core::state::GameState;

pub(super) fn plugin(app: &mut App) {
    app.add_systems(Startup, spawn)
        .add_systems(OnEnter(GameState::Menu), enable)
        .add_systems(OnExit(GameState::Menu), disable);
}

fn spawn(mut commands: Commands) {
    debug!("spawning camera for menu");
    commands.spawn(MenuCamera);
}

fn enable(mut camera: Single<&mut Camera, With<Camera2d>>) {
    debug!("disabling menu camera");
    camera.is_active = true;
}

fn disable(mut camera: Single<&mut Camera, With<Camera2d>>) {
    debug!("disabling menu camera");
    camera.is_active = false;
}

#[derive(Component)]
#[require(
    Name::new("Menu camera"),
    Camera2d,
    Camera {
        is_active: false,
        order: -1,
        ..Default::default()
    },
)]
struct MenuCamera;
