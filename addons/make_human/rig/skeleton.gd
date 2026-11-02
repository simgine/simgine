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

## Original MakeHuman rests expressed in the humanoid parent's rest space.
var _mh_to_humanoid: Array[Transform3D]

## Conversions from humanoid bone space to reference-pose bone space.
var _humanoid_to_reference: Array[Transform3D]


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
## Applies [param reference_pose] and adapts bone axes to [SkeletonProfileHumanoid].
## The returned skin accounts for these changes.
func rebuild(
	rig: MHRig,
	vertex_groups: MHVertexGroups,
	body_vertices: PackedVector3Array,
	reference_pose: MHPose,
) -> Skin:
	clear_bones()

	_mh_to_humanoid.resize(rig.bones.size())

	var inv_global_rests: Array[Transform3D]
	inv_global_rests.resize(rig.bones.size())

	for bone_index in rig.bones.size():
		var bone := rig.bones[bone_index]
		var added_index := add_bone(bone.name)
		assert(added_index == bone_index)

		var global_rest := bone.resolve_global_rest(body_vertices, vertex_groups)
		var rest := global_rest
		if bone.parent_index >= 0:
			set_bone_parent(bone_index, bone.parent_index)
			rest = inv_global_rests[bone.parent_index] * global_rest

		_mh_to_humanoid[bone_index] = rest
		inv_global_rests[bone_index] = global_rest.affine_inverse()
		var pose_rotation: Quaternion = reference_pose.rotations.get(bone.name, Quaternion.IDENTITY)
		rest.basis *= Basis(pose_rotation)
		set_bone_rest(bone_index, rest)

	var profile := SkeletonProfileHumanoid.new()
	var skin := _adapt_to_humanoid(profile, inv_global_rests)
	_update_motion_scale(profile)
	reset_bone_poses()
	notify_property_list_changed()

	return skin


func _adapt_to_humanoid(profile: SkeletonProfile, inv_global_rests: Array[Transform3D]) -> Skin:
	var profile_bases := _get_profile_bases(profile)

	# Save before changing parents, which would also move their children.
	var reference_rests: Array[Transform3D]
	for bone_index in get_bone_count():
		reference_rests.append(get_bone_global_rest(bone_index))

	_humanoid_to_reference.resize(get_bone_count())

	# Avoid refreshing Godot's global-rest cache after each rest change.
	var inv_humanoid_rests: Array[Transform3D]
	inv_humanoid_rests.resize(get_bone_count())
	var skin := Skin.new()
	for bone_index in get_bone_count():
		var corrected_rest := reference_rests[bone_index]
		var bone_name := get_bone_name(bone_index)
		if bone_name == profile.root_bone:
			# The humanoid profile expects Root at the model origin.
			corrected_rest.origin = Vector3.ZERO

		# Keep the joint position, but use the axes expected by humanoid animations.
		var humanoid_rest := corrected_rest
		humanoid_rest.basis = profile_bases.get(bone_name, humanoid_rest.basis)

		var inv_humanoid_rest := humanoid_rest.affine_inverse()
		inv_humanoid_rests[bone_index] = inv_humanoid_rest

		# Godot stores each rest relative to its parent.
		var rest := humanoid_rest
		var parent_index := get_bone_parent(bone_index)
		if parent_index >= 0:
			rest = inv_humanoid_rests[parent_index] * humanoid_rest
		set_bone_rest(bone_index, rest)

		# Cache the parent correction so posing doesn't need global transforms.
		if parent_index >= 0:
			_mh_to_humanoid[bone_index] = (
				inv_humanoid_rests[parent_index]
				* reference_rests[parent_index] * _mh_to_humanoid[bone_index]
			)
		# Include Root's shift so posing doesn't undo its recentering.
		_humanoid_to_reference[bone_index] = reference_rests[bone_index].affine_inverse() * humanoid_rest

		# Build mesh-to-bone bindings that include the reference pose and compensate
		# for the changed bone axes.
		var bind_pose := inv_humanoid_rest * corrected_rest * inv_global_rests[bone_index]
		skin.add_bind(bone_index, bind_pose)

	return skin


## Use this character's Hips height to scale positions imported with
## "Normalize Position Tracks", so animation movement matches its size.
func _update_motion_scale(profile: SkeletonProfile) -> void:
	motion_scale = 1.0
	var hips_index := find_bone(profile.scale_base_bone)
	if hips_index >= 0:
		var hips_height := get_bone_global_rest(hips_index).origin.y
		if not is_zero_approx(hips_height):
			motion_scale = absf(hips_height)


## Puts the skeleton into [param pose].
##
## Rotations are applied on top of the MakeHuman rest, the same way
## [method rebuild] applies the reference pose. Bones missing from
## [param pose] keep their MakeHuman original orientation.
##
## Playing an animation or skeleton rebuild resets the pose.
func set_pose(pose: MHPose) -> void:
	for bone_index in get_bone_count():
		var bone_name := get_bone_name(bone_index)
		var bone_rotation: Quaternion = pose.rotations.get(bone_name, Quaternion.IDENTITY)

		var local_pose := _mh_to_humanoid[bone_index]
		local_pose.basis *= Basis(bone_rotation)
		set_bone_pose(bone_index, local_pose * _humanoid_to_reference[bone_index])


static func _get_profile_bases(profile: SkeletonProfile) -> Dictionary[StringName, Basis]:
	var reference_bases: Dictionary[StringName, Basis]
	for index in profile.bone_size:
		var reference_basis := profile.get_reference_pose(index).basis
		var parent_name := profile.get_bone_parent(index)
		if parent_name:
			reference_basis = reference_bases[parent_name] * reference_basis
		var bone_name := profile.get_bone_name(index)
		reference_bases[bone_name] = reference_basis
	return reference_bases


class BoneSnapshot:
	var name: String
	var parent: int
	var rest: Transform3D
	var pose: Transform3D
	var enabled: bool
