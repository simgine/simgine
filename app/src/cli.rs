use bevy::prelude::*;
use clap::{Parser, Subcommand};
use simgine_core::{state::GameState, world::LoadWorld};

/// Logic for command line interface.
///
/// [`Cli`] should be initialized early to avoid creating
/// a window for commands like `--help` or `--version`.
pub(super) fn plugin(app: &mut App) {
    app.init_resource::<Cli>()
        .add_systems(OnEnter(GameState::Menu), apply_command);
}

fn apply_command(mut commands: Commands, mut cli: ResMut<Cli>) {
    let Some(command) = cli.command.take() else {
        return;
    };

    match command {
        GameCommand::Load { name } => commands.trigger(LoadWorld { name }),
    }
}

#[derive(Resource, Clone, Parser)]
#[command(author, version, about)]
pub(crate) struct Cli {
    /// Game command to run.
    #[command(subcommand)]
    command: Option<GameCommand>,
}

impl Default for Cli {
    fn default() -> Self {
        Self::parse()
    }
}

#[derive(Subcommand, Clone)]
enum GameCommand {
    Load { name: String },
}
