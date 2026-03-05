use bevy::prelude::*;
use simgine_core::error_event::ErrorEvent;

use crate::widget::dialog::{dialog, dialog_close_button, dialog_text, dialog_title};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(spawn);
}

fn spawn(error: On<ErrorEvent>, mut commands: Commands) {
    let message = error.to_string();
    commands.spawn((
        dialog(),
        children![
            dialog_title("Error"),
            dialog_text(message),
            dialog_close_button("Ok"),
        ],
    ));
}
