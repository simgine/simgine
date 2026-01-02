mod building;
mod life;

use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;
use simgine_core::state::{FamilyMode, GameState};

use crate::{
    button_bindings,
    widget::{
        SCREEN_OFFSET,
        button::{
            action::{Activate, ButtonContext},
            exclusive_group::ExclusiveGroup,
            icon::ButtonIcon,
            style::ButtonStyle,
            toggled::Toggled,
        },
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
            position_type: PositionType::Absolute,
            flex_direction: FlexDirection::RowReverse,
            right: SCREEN_OFFSET,
            top: SCREEN_OFFSET,
            height: px(50.0),
            ..Default::default()
        },
        DespawnOnExit(GameState::InGame),
        ExclusiveGroup::default(),
        children![
            (
                ButtonIcon::new("base/ui/icons/life_mode.png"),
                FamilyModeButton(FamilyMode::Building),
                button_bindings![KeyCode::F2]
            ),
            (
                ButtonIcon::new("base/ui/icons/building_mode.png"),
                Toggled(true),
                FamilyModeButton(FamilyMode::Life),
                button_bindings![KeyCode::F1],
            ),
        ],
    ));
}

fn set_mode(
    activate: On<Fire<Activate>>,
    mut family_mode: ResMut<NextState<FamilyMode>>,
    buttons: Query<&FamilyModeButton>,
) {
    if let Ok(&mode) = buttons.get(activate.context) {
        info!("changing family mode to `{:?}`", *mode);
        family_mode.as_mut().set_if_neq(*mode);
    }
}

#[derive(Component, Deref, Clone, Copy)]
#[component(immutable)]
#[require(ButtonContext, ButtonStyle, Toggled)]
struct FamilyModeButton(FamilyMode);
