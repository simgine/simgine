use bevy::prelude::*;
use bevy_mod_outline::OutlineVolume;

pub(super) fn plugin(app: &mut App) {
    app.init_resource::<HoverState>()
        .add_observer(show)
        .add_observer(hide)
        .add_observer(enable)
        .add_observer(disable);
}

fn show(
    over: On<Pointer<Over>>,
    mut hover: ResMut<HoverState>,
    disabler: Query<(), With<OutlineDisabler>>,
    mut volumes: Query<&mut OutlineVolume>,
) {
    let Ok(mut outline) = volumes.get_mut(over.entity) else {
        return;
    };

    hover.last_hovered = Some(over.entity);
    if disabler.is_empty() {
        debug!("showing outline for `{}`", over.entity);
        outline.visible = true;
    }
}

fn hide(
    out: On<Pointer<Out>>,
    mut volumes: Query<&mut OutlineVolume>,
    mut hover: ResMut<HoverState>,
) {
    let Ok(mut outline) = volumes.get_mut(out.entity) else {
        return;
    };

    hover.last_hovered = None;
    if outline.visible {
        debug!("hiding outline for `{}`", out.entity);
        outline.visible = false;
    }
}

fn disable(
    _on: On<Add, OutlineDisabler>,
    mut volumes: Query<&mut OutlineVolume>,
    mut hover: ResMut<HoverState>,
) {
    if let Some(entity) = hover.last_hovered {
        if let Ok(mut outline) = volumes.get_mut(entity) {
            debug!("disabling outline for `{entity}`");
            outline.visible = true;
        } else {
            hover.last_hovered = None;
        }
    }
}

fn enable(
    _on: On<Remove, OutlineDisabler>,
    mut hover: ResMut<HoverState>,
    mut volumes: Query<&mut OutlineVolume>,
) {
    if let Some(entity) = hover.last_hovered {
        if let Ok(mut outline) = volumes.get_mut(entity) {
            debug!("enabling outline for `{entity}`");
            outline.visible = true;
        } else {
            hover.last_hovered = None;
        }
    }
}

pub(crate) const OUTLINE_VOLUME: OutlineVolume = OutlineVolume {
    visible: false,
    colour: Color::srgba(1.0, 1.0, 1.0, 0.3),
    width: 3.0,
};

#[derive(Resource, Default)]
struct HoverState {
    last_hovered: Option<Entity>,
}

/// Outline will be disabled if any entity with this component is present.
#[derive(Component, Default)]
pub(super) struct OutlineDisabler;
