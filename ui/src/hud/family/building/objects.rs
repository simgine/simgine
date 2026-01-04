use bevy::prelude::*;
use simgine_core::{
    asset_manifest::{ObjectCategory, ObjectManifest},
    state::BuildingMode,
};

use crate::{
    preview::Preview,
    widget::{
        button::{
            exclusive_group::ExclusiveGroup, icon::ButtonIcon, style::ButtonStyle, toggled::Toggled,
        },
        theme::{
            INNER_RADIUS, OUTER_RADIUS, PREVIEW_COLUMNS, PREVIEW_GAP, PREVIEW_HEIGHT,
            PREVIEW_WIDTH, RADIUS_GAP, SHADOW,
        },
    },
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(spawn_grid_buttons)
        .add_systems(OnEnter(BuildingMode::Objects), show)
        .add_systems(OnExit(BuildingMode::Objects), hide);
}

fn spawn_grid_buttons(
    add: On<Add, ObjectsGrid>,
    mut commands: Commands,
    objects: Res<Assets<ObjectManifest>>,
) {
    trace!("spawning grid buttons");

    commands.entity(add.entity).with_children(|parent| {
        for (id, _) in objects.iter() {
            parent.spawn((
                Node {
                    padding: RADIUS_GAP,
                    border_radius: OUTER_RADIUS,
                    ..Default::default()
                },
                BoxShadow::from(SHADOW),
                ButtonStyle::default(),
                Toggled(false),
                children![(
                    Preview(id),
                    Node {
                        height: PREVIEW_HEIGHT,
                        width: PREVIEW_WIDTH,
                        border_radius: INNER_RADIUS,
                        ..Default::default()
                    },
                )],
            ));
        }
    });
}

fn show(mut visibility: Single<&mut Visibility, With<ObjectsNode>>) {
    **visibility = Visibility::Inherited;
}

fn hide(mut visibility: Single<&mut Visibility, With<ObjectsNode>>) {
    **visibility = Visibility::Hidden;
}

pub(super) fn objects_node() -> impl Bundle {
    (
        Node {
            flex_direction: FlexDirection::Column,
            ..Default::default()
        },
        ObjectsNode,
        children![
            (
                Node::default(),
                ExclusiveGroup::default(),
                children![
                    (
                        ButtonIcon::new("base/ui/icons/all_objects.png"),
                        Toggled(true),
                        CategoryButton::from(CategoryFilter::AllObjects)
                    ),
                    (
                        ButtonIcon::new("base/ui/icons/furniture.png"),
                        CategoryButton::from(ObjectCategory::Furniture),
                    )
                ],
            ),
            (
                ExclusiveGroup::default(),
                ObjectsGrid,
                Node {
                    display: Display::Grid,
                    column_gap: PREVIEW_GAP,
                    row_gap: PREVIEW_GAP,
                    grid_template_columns: vec![GridTrack::auto(); PREVIEW_COLUMNS],
                    ..Default::default()
                },
            )
        ],
    )
}

#[derive(Component)]
struct ObjectsNode;

#[derive(Component, Deref, Clone, Copy)]
#[component(immutable)]
#[require(ButtonStyle, Toggled)]
struct CategoryButton(CategoryFilter);

impl<T: Into<CategoryFilter>> From<T> for CategoryButton {
    fn from(value: T) -> Self {
        Self(value.into())
    }
}

#[derive(Component)]
struct ObjectsGrid;

#[derive(Default, PartialEq, Clone, Copy)]
enum CategoryFilter {
    #[default]
    AllObjects,
    Category(ObjectCategory),
}

impl From<ObjectCategory> for CategoryFilter {
    fn from(value: ObjectCategory) -> Self {
        Self::Category(value)
    }
}
