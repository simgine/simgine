mod objects;

use bevy::prelude::*;
use simgine_core::{BuildingMode, FamilyMode};

use crate::widget::{
    SCREEN_OFFSET,
    button::{
        icon::ButtonIcon,
        toggle::{Exclusive, Toggled},
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(objects::plugin)
        .add_observer(set_mode)
        .add_systems(OnEnter(FamilyMode::Building), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            flex_direction: FlexDirection::Column,
            left: SCREEN_OFFSET,
            top: SCREEN_OFFSET,
            ..Default::default()
        },
        DespawnOnExit(FamilyMode::Building),
        children![
            (
                Node::default(),
                children![
                    (
                        ButtonIcon::new("base/ui/icons/objects_mode.png"),
                        Toggled(true),
                        BuildingModeButton(BuildingMode::Objects)
                    ),
                    (
                        ButtonIcon::new("base/ui/icons/walls_mode.png"),
                        BuildingModeButton(BuildingMode::Walls),
                    )
                ]
            ),
            objects::objects_node(),
        ],
    ));
}

fn set_mode(
    mut click: On<Pointer<Click>>,
    mut building_mode: ResMut<NextState<BuildingMode>>,
    buttons: Query<&BuildingModeButton>,
) {
    if let Ok(&mode) = buttons.get(click.entity) {
        click.propagate(false);
        building_mode.as_mut().set_if_neq(*mode);
    }
}

#[derive(Component, Deref, Clone, Copy)]
#[component(immutable)]
#[require(Exclusive)]
struct BuildingModeButton(BuildingMode);
