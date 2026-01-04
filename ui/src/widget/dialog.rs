use bevy::prelude::*;

use crate::widget::theme::LARGE_TEXT;

use super::{
    button::style::ButtonStyle,
    theme::{GAP, NORMAL_TEXT, OUTER_RADIUS, PADDING},
};

#[derive(Component)]
#[require(
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
)]
pub(crate) struct Dialog;

#[derive(Component)]
#[require(
    Node {
        align_self: AlignSelf::Start,
        ..Default::default()
    },
    TextFont::from_font_size(LARGE_TEXT),
)]
pub(crate) struct DialogTitle;

#[derive(Component)]
#[require(ButtonStyle::default(), TextFont::from_font_size(NORMAL_TEXT))]
pub(crate) struct DialogButton;
