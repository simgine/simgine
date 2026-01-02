use bevy::{ecs::query::QueryFilter, prelude::*};
use bevy_enhanced_input::prelude::*;

use crate::widget::button::{action::ButtonContext, exclusive_group::ExclusiveGroup};

use super::action::Activate;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(toggle::<Pointer<Click>, Without<ButtonContext>>) // Buttons with context activate on click.
        .add_observer(toggle::<Fire<Activate>, ()>);
}

fn toggle<E: EntityEvent, F: QueryFilter>(
    event: On<E>,
    mut commands: Commands,
    buttons: Query<(&Toggled, &ChildOf), F>,
    groups: Query<&ExclusiveGroup>,
) {
    let button = event.event_target();
    if let Ok((&toggled, parent)) = buttons.get(button) {
        let exclusive = groups.get(parent.0).is_ok();
        if exclusive && *toggled {
            // Exclusive buttons cannot be untoggled.
            return;
        }

        let flipped = toggled.flip();
        debug!("toggling `{button}` to `{}`", *flipped);
        commands.entity(button).insert(flipped);
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
