@tool
class_name MHRig
extends Resource
## Defines the native bone hierarchy, saved rest endpoints, and how each bone
## endpoint follows the mesh.
##
## Imported from `rig.*.json`.

## Bones keyed by their MakeHuman bone name, in parent-first order.
@export var bones: Dictionary[StringName, MHBone]


## Checks if [param bone_map] can be used with this rig.
func validate_bone_map(bone_map: BoneMap) -> bool:
	var profile := bone_map.profile
	if not profile:
		push_error("Bone map requires a profile")
		return false

	var target_names: Dictionary[StringName, bool]
	for bone_name in bones:
		var bone := bones[bone_name]
		var mapped_name := bone_map.find_profile_bone_name(bone_name)
		if not mapped_name:
			if profile.find_bone(bone_name) >= 0:
				push_error("Unmapped bone uses a profile bone name: %s" % bone_name)
				return false
			continue

		var target_name := mapped_name if mapped_name else bone_name
		if target_names.has(target_name):
			push_error("Rig bones rename to the same target bone: %s" % target_name)
			return false
		target_names[target_name] = true

		var profile_index := profile.find_bone(mapped_name)
		var parent_name: StringName
		if bone.parent_name:
			parent_name = bone_map.find_profile_bone_name(bone.parent_name)
			if not parent_name:
				push_error(
					"Unsupported target hierarchy: mapped bone %s has unmapped parent %s"
					% [bone_name, bone.parent_name],
				)
				return false

		if parent_name != profile.get_bone_parent(profile_index):
			push_error(
				"Unsupported target hierarchy: parent of %s differs from profile" % bone_name
			)
			return false

	for profile_index in profile.bone_size:
		var bone_name := profile.get_bone_name(profile_index)
		if profile.is_required(profile_index) and not target_names.has(bone_name):
			push_error("Bone map is missing required bone '%s'" % bone_name)
			return false

	return true
