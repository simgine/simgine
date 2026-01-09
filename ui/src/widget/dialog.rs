use bevy::prelude::*;
use bevy_enhanced_input::prelude::{*, Release};

use crate::widget::theme::{LARGE_TEXT, SMALL_TEXT};

use super::{
    button::style::ButtonStyle,
    theme::{GAP, NORMAL_TEXT, OUTER_RADIUS, PADDING},
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(add_close_action).add_observer(close).add_input_context::<Dialog>();
}

fn add_close_action(insert: On<Insert, Dialog>, mut commands: Commands) {
    commands.entity(insert.entity).insert(
        actions!(Dialog[(
            Action::<CloseDialog>::new(),
            Release::default(),
            bindings![KeyCode::Escape]
        )]),
    );
}

fn close(close: On<Fire<CloseDialog>>, mut commands: Commands) {
    commands.entity(close.context).despawn();
}

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
    ContextPriority::<Self>::new(1),
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

#[derive(InputAction)]
#[action_output(bool)]
pub(crate) struct CloseDialog;
