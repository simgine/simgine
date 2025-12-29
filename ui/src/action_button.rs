use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<ActionButton>()
        .add_observer(mock_action);
}

fn mock_action(
    mut click: On<Pointer<Click>>,
    mut commands: Commands,
    buttons: Query<&Actions<ActionButton>, With<ActionButton>>,
) {
    if let Ok(actions) = buttons.get(click.entity)
        && let Some(&action) = actions.first()
    {
        click.propagate(false);
        commands
            .entity(action)
            .insert(ActionMock::once(ActionState::Fired, true));
    }
}

#[derive(Component, Default)]
#[require(Button)]
pub(crate) struct ActionButton;

#[macro_export]
macro_rules! button_bindings {
    ($action:ty [$($bindings:expr),*$(,)?]) => {
        ::bevy_enhanced_input::prelude::actions!($crate::action_button::ActionButton[(
            ::bevy_enhanced_input::prelude::Action::<$action>::new(),
            ::bevy_enhanced_input::prelude::Press::default(),
            bindings![$($bindings),*],
        )])
    };
}
