@tool
class_name MHNativePose
extends Resource
## A predefined character pose.
##
## Imported from pose JSON. Can be used as a reference pose.
## See also [MHPose] for a pose retargeted to a [SkeletonProfile].

## Associated rig.
@export var rig: MHRig

## Maps bones to rotations.
##
## Missing entries leave a bone in its rest orientation.
@export var rotations: Dictionary[StringName, Quaternion]


## Bakes native rotations into [param bone_map]'s profile space.
##
## Evaluates every source ancestor so unmapped intermediate bones are not lost.
func retarget(bone_map: BoneMap, reference_pose: MHNativePose = null) -> MHPose:
	if reference_pose and reference_pose.rig != rig:
		push_error("The reference pose must use the same source rig")
		return null

	var native_rests: Array[Basis]
	var posed_bases: Array[Basis]
	var reference_bases: Array[Basis]
	for bone in rig.bones:
		var native_rest := bone.get_rest_basis()

		var local_rest := native_rest
		if bone.parent_index >= 0:
			local_rest = native_rests[bone.parent_index].inverse() * native_rest
		native_rests.append(native_rest)

		var posed_basis := local_rest * Basis(rotations.get(bone.name, Quaternion.IDENTITY))
		var reference_basis := local_rest
		if reference_pose:
			reference_basis *= Basis(reference_pose.rotations.get(bone.name, Quaternion.IDENTITY))
		if bone.parent_index >= 0:
			posed_basis = posed_bases[bone.parent_index] * posed_basis
			reference_basis = reference_bases[bone.parent_index] * reference_basis
		posed_bases.append(posed_basis)
		reference_bases.append(reference_basis)

	var pose := MHPose.new()
	var profile := bone_map.profile
	pose.profile = profile
	var profile_bases := get_profile_bases(profile)
	var retargeted_bases: Dictionary[StringName, Basis]
	var mapped_names: Dictionary[StringName, bool]
	var bone_indices := rig.get_bone_indices()
	for profile_index in profile.bone_size:
		var profile_name := profile.get_bone_name(profile_index)
		var parent_name := profile.get_bone_parent(profile_index)

		var source_name := bone_map.get_skeleton_bone_name(profile_name)
		if source_name:
			if not bone_indices.has(source_name):
				push_error("BoneMap source bone '%s' is missing from the rig" % source_name)
				return null
			if mapped_names.has(source_name):
				push_error("BoneMap source bone '%s' is mapped more than once" % source_name)
				return null
			mapped_names[source_name] = true

			var ancestor_name := _find_mapped_ancestor(bone_map, profile, parent_name)
			if ancestor_name:
				var ancestor_index := bone_indices[ancestor_name]
				var source_index := rig.bones[bone_indices[source_name]].parent_index
				while source_index >= 0 and source_index != ancestor_index:
					source_index = rig.bones[source_index].parent_index
				if source_index < 0:
					push_error("BoneMap hierarchy is incompatible at '%s'" % profile_name)
					return null
		elif profile.is_required(profile_index):
			push_error("BoneMap is missing required bone '%s'" % profile_name)
			return null

		var parent_basis := Basis.IDENTITY
		if parent_name:
			parent_basis = retargeted_bases[parent_name]

		var retargeted_basis := parent_basis * profile.get_reference_pose(profile_index).basis
		if source_name:
			var source_index := bone_indices[source_name]
			retargeted_basis = (
				posed_bases[source_index] * reference_bases[source_index].inverse()
				* profile_bases[profile_name]
			)
		retargeted_bases[profile_name] = retargeted_basis
		pose.rotations[profile_name] = (
			(parent_basis.inverse() * retargeted_basis).orthonormalized().get_rotation_quaternion()
		)

	if mapped_names.is_empty():
		push_error("BoneMap must map at least one source bone")
		return null

	return pose


static func get_profile_bases(profile: SkeletonProfile) -> Dictionary[StringName, Basis]:
	var bases: Dictionary[StringName, Basis]
	for profile_index in profile.bone_size:
		var global_basis := profile.get_reference_pose(profile_index).basis
		var parent_name := profile.get_bone_parent(profile_index)
		if parent_name:
			global_basis = bases[parent_name] * global_basis
		bases[profile.get_bone_name(profile_index)] = global_basis

	return bases


## Climbs the profile parent chain from [param profile_name] and returns the
## source bone name of the nearest mapped ancestor, or an empty [StringName]
## when none is mapped.
##
## Intermediate profile bones can be unmapped. The hierarchy check must target
## the closest mapped ancestor, and a source bone outside its subtree would
## silently bake in an incorrect offset.
static func _find_mapped_ancestor(
	bone_map: BoneMap,
	profile: SkeletonProfile,
	profile_name: StringName,
) -> StringName:
	while profile_name:
		var skeleton_name := bone_map.get_skeleton_bone_name(profile_name)
		if skeleton_name:
			return skeleton_name
		profile_name = profile.get_bone_parent(profile.find_bone(profile_name))

	return ""
