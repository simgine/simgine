use bevy::{
    picking::hover::Hovered,
    prelude::*,
    text::{EditableText, TextCursorStyle},
    ui::UiSystems,
};

use super::{
    focus::Focused,
    theme::{ACTIVE, HOWERED, HOWERED_ACTIVE, INACTIVE, NORMAL_TEXT, OUTER_RADIUS, RADIUS_GAP},
};

pub(super) fn plugin(app: &mut App) {
    app.add_systems(PreUpdate, update_style.after(UiSystems::Focus));
}

pub(crate) fn text_edit(initial_text: impl AsRef<str>) -> impl Bundle {
    (
        Node {
            align_self: AlignSelf::Center,
            width: Val::Px(300.0),
            border_radius: OUTER_RADIUS,
            border: RADIUS_GAP,
            padding: RADIUS_GAP,
            ..Default::default()
        },
        EditableText::new(initial_text),
        TextFont::from_font_size(NORMAL_TEXT),
        TextCursorStyle {
            color: Color::WHITE,
            selection_color: ACTIVE.into(),
            unfocused_selection_color: INACTIVE.into(),
            ..Default::default()
        },
        Hovered::default(),
        Focused::default(),
    )
}

fn update_style(
    mut text_edits: Query<
        (&Focused, &Hovered, &mut BorderColor),
        Or<(Changed<Focused>, Changed<Hovered>)>,
    >,
) {
    for (focused, hovered, mut border_color) in &mut text_edits {
        *border_color = match (**focused, hovered.get()) {
            (true, true) => HOWERED_ACTIVE.into(),
            (true, false) => ACTIVE.into(),
            (false, true) => HOWERED.into(),
            (false, false) => INACTIVE.into(),
        };
    }
}
