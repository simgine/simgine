extends TestSuite

const BODY_VERTICES: PackedVector3Array = [
	Vector3(0, 1, 0),
	Vector3(0, 2, 0),
	Vector3(0, 4, 0),
	Vector3(0, 5, 0),
	Vector3(-2, 4, 0),
	Vector3(2, 4, 0),
]


func test_unmapped_ancestors() -> void:
	var rig := _rig_with_intermediate()
	var bone_map := _bone_map()
	var native := MHNativePose.new()
	native.rig = rig
	native.rotations = {
		"spine05": Quaternion(Vector3.UP, 0.4),
		"intermediate": Quaternion(Vector3.RIGHT, 0.7),
		"spine01": Quaternion(Vector3.BACK, -0.3),
	}

	var pose := native.retarget(bone_map)
	var root_motion := Basis(native.rotations["spine05"])
	var child_motion := (
		root_motion * Basis(native.rotations["intermediate"]) * Basis(native.rotations["spine01"])
	)
	var profile_root := bone_map.profile.get_reference_pose(0).basis
	var profile_child := profile_root * bone_map.profile.get_reference_pose(1).basis
	var profile_tip := profile_child * bone_map.profile.get_reference_pose(2).basis
	var posed_root := Basis(pose.rotations["Root"])
	var posed_child := posed_root * Basis(pose.rotations["Child"])
	var posed_tip := posed_child * Basis(pose.rotations["Tip"])
	assert_approx_eq(posed_root, root_motion * profile_root)
	assert_approx_eq(
		posed_child,
		child_motion * profile_child,
		1e-6,
		"mapped child retains motion from its unmapped ancestor",
	)
	assert_approx_eq(
		posed_tip,
		child_motion * profile_tip,
		1e-6,
		"ancestor motion propagates to mapped descendants",
	)


func test_reference_pose() -> void:
	var native := MHNativePose.new()
	native.rig = _rig_with_intermediate()
	native.rotations = {
		"spine05": Quaternion(Vector3.UP, 0.4),
		"intermediate": Quaternion(Vector3.RIGHT, 0.7),
		"spine01": Quaternion(Vector3.BACK, -0.3),
	}
	native.translations = {
		"spine05": Vector3(1, 2, 3),
		"intermediate": Vector3(-2, 1, 4),
		"spine01": Vector3(3, -1, 2),
		"tip": Vector3(1, 0, -2),
	}

	var bone_map := _bone_map()
	var pose := native.retarget(bone_map, native)
	assert(
		pose.translations.is_empty(),
		"retargeting against itself cancels all translation offsets",
	)
	assert_eq(pose.rotations.size(), bone_map.profile.bone_size)

	for bone_index in bone_map.profile.bone_size:
		var bone_name := bone_map.profile.get_bone_name(bone_index)
		assert_approx_eq(
			Basis(pose.rotations[bone_name]),
			bone_map.profile.get_reference_pose(bone_index).basis,
			1e-6,
			"%s returns to its profile reference orientation" % bone_name,
		)


func test_translations() -> void:
	var rig := _rig()
	var bone_map := _bone_map()
	var native := _native_pose(rig)
	var reference := MHNativePose.new()
	reference.rig = rig
	reference.rotations = { "spine05": Quaternion(Vector3.UP, -PI * 0.5) }
	reference.translations = { "spine05": Vector3(-2, 1, 1), "spine01": Vector3(1, 2, -2) }

	var pose := native.retarget(bone_map, reference)
	assert_eq(pose.translations.size(), 3)
	assert_approx_eq(
		pose.translations["Root"],
		Vector3(3, 1, 2),
		1e-6,
		"root offset is relative to the reference translation",
	)
	# The posed child offset rotates to (1, -1, -2), the reference to (2, 2, 1).
	assert_approx_eq(
		pose.translations["Child"],
		Vector3(2, -2, -1),
		1e-6,
		"child offsets are compared in skeleton space after parent rotations",
	)
	assert_approx_eq(
		pose.translations["Tip"],
		Vector3(2, -2, -1),
		1e-6,
		"tip inherits its parent's total displacement",
	)
	assert_approx_eq(pose.original_shoulder_width, 2.0)
	assert_approx_eq(pose.original_spine_length, 1.0)

	# Measured shoulders are 4 wide and the spine is 3 long: scale X/Z by 2, Y by 3.
	_assert_displacements(
		_skeleton(rig, bone_map),
		pose,
		Vector3(6, 3, 4),
		Vector3(4, -6, -2),
		"translations scale in skeleton space without counting parent displacement twice",
	)


func test_replacement() -> void:
	var rig := _rig()
	var bone_map := _bone_map()
	var skeleton := _skeleton(rig, bone_map)
	var rests := _global_poses(skeleton)

	var pose := _native_pose(rig).retarget(bone_map)
	skeleton.pose = pose

	var applied := _global_poses(skeleton)
	skeleton.pose = pose

	_assert_global_poses(skeleton, applied, "reapplying a pose must not accumulate displacement")

	var replacement_native := MHNativePose.new()
	replacement_native.rig = rig
	replacement_native.translations = { "spine05": Vector3(-1, 0, 2) }

	var replacement := replacement_native.retarget(bone_map)
	skeleton.pose = replacement

	var fresh := _skeleton(rig, bone_map)
	fresh.pose = replacement

	_assert_global_poses(
		skeleton,
		_global_poses(fresh),
		"replacement removes rotations and translations from the previous pose",
	)

	skeleton.pose = null
	_assert_global_poses(skeleton, rests, "clearing the pose restores rests")

	for bone_index in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(bone_index)
		var reset := skeleton.get_bone_pose(bone_index)
		assert_approx_eq(
			reset,
			rest,
			1e-6,
			"clearing the pose restores the local rest for %s" % skeleton.get_bone_name(bone_index),
		)


func test_unscaled_translations() -> void:
	var rig := _rig()
	var bone_map := _bone_map()
	var native := _native_pose(rig)
	native.original_shoulder_width = 0.0
	native.original_spine_length = 0.0

	_assert_displacements(
		_skeleton(rig, bone_map),
		native.retarget(bone_map),
		Vector3(1, 2, 3),
		Vector3(2, 1, 1),
		"missing capture proportions leave translations unscaled",
	)

	# Nonzero capture proportions must also fall back when the rig cannot be measured.
	native.original_shoulder_width = 2.0
	native.original_spine_length = 1.0
	rig.bones["left"] = rig.bones["shoulder01.L"]
	rig.bones["right"] = rig.bones["shoulder01.R"]
	rig.bones.erase("shoulder01.L")
	rig.bones.erase("shoulder01.R")
	_assert_displacements(
		_skeleton(rig, bone_map),
		native.retarget(bone_map),
		Vector3(1, 2, 3),
		Vector3(2, 1, 1),
		"missing body measurements leave translations unscaled despite capture proportions",
	)


static func _assert_global_poses(
	skeleton: MHSkeleton,
	expected: Array[Transform3D],
	msg: String = "",
) -> void:
	assert_eq(skeleton.get_bone_count(), expected.size(), msg)
	for bone_index in skeleton.get_bone_count():
		var actual := skeleton.get_bone_global_pose(bone_index)
		assert_approx_eq(
			actual,
			expected[bone_index],
			1e-6,
			"%s for %s" % [msg, skeleton.get_bone_name(bone_index)],
		)


static func _assert_displacements(
	skeleton: MHSkeleton,
	pose: MHPose,
	root_offset: Vector3,
	child_offset: Vector3,
	msg: String = "",
) -> void:
	var rotations_only := MHPose.new()
	rotations_only.profile = pose.profile
	rotations_only.rotations = pose.rotations
	skeleton.pose = rotations_only
	var baseline := _global_poses(skeleton)
	skeleton.pose = pose
	for bone_index in skeleton.get_bone_count():
		var actual := skeleton.get_bone_global_pose(bone_index)
		var offset := root_offset if bone_index == 0 else child_offset
		assert_approx_eq(
			actual.origin - baseline[bone_index].origin,
			offset,
			1e-6,
			"%s for %s" % [msg, skeleton.get_bone_name(bone_index)],
		)
		assert_approx_eq(
			actual.basis,
			baseline[bone_index].basis,
			1e-6,
			"translations must not change %s orientation" % skeleton.get_bone_name(bone_index),
		)


func _skeleton(rig: MHRig, bone_map: BoneMap) -> MHSkeleton:
	var skeleton := MHSkeleton.new()
	add_child(skeleton)
	assert(skeleton.rebuild(rig, MHVertexGroups.new(), BODY_VERTICES, null, bone_map) != null)
	return skeleton


static func _rig() -> MHRig:
	var rig := MHRig.new()
	rig.bones = {
		"spine05": _bone(0, 1),
		"spine01": _bone(1, 2, "spine05"),
		"tip": _bone(2, 3, "spine01"),
		"shoulder01.L": _bone(2, 4, "spine01"),
		"shoulder01.R": _bone(2, 5, "spine01"),
	}
	return rig


static func _rig_with_intermediate() -> MHRig:
	var rig := MHRig.new()
	rig.bones = {
		"spine05": _bone(0, 1),
		"intermediate": _bone(1, 2, "spine05"),
		"spine01": _bone(2, 3, "intermediate"),
		"tip": _bone(2, 3, "spine01"),
	}
	return rig


static func _bone(head_index: int, tail_index: int, parent_name: StringName = "") -> MHBone:
	var bone := MHBone.new()
	bone.head = _vertex(head_index)
	bone.tail = _vertex(tail_index)
	bone.parent_name = parent_name
	return bone


static func _vertex(vertex_index: int) -> MHRigPosition:
	var endpoint := MHRigPosition.new()
	endpoint.strategy = MHRigPosition.Strategy.VERTEX
	endpoint.vertex_indices = [vertex_index]
	var position := BODY_VERTICES[vertex_index]
	endpoint.default_position = Vector3(position.x, -position.z, position.y)
	return endpoint


static func _bone_map() -> BoneMap:
	var profile := SkeletonProfile.new()
	profile.bone_size = 3
	var names: PackedStringArray = ["Root", "Child", "Tip"]
	var sources: PackedStringArray = ["spine05", "spine01", "tip"]
	var axes: Array[Vector3] = [Vector3.UP, Vector3.RIGHT, Vector3.BACK]
	for bone_index in names.size():
		profile.set_bone_name(bone_index, names[bone_index])
		if bone_index > 0:
			profile.set_bone_parent(bone_index, names[bone_index - 1])
		profile.set_reference_pose(
			bone_index,
			Transform3D(Basis(axes[bone_index], PI * 0.5), Vector3(10, 20, 30)),
		)

	var bone_map := BoneMap.new()
	bone_map.profile = profile
	for bone_index in names.size():
		bone_map.set_skeleton_bone_name(names[bone_index], sources[bone_index])
	return bone_map


static func _native_pose(rig: MHRig) -> MHNativePose:
	var native := MHNativePose.new()
	native.rig = rig
	native.rotations = {
		"spine05": Quaternion(Vector3.UP, PI * 0.5),
		"spine01": Quaternion(Vector3.RIGHT, PI * 0.5),
	}
	native.translations = {
		"spine05": Vector3(1, 2, 3),
		"spine01": Vector3(2, -1, 1),
		"tip": Vector3.ZERO,
	}
	native.original_shoulder_width = 2.0
	native.original_spine_length = 1.0
	return native


static func _global_poses(skeleton: MHSkeleton) -> Array[Transform3D]:
	var transforms: Array[Transform3D]
	for bone_index in skeleton.get_bone_count():
		transforms.append(skeleton.get_bone_global_pose(bone_index))
	return transforms
