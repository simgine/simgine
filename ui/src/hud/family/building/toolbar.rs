use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use bevy_enhanced_input::prelude::*;
use simgine_core::state::FamilyMode;

use crate::{
    button_bindings,
    widget::{
        button::{action::ButtonContext, icon::ButtonIcon, style::ButtonStyle},
        theme::SCREEN_OFFSET,
    },
};

pub(super) fn toolbar_node() -> impl Bundle {
    (
        Node {
            align_items: AlignItems::FlexStart,
            justify_self: JustifySelf::Center,
            margin: SCREEN_OFFSET,
            ..Default::default()
        },
        DespawnOnExit(FamilyMode::Building),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent.spawn((
                Button,
                ImageNode {
                    flip_x: true,
                    ..Default::default()
                },
                ButtonIcon::new("base/ui/icons/redo.png"),
                ButtonStyle::default(),
                ButtonContext,
                button_bindings![KeyCode::KeyZ.with_mod_keys(ModKeys::CONTROL)],
            ));
            parent.spawn((
                Button,
                ButtonIcon::new("base/ui/icons/redo.png"),
                ButtonStyle::default(),
                ButtonContext,
                button_bindings![KeyCode::KeyZ.with_mod_keys(ModKeys::CONTROL | ModKeys::SHIFT)],
            ));
        })),
    )
}
