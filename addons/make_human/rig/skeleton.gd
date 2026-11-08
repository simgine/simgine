@tool
class_name MHSkeleton
extends Skeleton3D

## Temporary storage for moving bones out during scene saving.
##
## By default, bones are serialized, and it's not possible to disable
## this via `_validate_property()`. Since MakeHuman bones are
## generated from JSON at runtime, they don't need to be serialized.
## To work around this they're temporarily removed before saving and
## restored immediately afterwards.
var _bone_snapshots: Array[BoneSnapshot]

## Profile used to build the current skeleton.
var _profile: SkeletonProfile

## Distance from the head of spine05 to the tail of spine01 on the current body.
##
## Set to 0 when the rig has no such bones (no translation scaling).
var _spine_length: float

## Distance between the tails of shoulder01.L and shoulder01.R on the current body.
##
## Set to 0 when the rig has no such bones (no translation scaling).
var _shoulder_width: float


func _validate_property(property: Dictionary) -> void:
	if property.name == "motion_scale":
		# Derived from the generated skeleton.
		property.usage &= ~PROPERTY_USAGE_STORAGE
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return

	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			_take_bones()
		NOTIFICATION_EDITOR_POST_SAVE:
			_restore_bones()


func _take_bones() -> void:
	for bone_idx in get_bone_count():
		var snapshot := BoneSnapshot.new()
		snapshot.name = get_bone_name(bone_idx)
		snapshot.parent = get_bone_parent(bone_idx)
		snapshot.rest = get_bone_rest(bone_idx)
		snapshot.pose = get_bone_pose(bone_idx)
		snapshot.enabled = is_bone_enabled(bone_idx)
		_bone_snapshots.push_back(snapshot)

	clear_bones()


func _restore_bones() -> void:
	assert(get_bone_count() == 0)

	for bone in _bone_snapshots:
		add_bone(bone.name)

	for idx in _bone_snapshots.size():
		var bone := _bone_snapshots[idx]
		set_bone_parent(idx, bone.parent)
		set_bone_rest(idx, bone.rest)
		set_bone_pose(idx, bone.pose)
		set_bone_enabled(idx, bone.enabled)

	_bone_snapshots.clear()


## Rebuilds bones for the body vertices and returns the matching [Skin].
##
## Bone rest transforms are first resolved in global skeleton space, then
## converted to parent-relative rests required by [Skeleton3D].
##
## Applies [param reference_pose], if provided, and adapts mapped bone names and
## axes to [member BoneMap.profile] when [param bone_map] is set.
## The returned skin accounts for these changes.
## The skeleton keeps the rig's bone order and parent hierarchy, so skinning
## built from the rig applies directly.
func rebuild(
	rig: MHRig,
	vertex_groups: MHVertexGroups,
	body_vertices: PackedVector3Array,
	reference_pose: MHNativePose = null,
	bone_map: BoneMap = null,
) -> Skin:
	if reference_pose and reference_pose.rig != rig:
		push_error("Skeleton reference pose must be native to the body rig")
		return null

	clear_bones()
	_profile = bone_map.profile if bone_map else null
	_update_proportions(rig, body_vertices, vertex_groups)

	var reference_shoulder_scale := 1.0
	var reference_spine_scale := 1.0
	if reference_pose:
		reference_shoulder_scale = _proportion_scale(
			_shoulder_width,
			reference_pose.original_shoulder_width,
		)
		reference_spine_scale = _proportion_scale(
			_spine_length,
			reference_pose.original_spine_length,
		)

	# Rigs are parent-first, so a parent is added before any of its children.
	var inv_global_rests: Array[Transform3D]
	inv_global_rests.resize(rig.bones.size())

	for bone_name in rig.bones:
		var bone := rig.bones[bone_name]
		var skeleton_name := bone_name
		if bone_map:
			var mapped_name := bone_map.find_profile_bone_name(bone_name)
			if mapped_name:
				skeleton_name = mapped_name
		var bone_index := add_bone(skeleton_name)

		var global_rest := bone.resolve_global_rest(body_vertices, vertex_groups)
		var rest := global_rest
		if bone.parent_name:
			var parent_name := bone.parent_name
			if bone_map:
				var mapped_parent := bone_map.find_profile_bone_name(bone.parent_name)
				if mapped_parent:
					parent_name = mapped_parent
			var parent_index := find_bone(parent_name)
			set_bone_parent(bone_index, parent_index)
			rest = inv_global_rests[parent_index] * global_rest

		inv_global_rests[bone_index] = global_rest.affine_inverse()
		if reference_pose:
			var pose_rotation: Quaternion = reference_pose.rotations.get(
				bone_name,
				Quaternion.IDENTITY,
			)
			var pose_translation: Vector3 = reference_pose.translations.get(bone_name, Vector3.ZERO)
			if not pose_translation.is_zero_approx():
				# Native armature space is Z-up, so its horizontal axes are X/Y.
				pose_translation = Vector3(
					pose_translation.x * reference_shoulder_scale,
					pose_translation.y * reference_shoulder_scale,
					pose_translation.z * reference_spine_scale,
				)
			rest *= Transform3D(Basis(pose_rotation), pose_translation)
		set_bone_rest(bone_index, rest)

	var skin := _build_skin(inv_global_rests)
	_update_motion_scale()
	reset_bone_poses()
	notify_property_list_changed()

	return skin


## Measures this body's spine and shoulder proportions for scaling pose
## translations.
func _update_proportions(
	rig: MHRig,
	body_vertices: PackedVector3Array,
	vertex_groups: MHVertexGroups,
) -> void:
	_spine_length = 0.0
	_shoulder_width = 0.0

	var left_shoulder: MHBone = rig.bones.get("shoulder01.L")
	var right_shoulder: MHBone = rig.bones.get("shoulder01.R")
	var upper_spine: MHBone = rig.bones.get("spine01")
	var lower_spine: MHBone = rig.bones.get("spine05")

	if left_shoulder and right_shoulder and upper_spine and lower_spine:
		var spine_top := upper_spine.tail.resolve(body_vertices, vertex_groups)
		var spine_bottom := lower_spine.head.resolve(body_vertices, vertex_groups)
		_spine_length = (spine_top - spine_bottom).length()

		var left_tail := left_shoulder.tail.resolve(body_vertices, vertex_groups)
		var right_tail := right_shoulder.tail.resolve(body_vertices, vertex_groups)
		_shoulder_width = (left_tail - right_tail).length()


func _build_skin(inv_global_rests: Array[Transform3D]) -> Skin:
	var profile_bases: Dictionary[StringName, Basis]
	if _profile:
		profile_bases = MHNativePose.get_profile_bases(_profile)

	# Save before changing rests, which would also move their children.
	var reference_rests: Array[Transform3D]
	for bone_index in get_bone_count():
		reference_rests.append(get_bone_global_rest(bone_index))

	# Avoid refreshing Godot's global-rest cache after each rest change.
	var inv_profile_rests: Array[Transform3D]
	inv_profile_rests.resize(get_bone_count())
	var skin := Skin.new()
	for bone_index in get_bone_count():
		var corrected_rest := reference_rests[bone_index]
		var bone_name := get_bone_name(bone_index)
		if _profile and bone_name == _profile.root_bone:
			# The profile expects its root at the model origin.
			corrected_rest.origin = Vector3.ZERO

		# Keep the joint position, but use the profile's axes.
		var profile_rest := corrected_rest
		profile_rest.basis = profile_bases.get(bone_name, profile_rest.basis)

		var inv_profile_rest := profile_rest.affine_inverse()
		inv_profile_rests[bone_index] = inv_profile_rest

		# Godot stores each rest relative to its parent.
		var rest := profile_rest
		var parent_index := get_bone_parent(bone_index)
		if parent_index >= 0:
			rest = inv_profile_rests[parent_index] * profile_rest
		set_bone_rest(bone_index, rest)

		# Build mesh-to-bone bindings that include the reference pose and compensate
		# for the changed bone axes.
		var bind_pose := inv_profile_rest * corrected_rest * inv_global_rests[bone_index]
		skin.add_bind(bone_index, bind_pose)

	return skin


## Use this character's Hips height to scale positions imported with
## "Normalize Position Tracks", so animation movement matches its size.
func _update_motion_scale() -> void:
	motion_scale = 1.0
	if not _profile:
		return

	var hips_index := find_bone(_profile.scale_base_bone)
	if hips_index >= 0:
		var hips_height := get_bone_global_rest(hips_index).origin.y
		if not is_zero_approx(hips_height):
			motion_scale = absf(hips_height)


## Applies a baked profile-space pose directly, without runtime retargeting.
##
## Missing optional target bones are skipped. Invalid poses leave the current pose unchanged.
## Playing an animation or rebuilding the skeleton resets the pose.
func set_pose(pose: MHPose) -> void:
	if _profile != pose.profile:
		push_error("Pose profile does not match the active skeleton profile")
		return

	reset_bone_poses()
	for bone_name in pose.rotations:
		var bone_index := find_bone(bone_name)
		if bone_index >= 0:
			set_bone_pose_rotation(bone_index, pose.rotations[bone_name])

	var shoulder_scale := _proportion_scale(_shoulder_width, pose.original_shoulder_width)
	var spine_scale := _proportion_scale(_spine_length, pose.original_spine_length)

	# Rigs are parent-first, so a translated parent was positioned first and its
	# contribution to this bone's displacement is already in place.
	for bone_name in pose.translations:
		var bone_index := find_bone(bone_name)
		if bone_index < 0:
			continue
		var displacement := pose.translations[bone_name]
		var parent_index := get_bone_parent(bone_index)
		if parent_index >= 0:
			displacement -= pose.translations.get(get_bone_name(parent_index), Vector3.ZERO)
			if displacement.is_zero_approx():
				continue
			displacement = _scale_displacement(displacement, shoulder_scale, spine_scale)
			var parent_pose := get_bone_global_pose(parent_index)
			set_bone_pose_position(
				bone_index,
				get_bone_pose_position(bone_index) + parent_pose.basis.inverse() * displacement,
			)
		elif not displacement.is_zero_approx():
			displacement = _scale_displacement(displacement, shoulder_scale, spine_scale)
			set_bone_pose_position(bone_index, get_bone_pose_position(bone_index) + displacement)


## Scales [param original] capture proportion to this skeleton's.
##
## Returns 1 (no scaling) when either proportion is 0: the rig has no bones
## to measure from, or the pose was recorded without capture proportions.
static func _proportion_scale(measured: float, original: float) -> float:
	if measured > 0.0 and original > 0.0001:
		return measured / original

	return 1.0


## Scales a skeleton-space (Y-up) displacement, whose vertical axis is Y, by the
## proportion scales.
static func _scale_displacement(
	displacement: Vector3,
	shoulder_scale: float,
	spine_scale: float,
) -> Vector3:
	return Vector3(
		displacement.x * shoulder_scale,
		displacement.y * spine_scale,
		displacement.z * shoulder_scale,
	)


class BoneSnapshot:
	var name: String
	var parent: int
	var rest: Transform3D
	var pose: Transform3D
	var enabled: bool
