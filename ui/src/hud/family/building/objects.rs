use bevy::prelude::*;
use simgine_core::{
    BuildingMode,
    asset_manifest::{ObjectCategory, ObjectManifest},
};

use crate::{
    preview::Preview,
    widget::button::{
        icon::ButtonIcon,
        toggled::{Exclusive, Toggled},
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
                    padding: UiRect::all(px(5)),
                    border_radius: BorderRadius::all(px(13)),
                    ..Default::default()
                },
                BoxShadow::from(ShadowStyle {
                    color: Color::BLACK.with_alpha(0.5),
                    blur_radius: px(2),
                    x_offset: px(8),
                    y_offset: px(8),
                    ..Default::default()
                }),
                BackgroundColor(Color::WHITE),
                children![(
                    Preview(id),
                    Node {
                        height: px(128),
                        width: px(98),
                        border_radius: BorderRadius::all(px(8)),
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
                ObjectsGrid,
                Node {
                    display: Display::Grid,
                    column_gap: px(8),
                    row_gap: px(8),
                    grid_template_columns: vec![GridTrack::auto(); 3],
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
#[require(Exclusive)]
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
