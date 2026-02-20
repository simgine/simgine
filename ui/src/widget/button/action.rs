use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<ButtonContext>()
        .add_observer(activate);
}

fn activate(
    mut click: On<Pointer<Click>>,
    mut commands: Commands,
    buttons: Query<(), With<ButtonContext>>,
) {
    if buttons.get(click.entity).is_ok() {
        debug!("firing action for `{}`", click.entity);
        click.propagate(false);
        commands
            .entity(click.entity)
            .mock_once::<ButtonContext, Activate>(TriggerState::Fired, true);
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
            ::bevy_enhanced_input::prelude::ActionSettings { require_reset: true, consume_input: true, ..Default::default() },
            ::bevy_enhanced_input::prelude::bindings![$($bindings),*],
        )])
    };
}
