use std::f32::consts::FRAC_PI_2;

use bevy::{
    anti_alias::taa::TemporalAntiAliasing,
    camera::Exposure,
    light::AtmosphereEnvironmentMapLight,
    pbr::{Atmosphere, ScatteringMedium, ScreenSpaceAmbientOcclusion},
    post_process::bloom::Bloom,
    prelude::*,
};
use bevy_enhanced_input::prelude::*;

use crate::state::GameState;

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<PlayerCamera>()
        .add_observer(pan)
        .add_observer(zoom)
        .add_observer(rotate)
        .add_systems(OnEnter(GameState::World), spawn)
        .add_systems(Update, apply_transform.run_if(in_state(GameState::World)));
}

fn spawn(mut commands: Commands, mut scattering_mediums: ResMut<Assets<ScatteringMedium>>) {
    debug!("spawning camera");

    commands.spawn((
        PlayerCamera,
        Atmosphere::earthlike(scattering_mediums.add(ScatteringMedium::default())),
        DespawnOnExit(GameState::World),
        Actions::<PlayerCamera>::spawn(SpawnWith(|context: &mut ActionSpawner<_>| {
            let enable_rotation = context
                .spawn((
                    Action::<EnableRotation>::new(),
                    bindings![MouseButton::Middle],
                ))
                .id();
            let enable_pan = context
                .spawn((
                    Action::<EnablePan>::new(),
                    bindings![MouseButton::Right, GamepadButton::East],
                ))
                .id();

            context.spawn((
                Action::<Pan>::new(),
                DeadZone::default(),
                Scale::splat(0.7),
                SmoothNudge::default(),
                Bindings::spawn((
                    Cardinal::wasd_keys(),
                    Axial::left_stick(),
                    Spawn((
                        Binding::mouse_motion(),
                        Chord::single(enable_pan),
                        Negate::y(),
                        Scale::splat(0.003),
                    )),
                )),
            ));

            context.spawn((
                Action::<Rotate>::new(),
                Scale::splat(0.05),
                SmoothNudge::default(),
                Bindings::spawn((
                    Bidirectional::new(KeyCode::Period, KeyCode::Comma),
                    Axial::right_stick(),
                    Spawn((
                        Binding::mouse_motion(),
                        Chord::single(enable_rotation),
                        Negate::all(),
                        Scale::splat(0.08),
                    )),
                )),
            ));

            context.spawn((
                Action::<Zoom>::new(),
                SmoothNudge::default(),
                Bindings::spawn((
                    Bidirectional::new(KeyCode::Equal, KeyCode::Minus),
                    Bidirectional::new(GamepadAxis::RightZ, GamepadAxis::LeftZ)
                        .with(Scale::splat(0.1)),
                    Spawn((Binding::mouse_wheel(), SwizzleAxis::YXZ)),
                )),
            ));
        })),
    ));
}

fn pan(pan: On<Fire<Pan>>, camera: Single<(&mut OrbitOrigin, &Transform, &SpringArm)>) {
    // Calculate direction without camera's tilt.
    let (mut orbit_origin, transform, spring_arm) = camera.into_inner();
    let forward = transform.forward();
    let camera_dir = Vec3::new(forward.x, 0.0, forward.z).normalize();
    let rotation = Quat::from_rotation_arc(Vec3::NEG_Z, camera_dir);

    // Movement consists of X and -Z components, so swap Y and Z with negation.
    let mut movement = pan.value.extend(0.0).xzy();
    movement.z = -movement.z;

    // Make speed dependent on camera distance.
    let arm_multiplier = **spring_arm * 0.02;

    **orbit_origin += rotation * movement * arm_multiplier;
}

fn zoom(zoom: On<Fire<Zoom>>, mut spring_arm: Single<&mut SpringArm>) {
    // Limit to prevent clipping into the ground.
    ***spring_arm = (***spring_arm - zoom.value).max(0.2);
}

fn rotate(rotate: On<Fire<Rotate>>, mut rotation: Single<&mut OrbitRotation>) {
    ***rotation += rotate.value;
    let min_y = 0.001; // To avoid flipping when the camera is vertical.
    let max_y = FRAC_PI_2 - 0.01; // To avoid ground intersection.
    rotation.y = rotation.y.clamp(min_y, max_y);
}

fn apply_transform(camera: Single<(&mut Transform, &OrbitOrigin, &OrbitRotation, &SpringArm)>) {
    let (mut transform, orbit_origin, orbit_rotation, spring_arm) = camera.into_inner();
    transform.translation = orbit_rotation.sphere_pos() * **spring_arm + **orbit_origin;
    transform.look_at(**orbit_origin, Vec3::Y);
}

#[derive(Component)]
#[require(
    Name::new("Player camera"),
    OrbitOrigin,
    OrbitRotation,
    SpringArm,
    Camera3d,
    Msaa::Off, // Required for TAA.
    TemporalAntiAliasing,
    Bloom::NATURAL,
    Exposure { ev100: 13.0 }, // Compensate for atmosphere.
    AtmosphereEnvironmentMapLight,
    ScreenSpaceAmbientOcclusion
)]
struct PlayerCamera;

/// The origin of a camera.
#[derive(Component, Default, Deref, DerefMut)]
struct OrbitOrigin(Vec3);

/// Camera rotation in `X` and `Z`.
#[derive(Component, Deref, DerefMut)]
struct OrbitRotation(Vec2);

impl OrbitRotation {
    fn sphere_pos(&self) -> Vec3 {
        Quat::from_euler(EulerRot::YXZ, self.x, self.y, 0.0) * Vec3::Y
    }
}

impl Default for OrbitRotation {
    fn default() -> Self {
        Self(Vec2::new(0.0, 60_f32.to_radians()))
    }
}

/// Camera distance.
#[derive(Component, Deref, DerefMut)]
struct SpringArm(f32);

impl Default for SpringArm {
    fn default() -> Self {
        Self(10.0)
    }
}

#[derive(InputAction)]
#[action_output(Vec2)]
struct Pan;

#[derive(InputAction)]
#[action_output(f32)]
struct Zoom;

#[derive(InputAction)]
#[action_output(Vec2)]
struct Rotate;

#[derive(InputAction)]
#[action_output(bool)]
struct EnableRotation;

#[derive(InputAction)]
#[action_output(bool)]
struct EnablePan;
