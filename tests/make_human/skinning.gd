extends TestSuite


func test_body_weights() -> void:
	var rig := MHRig.new()
	rig.bones = { "unweighted": MHBone.new(), "first": MHBone.new(), "second": MHBone.new() }

	var rig_weights := MHRigWeights.new()
	# Deliberately reverse the rig order and omit the unweighted bone.
	rig_weights.bones = {
		"second": _bone_weights([2, 0], [0.6, 0.25]),
		"first": _bone_weights([1, 2, 0], [1.0, 0.4, 0.75]),
	}

	var geometry := _geometry(3, [2, 0, 1, 0])
	var skinning := MHSkinning.new()
	skinning.build_from_rig(geometry, rig, rig_weights)

	assert_eq(skinning.get_vertex_count(), 3)
	# fmt: off
	assert_eq(
		skinning.bones,
		[
			1, 2, 0, 0, 0, 0, 0, 0,
			1, 0, 0, 0, 0, 0, 0, 0,
			1, 2, 0, 0, 0, 0, 0, 0,
		],
	)
	assert_approx_eq(
		skinning.weights,
		[
			0.75, 0.25, 0, 0, 0, 0, 0, 0,
			1.0, 0, 0, 0, 0, 0, 0, 0,
			0.4, 0.6, 0, 0, 0, 0, 0, 0,
		],
	)
	assert_eq(
		skinning.render_bones,
		[
			1, 2, 0, 0, 0, 0, 0, 0,
			1, 2, 0, 0, 0, 0, 0, 0,
			1, 0, 0, 0, 0, 0, 0, 0,
			1, 2, 0, 0, 0, 0, 0, 0,
		],
	)
	assert_approx_eq(
		skinning.render_weights,
		[
			0.4, 0.6, 0, 0, 0, 0, 0, 0,
			0.75, 0.25, 0, 0, 0, 0, 0, 0,
			1.0, 0, 0, 0, 0, 0, 0, 0,
			0.75, 0.25, 0, 0, 0, 0, 0, 0,
		],
	)
	# fmt: on


func test_proxy_weights() -> void:
	var body := _body_skinning([[0.75, 0.25, 0.5], [0.25, 0, 0], [0, 0.75, 0], [0, 0, 0.5]])

	var proxy := _proxy(Vector3(0.5, 0.2, 0.3))
	proxy.ref_a = [2]
	proxy.ref_b = [0]
	proxy.ref_c = [1]

	var skinning := MHSkinning.new()
	skinning.build_from_proxy(body, proxy)

	# Bone 0 receives 0.5 * 0.5 + 0.75 * 0.2 + 0.25 * 0.3 = 0.475.
	assert_eq(skinning.bones, [0, 3, 2, 1, 0, 0, 0, 0])
	assert_approx_eq(skinning.weights, [0.475, 0.25, 0.225, 0.05, 0, 0, 0, 0])
	assert_eq(skinning.render_bones, skinning.bones)
	assert_eq(skinning.render_weights, skinning.weights)


func test_influence_pruning() -> void:
	# Each reference has four normalized influences.
	# Together they contribute twelve bones.
	var body := _body_skinning(
		[
			[0.4, 0, 0],
			[0.3, 0, 0],
			[0.2, 0, 0],
			[0.1, 0, 0],
			[0, 0.4, 0],
			[0, 0.3, 0],
			[0, 0.2, 0],
			[0, 0.1, 0],
			[0, 0, 0.4],
			[0, 0, 0.3],
			[0, 0, 0.2],
			[0, 0, 0.1],
		],
	)

	var skinning := MHSkinning.new()
	skinning.build_from_proxy(body, _proxy(Vector3(0.5, 0.35, 0.15)))

	assert_eq(skinning.bones, [0, 1, 4, 5, 2, 6, 8, 3])
	# The retained contributions sum to 0.875, not the original total of 1.
	assert_approx_eq(
		skinning.weights,
		[
			0.2 / 0.875,
			0.15 / 0.875,
			0.14 / 0.875,
			0.105 / 0.875,
			0.1 / 0.875,
			0.07 / 0.875,
			0.06 / 0.875,
			0.05 / 0.875,
		],
	)


func test_influence_filtering() -> void:
	var body := _body_skinning(
		[
			[0.5, 0.5, 0.25],
			[0.25, 0, 0.5],
			[0.125, 0.25, 0],
			[0.12475, 0.2495, 0],
			[0.00025, 0.0005, 0],
			[0, 0, 0.25],
		],
	)

	var skinning := MHSkinning.new()
	# Negative fitting factors occur in real proxies such as afro01.mhclo.
	skinning.build_from_proxy(body, _proxy(Vector3(1, 0.5, -0.5)))

	# Bone 1 cancels to zero, bone 4 contributes only 0.0005, and bone 5 is negative.
	assert_eq(skinning.bones, [0, 2, 3, 0, 0, 0, 0, 0])
	assert_approx_eq(
		skinning.weights,
		[0.625 / 1.1245, 0.25 / 1.1245, 0.2495 / 1.1245, 0, 0, 0, 0, 0],
	)


static func _bone_weights(
	vertex_indices: PackedInt32Array,
	vertex_weights: PackedFloat32Array,
) -> MHBoneWeights:
	var bone_weights := MHBoneWeights.new()
	bone_weights.vertices = vertex_indices
	bone_weights.weights = vertex_weights
	return bone_weights


static func _body_skinning(weights_by_bone: Array[PackedFloat32Array]) -> MHSkinning:
	var rig := MHRig.new()
	var rig_weights := MHRigWeights.new()
	for bone_index in weights_by_bone.size():
		var bone_name: StringName = "bone_%d" % bone_index
		rig.bones[bone_name] = MHBone.new()

		var bone_weights := MHBoneWeights.new()
		var vertex_weights := weights_by_bone[bone_index]
		for vertex_index in vertex_weights.size():
			if vertex_weights[vertex_index] > 0.0:
				bone_weights.vertices.append(vertex_index)
				bone_weights.weights.append(vertex_weights[vertex_index])

		rig_weights.bones[bone_name] = bone_weights

	var skinning := MHSkinning.new()
	skinning.build_from_rig(_geometry(weights_by_bone[0].size()), rig, rig_weights)

	return skinning


static func _proxy(fit_weights: Vector3) -> MHProxy:
	var proxy := MHProxy.new()
	proxy.geometry = _geometry(1, [0])
	proxy.ref_a = [0]
	proxy.ref_b = [1]
	proxy.ref_c = [2]
	proxy.weights = [fit_weights]
	proxy.offsets = [Vector3.ZERO]
	return proxy


static func _geometry(vertex_count: int, render_indices: PackedInt32Array = []) -> MHGeometry:
	var geometry := MHGeometry.new()
	geometry.vertices.resize(vertex_count)
	# Supply the already-expanded seam mapping.
	# Topology construction is tested separately.
	geometry.topology = MHGeometry.RenderTopology.new()
	geometry.topology.geometry_indices = render_indices
	return geometry
