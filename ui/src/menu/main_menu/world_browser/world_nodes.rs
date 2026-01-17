use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use simgine_core::{error_event::trigger_error, game_paths::GamePaths, world::LoadWorld};

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
        for name in worlds_iter {
            parent.spawn((
                Node {
                    padding: RADIUS_GAP,
                    border_radius: OUTER_RADIUS,
                    column_gap: GAP,
                    ..Default::default()
                },
                BackgroundColor(Color::WHITE),
                BoxShadow::from(SHADOW),
                Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
                    let world_node = parent.target_entity();
                    parent.spawn((
                        BackgroundColor(Color::BLACK),
                        Node {
                            width: px(150),
                            height: px(100),
                            border_radius: INNER_RADIUS,
                            ..Default::default()
                        },
                    ));
                    let world_label = parent
                        .spawn((
                            Text::new(name),
                            TextFont::from_font_size(SMALL_TEXT),
                            TextColor(Color::BLACK),
                            Node {
                                justify_self: JustifySelf::Center,
                                width: px(128),
                                ..Default::default()
                            },
                        ))
                        .id();
                    parent.spawn((
                        Node {
                            align_self: AlignSelf::Center,
                            flex_direction: FlexDirection::Column,
                            ..Default::default()
                        },
                        Children::spawn(SpawnWith(move |parent: &mut RelatedSpawner<_>| {
                            parent.spawn((WorldButton, Text::new("Play"))).observe(
                                move |_on: On<Pointer<Click>>,
                                      mut commands: Commands,
                                      labels: Query<&Text>| {
                                    let text = labels.get(world_label).unwrap();
                                    commands.trigger(LoadWorld {
                                        name: text.to_string(),
                                    });
                                },
                            );
                            let remove_world = move |_on: On<Pointer<Click>>,
                                                     mut commands: Commands,
                                                     game_paths: Res<GamePaths>,
                                                     labels: Query<&Text>|
                                  -> Result<()> {
                                let text = labels.get(world_label).unwrap();
                                let path = game_paths.world_path(text);
                                info!("removing {path:?}");
                                trash::delete(path)?;
                                commands.entity(world_node).despawn();
                                Ok(())
                            };
                            parent
                                .spawn((WorldButton, Text::new("Delete")))
                                .observe(remove_world.pipe(trigger_error));
                        })),
                    ));
                })),
            ));
        }
    });

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
