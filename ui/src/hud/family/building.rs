use bevy::{color::palettes::tailwind::BLUE_500, prelude::*};
use simgine_core::{BuildingMode, FamilyMode};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(set_mode)
        .add_systems(OnEnter(FamilyMode::Building), spawn)
        .add_systems(OnEnter(BuildingMode::Objects), update_buttons)
        .add_systems(OnEnter(BuildingMode::Walls), update_buttons);
}

fn spawn(mut commands: Commands, asset_server: Res<AssetServer>) {
    let objects_mode = asset_server.load("base/ui/icons/objects_mode.png");
    let walls_mode = asset_server.load("base/ui/icons/walls_mode.png");

    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            left: px(16.0),
            top: px(16.0),
            height: px(50),
            ..Default::default()
        },
        DespawnOnExit(FamilyMode::Building),
        children![
            (
                ImageNode::new(objects_mode),
                ModeButton(BuildingMode::Objects),
            ),
            (ImageNode::new(walls_mode), ModeButton(BuildingMode::Walls)),
        ],
    ));
}

fn update_buttons(
    building_mode: Res<State<BuildingMode>>,
    mut mode_nodes: Query<(&mut ImageNode, &ModeButton)>,
) {
    for (mut node, &button_mode) in &mut mode_nodes {
        if *button_mode == **building_mode {
            node.color = BLUE_500.into();
        } else {
            node.color = Color::WHITE;
        }
    }
}

fn set_mode(
    mut click: On<Pointer<Click>>,
    mut building_mode: ResMut<NextState<BuildingMode>>,
    mode_buttons: Query<&ModeButton>,
) {
    if let Ok(&mode_button) = mode_buttons.get(click.entity) {
        click.propagate(false);
        building_mode.as_mut().set_if_neq(*mode_button);
    }
}

#[derive(Component, Deref, Clone, Copy)]
struct ModeButton(BuildingMode);
