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
var _bone_snapshots: Array[BoneSnapshot] = []


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


## Rebuilds bones for the body vertices.
##
## Bone rest transforms are first resolved in global skeleton space, then
## converted to parent-relative rests required by [Skeleton3D].
func rebuild(rig: MHRig, vertex_groups: MHVertexGroups, body_vertices: PackedVector3Array) -> void:
	clear_bones()

	var global_rests: Array[Transform3D]
	global_rests.resize(rig.bones.size())

	for bone_index in rig.bones.size():
		var bone := rig.bones[bone_index]
		var added_index := add_bone(bone.export_name)
		assert(added_index == bone_index)

		var global_rest := bone.resolve_global_rest(body_vertices, vertex_groups)
		var rest := global_rest
		if bone.parent_index >= 0:
			set_bone_parent(bone_index, bone.parent_index)
			var parent_rest := global_rests[bone.parent_index]
			rest = parent_rest.affine_inverse() * global_rest

		global_rests[bone_index] = global_rest
		set_bone_rest(bone_index, rest)

	reset_bone_poses()
	notify_property_list_changed()


class BoneSnapshot:
	var name: String
	var parent: int
	var rest: Transform3D
	var pose: Transform3D
	var enabled: bool
