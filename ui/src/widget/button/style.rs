use bevy::{
    color::palettes::tailwind::{BLUE_50, BLUE_400, BLUE_500},
    prelude::*,
    ui::UiSystems,
};

use super::toggled::Toggled;

pub(super) fn plugin(app: &mut App) {
    app.add_systems(PreUpdate, update_style.after(UiSystems::Focus));
}

fn update_style(
    mut buttons: Query<
        (
            Entity,
            &Interaction,
            &ButtonStyle,
            &mut BackgroundColor,
            Option<&mut ImageNode>,
            Option<&Toggled>,
        ),
        Or<(Changed<Interaction>, Changed<Toggled>)>,
    >,
) {
    for (entity, interaction, style, mut background, node, toggled) in &mut buttons {
        trace!("changing style for `{entity}` based on `{interaction:?}` and `{toggled:?}`");
        let color = style.get_color(interaction, toggled);
        if let Some(mut node) = node {
            node.color = color
        } else {
            *background = color.into();
        }
    }
}

#[derive(Component, Clone, Copy)]
#[require(Button)]
pub(crate) struct ButtonStyle {
    pub(crate) hovered_pressed: Color,
    pub(crate) pressed: Color,
    pub(crate) hovered: Color,
    pub(crate) none: Color,
}

impl ButtonStyle {
    fn get_color(&self, interaction: &Interaction, toggled: Option<&Toggled>) -> Color {
        let toggled = toggled.map(|toggled| toggled.0).unwrap_or_default();
        match (interaction, toggled) {
            (Interaction::Pressed, _) | (Interaction::None, true) => self.pressed,
            (Interaction::Hovered, true) => self.hovered_pressed,
            (Interaction::Hovered, false) => self.hovered,
            (Interaction::None, false) => self.none,
        }
    }
}

impl Default for ButtonStyle {
    fn default() -> Self {
        Self {
            hovered_pressed: BLUE_400.into(),
            pressed: BLUE_500.into(),
            hovered: BLUE_50.into(),
            none: Color::WHITE,
        }
    }
}
