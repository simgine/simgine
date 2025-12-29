mod building;
mod life;

use bevy::{color::palettes::tailwind::GREEN_500, prelude::*};
use bevy_enhanced_input::prelude::*;
use simgine_core::{FamilyMode, GameState};

use crate::button_bindings;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(building::plugin)
        .add_plugins(life::plugin)
        .add_observer(init_button)
        .add_observer(set_mode)
        .add_systems(OnEnter(GameState::InGame), spawn)
        .add_systems(OnEnter(FamilyMode::Life), update_buttons)
        .add_systems(OnEnter(FamilyMode::Building), update_buttons);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            flex_direction: FlexDirection::RowReverse,
            right: px(16.0),
            top: px(16.0),
            height: px(50),
            ..Default::default()
        },
        DespawnOnExit(GameState::InGame),
        children![
            (
                ModeButton(FamilyMode::Building),
                button_bindings!(SetMode[KeyCode::F2])
            ),
            (
                ModeButton(FamilyMode::Life),
                button_bindings!(SetMode[KeyCode::F1]),
            ),
        ],
    ));
}

fn init_button(
    insert: On<Insert, ModeButton>,
    asset_server: Res<AssetServer>,
    mut mode_buttons: Query<(&mut ImageNode, &ModeButton)>,
) {
    let (mut node, &mode_button) = mode_buttons.get_mut(insert.entity).unwrap();
    let image = match *mode_button {
        FamilyMode::Life => asset_server.load("base/ui/icons/life_mode.png"),
        FamilyMode::Building => asset_server.load("base/ui/icons/building_mode.png"),
    };
    node.image = image;
}

fn update_buttons(
    family_mode: Res<State<FamilyMode>>,
    mut mode_nodes: Query<(&mut ImageNode, &ModeButton)>,
) {
    for (mut node, &button_mode) in &mut mode_nodes {
        if *button_mode == **family_mode {
            node.color = GREEN_500.into();
        } else {
            node.color = Color::WHITE;
        }
    }
}

fn set_mode(
    set_mode: On<Fire<SetMode>>,
    mut family_mode: ResMut<NextState<FamilyMode>>,
    mode_buttons: Query<&ModeButton>,
) {
    let mode = **mode_buttons.get(set_mode.context).unwrap();
    family_mode.as_mut().set_if_neq(mode);
}

#[derive(Component, Deref, Clone, Copy)]
struct ModeButton(FamilyMode);

#[derive(InputAction)]
#[action_output(bool)]
struct SetMode;
