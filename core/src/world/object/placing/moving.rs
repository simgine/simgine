use bevy::prelude::*;
use bevy_enhanced_input::prelude::*;

use super::PlacingObject;
use crate::{
    state::BuildingMode,
    undo::{HistoryCommands, client_command::DespawnOnResponse},
    world::{
        cursor::{
            caster::{CursorMask, CursorTarget},
            follower::CursorOffset,
        },
        layer::GameLayer,
        object::{MoveObject, Object, SellObject, placing::placing_object},
        placing::PlacingBlockers,
        preview::PreviewOf,
    },
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
    _on: On<Start<Pick>>,
    cursor_target: Single<&CursorTarget>,
    mut commands: Commands,
    objects: Query<(&SceneRoot, &Transform), With<Object>>,
) {
    let Some(target) = ***cursor_target else {
        return;
    };
    let Ok((scene_root, transform)) = objects.get(target) else {
        return;
    };

    info!("picking `{target}`");
    commands.spawn((
        Name::new("Moving object"),
        placing_object(),
        MovingObject,
        ContextPriority::<MovingObject>::new(100),
        PreviewOf { target },
        scene_root.clone(),
        *transform,
        CursorOffset::default(),
        DespawnOnExit(BuildingMode::Objects),
        actions!(MovingObject[
            (
                Action::<Place>::new(),
                ActionSettings {
                    consume_input: true,
                    require_reset: true,
                    ..Default::default()
                },
                bindings![MouseButton::Left, GamepadButton::South]
            ),
            (
                Action::<Sell>::new(),
                bindings![KeyCode::Delete, GamepadButton::North]
            ),
        ]),
    ));
}

fn place(
    place: On<Start<Place>>,
    mut commands: HistoryCommands,
    moving_object: Single<(&PreviewOf, &Transform, &PlacingBlockers), With<MovingObject>>,
) {
    let (preview, transform, blockers) = *moving_object;
    if !blockers.is_empty() {
        return;
    }

    info!("moving `{}`", preview.target);
    let id = commands.queue_confirmable(MoveObject {
        object: preview.target,
        translation: transform.translation,
        rotation: transform.rotation,
    });

    commands
        .entity(place.context)
        .remove_with_requires::<MovingObject>()
        .despawn_related::<Actions<PlacingObject>>()
        .despawn_related::<Actions<MovingObject>>()
        .insert(DespawnOnResponse { id });
}

fn sell(
    sell: On<Start<Sell>>,
    mut commands: HistoryCommands,
    preview: Single<&PreviewOf, With<MovingObject>>,
) {
    info!("selling `{}`", preview.target);

    let id = commands.queue_confirmable(SellObject {
        object: preview.target,
    });

    commands
        .entity(sell.context)
        .remove_with_requires::<MovingObject>()
        .despawn_related::<Actions<MovingObject>>()
        .insert(DespawnOnResponse { id });
}

#[derive(Component)]
struct ObjectSelector;

#[derive(InputAction)]
#[action_output(bool)]
struct Pick;

#[derive(Component)]
#[require(PlacingObject)]
struct MovingObject;

#[derive(InputAction)]
#[action_output(bool)]
struct Place;

#[derive(InputAction)]
#[action_output(bool)]
struct Sell;
