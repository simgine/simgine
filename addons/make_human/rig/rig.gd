@tool
class_name MHRig
extends Resource
## Defines the native bone hierarchy, saved rest endpoints, and how each bone
## endpoint follows the mesh.
##
## Imported from `rig.*.json`.

## Bones in parent-first order.
@export var bones: Array[MHBone]


func get_bone_indices() -> Dictionary[StringName, int]:
	var indices: Dictionary[StringName, int]
	for bone_index in bones.size():
		indices[bones[bone_index].name] = bone_index
	return indices


## Checks if [param bone_map] can be used with this rig.
func validate_bone_map(bone_map: BoneMap) -> bool:
	var profile := bone_map.profile
	if not profile:
		push_error("Bone map requires a profile")
		return false

	var target_names: Dictionary[StringName, bool]
	for bone in bones:
		var mapped_name := bone_map.find_profile_bone_name(bone.name)
		if not mapped_name:
			if profile.find_bone(bone.name) >= 0:
				push_error("Unmapped bone uses a profile bone name: %s" % bone.name)
				return false
			continue

		var target_name := mapped_name if mapped_name else bone.name
		if target_names.has(target_name):
			push_error("Rig bones rename to the same target bone: %s" % target_name)
			return false
		target_names[target_name] = true

		var profile_index := profile.find_bone(mapped_name)
		var parent_name: StringName
		if bone.parent_index >= 0:
			var parent_bone := bones[bone.parent_index]
			parent_name = bone_map.find_profile_bone_name(parent_bone.name)
			if not parent_name:
				push_error(
					"Unsupported target hierarchy: mapped bone %s has unmapped parent %s"
					% [bone.name, parent_bone.name],
				)
				return false

		if parent_name != profile.get_bone_parent(profile_index):
			push_error(
				"Unsupported target hierarchy: parent of %s differs from profile" % bone.name
			)
			return false

	for profile_index in profile.bone_size:
		var bone_name := profile.get_bone_name(profile_index)
		if profile.is_required(profile_index) and not target_names.has(bone_name):
			push_error("Bone map is missing required bone '%s'" % bone_name)
			return false

	return true
