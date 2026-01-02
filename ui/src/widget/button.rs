pub(crate) mod action;
pub(crate) mod exclusive_group;
pub(crate) mod icon;
pub(crate) mod style;
pub(crate) mod toggled;

use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins((
        action::plugin,
        exclusive_group::plugin,
        style::plugin,
        icon::plugin,
        toggled::plugin,
    ));
}
