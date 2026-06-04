use std::iter;

use bevy::{prelude::*, world_serialization::WorldInstanceReady};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(init_asset_instance).add_observer(init);
}

fn init(
    add: On<Insert, Tint>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    tints: Query<&Tint>,
    children: Query<&Children>,
    mut material_handles: Query<&mut MeshMaterial3d<StandardMaterial>>,
) {
    let tint = tints.get(add.entity).unwrap();
    set_color(
        add.entity,
        &mut materials,
        &mut material_handles,
        &children,
        tint.color,
    );
}

fn init_asset_instance(
    ready: On<WorldInstanceReady>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    tints: Query<&Tint>,
    children: Query<&Children>,
    mut material_handles: Query<&mut MeshMaterial3d<StandardMaterial>>,
) {
    if let Ok(tint) = tints.get(ready.entity) {
        set_color(
            ready.entity,
            &mut materials,
            &mut material_handles,
            &children,
            tint.color,
        );
    }
}

fn set_color(
    entity: Entity,
    materials: &mut Assets<StandardMaterial>,
    material_handles: &mut Query<&mut MeshMaterial3d<StandardMaterial>>,
    children: &Query<&Children>,
    color: Color,
) {
    debug!("setting color to `{color:?}`");

    let mut iter =
        material_handles.iter_many_mut(iter::once(entity).chain(children.iter_descendants(entity)));
    while let Some(mut material_handle) = iter.fetch_next() {
        let Some(material) = materials.get(&*material_handle) else {
            // Skip non-loaded, their alpha color will be updated only after full asset loading anyway.
            return;
        };

        // If color matches, assume that we don't need any update.
        if material.base_color == color {
            return;
        }

        let mut material = material.clone();
        material.base_color = color;
        material.alpha_mode = AlphaMode::Add;
        *material_handle = materials.add(material).into();
    }
}

/// Tints the entity's material by blending its texture with the given color.
#[derive(Component, Clone, Copy, Deref)]
#[component(immutable)]
pub(crate) struct Tint {
    pub(crate) color: Color,
}
