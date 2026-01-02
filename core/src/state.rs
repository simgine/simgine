use bevy::prelude::*;

pub(super) fn plugin(app: &mut App) {
    app.init_state::<GameState>()
        .add_sub_state::<FamilyMode>()
        .add_sub_state::<BuildingMode>();
}

#[derive(States, Default, Debug, PartialEq, Eq, Hash, Clone)]
#[states(state_scoped = true)]
pub enum GameState {
    #[default]
    ManifestsLoading,
    InGame,
}

#[derive(SubStates, Default, Debug, PartialEq, Eq, Hash, Clone, Copy)]
#[source(GameState = GameState::InGame)]
#[states(state_scoped = true)]
pub enum FamilyMode {
    #[default]
    Life,
    Building,
}

#[derive(SubStates, Default, Debug, PartialEq, Eq, Hash, Clone, Copy)]
#[source(FamilyMode = FamilyMode::Building)]
#[states(state_scoped = true)]
pub enum BuildingMode {
    #[default]
    Objects,
    Walls,
}
