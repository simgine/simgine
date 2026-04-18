use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(init).add_observer(cleanup);
}

fn init(add: On<Add, PreviewOf>, previews: Query<&PreviewOf>, mut targets: Query<&mut Visibility>) {
    let preview = previews.get(add.entity).unwrap();
    let mut visibility = targets.get_mut(preview.target).unwrap();

    *visibility = Visibility::Hidden;
    debug!(
        "changing visibility to `{:?}` for `{}`",
        *visibility, preview.target
    );
}

fn cleanup(
    remove: On<Remove, PreviewOf>,
    previews: Query<&PreviewOf>,
    mut targets: Query<&mut Visibility>,
) {
    let preview = previews.get(remove.entity).unwrap();
    let Ok(mut visibility) = targets.get_mut(preview.target) else {
        // If entity missing visibility, consider it despawned.
        return;
    };

    *visibility = Visibility::Inherited;
    debug!(
        "changing visibility to `{:?}` for `{}`",
        *visibility, preview.target
    );
}

/// Hides the target entity while this component exists.
#[derive(Component, Clone, Copy)]
#[component(immutable)]
pub(crate) struct PreviewOf {
    pub(crate) target: Entity,
}
