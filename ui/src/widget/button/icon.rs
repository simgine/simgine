use bevy::{asset::AssetPath, prelude::*, ui::UiSystems};

use super::{ButtonStyle, toggled::Toggled};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(load_icon)
        .add_systems(PreUpdate, update_style.after(UiSystems::Focus));
}

fn load_icon(
    insert: On<Insert, ButtonIcon>,
    asset_server: Res<AssetServer>,
    mut buttons: Query<(&mut ImageNode, &ButtonIcon)>,
) {
    let (mut node, icon) = buttons.get_mut(insert.entity).unwrap();
    trace!("loading icon '{}' for `{}`", insert.entity, **icon);
    node.image = asset_server.load(&**icon);
}

fn update_style(
    mut buttons: Query<
        (
            Entity,
            &Interaction,
            &mut ImageNode,
            Option<&ButtonStyle>,
            Option<&Toggled>,
        ),
        (
            Or<(Changed<Interaction>, Changed<Toggled>)>,
            With<ButtonIcon>,
        ),
    >,
) {
    for (entity, interaction, mut node, style_override, toggle) in &mut buttons {
        trace!("changing style for `{entity}` based on `{interaction:?}` and `{toggle:?}`");
        let style = style_override.copied().unwrap_or_default();
        node.color = style.get_color(interaction, toggle);
    }
}

#[derive(Component, Deref)]
#[component(immutable)]
#[require(Button, ImageNode)]
pub(crate) struct ButtonIcon(pub(crate) AssetPath<'static>);

impl ButtonIcon {
    pub(crate) fn new(path: impl Into<AssetPath<'static>>) -> Self {
        Self(path.into())
    }
}
