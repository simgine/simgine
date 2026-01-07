use bevy::prelude::*;

use crate::widget::theme::{LARGE_TEXT, SMALL_TEXT};

use super::{
    button::style::ButtonStyle,
    theme::{GAP, NORMAL_TEXT, OUTER_RADIUS, PADDING},
};

#[derive(Component, Default)]
#[require(
    Node {
        flex_direction: FlexDirection::Column,
        align_self: AlignSelf::Center,
        justify_self: JustifySelf::Center,
        padding: UiRect::all(PADDING),
        row_gap: GAP,
        border_radius: OUTER_RADIUS,
        ..Default::default()
    },
    BackgroundColor(Color::BLACK),
)]
pub(crate) struct Dialog;

#[derive(Component)]
#[require(TextFont::from_font_size(LARGE_TEXT))]
pub(crate) struct DialogTitle;

#[derive(Component)]
#[require(TextFont::from_font_size(SMALL_TEXT))]
pub(crate) struct DialogText;

#[derive(Component, Default)]
#[require(
    Node {
        align_self: AlignSelf::Center,
        ..Default::default()
    },
    ButtonStyle,
    TextFont::from_font_size(NORMAL_TEXT)
)]
pub(crate) struct DialogButton;
