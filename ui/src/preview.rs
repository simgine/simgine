use bevy::{
    asset::RecursiveDependencyLoadState,
    camera::{
        RenderTarget,
        primitives::{Aabb, Sphere},
        visibility::{NoFrustumCulling, RenderLayers},
    },
    color::palettes::tailwind::GRAY_400,
    light::light_consts::lux,
    pbr::wireframe::NoWireframe,
    prelude::*,
    render::render_resource::TextureFormat,
    scene,
};
use simgine_core::asset_manifest::ObjectManifest;

pub(super) fn plugin(app: &mut App) {
    app.init_state::<PreviewState>()
        .add_systems(Startup, setup)
        .add_systems(OnEnter(PreviewState::Inactive), despawn_scene)
        .add_systems(OnEnter(PreviewState::Warmup), warmup)
        .add_systems(OnEnter(PreviewState::Rendering), render)
        .add_systems(
            SpawnScene,
            wait_for_request
                .before(scene::scene_spawner_system)
                .run_if(in_state(PreviewState::Inactive)),
        )
        .add_systems(
            PostUpdate,
            wait_for_loading
                .after(TransformSystems::Propagate) // To properly calculate AABB.
                .run_if(in_state(PreviewState::LoadingAsset)),
        );
}

fn setup(mut commands: Commands) {
    const YAW: f32 = 35.0_f32.to_radians();
    const PITCH: f32 = 50.0_f32.to_radians();

    commands.spawn(PreviewCamera);
    commands.spawn((
        Name::new("Preview light"),
        PREVIEW_RENDER_LAYER,
        DirectionalLight {
            illuminance: lux::FULL_DAYLIGHT,
            shadows_enabled: true,
            ..Default::default()
        },
        Transform::from_rotation(Quat::from_euler(EulerRot::YXZ, YAW, -PITCH, 0.0)),
    ));
}

fn wait_for_request(
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    manifests: Res<Assets<ObjectManifest>>,
    previews: Query<(Entity, &Preview, Has<CalculatedClip>), Without<PreviewProcessed>>,
) {
    // Check for `CalculatedClip` to make sure that the preview node is visible.
    let Some((target, &preview, ..)) = previews.iter().find(|&(.., c)| !c) else {
        return;
    };

    let manifest = manifests
        .get(*preview)
        .expect("manifests should be preloaded");
    debug!("spawning scene '{:?}'", manifest.scene);
    let scene = asset_server.load(manifest.scene.clone()).into();

    commands.entity(target).insert(PreviewProcessed);
    commands.spawn((
        Name::new("Preview target"),
        PREVIEW_RENDER_LAYER,
        PreviewTarget(target),
        SceneRoot(scene),
    ));

    commands.set_state(PreviewState::LoadingAsset);
}

fn wait_for_loading(
    mut commands: Commands,
    mut images: ResMut<Assets<Image>>,
    asset_server: Res<AssetServer>,
    scene: Single<(Entity, &PreviewTarget, &SceneRoot)>,
    camera: Single<(&mut RenderTarget, &mut Transform, &Projection), With<PreviewCamera>>,
    nodes: Query<&Node>,
    children: Query<&Children>,
    meshes: Query<(Entity, &Aabb, &GlobalTransform)>,
) {
    let (scene_entity, &preview_target, scene) = *scene;
    match asset_server.recursive_dependency_load_state(&**scene) {
        RecursiveDependencyLoadState::Loaded => {
            let Ok(node) = nodes.get(*preview_target) else {
                debug!("preview target is no longer valid");
                commands.set_state(PreviewState::Inactive);
                return;
            };

            let (Val::Px(width), Val::Px(height)) = (node.width, node.height) else {
                panic!("width and height should be set in pixels");
            };

            debug!("creating preview {width}x{height} for loaded scene");
            let image = images.add(Image::new_target_texture(
                width as u32,
                height as u32,
                TextureFormat::Rgba8Unorm,
                Some(TextureFormat::Rgba8UnormSrgb),
            ));

            let (mut render_target, mut camera_transform, projection) = camera.into_inner();
            *render_target = RenderTarget::Image(image.into());

            let mut min = Vec3A::splat(f32::MAX);
            let mut max = Vec3A::splat(f32::MIN);
            for (child_entity, aabb, transform) in
                meshes.iter_many(children.iter_descendants(scene_entity))
            {
                commands.entity(child_entity).insert((
                    PREVIEW_RENDER_LAYER,
                    NoFrustumCulling,
                    NoWireframe,
                ));

                // Convert `Aabb` into global space.
                let sphere = Sphere {
                    center: Vec3A::from(transform.transform_point(Vec3::from(aabb.center))),
                    radius: transform.radius_vec3a(aabb.half_extents),
                };
                let aabb = Aabb::from(sphere);
                min = min.min(aabb.min());
                max = max.max(aabb.max());
            }

            let aabb = Aabb::from_min_max(min.to_vec3(), max.to_vec3());
            let center = aabb.center.to_vec3();
            let radius = aabb.half_extents.length();
            let fov = match projection {
                Projection::Perspective(p) => p.fov,
                _ => unreachable!("preview camera should be perspective"),
            };

            const PADDING: f32 = 1.2;
            let distance = radius / (fov / 2.0).tan() * PADDING;

            let view_dir = Vec3::new(0.75, 0.5, 0.75).normalize();
            camera_transform.translation = center + view_dir * distance;
            camera_transform.look_at(center, Vec3::Y);

            commands.set_state(PreviewState::Warmup);
        }
        RecursiveDependencyLoadState::Failed(e) => {
            error!("unable to load asset: {e:#}");
            commands.set_state(PreviewState::Inactive);
        }
        RecursiveDependencyLoadState::NotLoaded | RecursiveDependencyLoadState::Loading => (),
    }
}

/// Waits one frame for camera transform and components like [`NoWireframe`] to take effect.
fn warmup(mut commands: Commands) {
    debug!("warming up");
    commands.set_state(PreviewState::Rendering);
}

fn render(mut commands: Commands, mut camera: Single<&mut Camera, With<PreviewCamera>>) {
    debug!("starting rendering");
    camera.is_active = true;
    commands.set_state(PreviewState::Inactive);
}

fn despawn_scene(
    mut commands: Commands,
    camera: Single<(&mut Camera, &RenderTarget), With<PreviewCamera>>,
    scene: Single<(Entity, &PreviewTarget)>,
    mut nodes: Query<&mut ImageNode>,
) {
    let (mut camera, render_target) = camera.into_inner();
    camera.is_active = false;

    let (entity, &preview_target) = *scene;
    if let Ok(mut node) = nodes.get_mut(*preview_target) {
        debug!("assigning image to node");
        let image = render_target
            .as_image()
            .expect("preview camera should render only to images");
        node.image = image.clone();
    } else {
        debug!("preview target is no longer valid");
    }

    commands.entity(entity).despawn();
}

const PREVIEW_RENDER_LAYER: RenderLayers = RenderLayers::layer(1);

#[derive(Clone, Copy, Debug, Default, Eq, Hash, PartialEq, States)]
enum PreviewState {
    #[default]
    Inactive,
    LoadingAsset,
    Warmup,
    Rendering,
}

/// Specifies preview that should be generated for specific actor in the world or for an object by its manifest.
///
/// Generated image handle will be written to the image handle on this entity.
/// Preview generation happens only if UI element entity is visible.
/// Processed entities will be marked with [`PreviewProcessed`].
#[derive(Component, Deref, Clone, Copy)]
#[require(ImageNode)]
pub(crate) struct Preview(pub(crate) AssetId<ObjectManifest>);

/// Marks entity with [`Preview`] as processed end excludes it from preview generation.
#[derive(Component)]
struct PreviewProcessed;

/// Marker for preview camera.
#[derive(Component)]
#[require(
    Name::new("Preview camera"),
    RenderLayers = PREVIEW_RENDER_LAYER,
    Camera3d,
    RenderTarget::from(Handle::<Image>::default()),
    Msaa::Sample8,
    Camera {
        order: -1,
        is_active: false,
        clear_color: ClearColorConfig::Custom(GRAY_400.into()),
        ..Default::default()
    },
)]
struct PreviewCamera;

/// Points to the entity for which the preview will be generated.
#[derive(Component, Deref, Clone, Copy)]
struct PreviewTarget(Entity);
