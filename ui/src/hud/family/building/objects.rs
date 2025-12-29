use bevy::{color::palettes::tailwind::BLUE_500, prelude::*};
use simgine_core::{
    BuildingMode,
    asset_manifest::{ObjectCategory, ObjectManifest},
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(init_category_button)
        .add_observer(spawn_object_buttons)
        .add_observer(apply_filter)
        .add_systems(OnEnter(BuildingMode::Objects), update_visibility)
        .add_systems(OnEnter(BuildingMode::Walls), update_visibility);
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

fn init_category_button(
    insert: On<Insert, CategoryButton>,
    asset_server: Res<AssetServer>,
    mut buttons: Query<(&mut ImageNode, &CategoryButton)>,
) {
    let (mut node, &category_button) = buttons.get_mut(insert.entity).unwrap();
    let image = match *category_button {
        CategoryFilter::AllObjects => asset_server.load("base/ui/icons/all_objects.png"),
        CategoryFilter::Category(ObjectCategory::Furniture) => {
            asset_server.load("base/ui/icons/furniture.png")
        }
    };
    node.image = image;
}

fn apply_filter(
    _on: On<Insert, ObjectsFilter>,
    objects_filter: Single<&ObjectsFilter>,
    mut buttons: Query<(&mut ImageNode, &CategoryButton)>,
) {
    for (mut node, category_button) in &mut buttons {
        node.color = if **category_button == objects_filter.category {
            BLUE_500.into()
        } else {
            Color::WHITE
        };
    }
}

fn update_visibility(
    building_mode: Res<State<BuildingMode>>,
    mut visibility: Single<&mut Visibility, With<ObjectsNode>>,
) {
    match **building_mode {
        BuildingMode::Objects => **visibility = Visibility::Visible,
        BuildingMode::Walls => **visibility = Visibility::Hidden,
    }
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
                    CategoryButton::from(CategoryFilter::AllObjects),
                    CategoryButton::from(ObjectCategory::Furniture),
                ],
            ),
            (
                ObjectsGrid,
                ObjectsFilter::default(),
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
#[require(Button, ImageNode)]
struct CategoryButton(CategoryFilter);

impl<T: Into<CategoryFilter>> From<T> for CategoryButton {
    fn from(value: T) -> Self {
        Self(value.into())
    }
}

#[derive(Component)]
struct ObjectsGrid;

#[derive(Component, Default)]
struct ObjectsFilter {
    category: CategoryFilter,
}

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
