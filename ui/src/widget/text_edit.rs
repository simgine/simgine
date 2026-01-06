use bevy::{input_focus::InputFocus, prelude::*};
use bevy_simple_text_input::{TextInput, TextInputInactive, TextInputSystem, TextInputTextFont};

use crate::widget::theme::{ACTIVE, INACTIVE, NORMAL_TEXT, OUTER_RADIUS, RADIUS_GAP};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(update_focus).add_systems(
        Update,
        update_style
            .before(TextInputSystem)
            .run_if(resource_changed::<InputFocus>),
    );
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
    focus: Res<InputFocus>,
    mut text_inputs: Query<(Entity, &mut TextInputInactive, &mut BorderColor)>,
) {
    for (entity, mut inactive, mut border_color) in &mut text_inputs {
        if focus.0 == Some(entity) {
            inactive.0 = false;
            *border_color = ACTIVE.into();
        } else {
            inactive.0 = true;
            *border_color = INACTIVE.into();
        }
    }
}

fn update_focus(
    mut trigger: On<Pointer<Click>>,
    mut focus: ResMut<InputFocus>,
    text_edits: Query<(), With<TextEdit>>,
) {
    if text_edits.get(trigger.entity).is_ok() {
        trigger.propagate(false);
        if focus.get().is_none_or(|e| e != trigger.entity) {
            focus.set(trigger.entity);
        }
    } else if focus.get().is_some() {
        focus.set(trigger.entity);
    }
}
