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
            width: px(50),
            height: px(50),
            ..Default::default()
        },
        ModePanel,
        children![
            (
                ImageNode::new(building_mode),
                ButtonMode(FamilyMode::Building),
                button_bindings!(SetMode[KeyCode::F2])
            ),
            (
                ImageNode::new(life_mode),
                ButtonMode(FamilyMode::Life),
                button_bindings!(SetMode[KeyCode::F1]),
            ),
        ],
    ));
}

fn update_buttons(
    family_mode: Res<State<FamilyMode>>,
    mode_buttons: Single<&Children, With<ModePanel>>,
    mut nodes: Query<(&mut ImageNode, &ButtonMode)>,
) {
    let mut iter = nodes.iter_many_mut(*mode_buttons);
    while let Some((mut node, &button_mode)) = iter.fetch_next() {
        if *button_mode == **family_mode {
            node.color = GREEN_500.into();
        } else {
            node.color = Color::WHITE;
        }
    }
}

fn set_mode(
    fire: On<Fire<SetMode>>,
    mut family_mode: ResMut<NextState<FamilyMode>>,
    button_modes: Query<&ButtonMode>,
) {
    let button_mode = button_modes.get(fire.context).unwrap();
    family_mode.as_mut().set_if_neq(**button_mode);
}

#[derive(Component)]
struct ModePanel;

#[derive(Component, Deref, Clone, Copy)]
struct ButtonMode(FamilyMode);

#[derive(InputAction)]
#[action_output(bool)]
struct SetMode;
