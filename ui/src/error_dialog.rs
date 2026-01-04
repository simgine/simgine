use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use simgine_core::error_event::ErrorEvent;

use crate::widget::theme;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(spawn);
}

fn spawn(error: On<ErrorEvent>, mut commands: Commands) {
    let message = error.to_string();
    commands.spawn((
        theme::dialog(),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            let dialog = parent.target_entity();
            parent.spawn((Text::new("Error"), theme::dialog_title()));
            parent.spawn(Text::new(message));
            parent
                .spawn((Text::new("Ok"), theme::dialog_button()))
                .observe(move |_on: On<Pointer<Click>>, mut commands: Commands| {
                    commands.entity(dialog).despawn();
                });
        })),
    ));
}
