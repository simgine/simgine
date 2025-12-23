use std::f32::consts::PI;

use bevy::{light::light_consts::lux, prelude::*};

use crate::GameState;

pub(crate) fn plugin(app: &mut App) {
    app.add_systems(OnEnter(GameState::InGame), spawn)
        .add_systems(Update, move_sun.run_if(in_state(GameState::InGame)));
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        DirectionalLight {
            shadows_enabled: true,
            illuminance: lux::RAW_SUNLIGHT,
            ..Default::default()
        },
        Transform::from_xyz(1.0, 0.4, 0.0).looking_at(Vec3::ZERO, Vec3::Y),
    ));
}

fn move_sun(mut sun: Single<&mut Transform, With<DirectionalLight>>, time: Res<Time>) {
    const SPEED: f32 = 100.0;
    sun.rotate_x(-time.delta_secs() * PI / SPEED);
}
