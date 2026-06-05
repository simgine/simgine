use bevy::{
    input_focus::{AutoFocus, FocusGained, FocusLost},
    prelude::*,
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(gain).add_observer(lose);
}

fn gain(gained: On<FocusGained>, mut focusable: Query<&mut Focused>) {
    if let Ok(mut focused) = focusable.get_mut(gained.entity) {
        focused.0 = true;
    }
}

fn lose(lost: On<FocusLost>, mut focusable: Query<&mut Focused>) {
    if let Ok(mut focused) = focusable.get_mut(lost.entity) {
        focused.0 = false;
    }
}

#[derive(Component, Deref, Default)]
#[require(AutoFocus)]
pub(crate) struct Focused(bool);
