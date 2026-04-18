use bevy::prelude::*;
use bevy_enhanced_input::prelude::{Press, *};

use crate::{
    cursor::{
        caster::{CursorMask, CursorTarget},
        follower::{CursorFollower, CursorOffset},
    },
    ghost::Ghost,
    layer::GameLayer,
    object::{MoveObject, Object, SellObject},
    state::BuildingMode,
    undo::{HistoryCommands, client_command::DespawnOnResponse},
};

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<MovePreview>()
        .add_input_context::<ObjectSelector>()
        .add_observer(select)
        .add_observer(move_action)
        .add_observer(sell)
        .add_observer(cancel)
        .add_systems(OnEnter(BuildingMode::Objects), spawn);
}

fn spawn(mut commands: Commands) {
    commands.spawn((
        ObjectSelector,
        CursorMask::new(GameLayer::Object),
        DespawnOnExit(BuildingMode::Objects),
        actions!(ObjectSelector[
            (
                Action::<Select>::new(),
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

fn select(
    _on: On<Fire<Select>>,
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

    info!("selecting `{cursor_target}`");
    commands.spawn((
        Name::new("Selected object"),
        scene_root.clone(),
        *transform,
        CursorFollower,
        CursorOffset::default(),
        CursorMask::new(GameLayer::Ground),
        DespawnOnExit(BuildingMode::Objects),
        MovePreview {
            object: cursor_target,
        },
        Ghost {
            original_entity: cursor_target,
        },
        ContextPriority::<MovePreview>::new(100),
        actions!(MovePreview[
            (
                Action::<Move>::new(),
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
            (
                Action::<Cancel>::new(),
                Press::default(),
                ActionSettings {
                    consume_input: true,
                    require_reset: true,
                    ..Default::default()
                },
                bindings![KeyCode::Escape, GamepadButton::East]
            )
        ]),
    ));
}

fn move_action(
    move_action: On<Fire<Move>>,
    mut commands: HistoryCommands,
    move_preview: Single<(&MovePreview, &Transform)>,
) {
    let (preview, transform) = *move_preview;
    info!("moving `{}`", preview.object);

    let id = commands.queue_confirmable(MoveObject {
        object: preview.object,
        translation: transform.translation,
        rotation: transform.rotation,
    });

    commands
        .entity(move_action.context)
        .remove_with_requires::<(CursorFollower, MovePreview)>()
        .despawn_related::<Actions<MovePreview>>()
        .insert(DespawnOnResponse { id });
}

fn sell(sell: On<Fire<Sell>>, mut commands: HistoryCommands, preview: Single<&MovePreview>) {
    info!("selling `{}`", preview.object);

    let id = commands.queue_confirmable(SellObject {
        object: preview.object,
    });

    commands
        .entity(sell.context)
        .remove_with_requires::<(CursorFollower, MovePreview)>()
        .despawn_related::<Actions<MovePreview>>()
        .insert(DespawnOnResponse { id });
}

fn cancel(cancel: On<Fire<Cancel>>, mut commands: Commands) {
    info!("cancelling");
    commands.entity(cancel.context).despawn();
}

#[derive(Component)]
struct ObjectSelector;

#[derive(InputAction)]
#[action_output(bool)]
struct Select;

#[derive(Component)]
#[component(immutable)]
struct MovePreview {
    object: Entity,
}

#[derive(InputAction)]
#[action_output(bool)]
struct Move;

#[derive(InputAction)]
#[action_output(bool)]
struct Sell;

#[derive(InputAction)]
#[action_output(bool)]
struct Cancel;
