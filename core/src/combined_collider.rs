use avian3d::prelude::*;
use bevy::{
    camera::primitives::MeshAabb, mesh::Indices, prelude::*,
    render::render_resource::PrimitiveTopology, scene::SceneInstanceReady,
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(init);
}

fn init(
    ready: On<SceneInstanceReady>,
    meshes: Res<Assets<Mesh>>,
    mut scenes: Query<(&Children, &CombinedCollider, &mut Collider)>,
    scene_meshes: Query<(&Transform, Option<&Mesh3d>, Option<&Children>)>,
) {
    let Ok((children, constructor, mut collider)) = scenes.get_mut(ready.entity) else {
        return;
    };

    debug!("generating collider for `{}`", ready.entity);

    let mut combined_mesh = Mesh::new(PrimitiveTopology::TriangleList, Default::default())
        .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, Vec::<Vec3>::new())
        .with_inserted_indices(Indices::U32(Vec::new()));

    for &child_entity in children {
        if let Err(e) = recursive_merge(
            &meshes,
            &scene_meshes,
            child_entity,
            Default::default(),
            &mut combined_mesh,
        ) {
            error!("unable to generate collider for `{}`: `{e}`", ready.entity);
            return;
        }
    }

    *collider = match constructor {
        CombinedCollider::Aabb => {
            let aabb = combined_mesh
                .compute_aabb()
                .expect("mesh should have the required attributes");
            let center: Vec3 = aabb.center.into();
            let cuboid = Collider::cuboid(
                aabb.half_extents.x * 2.0,
                aabb.half_extents.y * 2.0,
                aabb.half_extents.z * 2.0,
            );
            Collider::compound(vec![(center, Rotation::default(), cuboid)])
        }
        CombinedCollider::ConvexHull => Collider::convex_hull_from_mesh(&combined_mesh)
            .expect("mesh should have the required attributes"),
    };
}

fn recursive_merge(
    meshes: &Assets<Mesh>,
    scene_meshes: &Query<(&Transform, Option<&Mesh3d>, Option<&Children>)>,
    current_entity: Entity,
    parent_transform: Transform,
    combined_mesh: &mut Mesh,
) -> Result<()> {
    let (transform, mesh_handle, children) = scene_meshes
        .get(current_entity)
        .expect("all scene children should have transform");

    let current_transform = parent_transform * *transform;
    if let Some(mesh_handle) = mesh_handle {
        let mut mesh = meshes
            .get(mesh_handle)
            .cloned()
            .expect("all scene children should be loaded");
        mesh.transform_by(current_transform);
        combined_mesh.merge(&mesh)?;
    }

    if let Some(children) = children {
        for &child in children {
            recursive_merge(
                meshes,
                scene_meshes,
                child,
                current_transform,
                combined_mesh,
            )?;
        }
    }

    Ok(())
}

#[derive(Component, Reflect)]
#[reflect(Component)]
#[require(Collider)]
pub(crate) enum CombinedCollider {
    Aabb,
    ConvexHull,
}
