pub(crate) mod button;
pub(crate) mod dialog;
pub(crate) mod text_edit;
pub(crate) mod theme;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((button::plugin, text_edit::plugin));
}
