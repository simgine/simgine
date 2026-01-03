use std::fmt::{self, Display, Formatter};

use bevy::prelude::*;

/// System adapter that logs errors and sends [`ErrorEvent`] event.
pub fn error_event(In(result): In<Result<()>>, mut commands: Commands) {
    if let Err(error) = result {
        error!("{error:#}");
        commands.trigger(ErrorEvent(error));
    }
}

/// Contains error that was reported using [`error_message`] adapter.
#[derive(Event, Deref)]
pub struct ErrorEvent(BevyError);

impl Display for ErrorEvent {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}
