use bevy::prelude::*;
use bevy_enhanced_input::prelude::{Press, *};

use super::{Object, placing::PlacingObject};
use crate::{
    cursor::{caster::CursorCaster, follower::CursorFollower},
    ghost::Ghost,
    layer::GameLayer,
    object::{MoveObject, SellObject},
    outline::OutlineDisabler,
    state::BuildingMode,
    undo::{HistoryCommands, client_command::DespawnOnResponse},
};

pub(super) fn plugin(app: &mut App) {
    app.add_input_context::<MovePreview>()
        .add_observer(select)
        .add_observer(move_action)
        .add_observer(sell)
        .add_observer(cancel);
}

fn select(
    mut click: On<Pointer<Click>>,
    caster: CursorCaster,
    mut commands: Commands,
    building_mode: Option<Res<State<BuildingMode>>>,
    objects: Query<(&SceneRoot, &Transform), With<Object>>,
    placing_or_moving: Query<(), Or<(With<PlacingObject>, With<MovePreview>)>>,
) {
    if click.button != PointerButton::Primary {
        return;
    }
    if building_mode.is_none_or(|mode| **mode != BuildingMode::Objects) {
        return;
    }
    if !placing_or_moving.is_empty() {
        return;
    }
    let Ok((scene_root, transform)) = objects.get(click.entity) else {
        return;
    };
    let Some(ground_point) = caster.cast_ray(GameLayer::Ground) else {
        return;
    };

    click.propagate(false);

    info!("selecting `{}`", click.entity);
    commands.spawn((
        Name::new("Selected object"),
        scene_root.clone(),
        CursorFollower {
            offset: transform.translation - ground_point,
        },
        MovePreview {
            object: click.entity,
        },
        OutlineDisabler,
        Ghost {
            original_entity: click.entity,
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
