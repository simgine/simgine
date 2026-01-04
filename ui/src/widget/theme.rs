use bevy::prelude::*;

pub(crate) const SCREEN_OFFSET: Val = Val::Px(16.0);

pub(crate) const OUTER_RADIUS: BorderRadius = BorderRadius::all(Val::Px(13.0));
pub(crate) const INNER_RADIUS: BorderRadius = BorderRadius::all(Val::Px(8.0));
pub(crate) const SHADOW: ShadowStyle = ShadowStyle {
    color: Color::linear_rgba(0.0, 0.0, 0.0, 0.5),
    x_offset: Val::Px(5.0),
    y_offset: Val::Px(5.0),
    spread_radius: Val::ZERO,
    blur_radius: Val::Px(2.0),
};

pub(crate) const PREVIEW_HEIGHT: Val = Val::Px(128.0);
pub(crate) const PREVIEW_WIDTH: Val = Val::Px(98.0);
pub(crate) const PREVIEW_GAP: Val = Val::Px(5.0);
pub(crate) const PREVIEW_COLUMNS: usize = 3;
pub(crate) const PREVIEW_PADDING: UiRect = UiRect::all(Val::Px(5.0)); // For previews border simulated by outer node because `ImageNode` draws over borders.
