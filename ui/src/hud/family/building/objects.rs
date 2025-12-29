use bevy::prelude::*;
use simgine_core::asset_manifest::ObjectManifest;

pub(super) fn plugin(app: &mut App) {
    app.add_observer(create_icons);
}

fn create_icons(
    add: On<Add, ObjectsNode>,
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

#[derive(Component)]
#[require(
    Node {
        display: Display::Grid,
        column_gap: px(8),
        row_gap: px(8),
        grid_template_columns: vec![GridTrack::auto(); 3],
        ..Default::default()
    },
)]
pub(super) struct ObjectsNode;
