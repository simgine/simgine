use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

use super::{
    button::{action::ButtonContext, style::ButtonStyle},
    theme::{GAP, LARGE_TEXT, NORMAL_TEXT, OUTER_RADIUS, PADDING, SMALL_TEXT},
};
use crate::{button_bindings, widget::button::action::Activate};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(add_close_bindings);
}

fn add_close_bindings(insert: On<Insert, DialogCloseButton>, mut commands: Commands) {
    commands
        .entity(insert.entity)
        .insert(button_bindings![KeyCode::Escape])
        .observe(
            |activate: On<Fire<Activate>>,
             mut commands: Commands,
             parents: Query<&ChildOf>,
             dialogs: Query<Entity, With<Dialog>>| {
                let Some(dialog) = dialogs
                    .iter_many(parents.iter_ancestors(activate.context))
                    .next()
                else {
                    warn!(
                        "ignoring activation without a dialog for `{}`",
                        activate.context
                    );
                    return;
                };

                commands.entity(dialog).despawn();
            },
        );
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

#[derive(Component, Default)]
#[require(DialogButton, ButtonContext)]
pub(crate) struct DialogCloseButton;
