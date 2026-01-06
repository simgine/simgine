use std::{fs, path::PathBuf};

use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use simgine_core::{error_event::trigger_error, game_paths::GamePaths, state::GameState};

use crate::widget::{
    button::style::ButtonStyle,
    theme::{GAP, INNER_RADIUS, OUTER_RADIUS, RADIUS_GAP, SHADOW, SMALL_TEXT},
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(spawn_world_nodes.pipe(trigger_error));
}

fn spawn_world_nodes(
    insert: On<Insert, WorldNodes>,
    mut commands: Commands,
    game_paths: Res<GamePaths>,
) -> Result<()> {
    let worlds_iter = game_paths.iter_worlds()?;

    commands.entity(insert.entity).with_children(|parent| {
        for (name, path) in worlds_iter {
            parent.spawn((
                Node {
                    padding: RADIUS_GAP,
                    border_radius: OUTER_RADIUS,
                    column_gap: GAP,
                    ..Default::default()
                },
                WorldNode { path },
                BackgroundColor(Color::WHITE),
                BoxShadow::from(SHADOW),
                children![
                    (
                        BackgroundColor(Color::BLACK),
                        Node {
                            width: px(150),
                            height: px(100),
                            border_radius: INNER_RADIUS,
                            ..Default::default()
                        },
                    ),
                    (
                        Text::new(name),
                        TextFont::from_font_size(SMALL_TEXT),
                        TextColor(Color::BLACK),
                        Node {
                            justify_self: JustifySelf::Center,
                            width: px(128),
                            ..Default::default()
                        },
                    ),
                    (
                        Node {
                            align_self: AlignSelf::Center,
                            flex_direction: FlexDirection::Column,
                            ..Default::default()
                        },
                        Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
                            parent.spawn((WorldButton, Text::new("Play"))).observe(
                                |_on: On<Pointer<Click>>, mut commands: Commands| {
                                    commands.set_state(GameState::World);
                                },
                            );
                            parent.spawn((WorldButton, Text::new("Host")));
                            parent
                                .spawn((WorldButton, Text::new("Delete")))
                                .observe(delete_world.pipe(trigger_error));
                        })),
                    )
                ],
            ));
        }
    });

    Ok(())
}

fn delete_world(
    click: On<Pointer<Click>>,
    mut commands: Commands,
    buttons: Query<&ChildOf>,
    nodes: Query<(Entity, &WorldNode)>,
) -> Result<()> {
    let (entity, node) = nodes
        .iter_many(buttons.iter_ancestors(click.entity))
        .next()
        .expect("world buttons should have ancestors");

    info!("removing {:?}", node.path);
    commands.entity(entity).despawn();
    fs::remove_file(&node.path)?;

    Ok(())
}

#[derive(Component)]
#[require(
    Node {
        row_gap: GAP,
        flex_direction: FlexDirection::Column,
        ..Default::default()
    },
)]
pub(super) struct WorldNodes;

#[derive(Component)]
#[require(
    Node {
        align_self: AlignSelf::End,
        ..Default::default()
    },
    TextFont::from_font_size(SMALL_TEXT),
    ButtonStyle::BLACK
)]
struct WorldButton;

#[derive(Component)]
struct WorldNode {
    path: PathBuf,
}
