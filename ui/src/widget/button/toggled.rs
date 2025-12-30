use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(toggle).add_observer(ensure_single);
}

fn toggle(
    click: On<Pointer<Click>>,
    mut commands: Commands,
    buttons: Query<(&Toggled, Has<Exclusive>)>,
) {
    if let Ok((&toggled, exclusive)) = buttons.get(click.entity) {
        if exclusive && *toggled {
            // Exclusive buttons cannot be untoggled.
            return;
        }

        debug!("button `{}` toggled to `{}`", click.entity, !*toggled);
        commands.entity(click.entity).insert(toggled.flip());
    }
}

fn ensure_single(
    insert: On<Insert, Toggled>,
    mut commands: Commands,
    mut buttons: Query<(Entity, &ChildOf, &Toggled), With<Exclusive>>,
    children: Query<&Children>,
) {
    let Ok((entity, child_of, toggled)) = buttons.get_mut(insert.entity) else {
        return;
    };

    if !**toggled {
        return;
    }

    debug!("untoggling neighbors for `{}`", insert.entity);
    let neighbors = children.get(child_of.0).unwrap();
    for (other_entity, _, other_toggle) in buttons.iter_many(neighbors) {
        if entity == other_entity {
            continue;
        }

        if **other_toggle {
            trace!("untoggling `{other_entity}`");
            commands.entity(other_entity).insert(Toggled(false));
        }
    }
}

#[derive(Component, Deref, Debug, Default, Clone, Copy)]
#[component(immutable)]
#[require(Button)]
pub(crate) struct Toggled(pub(crate) bool);

impl Toggled {
    fn flip(&self) -> Self {
        Self(!**self)
    }
}

/// If present, then only one button that belongs to the parent node can be toggled at any given time.
///
/// The user can click on any button to check it, and that button will replace the existing one as the checked button in the parent node.
#[derive(Component, Default)]
#[require(Toggled)]
pub(crate) struct Exclusive;
