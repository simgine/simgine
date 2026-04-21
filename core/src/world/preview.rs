use avian3d::prelude::*;
use bevy::prelude::*;

use crate::world::layer::GameLayer;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(init).add_observer(cleanup);
}

fn init(
    add: On<Add, PreviewOf>,
    mut commands: Commands,
    previews: Query<&PreviewOf>,
    mut targets: Query<(&mut Visibility, &CollisionLayers)>,
) {
    let preview = previews.get(add.entity).unwrap();

    debug!("creating preview for `{}`", preview.target);

    let (mut visibility, &layers) = targets.get_mut(preview.target).unwrap();

    *visibility = Visibility::Hidden;

    let mut new_layers = layers;
    new_layers.filters.remove(GameLayer::Preview);
    commands.entity(preview.target).insert(new_layers);
}

fn cleanup(
    remove: On<Remove, PreviewOf>,
    mut commands: Commands,
    previews: Query<&PreviewOf>,
    mut targets: Query<(&mut Visibility, &CollisionLayers)>,
) {
    let preview = previews.get(remove.entity).unwrap();
    let Ok((mut visibility, &layers)) = targets.get_mut(preview.target) else {
        // If entity missing visibility or layers, consider it despawned.
        return;
    };
    debug!("removing preview for `{}`", preview.target);

    *visibility = Visibility::Inherited;

    let mut new_layers = layers;
    new_layers.filters.add(GameLayer::Preview);
    commands.entity(preview.target).insert(new_layers);
}

/// Hides the target entity and removes collision with the preview while this component exists.
#[derive(Component, Clone, Copy)]
#[component(immutable)]
pub(crate) struct PreviewOf {
    pub(crate) target: Entity,
}
