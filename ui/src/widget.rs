pub(crate) mod button;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(button::plugin);
}

pub(crate) const SCREEN_OFFSET: Val = Val::Px(16.0);
