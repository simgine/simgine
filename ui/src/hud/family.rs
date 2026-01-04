mod building;
mod life;

use bevy::prelude::*;
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
        .add_observer(set_mode)
        .add_systems(OnEnter(GameState::InGame), spawn);
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
        DespawnOnExit(GameState::InGame),
        ExclusiveGroup::default(),
        children![
            (
                ButtonIcon::new("base/ui/icons/building_mode.png"),
                Toggled(true),
                FamilyModeButton(FamilyMode::Life),
                button_bindings![KeyCode::F1],
            ),
            (
                ButtonIcon::new("base/ui/icons/life_mode.png"),
                FamilyModeButton(FamilyMode::Building),
                button_bindings![KeyCode::F2]
            ),
        ],
    ));
}

fn set_mode(
    activate: On<Fire<Activate>>,
    mut commands: Commands,
    buttons: Query<&FamilyModeButton>,
) {
    if let Ok(&mode) = buttons.get(activate.context) {
        info!("changing family mode to `{:?}`", *mode);
        commands.set_state_if_neq(*mode);
    }
}

#[derive(Component, Deref, Clone, Copy)]
#[component(immutable)]
#[require(ButtonContext, ButtonStyle, Toggled)]
struct FamilyModeButton(FamilyMode);
