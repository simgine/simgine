mod objects;

use bevy::{color::palettes::tailwind::BLUE_500, prelude::*};
use simgine_core::{BuildingMode, FamilyMode};

use objects::ObjectsNode;

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(objects::plugin)
        .add_observer(init_button)
        .add_observer(set_mode)
        .add_systems(OnEnter(FamilyMode::Building), spawn)
        .add_systems(OnEnter(BuildingMode::Objects), update)
        .add_systems(OnEnter(BuildingMode::Walls), update);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            flex_direction: FlexDirection::Column,
            left: px(16.0),
            top: px(16.0),
            ..Default::default()
        },
        DespawnOnExit(FamilyMode::Building),
        children![
            (
                Node::default(),
                children![
                    BuildingModeButton(BuildingMode::Objects),
                    BuildingModeButton(BuildingMode::Walls),
                ]
            ),
            ObjectsNode,
        ],
    ));
}

fn init_button(
    insert: On<Insert, BuildingModeButton>,
    asset_server: Res<AssetServer>,
    mut buttons: Query<(&mut ImageNode, &BuildingModeButton)>,
) {
    let (mut node, &mode_button) = buttons.get_mut(insert.entity).unwrap();
    let image = match *mode_button {
        BuildingMode::Objects => asset_server.load("base/ui/icons/objects_mode.png"),
        BuildingMode::Walls => asset_server.load("base/ui/icons/walls_mode.png"),
    };
    node.image = image;
}

fn update(
    building_mode: Res<State<BuildingMode>>,
    mut buttons: Query<(&mut ImageNode, &BuildingModeButton)>,
    mut objects_visibility: Single<&mut Visibility, With<ObjectsNode>>,
) {
    for (mut node, &button_mode) in &mut buttons {
        if *button_mode == **building_mode {
            node.color = BLUE_500.into();
        } else {
            node.color = Color::WHITE;
        }
    }

    match **building_mode {
        BuildingMode::Objects => **objects_visibility = Visibility::Visible,
        BuildingMode::Walls => **objects_visibility = Visibility::Hidden,
    }
}

fn set_mode(
    mut click: On<Pointer<Click>>,
    mut building_mode: ResMut<NextState<BuildingMode>>,
    buttons: Query<&BuildingModeButton>,
) {
    if let Ok(&mode_button) = buttons.get(click.entity) {
        click.propagate(false);
        building_mode.as_mut().set_if_neq(*mode_button);
    }
}

#[derive(Component, Deref, Clone, Copy)]
#[require(ImageNode)]
struct BuildingModeButton(BuildingMode);
