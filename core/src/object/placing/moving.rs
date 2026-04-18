use bevy::prelude::*;
use bevy_enhanced_input::prelude::{Press, *};

use super::PlacingObject;
use crate::{
    cursor::{
        caster::{CursorMask, CursorTarget},
        follower::{CursorFollower, CursorOffset},
    },
    ghost::Ghost,
    layer::GameLayer,
    object::{MoveObject, Object, SellObject, placing::placing_object},
    state::BuildingMode,
    undo::{HistoryCommands, client_command::DespawnOnResponse},
};

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<MovingObject>()
        .add_input_context::<ObjectSelector>()
        .add_observer(pick)
        .add_observer(place)
        .add_observer(sell)
        .add_systems(OnEnter(BuildingMode::Objects), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        ObjectSelector,
        CursorMask::new(GameLayer::Object),
        DespawnOnExit(BuildingMode::Objects),
        actions!(ObjectSelector[
            (
                Action::<Pick>::new(),
                Press::default(),
                ActionSettings {
                    consume_input: true,
                    require_reset: true,
                    ..Default::default()
                },
                bindings![MouseButton::Left, GamepadButton::South]
            ),
        ]),
    ));
}

fn pick(
    _on: On<Fire<Pick>>,
    cursor_target: Single<&CursorTarget>,
    mut commands: Commands,
    objects: Query<(&SceneRoot, &Transform), With<Object>>,
) {
    let Some(cursor_target) = ***cursor_target else {
        return;
    };
    let Ok((scene_root, transform)) = objects.get(cursor_target) else {
        return;
    };

    info!("picking `{cursor_target}`");
    commands.spawn((
        Name::new("Moving object"),
        placing_object(),
        MovingObject,
        ContextPriority::<MovingObject>::new(100),
        Ghost {
            original_entity: cursor_target,
        },
        scene_root.clone(),
        *transform,
        CursorOffset::default(),
        DespawnOnExit(BuildingMode::Objects),
        actions!(MovingObject[
            (
                Action::<Place>::new(),
                Press::default(),
                ActionSettings {
                    consume_input: true,
                    require_reset: true,
                    ..Default::default()
                },
                bindings![MouseButton::Left, GamepadButton::South]
            ),
            (
                Action::<Sell>::new(),
                Press::default(),
                bindings![KeyCode::Delete, GamepadButton::North]
            ),
        ]),
    ));
}

fn place(
    place: On<Fire<Place>>,
    mut commands: HistoryCommands,
    moving_object: Single<(&Ghost, &Transform), With<MovingObject>>,
) {
    let (ghost, transform) = *moving_object;
    info!("moving `{}`", ghost.original_entity);

    let id = commands.queue_confirmable(MoveObject {
        object: ghost.original_entity,
        translation: transform.translation,
        rotation: transform.rotation,
    });

    commands
        .entity(place.context)
        .remove_with_requires::<(PlacingObject, MovingObject)>()
        .despawn_related::<Actions<PlacingObject>>()
        .despawn_related::<Actions<MovingObject>>()
        .insert(DespawnOnResponse { id });
}

fn sell(
    sell: On<Fire<Sell>>,
    mut commands: HistoryCommands,
    ghost: Single<&Ghost, With<MovingObject>>,
) {
    info!("selling `{}`", ghost.original_entity);

    let id = commands.queue_confirmable(SellObject {
        object: ghost.original_entity,
    });

    commands
        .entity(sell.context)
        .remove_with_requires::<(CursorFollower, MovingObject)>()
        .despawn_related::<Actions<MovingObject>>()
        .insert(DespawnOnResponse { id });
}

#[derive(Component)]
struct ObjectSelector;

#[derive(InputAction)]
#[action_output(bool)]
struct Pick;

#[derive(Component)]
struct MovingObject;

#[derive(InputAction)]
#[action_output(bool)]
struct Place;

#[derive(InputAction)]
#[action_output(bool)]
struct Sell;
