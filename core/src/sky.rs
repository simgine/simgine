use std::f32::consts::{FRAC_PI_2, TAU};

use bevy::{light::light_consts::lux, prelude::*};

use crate::{
    GameState,
    clock::{GameTime, MinuteCarry, SECS_PER_DAY},
};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(OnEnter(GameState::InGame), spawn)
        .add_systems(Update, move_planets.run_if(in_state(GameState::InGame)));
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        Sun,
        DirectionalLight {
            shadows_enabled: true,
            illuminance: lux::RAW_SUNLIGHT,
            ..Default::default()
        },
    ));

    commands.spawn((
        Moon,
        DirectionalLight {
            shadows_enabled: true,
            illuminance: 400.0, // Keep nights bright.
            ..Default::default()
        },
    ));
}

fn move_planets(
    game_clock: Single<(&GameTime, &MinuteCarry)>,
    mut sun: Single<&mut Transform, With<Sun>>,
    mut moon: Single<&mut Transform, (With<Moon>, Without<Sun>)>,
) {
    let (game_time, carry) = game_clock.into_inner();
    let secs = game_time.secs_since_midnight() as f32 + carry.as_secs_f32();
    let day_fract = secs / SECS_PER_DAY as f32;

    let angle = day_fract * TAU; // 0 is midnight, 1 is TAU.

    // Shift sun and moon accordingly.
    let sun_angle = angle - FRAC_PI_2;
    let moon_angle = angle + FRAC_PI_2;

    let sun_dir = Vec3::new(0.0, sun_angle.sin(), sun_angle.cos());
    let moon_dir = Vec3::new(0.0, moon_angle.sin(), moon_angle.cos());

    // Position doesn't matter for `DirectionalLight`.
    sun.look_at(-sun_dir, Vec3::Y);
    moon.look_at(-moon_dir, Vec3::Y);
}

#[derive(Component)]
struct Sun;

#[derive(Component)]
struct Moon;
