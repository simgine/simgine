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
use simgine_core::asset_manifest::object::ObjectManifest;

pub(super) fn plugin(app: &mut App) {
    app.init_state::<ThumbnailState>()
        .add_systems(Startup, setup)
        .add_systems(OnEnter(ThumbnailState::Inactive), despawn_scene)
        .add_systems(OnEnter(ThumbnailState::Warmup), warmup)
        .add_systems(OnEnter(ThumbnailState::Rendering), render)
        .add_systems(
            SpawnScene,
            wait_for_request
                .before(scene::scene_spawner_system)
                .run_if(in_state(ThumbnailState::Inactive)),
        )
        .add_systems(
            PostUpdate,
            wait_for_loading
                .after(TransformSystems::Propagate) // To properly calculate AABB.
                .run_if(in_state(ThumbnailState::LoadingAsset)),
        );
}

fn setup(mut commands: Commands) {
    const YAW: f32 = 35.0_f32.to_radians();
    const PITCH: f32 = 50.0_f32.to_radians();

    commands.spawn((
        Name::new("Thumbnail camera"),
        ThumbnailCamera,
        THUMBNAIL_RENDER_LAYER,
        Camera3d::default(),
        RenderTarget::from(Handle::<Image>::default()),
        Msaa::Sample8,
        Camera {
            order: -1,
            is_active: false,
            clear_color: ClearColorConfig::Custom(GRAY_400.into()),
            ..Default::default()
        },
    ));
    commands.spawn((
        Name::new("Thumbnail light"),
        THUMBNAIL_RENDER_LAYER,
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
    thumbnails: Query<(Entity, &Thumbnail, Has<CalculatedClip>), Without<ThumbnailProcessed>>,
) {
    // Check for `CalculatedClip` to make sure that the thumbnail node is visible.
    let Some((target, &thumbnail, ..)) = thumbnails.iter().find(|&(.., c)| !c) else {
        return;
    };

    let manifest = manifests
        .get(*thumbnail)
        .expect("manifests should be preloaded");
    debug!("spawning scene '{:?}'", manifest.scene);
    let scene = asset_server.load(manifest.scene.clone());

    commands.entity(target).insert(ThumbnailProcessed);
    commands.spawn((
        Name::new("Thumbnail target"),
        THUMBNAIL_RENDER_LAYER,
        ThumbnailOf(target),
        SceneRoot(scene),
    ));

    commands.set_state(ThumbnailState::LoadingAsset);
}

fn wait_for_loading(
    mut commands: Commands,
    mut images: ResMut<Assets<Image>>,
    asset_server: Res<AssetServer>,
    scene: Single<(Entity, &ThumbnailOf, &SceneRoot)>,
    camera: Single<(&mut RenderTarget, &mut Transform, &Projection), With<ThumbnailCamera>>,
    nodes: Query<&Node>,
    children: Query<&Children>,
    meshes: Query<(Entity, &Aabb, &GlobalTransform)>,
) {
    let (scene_entity, &thumbnail_of, scene) = *scene;
    match asset_server.recursive_dependency_load_state(&**scene) {
        RecursiveDependencyLoadState::Loaded => {
            let Ok(node) = nodes.get(*thumbnail_of) else {
                debug!("thumbnail target is no longer valid");
                commands.set_state(ThumbnailState::Inactive);
                return;
            };

            let (Val::Px(width), Val::Px(height)) = (node.width, node.height) else {
                panic!("width and height should be set in pixels");
            };

            debug!("creating thumbnail {width}x{height} for loaded scene");
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
                    THUMBNAIL_RENDER_LAYER,
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
                _ => unreachable!("thumbnail camera should be perspective"),
            };

            const PADDING: f32 = 1.2;
            let distance = radius / (fov / 2.0).tan() * PADDING;

            let view_dir = Vec3::new(0.75, 0.5, 0.75).normalize();
            camera_transform.translation = center + view_dir * distance;
            camera_transform.look_at(center, Vec3::Y);

            commands.set_state(ThumbnailState::Warmup);
        }
        RecursiveDependencyLoadState::Failed(e) => {
            error!("unable to load asset: {e:#}");
            commands.set_state(ThumbnailState::Inactive);
        }
        RecursiveDependencyLoadState::NotLoaded | RecursiveDependencyLoadState::Loading => (),
    }
}

/// Waits one frame for camera transform and components like [`NoWireframe`] to take effect.
fn warmup(mut commands: Commands) {
    debug!("warming up");
    commands.set_state(ThumbnailState::Rendering);
}

fn render(mut commands: Commands, mut camera: Single<&mut Camera, With<ThumbnailCamera>>) {
    debug!("starting rendering");
    camera.is_active = true;
    commands.set_state(ThumbnailState::Inactive);
}

fn despawn_scene(
    mut commands: Commands,
    camera: Single<(&mut Camera, &RenderTarget), With<ThumbnailCamera>>,
    scene: Single<(Entity, &ThumbnailOf)>,
    mut nodes: Query<&mut ImageNode>,
) {
    let (mut camera, render_target) = camera.into_inner();
    camera.is_active = false;

    let (entity, &thumbnail_of) = *scene;
    if let Ok(mut node) = nodes.get_mut(*thumbnail_of) {
        debug!("assigning image to node");
        let image = render_target
            .as_image()
            .expect("thumbnail camera should render only to images");
        node.image = image.clone();
    } else {
        debug!("thumbnail target is no longer valid");
    }

    commands.entity(entity).despawn();
}

const THUMBNAIL_RENDER_LAYER: RenderLayers = RenderLayers::layer(1);

#[derive(Clone, Copy, Debug, Default, Eq, Hash, PartialEq, States)]
enum ThumbnailState {
    #[default]
    Inactive,
    LoadingAsset,
    Warmup,
    Rendering,
}

/// Specifies thumbnail that should be generated for specific actor in the world or for an object by its manifest.
///
/// Generated image handle will be written to the image handle on this entity.
/// Thumbnail generation happens only if UI element entity is visible.
/// Processed entities will be marked with [`ThumbnailProcessed`].
#[derive(Component, Deref, Clone, Copy)]
#[require(ImageNode)]
pub(crate) struct Thumbnail(pub(crate) AssetId<ObjectManifest>);

/// Marks entity with [`Thumbnail`] as processed end excludes it from thumbnail generation.
#[derive(Component)]
struct ThumbnailProcessed;

/// Marker for thumbnail camera.
#[derive(Component)]
struct ThumbnailCamera;

/// Points to the entity for which the thumbnail will be generated.
#[derive(Component, Deref, Clone, Copy)]
struct ThumbnailOf(Entity);
