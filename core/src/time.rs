use std::{
    fmt::{self, Display, Formatter},
    time::Duration,
};

use bevy::prelude::*;
use bevy_replicon::prelude::*;
use serde::{Deserialize, Serialize};

use crate::{
    component_res::{ComponentResExt, InsertComponentResExt},
    state::GameState,
};

pub(super) fn plugin(app: &mut App) {
    app.register_resource_component::<Weekday>()
        .register_resource_component::<Clock>()
        .replicate::<Clock>()
        .replicate::<Weekday>()
        .add_systems(
            OnEnter(GameState::World),
            spawn.run_if(not(in_state(ClientState::Connected))),
        )
        .add_systems(
            PreUpdate,
            tick.run_if(in_state(GameState::World))
                .run_if(not(in_state(ClientState::Connected))),
        );
}

fn spawn(mut commands: Commands) {
    commands.spawn(Clock::default());
    commands.spawn(Weekday::default());
}

const SECS_PER_MIN: u64 = 2;
pub(crate) const SECS_PER_DAY: u64 = 24 * 60 * SECS_PER_MIN;

fn tick(
    mut commands: Commands,
    time: Res<Time>,
    weekday: Single<&Weekday>,
    game_clock: Single<(&mut MinuteCarry, &Clock)>,
) {
    let (mut carry, &game_time) = game_clock.into_inner();
    **carry += time.delta();

    let minutes = carry.as_secs() / SECS_PER_MIN;
    if minutes == 0 {
        return;
    }
    let consumed = minutes * SECS_PER_MIN;
    **carry -= Duration::from_secs(consumed);

    let mut current_weekday = **weekday;
    let mut hour = game_time.hour as u64;
    let mut minute = game_time.minute as u64 + minutes;
    if minute >= 60 {
        hour += minute / 60;
        minute %= 60;
    }
    if hour >= 24 {
        current_weekday.advance(hour / 24);
        hour %= 24;
    }
    let current_time = Clock {
        hour: hour as u8,
        minute: minute as u8,
    };

    if current_weekday != **weekday {
        debug!("changing weekday to {current_weekday}");
        commands.insert_component_resource(current_weekday);
    }
    if current_time != game_time {
        debug!("changing time to {current_time}");
        commands.insert_component_resource(current_time);
    }
}

#[derive(Component, Default, Deref, DerefMut)]
pub(crate) struct MinuteCarry(Duration);

#[derive(Component, Default, Serialize, Deserialize, PartialEq, Eq, Clone, Copy)]
#[require(
    Name::new("Weekday"),
    Replicated,
    DespawnOnExit::<_>(GameState::World)
)]
#[component(immutable)]
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

#[derive(Component, Serialize, Deserialize, PartialEq, Clone, Copy)]
#[require(
    Name::new("Clock"),
    Replicated,
    MinuteCarry,
    DespawnOnExit::<_>(GameState::World)
)]
#[component(immutable)]
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
