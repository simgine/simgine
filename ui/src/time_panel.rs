use bevy::{
    color::palettes::tailwind::{BLUE_500, RED_500},
    ecs::relationship::RelatedSpawner,
    prelude::*,
};
use bevy_enhanced_input::prelude::*;
use simgine_core::{
    FamilyMode,
    game_speed::{GameSpeed, SetFast, SetNormal, SetUltra, TogglePause},
};

pub(crate) fn plugin(app: &mut App) {
    app.add_observer(reset_speed_buttons)
        .add_observer(update_speed_buttons)
        .add_systems(OnEnter(FamilyMode::Family), spawn);
}

fn spawn(mut commands: Commands, asset_server: Res<AssetServer>) {
    let pause = asset_server.load("base/ui/icons/pause.png");
    let normal_speed = asset_server.load("base/ui/icons/normal_speed.png");
    let fast_speed = asset_server.load("base/ui/icons/fast_speed.png");
    let ultra_speed = asset_server.load("base/ui/icons/ultra_speed.png");

    commands
        .spawn((
            Node {
                position_type: PositionType::Absolute,
                height: px(50.0),
                width: px(50.0),
                left: px(16.0),
                top: px(16.0),
                ..Default::default()
            },
            DespawnOnExit(FamilyMode::Family),
            Children::spawn(SpawnWith(|parent: &mut RelatedSpawner<_>| {
                parent
                    .spawn((
                        Button,
                        ImageNode {
                            image: pause,
                            ..Default::default()
                        },
                    ))
                    .observe(mock_speed_action::<TogglePause>);
                parent
                    .spawn((
                        Button,
                        ImageNode {
                            image: normal_speed,
                            ..Default::default()
                        },
                    ))
                    .observe(mock_speed_action::<SetNormal>);
                parent
                    .spawn((
                        Button,
                        ImageNode {
                            image: fast_speed,
                            ..Default::default()
                        },
                    ))
                    .observe(mock_speed_action::<SetFast>);
                parent
                    .spawn((
                        Button,
                        ImageNode {
                            image: ultra_speed,
                            ..Default::default()
                        },
                    ))
                    .observe(mock_speed_action::<SetUltra>);
            })),
        ))
        .insert(SpeedPanel); // Workaround to react on insertion after hierarchy spawn.
}

fn mock_speed_action<A: InputAction>(
    _on: On<Pointer<Click>>,
    mut commands: Commands,
    action: Single<Entity, With<Action<A>>>,
) {
    commands
        .entity(*action)
        .insert(ActionMock::once(ActionState::Fired, true));
}

fn reset_speed_buttons(
    _on: On<Replace, GameSpeed>,
    game_speed: Single<&GameSpeed>,
    speed_buttons: Single<&Children, With<SpeedPanel>>,
    mut nodes: Query<&mut ImageNode>,
) {
    match **game_speed {
        GameSpeed::Paused { previous } => {
            let mut pause = nodes.get_mut(speed_buttons[0]).unwrap();
            pause.color = Color::WHITE;
            let mut previous = nodes.get_mut(speed_buttons[previous as usize + 1]).unwrap();
            previous.color = Color::WHITE;
        }
        GameSpeed::Running { speed } => {
            let mut button = nodes.get_mut(speed_buttons[speed as usize + 1]).unwrap();
            button.color = Color::WHITE;
        }
    }
}

fn update_speed_buttons(
    _on: On<Insert, (GameSpeed, SpeedPanel)>,
    game_speed: Single<&GameSpeed>,
    speed_buttons: Single<&Children, With<SpeedPanel>>,
    mut nodes: Query<&mut ImageNode>,
) {
    match **game_speed {
        GameSpeed::Paused { previous } => {
            let mut pause = nodes.get_mut(speed_buttons[0]).unwrap();
            pause.color = RED_500.into();
            let mut previous = nodes.get_mut(speed_buttons[previous as usize + 1]).unwrap();
            previous.color = BLUE_500.into();
        }
        GameSpeed::Running { speed } => {
            let mut button = nodes.get_mut(speed_buttons[speed as usize + 1]).unwrap();
            button.color = BLUE_500.into();
        }
    }
}

#[derive(Component)]
struct SpeedPanel;
