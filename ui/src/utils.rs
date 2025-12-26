use std::fmt::Debug;

use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

/// Maps clicks on buttons to actions on the same entity via indices.
///
/// Needed to associate actions with shortcuts defined by actions.
// TODO: Remove `Debug` from fn and used types after next BEI release.
pub(crate) fn mock_action<C: Component + Debug>(
    click: On<Pointer<Click>>,
    mut commands: Commands,
    context: Query<(&Children, &Actions<C>)>,
) {
    let (children, actions) = context.get(click.entity).unwrap();

    let position = children
        .iter()
        .position(|entity| click.original_event_target() == entity)
        .unwrap_or_else(|| {
            panic!(
                "`{children:?}` should contain `{}`",
                click.original_event_target()
            )
        });

    let action = *actions
        .get(position)
        .unwrap_or_else(|| panic!("`{actions:?}` should contain an entity at index {position}"));

    debug!(
        "mocking `{action}` for `{}` at index {position}",
        ShortName::of::<C>()
    );

    commands
        .entity(action)
        .insert(ActionMock::once(ActionState::Fired, true));
}
