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

## Maps bones to local translations.
##
## When applied, the bone and its subtree are displaced by the offset
## relative to their positions without the translations.
##
## Missing entries leave a bone in its rest position.
## Typically only present for root bones and IK control bones.
@export var translations: Dictionary[StringName, Vector3]


## Bakes native rotations and translations into [param bone_map]'s profile space.
##
## Evaluates every source ancestor so unmapped intermediate bones are not lost.
func retarget(bone_map: BoneMap, reference_pose: MHNativePose = null) -> MHPose:
	if reference_pose and reference_pose.rig != rig:
		push_error("The reference pose must use the same source rig")
		return null

	var native_rests: Dictionary[StringName, Basis]
	var posed_bases: Dictionary[StringName, Basis]
	var reference_bases: Dictionary[StringName, Basis]
	var posed_deltas: Dictionary[StringName, Vector3]
	var reference_deltas: Dictionary[StringName, Vector3]
	for bone_name in rig.bones:
		var bone := rig.bones[bone_name]
		var native_rest := bone.get_rest_basis()

		var local_rest := native_rest
		if bone.parent_name:
			local_rest = native_rests[bone.parent_name].inverse() * native_rest
		native_rests[bone_name] = native_rest

		var posed_basis := local_rest * Basis(rotations.get(bone_name, Quaternion.IDENTITY))
		var reference_basis := local_rest
		var reference_translation := Vector3.ZERO
		if reference_pose:
			reference_basis *= Basis(reference_pose.rotations.get(bone_name, Quaternion.IDENTITY))
			reference_translation = reference_pose.translations.get(bone_name, Vector3.ZERO)
		if bone.parent_name:
			posed_basis = posed_bases[bone.parent_name] * posed_basis
			reference_basis = reference_bases[bone.parent_name] * reference_basis
		posed_bases[bone_name] = posed_basis
		reference_bases[bone_name] = reference_basis

		# Translations accumulate through the posed bases, so the joint
		# displacement of a translated bone carries over to its subtree.
		var posed_translation: Vector3 = translations.get(bone_name, Vector3.ZERO)
		var posed_delta := local_rest * posed_translation
		var reference_delta := local_rest * reference_translation
		if bone.parent_name:
			posed_delta = (
				posed_bases[bone.parent_name] * posed_delta + posed_deltas[bone.parent_name]
			)
			reference_delta = (
				reference_bases[bone.parent_name] * reference_delta
				+ reference_deltas[bone.parent_name]
			)
		posed_deltas[bone_name] = posed_delta
		reference_deltas[bone_name] = reference_delta

	var pose := MHPose.new()
	var profile := bone_map.profile
	pose.profile = profile
	var profile_bases := get_profile_bases(profile)
	var retargeted_bases: Dictionary[StringName, Basis]
	var mapped_names: Dictionary[StringName, bool]
	for profile_index in profile.bone_size:
		var profile_name := profile.get_bone_name(profile_index)
		var parent_name := profile.get_bone_parent(profile_index)

		var source_name := bone_map.get_skeleton_bone_name(profile_name)
		if source_name:
			if not rig.bones.has(source_name):
				push_error("BoneMap source bone '%s' is missing from the rig" % source_name)
				return null
			if mapped_names.has(source_name):
				push_error("BoneMap source bone '%s' is mapped more than once" % source_name)
				return null
			mapped_names[source_name] = true

			var ancestor_name := _find_mapped_ancestor(bone_map, profile, parent_name)
			if ancestor_name:
				var source := source_name
				while source and source != ancestor_name:
					source = rig.bones[source].parent_name
				if not source:
					push_error("BoneMap hierarchy is incompatible at '%s'" % profile_name)
					return null
		elif profile.is_required(profile_index):
			push_error("BoneMap is missing required bone '%s'" % profile_name)
			return null

		var parent_basis := Basis.IDENTITY
		if parent_name:
			parent_basis = retargeted_bases[parent_name]

		var delta := Vector3.ZERO
		var retargeted_basis := parent_basis * profile.get_reference_pose(profile_index).basis
		if source_name:
			retargeted_basis = (
				posed_bases[source_name] * reference_bases[source_name].inverse()
				* profile_bases[profile_name]
			)
			var has_translation := translations.has(source_name)
			if not has_translation and reference_pose:
				has_translation = reference_pose.translations.has(source_name)
			if has_translation:
				delta = posed_deltas[source_name] - reference_deltas[source_name]

		retargeted_bases[profile_name] = retargeted_basis
		pose.rotations[profile_name] = (
			(parent_basis.inverse() * retargeted_basis).orthonormalized().get_rotation_quaternion()
		)
		if delta != Vector3.ZERO:
			pose.translations[profile_name] = delta

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
