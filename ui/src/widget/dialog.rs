use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

use super::{
    button::{action::ButtonContext, style::ButtonStyle},
    theme::{GAP, LARGE_TEXT, NORMAL_TEXT, OUTER_RADIUS, PADDING, SMALL_TEXT},
};
use crate::{button_bindings, widget::button::action::Activate};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(observe_close);
}

fn observe_close(insert: On<Insert, CloseButton>, mut commands: Commands) {
    commands.entity(insert.entity).observe(
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

pub(crate) fn dialog() -> impl Bundle {
    (
        Dialog,
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
    )
}

pub(crate) fn dialog_title(text: &str) -> impl Bundle {
    (Text::new(text), TextFont::from_font_size(LARGE_TEXT))
}

pub(crate) fn dialog_text(text: impl Into<String>) -> impl Bundle {
    (Text::new(text), TextFont::from_font_size(SMALL_TEXT))
}

pub(crate) fn dialog_close_button(text: &str) -> impl Bundle {
    (
        dialog_button(text),
        CloseButton,
        ButtonContext,
        button_bindings![KeyCode::Escape],
    )
}

pub(crate) fn dialog_button(text: &str) -> impl Bundle {
    (
        Text::new(text),
        TextFont::from_font_size(NORMAL_TEXT),
        ButtonStyle::default(),
        Node {
            align_self: AlignSelf::Center,
            ..Default::default()
        },
    )
}

#[derive(Component)]
struct Dialog;

#[derive(Component)]
struct CloseButton;
