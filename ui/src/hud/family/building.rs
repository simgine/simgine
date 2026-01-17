mod objects;

use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use simgine_core::state::{BuildingMode, FamilyMode};

use crate::widget::{
    button::{
        exclusive_group::ExclusiveGroup, icon::ButtonIcon, style::ButtonStyle, toggled::Toggled,
    },
    theme::SCREEN_OFFSET,
};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(objects::plugin)
        .add_systems(OnEnter(FamilyMode::Building), spawn);
}

fn spawn(mut commands: Commands) {
    trace!("spawning building mode node");

    commands.spawn((
        Node {
            flex_direction: FlexDirection::Column,
            margin: SCREEN_OFFSET,
            ..Default::default()
        },
        DespawnOnExit(FamilyMode::Building),
        children![
            (
                Node::default(),
                ExclusiveGroup::default(),
                Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
                    parent
                        .spawn((
                            ButtonIcon::new("base/ui/icons/objects_mode.png"),
                            ButtonStyle::default(),
                            Toggled(true),
                        ))
                        .observe(|_on: On<Pointer<Click>>, mut commands: Commands| {
                            commands.set_state_if_neq(BuildingMode::Objects);
                        });
                    parent
                        .spawn((
                            ButtonIcon::new("base/ui/icons/walls_mode.png"),
                            ButtonStyle::default(),
                            Toggled(false),
                        ))
                        .observe(|_on: On<Pointer<Click>>, mut commands: Commands| {
                            commands.set_state_if_neq(BuildingMode::Walls);
                        });
                })),
            ),
            objects::objects_node(),
        ],
    ));
}
