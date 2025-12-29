use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<ButtonContext>()
        .add_observer(activate);
}

fn activate(
    mut click: On<Pointer<Click>>,
    mut commands: Commands,
    buttons: Query<&Actions<ButtonContext>, With<ButtonContext>>,
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
pub(crate) struct ButtonContext;

#[derive(InputAction)]
#[action_output(bool)]
pub(crate) struct Activate;

#[macro_export]
macro_rules! button_bindings {
    [$($bindings:expr),*$(,)?] => {
        ::bevy_enhanced_input::prelude::actions!($crate::widget::button::action::ButtonContext[(
            ::bevy_enhanced_input::prelude::Action::<$crate::widget::button::action::Activate>::new(),
            ::bevy_enhanced_input::prelude::Press::default(),
            ::bevy_enhanced_input::prelude::bindings![$($bindings),*],
        )])
    };
}
