pub(crate) mod action;
pub(crate) mod icon;
pub(crate) mod style;
pub(crate) mod toggled;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((action::plugin, style::plugin, icon::plugin, toggled::plugin));
}
