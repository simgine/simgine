use bevy::{ecs::relationship::RelatedSpawner, prelude::*};
use simgine_core::{error_event::error_event, game_paths::GamePaths, state::GameState};

use crate::widget::{
    button::style::ButtonStyle,
    theme::{GAP, INNER_RADIUS, OUTER_RADIUS, RADIUS_GAP, SHADOW, SMALL_TEXT},
};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(spawn_world_nodes.pipe(error_event));
}

fn spawn_world_nodes(
    insert: On<Insert, WorldNodes>,
    mut commands: Commands,
    game_paths: Res<GamePaths>,
) -> Result<()> {
    let world_names = game_paths.world_names()?;

    commands.entity(insert.entity).with_children(|parent| {
        for name in world_names {
            parent.spawn((
                Node {
                    padding: RADIUS_GAP,
                    border_radius: OUTER_RADIUS,
                    column_gap: GAP,
                    ..Default::default()
                },
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
                                    commands.set_state(GameState::InGame);
                                },
                            );
                            parent.spawn((WorldButton, Text::new("Host")));
                            parent.spawn((WorldButton, Text::new("Delete")));
                        })),
                    )
                ],
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
