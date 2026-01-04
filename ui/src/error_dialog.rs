use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use simgine_core::error_event::ErrorEvent;

use crate::widget::dialog::{Dialog, DialogButton, DialogTitle};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(spawn);
}

fn spawn(error: On<ErrorEvent>, mut commands: Commands) {
    let message = error.to_string();
    commands.spawn((
        Dialog,
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            let dialog = parent.target_entity();
            parent.spawn((DialogTitle, Text::new("Error")));
            parent.spawn(Text::new(message));
            parent.spawn((DialogButton, Text::new("Ok"))).observe(
                move |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.entity(dialog).despawn();
                },
            );
        })),
    ));
}
