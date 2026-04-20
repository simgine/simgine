use bevy::prelude::*;
use bevy_mod_outline::OutlineVolume;

use super::caster::CursorTarget;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(show)
        .add_observer(hide)
        .add_observer(enable)
        .add_observer(disable);
}

fn show(
    _on: On<Insert, CursorTarget>,
    cursor_target: Single<&CursorTarget>,
    mut volumes: Query<&mut OutlineVolume>,
    disabler: Query<(), With<OutlineDisabler>>,
) {
    let Some(entity) = ***cursor_target else {
        return;
    };
    let Ok(mut outline) = volumes.get_mut(entity) else {
        return;
    };

    if disabler.is_empty() {
        debug!("showing outline for `{entity}`");
        outline.visible = true;
    }
}

fn hide(
    _on: On<Replace, CursorTarget>,
    cursor_target: Single<&CursorTarget>,
    mut volumes: Query<&mut OutlineVolume>,
) {
    let Some(entity) = ***cursor_target else {
        return;
    };
    let Ok(mut outline) = volumes.get_mut(entity) else {
        return;
    };

    if outline.visible {
        debug!("hiding outline for `{entity}`");
        outline.visible = false;
    }
}

fn disable(
    _on: On<Add, OutlineDisabler>,
    cursor_target: Single<&CursorTarget>,
    mut volumes: Query<&mut OutlineVolume>,
) {
    let Some(entity) = ***cursor_target else {
        return;
    };

    if let Ok(mut outline) = volumes.get_mut(entity) {
        debug!("disabling outline for `{entity}`");
        outline.visible = true;
    }
}

fn enable(
    _on: On<Remove, OutlineDisabler>,
    cursor_target: Single<&CursorTarget>,
    mut volumes: Query<&mut OutlineVolume>,
) {
    let Some(entity) = ***cursor_target else {
        return;
    };

    if let Ok(mut outline) = volumes.get_mut(entity) {
        debug!("enabling outline for `{entity}`");
        outline.visible = true;
    }
}

pub(crate) const OUTLINE_VOLUME: OutlineVolume = OutlineVolume {
    visible: false,
    colour: Color::srgba(1.0, 1.0, 1.0, 0.3),
    width: 3.0,
};

/// Outline will be disabled if any entity with this component is present.
#[derive(Component, Default)]
pub(crate) struct OutlineDisabler;
