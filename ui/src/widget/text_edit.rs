use bevy::{input_focus::InputFocus, prelude::*, ui::UiSystems};
use bevy_simple_text_input::{TextInput, TextInputInactive, TextInputTextFont};

use crate::widget::theme::{
    ACTIVE, HOWERED, HOWERED_ACTIVE, INACTIVE, NORMAL_TEXT, OUTER_RADIUS, RADIUS_GAP,
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(activate)
        .add_observer(update_focus)
        .add_systems(PreUpdate, update_style.after(UiSystems::Focus));
}

#[derive(Component)]
#[require(
   Node {
        align_self: AlignSelf::Center,
        width: Val::Px(300.0),
        border_radius: OUTER_RADIUS,
        border: RADIUS_GAP,
        padding: RADIUS_GAP,
        ..Default::default()
    },
    TextInput,
    TextInputTextFont(TextFont::from_font_size(NORMAL_TEXT)),
)]
pub(crate) struct TextEdit;

fn update_style(
    mut text_edits: Query<
        (&Interaction, &TextInputInactive, &mut BorderColor),
        Or<(Changed<Interaction>, Changed<TextInputInactive>)>,
    >,
) {
    for (interaction, inactive, mut border_color) in &mut text_edits {
        *border_color = match (interaction, inactive.0) {
            (Interaction::Pressed, _) | (Interaction::None, false) => ACTIVE.into(),
            (Interaction::Hovered, false) => HOWERED_ACTIVE.into(),
            (Interaction::Hovered, true) => HOWERED.into(),
            (Interaction::None, true) => INACTIVE.into(),
        };
    }
}

fn activate(
    mut trigger: On<Pointer<Click>>,
    mut commands: Commands,
    text_edits: Query<&TextInputInactive>,
) {
    let Ok(inactive) = text_edits.get(trigger.entity) else {
        return;
    };

    trigger.propagate(false);
    if inactive.0 {
        commands
            .entity(trigger.entity)
            .insert(TextInputInactive(false));
    }
}

fn update_focus(
    trigger: On<Insert, TextInputInactive>,
    mut focus: ResMut<InputFocus>,
    mut text_edits: Query<&mut TextInputInactive>,
) {
    let inactive = text_edits.get(trigger.entity).unwrap();
    if inactive.0 {
        return;
    }

    if let Some(previous) = focus.get()
        && let Ok(mut inactive) = text_edits.get_mut(previous)
    {
        inactive.0 = true;
    }

    debug!("activating `{}`", trigger.entity);
    focus.set(trigger.entity);
}
