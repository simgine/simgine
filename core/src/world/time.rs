pub mod speed;

use std::{
    fmt::{self, Display, Formatter},
    time::Duration,
};

use bevy::prelude::*;
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::{state::GameState, world::CreateWorld};

pub(super) fn plugin(app: &mut App) {
    app.add_plugins(speed::plugin)
        .replicate_resource::<Clock>()
        .replicate_resource::<MinuteCarry>()
        .replicate_resource::<Weekday>()
        .add_observer(create_world)
        .add_systems(
            PreUpdate,
            tick.run_if(in_state(GameState::World))
                .run_if(not(in_state(ClientState::Connected))),
        );
}

fn create_world(_on: On<CreateWorld>, mut commands: Commands) {
    commands.insert_resource(Clock::default());
    commands.insert_resource(MinuteCarry::default());
    commands.insert_resource(Weekday::default());
}

const SECS_PER_MIN: u64 = 2;
pub(crate) const SECS_PER_DAY: u64 = 24 * 60 * SECS_PER_MIN;

fn tick(
    mut commands: Commands,
    time: Res<Time>,
    weekday: Res<Weekday>,
    clock: Res<Clock>,
    mut carry: ResMut<MinuteCarry>,
) {
    **carry += time.delta();

    let minutes = carry.as_secs() / SECS_PER_MIN;
    if minutes == 0 {
        return;
    }
    let consumed = minutes * SECS_PER_MIN;
    **carry -= Duration::from_secs(consumed);

    let mut current_weekday = *weekday;
    let mut hour = clock.hour as u64;
    let mut minute = clock.minute as u64 + minutes;
    if minute >= 60 {
        hour += minute / 60;
        minute %= 60;
    }
    if hour >= 24 {
        current_weekday.advance(hour / 24);
        hour %= 24;
    }
    let current_clock = Clock {
        hour: hour as u8,
        minute: minute as u8,
    };

    commands.insert_resource_if_neq(current_weekday);
    commands.insert_resource_if_neq(current_clock);
}

#[derive(Resource, Reflect, Deref, DerefMut, Default, Serialize, Deserialize)]
#[reflect(Resource)]
#[require(DespawnOnExit::<_>(GameState::World))]
pub(crate) struct MinuteCarry(Duration);

#[derive(Resource, Reflect, Default, Serialize, Deserialize, PartialEq, Eq, Clone, Copy)]
#[component(immutable)]
#[reflect(Resource)]
#[require(DespawnOnExit::<_>(GameState::World))]
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
    fn advance(&mut self, days: u64) {
        *self = match (*self as u64 + days) % 7 {
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

impl Display for Weekday {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        let name = match self {
            Weekday::Mon => "Mon",
            Weekday::Tue => "Tue",
            Weekday::Wed => "Wed",
            Weekday::Thu => "Thu",
            Weekday::Fri => "Fri",
            Weekday::Sat => "Sat",
            Weekday::Sun => "Sun",
        };
        f.write_str(name)
    }
}

#[derive(Resource, Reflect, Serialize, Deserialize, PartialEq, Clone, Copy)]
#[component(immutable)]
#[reflect(Resource)]
#[require(DespawnOnExit::<_>(GameState::World))]
pub struct Clock {
    hour: u8,
    minute: u8,
}

impl Clock {
    pub(crate) fn secs_since_midnight(&self) -> u64 {
        let mins = self.hour as u64 * 60 + self.minute as u64;
        mins * SECS_PER_MIN
    }
}

impl Default for Clock {
    fn default() -> Self {
        Self {
            hour: 13,
            minute: 0,
        }
    }
}

impl Display for Clock {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{:02}:{:02}", self.hour, self.minute)
    }
}
