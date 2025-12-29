use bevy::{color::palettes::tailwind::BLUE_500, prelude::*};
use simgine_core::{BuildingMode, FamilyMode};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(init_button)
        .add_observer(set_mode)
        .add_systems(OnEnter(FamilyMode::Building), spawn)
        .add_systems(OnEnter(BuildingMode::Objects), update_buttons)
        .add_systems(OnEnter(BuildingMode::Walls), update_buttons);
}

fn spawn(mut commands: Commands) {
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
            ModeButton(BuildingMode::Objects),
            ModeButton(BuildingMode::Walls),
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
        BuildingMode::Objects => asset_server.load("base/ui/icons/objects_mode.png"),
        BuildingMode::Walls => asset_server.load("base/ui/icons/walls_mode.png"),
    };
    node.image = image;
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
#[require(ImageNode)]
struct ModeButton(BuildingMode);
