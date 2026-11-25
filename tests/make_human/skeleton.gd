extends TestSuite
## Bone transforms, poses, and lifecycle.

const STANDING_POSE := preload(
	"res://characters/visuals/make_human/data/poses/callharvey3d_standingnatural/callharvey3d_standingnatural.bvh"
)

# Recorded from STANDING_POSE on body.tres at default modifiers, in skeleton space (meters).
# Hips captures root displacement. Hand and foot sample upper/lower-body chains.
const STANDING_TRANSFORMS: Dictionary[StringName, Transform3D] = {
	"Hips": Transform3D(
		Basis(
			Vector3(0.99501246, -0.00539069, -0.099604845),
			Vector3(0.00539069, 0.99998546, -0.00026913738),
			Vector3(0.099604845, -0.00026914378, 0.99502707),
		),
		Vector3(0, 0.8816923, -0.05156396),
	),
	"LeftHand": Transform3D(
		Basis(
			Vector3(0.18558466, -0.084220335, -0.9790125),
			Vector3(0.07495832, -0.9922037, 0.09956439),
			Vector3(-0.97976506, -0.09186296, -0.17782488),
		),
		Vector3(0.21654437, 0.87110287, 0.025527492),
	),
	"LeftFoot": Transform3D(
		Basis(
			Vector3(-0.86011964, 0.038700204, 0.50862193),
			Vector3(0.50827587, -0.019044086, 0.8609838),
			Vector3(0.043006472, 0.9990694, -0.003290169),
		),
		Vector3(0.09638484, 0.07542476, -0.13902646),
	),
}


func requires_editor() -> bool:
	# Skeleton save notifications are skipped outside of the editor.
	return true


func test_rest_transforms() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# Parent-relative rests: profile root, pelvis, and a deeper T-pose arm joint.
	var expected_rests: Dictionary[StringName, Transform3D] = {
		"Root": Transform3D.IDENTITY,
		"Hips": Transform3D(Basis.IDENTITY, Vector3(0.000000000058, 0.873886346817, 0.013216649182)),
		"LeftUpperArm": Transform3D(
			Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)),
			Vector3(-0.005248412490, 0.147960007191, 0.016419172287),
		),
	}
	var skeleton := instance.skeleton_node
	for bone_name in expected_rests:
		var bone_index := skeleton.find_bone(bone_name)
		assert(bone_index >= 0, "missing bone %s" % bone_name)
		assert_approx_eq(
			skeleton.get_bone_rest(bone_index),
			expected_rests[bone_name],
			1e-6,
			bone_name,
		)


func test_skin_binds() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	var skeleton := instance.skeleton_node
	# Recorded mesh-to-bone binds include the reference pose and profile-axis compensation.
	var expected_binds: Dictionary[StringName, Transform3D] = {
		"LeftUpperArm": Transform3D(
			Basis(
				Vector3(0.020021120086, 0.682402729988, -0.730702459812),
				Vector3(-0.037421703339, -0.729825198650, -0.682609021664),
				Vector3(-0.999099135399, 0.041010711342, 0.010924790055),
			),
			Vector3(0.065243273973, 0.846633791924, 1.025134086609),
		),
		"LeftHand": Transform3D(
			Basis(
				Vector3(0.406064927578, 0.563435018063, -0.719480693340),
				Vector3(-0.450506031513, -0.561570882797, -0.694033563137),
				Vector3(-0.795082211494, 0.605953156948, 0.025796771049),
			),
			Vector3(0.419199317694, 0.203976318240, 1.026079654694),
		),
	}
	for bone_name in expected_binds:
		var bone_index := skeleton.find_bone(bone_name)
		assert(bone_index >= 0, "missing bone %s" % bone_name)
		assert_eq(
			instance.skin.get_bind_bone(bone_index),
			bone_index,
			"bind order must match skeleton bone order for %s" % bone_name,
		)
		assert_approx_eq(
			instance.skin.get_bind_pose(bone_index),
			expected_binds[bone_name],
			1e-6,
			"skin bind for %s" % bone_name,
		)


func test_body_shape_updates() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	var skeleton := instance.skeleton_node
	var hips_index := skeleton.find_bone("Hips")
	assert(hips_index >= 0, "missing bone Hips")
	var hand_index := skeleton.find_bone("LeftHand")
	assert(hand_index >= 0, "missing bone LeftHand")

	var initial_hips_rest := skeleton.get_bone_global_rest(hips_index)
	var initial_hand_rest := skeleton.get_bone_global_rest(hand_index)
	var initial_hand_bind := instance.skin.get_bind_pose(hand_index)
	var initial_motion_scale := skeleton.motion_scale

	instance.set_modifier("height", 0.8)

	await get_tree().process_frame

	# Recorded global rests and hand bind at height 0.8, in meters.
	assert_approx_eq(
		skeleton.get_bone_global_rest(hips_index),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.136813879013, 0.014811557718)),
	)
	assert_approx_eq(
		skeleton.get_bone_global_rest(hand_index),
		Transform3D(
			Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)),
			Vector3(0.815312564373, 1.716493010521, 0.047614835203),
		),
	)
	assert_approx_eq(
		instance.skin.get_bind_pose(hand_index),
		Transform3D(
			Basis(
				Vector3(0.407844543457, 0.563433289528, -0.718474864960),
				Vector3(-0.451992481947, -0.559122443199, -0.695042908192),
				Vector3(-0.793325901031, 0.608214557171, 0.026632487774),
			),
			Vector3(0.541042089462, 0.261427193880, 1.294720053673),
		),
		1e-6,
	)
	assert_approx_eq(skeleton.motion_scale, 1.136813879013)

	instance.set_modifier("height", MHMacroRegistry.DEFAULT_VALUE)

	await get_tree().process_frame

	assert_approx_eq(skeleton.get_bone_global_rest(hips_index), initial_hips_rest)
	assert_approx_eq(skeleton.get_bone_global_rest(hand_index), initial_hand_rest)
	assert_approx_eq(instance.skin.get_bind_pose(hand_index), initial_hand_bind)
	assert_approx_eq(skeleton.motion_scale, initial_motion_scale)


func test_save_restore() -> void:
	var instance := _create_instance()
	var skeleton := instance.skeleton_node
	instance.owner = skeleton
	skeleton.pose = STANDING_POSE
	assert(skeleton.pose)

	await get_tree().process_frame

	var hierarchy_before := _bone_hierarchy(skeleton)
	var transforms_before := _bone_transforms(skeleton)

	assert(skeleton.get_bone_count() > 0)

	var packed := PackedScene.new()
	# pack() does not send the editor's save notifications.
	skeleton.propagate_notification(Node.NOTIFICATION_EDITOR_PRE_SAVE)
	assert_eq(skeleton.get_bone_count(), 0, "bones must be removed right before serialization")
	var error := packed.pack(skeleton)
	skeleton.propagate_notification(Node.NOTIFICATION_EDITOR_POST_SAVE)
	assert_eq(error, OK)

	assert_eq(_bone_hierarchy(skeleton), hierarchy_before)
	assert_approx_eq(_bone_transforms(skeleton), transforms_before)

	var restored := packed.instantiate() as MHSkeleton
	assert_eq(restored.get_bone_count(), 0)
	add_child(restored)

	await get_tree().process_frame

	assert_eq(_bone_hierarchy(restored), hierarchy_before)
	assert_approx_eq(_bone_transforms(restored), transforms_before)


func test_pose_reapplication() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	instance.skeleton_node.pose = STANDING_POSE
	_assert_global_transforms(instance.skeleton_node, STANDING_TRANSFORMS)

	instance.skeleton_node.pose = STANDING_POSE
	_assert_global_transforms(instance.skeleton_node, STANDING_TRANSFORMS)


func test_pose_replacement() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	instance.skeleton_node.pose = STANDING_POSE
	_assert_global_transforms(instance.skeleton_node, STANDING_TRANSFORMS)

	# The bundled game-engine T-pose is native, so use its production map and reference.
	var body := instance.body
	var t_pose := body.reference_pose.retarget(body.bone_map, body.reference_pose)
	instance.skeleton_node.pose = t_pose

	# Recorded from the game-engine T-pose in skeleton space (meters).
	const T_POSE_TRANSFORMS: Dictionary[StringName, Transform3D] = {
		"Hips": Transform3D(
			Basis(
				Vector3(1.000000000000, 0.000000000000, 0.000000000000),
				Vector3(0.000000000000, 1.000000000000, 0.000000029802),
				Vector3(0.000000000000, -0.000000029802, 1.000000000000),
			),
			Vector3(0.000000000058, 0.873886346817, 0.013216649182),
		),
		"LeftHand": Transform3D(
			Basis(
				Vector3(-0.000000013039, -0.000000014901, -1.000000000000),
				Vector3(1.000000000000, 0.000000000466, -0.000000013039),
				Vector3(0.000000000466, -1.000000000000, 0.000000014901),
			),
			Vector3(0.649723172188, 1.350847601891, 0.032009497285),
		),
		"LeftFoot": Transform3D(
			Basis(
				Vector3(-1.000000000000, -0.000000007451, 0.000000003725),
				Vector3(0.000000003725, 0.000000000000, 1.000000000000),
				Vector3(-0.000000007451, 1.000000000000, -0.000000000000),
			),
			Vector3(0.093936726451, 0.065180748701, 0.019135668874),
		),
	}
	_assert_global_transforms(instance.skeleton_node, T_POSE_TRANSFORMS)


func test_pose_clearing() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	var initial: Dictionary[StringName, Transform3D]
	for bone_name in STANDING_TRANSFORMS:
		var bone_index := instance.skeleton_node.find_bone(bone_name)
		assert(bone_index >= 0, "missing bone %s" % bone_name)
		initial[bone_name] = instance.skeleton_node.get_bone_global_pose(bone_index)

	instance.skeleton_node.pose = STANDING_POSE
	_assert_global_transforms(instance.skeleton_node, STANDING_TRANSFORMS)

	instance.skeleton_node.pose = null
	_assert_global_transforms(instance.skeleton_node, initial)


func _create_instance() -> MHBodyInstance:
	var skeleton := MHSkeleton.new()
	add_child(skeleton)

	var instance := MHBodyInstance.new()
	instance.body = load("res://characters/visuals/make_human/body.tres") as MHBody
	skeleton.add_child(instance)
	instance.skeleton_node = skeleton

	return instance


static func _bone_hierarchy(skeleton: MHSkeleton) -> Array[Array]:
	var hierarchy: Array[Array]
	for bone_index in skeleton.get_bone_count():
		hierarchy.append(
			[
				skeleton.get_bone_name(bone_index),
				skeleton.get_bone_parent(bone_index),
				skeleton.is_bone_enabled(bone_index),
			]
		)
	return hierarchy


static func _bone_transforms(skeleton: MHSkeleton) -> Array[Transform3D]:
	var transforms: Array[Transform3D]
	for bone_index in skeleton.get_bone_count():
		transforms.append(skeleton.get_bone_rest(bone_index))
		transforms.append(skeleton.get_bone_pose(bone_index))
	return transforms


static func _assert_global_transforms(
	skeleton: MHSkeleton,
	expected: Dictionary[StringName, Transform3D],
) -> void:
	for bone_name in expected:
		var bone_index := skeleton.find_bone(bone_name)
		assert(bone_index >= 0, "bone %s should belong to the skeleton" % bone_name)
		assert_approx_eq(
			skeleton.get_bone_global_pose(bone_index),
			expected[bone_name],
			1e-6,
			"global pose for %s" % bone_name,
		)
