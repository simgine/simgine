use avian3d::prelude::*;
use bevy::prelude::*;
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::world::layer::GameLayer;

pub(super) fn plugin(app: &mut App) {
    app.replicate::<FirstName>()
        .replicate::<LastName>()
        .replicate::<Sex>();
}

const HEIGHT: f32 = 1.8;
const RADIUS: f32 = 0.4;

#[derive(Component)]
#[require(
    Sex,
    FirstName,
    LastName,
    Replicated,
    SceneRoot,
    RigidBody::Kinematic,
    Collider::capsule_endpoints(
        RADIUS,
        Vec3::Y * RADIUS,
        Vec3::Y * (HEIGHT - RADIUS),
    ),
    CollisionLayers::new(GameLayer::Character, LayerMask::ALL)
)]
pub struct Character;

#[derive(Component, Deref, DerefMut, Reflect, Default, Serialize, Deserialize, Clone)]
#[reflect(Component)]
pub struct FirstName(pub String);

#[derive(Component, Deref, DerefMut, Reflect, Default, Serialize, Deserialize, Clone)]
#[reflect(Component)]
pub struct LastName(pub String);

#[derive(Component, Reflect, Default, Debug, Serialize, Deserialize, PartialEq, Clone, Copy)]
#[reflect(Component)]
pub enum Sex {
    #[default]
    Male,
    Female,
}
