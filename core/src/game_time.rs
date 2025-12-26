use std::time::Duration;

use bevy::prelude::*;

use crate::GameState;

pub(crate) fn plugin(app: &mut App) {
    app.add_systems(OnEnter(GameState::InGame), load)
        .add_systems(OnExit(GameState::InGame), unload)
        .add_systems(PreUpdate, tick.run_if(in_state(GameState::InGame)));
}

fn load(mut commands: Commands) {
    commands.init_resource::<GameClock>();
    commands.init_resource::<Weekday>();
    commands.init_resource::<Hour>();
    commands.init_resource::<Minute>();
}

fn unload(mut commands: Commands) {
    commands.remove_resource::<GameClock>();
    commands.remove_resource::<Weekday>();
    commands.remove_resource::<Hour>();
    commands.remove_resource::<Minute>();
}

const MINS_PER_DAY: u64 = 24 * 60;
const SECS_PER_GAME_MINUTE: u64 = 2;
const SECS_PER_GAME_DAY: u64 = SECS_PER_GAME_MINUTE * MINS_PER_DAY;

fn tick(
    time: Res<Time>,
    mut clock: ResMut<GameClock>,
    mut weekday: ResMut<Weekday>,
    mut hour: ResMut<Hour>,
    mut minute: ResMut<Minute>,
) {
    clock.elapsed += time.delta();

    let elapsed_mins = clock.elapsed_mins();
    let elapsed_days = elapsed_mins / MINS_PER_DAY;
    let minute_of_day = elapsed_mins % MINS_PER_DAY;

    let current_weekday = Weekday::from_elapsed_days(elapsed_days);
    let current_hour = (minute_of_day / 60) as u8;
    let current_minute = (minute_of_day % 60) as u8;

    weekday.set_if_neq(current_weekday);
    hour.set_if_neq(Hour(current_hour));
    minute.set_if_neq(Minute(current_minute));

    if minute.is_changed() || hour.is_changed() || weekday.is_changed() {
        debug!("time changed: {:?} {:02}:{:02}", *weekday, **hour, **minute)
    }
}

#[derive(Resource)]
pub struct GameClock {
    elapsed: Duration,
}

impl GameClock {
    fn elapsed_mins(&self) -> u64 {
        self.elapsed.as_secs() / SECS_PER_GAME_MINUTE
    }

    pub(crate) fn day_fract(&self) -> f32 {
        let sec_of_day = self.elapsed.as_secs_f32() % SECS_PER_GAME_DAY as f32;
        sec_of_day / SECS_PER_GAME_DAY as f32
    }
}

impl Default for GameClock {
    fn default() -> Self {
        // Mon 13:00
        Self {
            elapsed: Duration::from_secs(13 * 60 * SECS_PER_GAME_MINUTE),
        }
    }
}

#[derive(Resource, Default, Debug, PartialEq, Eq, Clone, Copy)]
pub enum Weekday {
    #[default]
    Mon,
    Tue,
    Wed,
    Thu,
    Fri,
    Sat,
    Sun,
}

impl Weekday {
    fn from_elapsed_days(elapsed_days: u64) -> Self {
        match elapsed_days % 7 {
            0 => Weekday::Mon,
            1 => Weekday::Tue,
            2 => Weekday::Wed,
            3 => Weekday::Thu,
            4 => Weekday::Fri,
            5 => Weekday::Sat,
            6 => Weekday::Sun,
            _ => unreachable!(),
        }
    }
}

#[derive(Resource, Deref, Default, PartialEq)]
pub struct Hour(u8);

#[derive(Resource, Deref, Default, PartialEq)]
pub struct Minute(u8);
