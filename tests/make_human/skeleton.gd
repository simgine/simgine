extends TestSuite

const BODY_VERTICES: PackedVector3Array = [Vector3(1, 2, 3), Vector3(3, 2, 3), Vector3(3, 5, 3)]
# Blender +X with +90° roll, and Blender +Z with -90° roll, converted to Y-up.
const ROOT_REST := Transform3D(
	Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)),
	Vector3(1, 2, 3),
)
const CHILD_REST := Transform3D(
	Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)),
	Vector3(3, 2, 3),
)

# Local root Z rotation cancels its native axes.
const REFERENCE_ROOT := Transform3D(Basis.IDENTITY, Vector3(3, 1, 3))
# Child X rotation follows that root.
const REFERENCE_CHILD := Transform3D(
	Basis(Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(1, 0, 0)),
	Vector3(2, 3, 3),
)
const PROFILE_ROOT_BASIS := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))

const SKIN_POINT := Vector3(4, 3, 5)


func test_joints() -> void:
	var vertices: PackedVector3Array = [
		Vector3(100, -50, 20),
		Vector3(1, 2, 3),
		Vector3(3, 4, 5),
		Vector3(-40, 90, 10),
		Vector3(-2, 1, 4),
		Vector3(4, 3, -1),
		Vector3(9, 0, 4),
		Vector3(30, 20, -60),
	]

	var groups := MHVertexGroups.new()
	# Unequal range lengths catch averaging range centers instead of all vertices.
	groups.ranges = { "joint-test": PackedInt32Array([1, 2, 4, 6]) }

	var endpoint := _vertex(5)
	endpoint.default_position = Vector3(999, 999, 999)
	assert_approx_eq(
		endpoint.resolve(vertices, groups),
		Vector3(4, 3, -1),
		1e-6,
		"vertex endpoints use the current body vertex",
	)

	endpoint.strategy = MHRigPosition.Strategy.MEAN
	endpoint.vertex_indices = [0, 3, 7]
	assert_approx_eq(
		endpoint.resolve(vertices, groups),
		Vector3(30, 20, -10),
		1e-6,
		"mean endpoints average only the explicitly selected vertices",
	)

	endpoint.strategy = MHRigPosition.Strategy.CUBE
	endpoint.cube_name = "joint-test"
	assert_approx_eq(
		endpoint.resolve(vertices, groups),
		Vector3(3, 2, 3),
		1e-6,
		"joint groups average every vertex in all inclusive ranges, excluding gaps",
	)


func test_rests() -> void:
	const CHILD_LOCAL_REST := Transform3D(
		Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)),
		Vector3(0, 2, 0),
	)

	var rig := _rig()
	var skeleton := _skeleton()
	var skin := skeleton.rebuild(rig, MHVertexGroups.new(), BODY_VERTICES)

	_assert_layout(skeleton, skin, ["root", "child"])
	assert_approx_eq(skeleton.get_bone_global_rest(0), ROOT_REST)
	assert_approx_eq(skeleton.get_bone_global_rest(1), CHILD_REST)
	assert_approx_eq(skeleton.get_bone_rest(0), ROOT_REST)
	assert_approx_eq(skeleton.get_bone_rest(1), CHILD_LOCAL_REST)

	# Without a reference pose, skinning at rest must leave the mesh unchanged.
	assert_approx_eq(skin.get_bind_pose(0), ROOT_REST.affine_inverse())
	assert_approx_eq(skin.get_bind_pose(1), CHILD_REST.affine_inverse())
	_assert_deformation(skeleton, skin, SKIN_POINT, SKIN_POINT, SKIN_POINT)


func test_rebuild() -> void:
	var rig := _rig()
	var groups := MHVertexGroups.new()
	var skeleton := _skeleton()
	skeleton.rebuild(rig, groups, BODY_VERTICES)

	# Change both bone directions and lengths, while keeping the rig's saved endpoints.
	var morphed_vertices: PackedVector3Array = [
		Vector3(-2, 1, 4),
		Vector3(-2, 4, 4),
		Vector3(2, 4, 4),
	]
	var morphed_root := Transform3D(
		Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)),
		Vector3(-2, 1, 4),
	)
	var morphed_child := Transform3D(
		Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
		Vector3(-2, 4, 4),
	)
	var skin := skeleton.rebuild(rig, groups, morphed_vertices)

	_assert_layout(skeleton, skin, ["root", "child"])
	assert_approx_eq(skeleton.get_bone_global_rest(0), morphed_root)
	assert_approx_eq(skeleton.get_bone_global_rest(1), morphed_child)
	assert_approx_eq(skeleton.get_bone_rest(1), morphed_root.affine_inverse() * morphed_child)
	assert_approx_eq(skin.get_bind_pose(0), morphed_root.affine_inverse())
	assert_approx_eq(skin.get_bind_pose(1), morphed_child.affine_inverse())
	_assert_deformation(skeleton, skin, SKIN_POINT, SKIN_POINT, SKIN_POINT)


func test_reference_pose() -> void:
	var rig := _rig()
	var skeleton := _skeleton()
	var skin := skeleton.rebuild(rig, MHVertexGroups.new(), BODY_VERTICES, _reference_pose(rig))

	_assert_layout(skeleton, skin, ["root", "child"])
	assert_approx_eq(skeleton.get_bone_global_rest(0), REFERENCE_ROOT)
	assert_approx_eq(skeleton.get_bone_global_rest(1), REFERENCE_CHILD)
	assert_approx_eq(
		skeleton.get_bone_rest(1),
		Transform3D(REFERENCE_CHILD.basis, Vector3(-1, 2, 0)),
	)
	assert_approx_eq(
		skin.get_bind_pose(0),
		ROOT_REST.affine_inverse(),
		1e-6,
		"root bind undoes the native rest",
	)
	assert_approx_eq(
		skin.get_bind_pose(1),
		CHILD_REST.affine_inverse(),
		1e-6,
		"child bind undoes the native rest",
	)

	# (4, 3, 5) has native bone-local coordinates (-1, 3, 2) and (2, 1, -1).
	# The reference rests move those to (2, 4, 5) and (1, 2, 5); blend at 25%/75%.
	_assert_deformation(skeleton, skin, Vector3(2, 4, 5), Vector3(1, 2, 5), Vector3(1.25, 2.5, 5))


func test_profile_mapping() -> void:
	const PROFILE_CHILD_BASIS := Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))

	var rig := _rig()
	var skeleton := _skeleton()
	var groups := MHVertexGroups.new()
	var bone_map := _bone_map()
	var skin := skeleton.rebuild(rig, groups, BODY_VERTICES, null, bone_map)

	var mapped_root := Transform3D(PROFILE_ROOT_BASIS, ROOT_REST.origin)
	var mapped_child := Transform3D(PROFILE_CHILD_BASIS, CHILD_REST.origin)

	_assert_layout(skeleton, skin, ["MappedRoot", "MappedChild"])
	# Use profile axes, but keep body joint positions rather than profile positions.
	# The child's global basis includes both profile bones' local rotations.
	assert_approx_eq(skeleton.get_bone_global_rest(0), mapped_root)
	assert_approx_eq(skeleton.get_bone_global_rest(1), mapped_child)
	assert_approx_eq(skeleton.get_bone_rest(1), mapped_root.affine_inverse() * mapped_child)
	_assert_deformation(
		skeleton,
		skin,
		SKIN_POINT,
		SKIN_POINT,
		SKIN_POINT,
		"changing axes alone must not deform the mesh",
	)

	skin = skeleton.rebuild(rig, groups, BODY_VERTICES, _reference_pose(rig), bone_map)
	mapped_root.origin = REFERENCE_ROOT.origin
	mapped_child.origin = REFERENCE_CHILD.origin
	assert_approx_eq(skeleton.get_bone_global_rest(0), mapped_root)
	assert_approx_eq(skeleton.get_bone_global_rest(1), mapped_child)
	_assert_deformation(
		skeleton,
		skin,
		Vector3(2, 4, 5),
		Vector3(1, 2, 5),
		Vector3(1.25, 2.5, 5),
		"mapping must preserve reference deformation",
	)


static func _assert_layout(
	skeleton: MHSkeleton,
	skin: Skin,
	names: PackedStringArray,
	msg: String = "",
) -> void:
	assert_eq(skeleton.get_bone_count(), 2, msg)
	assert_eq(skin.get_bind_count(), 2, msg)
	for bone_index in 2:
		assert_eq(skeleton.get_bone_name(bone_index), names[bone_index], msg)
		assert_eq(skeleton.get_bone_parent(bone_index), bone_index - 1, msg)
		assert_eq(skin.get_bind_bone(bone_index), bone_index, msg)


static func _assert_deformation(
	skeleton: MHSkeleton,
	skin: Skin,
	expected_root_point: Vector3,
	expected_child_point: Vector3,
	expected_blended_point: Vector3,
	msg: String = "",
) -> void:
	var root_point := skeleton.get_bone_global_pose(0) * skin.get_bind_pose(0) * SKIN_POINT
	var child_point := skeleton.get_bone_global_pose(1) * skin.get_bind_pose(1) * SKIN_POINT
	assert_approx_eq(root_point, expected_root_point, 1e-6, msg)
	assert_approx_eq(child_point, expected_child_point, 1e-6, msg)
	assert_approx_eq(root_point * 0.25 + child_point * 0.75, expected_blended_point, 1e-6, msg)


static func _rig() -> MHRig:
	var root := MHBone.new()
	root.head = _vertex(0)
	root.tail = _vertex(1)
	root.roll = PI * 0.5

	var child := MHBone.new()
	child.parent_name = "root"
	child.head = _vertex(1)
	child.tail = _vertex(2)
	child.roll = -PI * 0.5

	var rig := MHRig.new()
	rig.bones = { "root": root, "child": child }

	return rig


static func _vertex(vertex_index: int) -> MHRigPosition:
	var endpoint := MHRigPosition.new()
	endpoint.strategy = MHRigPosition.Strategy.VERTEX
	endpoint.vertex_indices = [vertex_index]

	if vertex_index < BODY_VERTICES.size():
		var position := BODY_VERTICES[vertex_index]
		endpoint.default_position = Vector3(position.x, -position.z, position.y)

	return endpoint


func _skeleton() -> MHSkeleton:
	var skeleton := MHSkeleton.new()
	add_child(skeleton)

	return skeleton


static func _reference_pose(rig: MHRig) -> MHNativePose:
	var reference := MHNativePose.new()
	reference.rig = rig
	reference.rotations = {
		"root": Quaternion(Vector3.BACK, PI * 0.5),
		"child": Quaternion(Vector3.RIGHT, PI * 0.5),
	}
	reference.translations = { "root": Vector3(1, 2, 0), "child": Vector3(0, 1, 0) }

	return reference


static func _bone_map() -> BoneMap:
	var profile := SkeletonProfile.new()
	profile.bone_size = 2
	profile.set_bone_name(0, "MappedRoot")
	profile.set_bone_name(1, "MappedChild")
	profile.set_bone_parent(1, "MappedRoot")
	profile.set_reference_pose(0, Transform3D(PROFILE_ROOT_BASIS, Vector3(20, 30, 40)))
	profile.set_reference_pose(
		1,
		Transform3D(
			Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)),
			Vector3(50, 60, 70),
		),
	)

	var bone_map := BoneMap.new()
	bone_map.profile = profile
	bone_map.set_skeleton_bone_name("MappedRoot", "root")
	bone_map.set_skeleton_bone_name("MappedChild", "child")

	return bone_map
