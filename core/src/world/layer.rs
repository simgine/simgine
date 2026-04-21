use avian3d::prelude::*;

#[derive(PhysicsLayer, Default, Debug, Clone, Copy)]
pub(crate) enum GameLayer {
    #[default]
    Default,
    Ground,
    Object,
    Preview,
}
