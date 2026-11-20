class_name MHBVHImporter
extends EditorImportPlugin
## Imports the first frame of a legacy MakeHuman BVH as a pose for the default rig.


func _get_importer_name() -> String:
	return "make_human.bvh_importer"


func _get_visible_name() -> String:
	return "MakeHuman BVH Importer"


func _get_recognized_extensions() -> PackedStringArray:
	return ["bvh"]


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_name(_preset_index: int) -> String:
	return ""


func _get_import_order() -> int:
	return 2 # Depends on JSON rigs and reference poses.


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "rig",
			"default_value": "",
			"property_hint": PROPERTY_HINT_FILE,
			"hint_string": "*.json",
		},
		{
			"name": "bone_map",
			"default_value": "",
			"property_hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tres,*.res",
		},
		{
			"name": "reference_pose",
			"default_value": "",
			"property_hint": PROPERTY_HINT_FILE,
			"hint_string": "*.json,*.bvh,*.tres,*.res",
		},
	]


func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	_platform_variants: Array,
	_gen_files: Array,
) -> Error:
	var rig_path: String = options.rig
	if not rig_path:
		push_error("BVH pose import requires the default MakeHuman source rig")
		return ERR_INVALID_PARAMETER

	var rig := ResourceLoader.load(rig_path) as MHRig
	if not rig:
		push_error("Unable to load source rig '%s'" % rig_path)
		return ERR_CANT_OPEN

	var map_path: String = options.bone_map
	var reference_path: String = options.reference_pose
	if reference_path and not map_path:
		push_error("A reference pose is only used when a BoneMap is supplied")
		return ERR_INVALID_PARAMETER

	var text := FileAccess.get_file_as_string(source_file)
	var open_error := FileAccess.get_open_error()
	if open_error != OK:
		push_error("Unable to open '%s': %s" % [source_file, error_string(open_error)])
		return open_error

	var native_pose := MHNativePose.new()
	native_pose.rig = rig
	if not _parse_pose(text, native_pose):
		return ERR_PARSE_ERROR

	var output_path := "%s.%s" % [save_path, _get_save_extension()]
	if not map_path:
		# Import as a native pose without retargeting.
		return ResourceSaver.save(native_pose, output_path)

	var bone_map := ResourceLoader.load(map_path) as BoneMap
	if not bone_map or not bone_map.profile:
		push_error("Pose retargeting requires a BoneMap with a profile")
		return ERR_INVALID_DATA

	var reference_pose: MHNativePose
	if reference_path:
		reference_pose = ResourceLoader.load(reference_path) as MHNativePose
		if not reference_pose:
			push_error("Reference pose '%s' must be an MHNativePose" % reference_path)
			return ERR_INVALID_DATA

	var pose := native_pose.retarget(bone_map, reference_pose)
	if not pose:
		return ERR_INVALID_DATA

	return ResourceSaver.save(pose, output_path)


func _parse_pose(text: String, pose: MHNativePose) -> bool:
	var joints: Array[Joint]
	var parents: Array[int]
	var awaiting_brace := false
	var first_line := true
	var motion_line := 0
	var line_index := 0
	for line in text.split("\n"):
		line_index += 1
		line = line.strip_edges().replace("\t", " ")
		if line.is_empty():
			continue

		var parts := line.split(" ", false)
		if first_line:
			if line != "HIERARCHY":
				push_error("Expected 'HIERARCHY' at line %d, got '%s'" % [line_index, line])
				return false
			first_line = false
			continue

		if motion_line > 0:
			match motion_line:
				1:
					if parts.size() != 2 or parts[0] != "Frames:" or parts[1].to_int() < 1:
						push_error(
							"Expected 'Frames:' with a positive frame count at %d" % line_index
						)
						return false
				2:
					if parts.size() != 3 or parts[0] != "Frame" or parts[1] != "Time:":
						push_error("Expected 'Frame Time: <value>' at %d" % line_index)
						return false
				3:
					return _apply_frame(joints, parts, pose)
			motion_line += 1
			continue

		if awaiting_brace:
			if line != "{":
				push_error(
					"Expected '{' after the declaration at %d, got '%s'" % [line_index, line]
				)
				return false
			awaiting_brace = false
			continue

		var joint: Joint = joints[parents.back()] if not parents.is_empty() else null
		match parts[0]:
			"ROOT", "JOINT", "End":
				var is_root := parts[0] == "ROOT"
				var is_end_site := parts[0] == "End"
				if (
					parts.size() != 2 or (is_root and not joints.is_empty())
					or (not is_root and (not joint or not joint.bone_name))
					or (is_end_site and parts[1] != "Site")
				):
					push_error("Invalid joint declaration at %d: '%s'" % [line_index, line])
					return false

				var child := Joint.new()
				if not is_end_site:
					child.bone_name = parts[1]
				if joint:
					child.parent = parents.back()
				parents.push_back(joints.size())
				joints.push_back(child)
				awaiting_brace = true
			"OFFSET":
				if not joint or parts.size() != 4:
					push_error("Invalid 'OFFSET' at %d: '%s'" % [line_index, line])
					return false
				joint.offset = Vector3(
					parts[1].to_float(),
					parts[2].to_float(),
					parts[3].to_float(),
				)
			"CHANNELS":
				if (
					not joint or not joint.bone_name or parts.size() < 3
					or parts[1].to_int() != parts.size() - 2
				):
					push_error("Invalid 'CHANNELS' at %d: '%s'" % [line_index, line])
					return false
				joint.channels = parts.slice(2)
			"}":
				if parents.is_empty():
					push_error("Unexpected '}' at %d" % line_index)
					return false
				parents.pop_back()
			"MOTION":
				if joints.is_empty() or not parents.is_empty():
					push_error("Expected a complete hierarchy before 'MOTION' at %d" % line_index)
					return false
				motion_line = 1
			_:
				push_error("Unexpected hierarchy line at %d: '%s'" % [line_index, line])
				return false

	push_error("Unexpected end of BVH at %d" % line_index)
	return false


func _apply_frame(joints: Array[Joint], values: PackedStringArray, pose: MHNativePose) -> bool:
	# Like MPFB2, assume legacy MakeHuman BVH poses are Z-up.
	const FROM_FILE := MHBone.BLENDER_TO_MH

	var rig := pose.rig
	var deltas: Dictionary[StringName, Basis]
	var root_translation := Vector3.ZERO
	var value_index := 0
	for joint in joints:
		if not joint.bone_name:
			continue

		var rotation := Basis.IDENTITY
		for channel in joint.channels:
			if value_index >= values.size():
				push_error("Missing BVH motion value for '%s'" % joint.bone_name)
				return false

			var token := values[value_index]
			if not token.is_valid_float():
				push_error("Invalid BVH motion value for '%s'" % joint.bone_name)
				return false

			var value := token.to_float()
			value_index += 1
			match channel:
				"Xrotation", "Yrotation", "Zrotation":
					var axis := Vector3.ZERO
					axis["XYZ".find(channel[0])] = 1.0
					rotation *= Basis(FROM_FILE * axis, deg_to_rad(value))
				"Xposition", "Yposition", "Zposition":
					# Legacy MakeHuman pose loading only applies root translations.
					if joint.parent == -1:
						root_translation["XYZ".find(channel[0])] = value
				_:
					push_error("Unsupported BVH channel '%s'" % channel)
					return false

		joint.delta = rotation
		if joint.parent != -1:
			joint.delta = joints[joint.parent].delta * joint.delta

		# Legacy MakeHuman's prefix for dummy joints.
		if joint.bone_name.begins_with("__"):
			continue

		if not rig.bones.has(joint.bone_name):
			push_error("BVH joint '%s' is missing from the source rig" % joint.bone_name)
			return false

		if deltas.has(joint.bone_name):
			push_error("Duplicate BVH joint '%s'" % joint.bone_name)
			return false

		deltas[joint.bone_name] = joint.delta

	if value_index != values.size():
		push_error("BVH motion frame has %d values for %d channels" % [values.size(), value_index])
		return false

	# Bake dummy joints into the rotations of their descendants on the native rig.
	for bone_name in rig.bones:
		var bone := rig.bones[bone_name]
		var parent_delta: Basis = deltas.get(bone.parent_name, Basis.IDENTITY)
		if not deltas.has(bone_name):
			deltas[bone_name] = parent_delta
			continue
		var rest := bone.get_rest_basis()
		var rotation := rest.inverse() * parent_delta.inverse() * deltas[bone_name] * rest
		pose.rotations[bone_name] = rotation.orthonormalized().get_rotation_quaternion()

	if not root_translation.is_zero_approx():
		var scale := _get_translation_scale(joints, rig)
		if scale <= 0.0:
			push_error(
				"BVH root translation requires a measurable 'upperleg02.L' in the BVH and rig"
			)
			return false

		var root_name := joints[0].bone_name
		if not rig.bones.has(root_name) or rig.bones[root_name].parent_name:
			push_error("BVH root '%s' must be a root bone of the source rig" % root_name)
			return false

		var rest := rig.bones[root_name].get_rest_basis()
		pose.translations[root_name] = rest.inverse() * (FROM_FILE * root_translation * scale)

	var lower_spine: MHBone = rig.bones.get("spine05")
	var upper_spine: MHBone = rig.bones.get("spine01")
	if lower_spine and upper_spine:
		pose.original_spine_length = lower_spine.head.default_position.distance_to(
			upper_spine.tail.default_position,
		)

	var left_shoulder: MHBone = rig.bones.get("shoulder01.L")
	var right_shoulder: MHBone = rig.bones.get("shoulder01.R")
	if left_shoulder and right_shoulder:
		pose.original_shoulder_width = left_shoulder.tail.default_position.distance_to(
			right_shoulder.tail.default_position,
		)

	return true


func _get_translation_scale(joints: Array[Joint], rig: MHRig) -> float:
	# Legacy MakeHuman scales root motion using this bone as a reference.
	const BONE_NAME: StringName = "upperleg02.L"
	var bone: MHBone = rig.bones.get(BONE_NAME)
	if not bone:
		push_error("Unable to find '%s' which used for translation scale" % BONE_NAME)
		return 0.0

	# The BVH has no explicit bone tail, so use the first child's offset to measure it.
	for joint in joints:
		if joint.parent != -1 and joints[joint.parent].bone_name == BONE_NAME:
			var length := joint.offset.length()
			if not is_zero_approx(length):
				return bone.head.default_position.distance_to(bone.tail.default_position) / length
			break

	push_error("Expected '%s' with a nonzero first-child offset" % BONE_NAME)
	return 0.0


class Joint:
	var bone_name: StringName
	var parent := -1
	var offset: Vector3
	var channels: PackedStringArray
	var delta: Basis
