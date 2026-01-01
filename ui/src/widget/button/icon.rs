use bevy::{asset::AssetPath, prelude::*};

pub(super) fn plugin(app: &mut App) {
    app.add_observer(load_icon);
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

#[derive(Component, Deref)]
#[component(immutable)]
#[require(Button, ImageNode)]
pub(crate) struct ButtonIcon(pub(crate) AssetPath<'static>);

impl ButtonIcon {
    pub(crate) fn new(path: impl Into<AssetPath<'static>>) -> Self {
        Self(path.into())
    }
}
