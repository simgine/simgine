use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(init).add_observer(cleanup);
}

fn init(add: On<Add, Ghost>, ghosts: Query<&mut Ghost>, mut targets: Query<&mut Visibility>) {
    let ghost = ghosts.get(add.entity).unwrap();
    let mut visibility = targets.get_mut(ghost.original_entity).unwrap();

    *visibility = Visibility::Hidden;
    debug!(
        "changing visibility to `{:?}` for `{}`",
        *visibility, ghost.original_entity
    );
}

fn cleanup(
    remove: On<Remove, Ghost>,
    ghosts: Query<&mut Ghost>,
    mut targets: Query<&mut Visibility>,
) {
    let ghost = ghosts.get(remove.entity).unwrap();
    let Ok(mut visibility) = targets.get_mut(ghost.original_entity) else {
        // If entity missing visibility, consider it despawned.
        return;
    };

    *visibility = Visibility::Inherited;
    debug!(
        "changing visibility to `{:?}` for `{}`",
        *visibility, ghost.original_entity
    );
}

/// Temporary entity that replaces the original while it is hidden.
#[derive(Component, Clone, Copy)]
pub(super) struct Ghost {
    /// The entity represented by this ghost.
    ///
    /// The original entity is hidden while this component exists.
    pub(super) original_entity: Entity,
}
