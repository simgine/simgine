use bevy::prelude::*;

use crate::GameState;

const HALF_CITY_SIZE: f32 = 250.0;

pub(crate) fn plugin(app: &mut App) {
    app.add_systems(OnEnter(GameState::InGame), spawn);
}

fn spawn(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
) {
    commands.spawn((
        Mesh3d(meshes.add(Plane3d::new(Vec3::Y, Vec2::splat(HALF_CITY_SIZE)))),
        MeshMaterial3d(materials.add(Color::WHITE)),
    ));
    commands.spawn((
        Mesh3d(meshes.add(Cuboid::new(1.0, 1.0, 1.0))),
        MeshMaterial3d(materials.add(Color::srgb_u8(124, 144, 255))),
        Transform::from_xyz(0.0, 0.5, 0.0),
    ));
}
