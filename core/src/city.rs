use bevy::prelude::*;

use crate::state::GameState;

const HALF_CITY_SIZE: f32 = 250.0;

pub(super) fn plugin(app: &mut App) {
    app.add_systems(OnEnter(GameState::World), spawn);
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
}
