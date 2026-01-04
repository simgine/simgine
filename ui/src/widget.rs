pub(crate) mod button;
pub(crate) mod dialog;
pub(crate) mod theme;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(button::plugin);
}
