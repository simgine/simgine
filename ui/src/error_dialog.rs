use bevy::prelude::*;
use simgine_core::error_event::ErrorEvent;

use crate::widget::dialog::{Dialog, DialogCloseButton, DialogText, DialogTitle};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(spawn);
}

fn spawn(error: On<ErrorEvent>, mut commands: Commands) {
    let message = error.to_string();
    commands.spawn((
        Dialog,
        children![
            (DialogTitle, Text::new("Error")),
            (DialogText, Text::new(message)),
            (DialogCloseButton, Text::new("Ok")),
        ],
    ));
}
