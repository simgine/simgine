mod building;
mod life;

use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use bevy_enhanced_input::prelude::*;
use simgine_core::state::{FamilyMode, GameState};

use crate::{
    button_bindings,
    widget::{
        button::{
            action::{Activate, ButtonContext},
            exclusive_group::ExclusiveGroup,
            icon::ButtonIcon,
            style::ButtonStyle,
            toggled::Toggled,
        },
        theme::SCREEN_OFFSET,
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(building::plugin)
        .add_plugins(life::plugin)
        .add_systems(OnEnter(GameState::World), spawn);
}

fn spawn(mut commands: Commands) {
    trace!("spawning family mode node");

    commands.spawn((
        Node {
            justify_self: JustifySelf::End,
            align_items: AlignItems::FlexStart,
            margin: SCREEN_OFFSET,
            ..Default::default()
        },
        DespawnOnExit(GameState::World),
        ExclusiveGroup::default(),
        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
            parent
                .spawn((
                    ButtonIcon::new("base/ui/icons/building_mode.png"),
                    Toggled(true),
                    ButtonStyle::default(),
                    ButtonContext,
                    button_bindings![KeyCode::F1],
                ))
                .observe(|_on: On<Fire<Activate>>, mut commands: Commands| {
                    commands.set_state_if_neq(FamilyMode::Life);
                });
            parent
                .spawn((
                    ButtonIcon::new("base/ui/icons/life_mode.png"),
                    ButtonStyle::default(),
                    Toggled(false),
                    ButtonContext,
                    button_bindings![KeyCode::F2],
                ))
                .observe(|_on: On<Fire<Activate>>, mut commands: Commands| {
                    commands.set_state_if_neq(FamilyMode::Building);
                });
        })),
    ));
}
