use bevy::prelude::*;

use super::button::style::ButtonStyle;

pub(crate) const SCREEN_OFFSET: Val = PADDING;
pub(crate) const PADDING: Val = Val::Px(16.0);
pub(crate) const GAP: Val = Val::Px(14.0);

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
pub(crate) const PREVIEW_GAP: Val = Val::Px(8.0);
pub(crate) const PREVIEW_COLUMNS: usize = 3;
pub(crate) const PREVIEW_PADDING: UiRect = UiRect::all(Val::Px(5.0)); // For previews border simulated by outer node because `ImageNode` draws over borders.

pub(crate) fn dialog() -> impl Bundle {
    (
        Node {
            flex_direction: FlexDirection::Column,
            align_self: AlignSelf::Center,
            justify_self: JustifySelf::Center,
            align_items: AlignItems::Center,
            padding: UiRect::all(PADDING),
            row_gap: GAP,
            border_radius: OUTER_RADIUS,
            min_width: Val::Px(400.0),
            ..Default::default()
        },
        BackgroundColor(Color::BLACK),
    )
}

pub(crate) fn dialog_title() -> impl Bundle {
    (
        Node {
            align_self: AlignSelf::Start,
            ..Default::default()
        },
        TextFont {
            font_size: 26.0,
            ..Default::default()
        },
    )
}

pub(crate) fn dialog_button() -> impl Bundle {
    (
        ButtonStyle::default(),
        TextFont {
            font_size: 24.0,
            ..Default::default()
        },
    )
}
