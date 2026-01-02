use bevy::prelude::*;

use crate::widget::button::toggled::Toggled;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(ensure_single);
}

fn ensure_single(
    insert: On<Insert, Toggled>,
    mut commands: Commands,
    parents: Query<&ChildOf>,
    toggled: Query<&Toggled>,
    mut groups: Query<&mut ExclusiveGroup>,
) {
    let toggled = *toggled.get(insert.entity).unwrap();
    if !*toggled {
        return;
    }

    let Ok(parent) = parents.get(insert.entity) else {
        return;
    };

    let Ok(mut group) = groups.get_mut(parent.0) else {
        return;
    };

    if let Some(active) = group.active
        && active != insert.entity
        && let Ok(mut entity) = commands.get_entity(active)
    {
        debug!("untoggling previously active `{active}`");
        entity.insert(Toggled(false));
    }

    group.active = Some(insert.entity);
}

#[derive(Component, Default)]
pub(crate) struct ExclusiveGroup {
    active: Option<Entity>,
}
