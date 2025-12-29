use bevy::prelude::*;
use simgine_core::asset_manifest::{ObjectCategory, ObjectManifest};

use crate::widget::button::{
    icon::ButtonIcon,
    toggle::{Exclusive, Toggled},
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(spawn_object_buttons);
}

fn spawn_object_buttons(
    add: On<Add, ObjectsGrid>,
    mut commands: Commands,
    objects: Res<Assets<ObjectManifest>>,
) {
    commands.entity(add.entity).with_children(|parent| {
        for _ in 0..objects.len() {
            parent.spawn((
                Node {
                    height: px(128),
                    width: px(98),
                    border_radius: BorderRadius::all(px(8)),
                    ..Default::default()
                },
                BackgroundColor(Color::WHITE),
            ));
        }
    });
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
