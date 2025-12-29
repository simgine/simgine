use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<ButtonAction>()
        .add_observer(mock_action);
}

fn mock_action(
    mut click: On<Pointer<Click>>,
    mut commands: Commands,
    buttons: Query<&Actions<ButtonAction>, With<ButtonAction>>,
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
pub(crate) struct ButtonAction;

#[macro_export]
macro_rules! button_bindings {
    ($action:ty [$($bindings:expr),*$(,)?]) => {
        ::bevy_enhanced_input::prelude::actions!($crate::button_action::ButtonAction[(
            ::bevy_enhanced_input::prelude::Action::<$action>::new(),
            ::bevy_enhanced_input::prelude::Press::default(),
            bindings![$($bindings),*],
        )])
    };
}
