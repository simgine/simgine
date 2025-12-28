use bevy::{color::palettes::tailwind::GREEN_500, prelude::*};
use bevy_enhanced_input::prelude::*;
use simgine_core::{FamilyMode, GameState};

use crate::button_bindings;

pub(crate) fn plugin(app: &mut App) {
    app.add_observer(set_mode)
        .add_systems(OnEnter(GameState::InGame), spawn)
        .add_systems(OnEnter(FamilyMode::Life), update_buttons)
        .add_systems(OnEnter(FamilyMode::Building), update_buttons);
}

fn spawn(mut commands: Commands, asset_server: Res<AssetServer>) {
    let life_mode = asset_server.load("base/ui/icons/life_mode.png");
    let building_mode = asset_server.load("base/ui/icons/building_mode.png");

    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            flex_direction: FlexDirection::RowReverse,
            right: px(16.0),
            top: px(16.0),
            height: px(50),
            ..Default::default()
        },
        ModePanel,
        children![
            (
                ImageNode::new(building_mode),
                ModeButton(FamilyMode::Building),
                button_bindings!(SetMode[KeyCode::F2])
            ),
            (
                ImageNode::new(life_mode),
                ModeButton(FamilyMode::Life),
                button_bindings!(SetMode[KeyCode::F1]),
            ),
        ],
    ));
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

#[derive(Component)]
struct ModePanel;

#[derive(Component, Deref, Clone, Copy)]
struct ModeButton(FamilyMode);

#[derive(InputAction)]
#[action_output(bool)]
struct SetMode;
