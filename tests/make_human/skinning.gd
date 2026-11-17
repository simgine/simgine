extends TestSuite
## Vertex bone influences.

# Configured with the game-engine rig and its bone weights.
const BODY: String = "res://characters/visuals/make_human/body.tres"


func test_mesh_weights() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	var skeleton := instance.skeleton_node
	var surface := instance.mesh.surface_get_arrays(0)
	var geometry_indices := instance.body.geometry.topology.geometry_indices

	# The torso sample blends pelvis and spine bones in the emitted mesh.
	var offset := geometry_indices.find(4093) * MHSkinning.MAX_INFLUENCES
	var render_bones: PackedInt32Array = surface[Mesh.ARRAY_BONES]
	var render_weights: PackedFloat32Array = surface[Mesh.ARRAY_WEIGHTS]
	var bone_names: PackedStringArray
	for bone_index in render_bones.slice(offset, offset + 4):
		bone_names.append(skeleton.get_bone_name(bone_index))
	assert_eq(bone_names, ["Hips", "Spine", "Chest", "UpperChest"])
	assert_approx_eq(
		render_weights.slice(offset, offset + MHSkinning.MAX_INFLUENCES),
		[0.012588692829, 0.148210883141, 0.309025704861, 0.530144214630, 0, 0, 0, 0],
	)


func test_body_weights() -> void:
	var body := load(BODY) as MHBody

	# Recorded rigid head vertex and neck seam with the configured game-engine rig.
	_assert_influences(
		body.skinning,
		body.geometry,
		4848,
		[22, 0, 0, 0, 0, 0, 0, 0],
		[1, 0, 0, 0, 0, 0, 0, 0],
	)
	# neck_01 precedes head in rig order, despite having the smaller weight.
	_assert_influences(
		body.skinning,
		body.geometry,
		745,
		[21, 22, 0, 0, 0, 0, 0, 0],
		[0.349899947643, 0.650099992752, 0, 0, 0, 0, 0, 0],
	)


func test_proxy_weights() -> void:
	var body := load(BODY) as MHBody
	# Contains three-reference blends and UV seams.
	var proxy := load(
		"res://characters/visuals/make_human/items/clothes/female_sportsuit01/female_sportsuit01.mhclo"
	) as MHProxy
	var skinning := body.get_proxy_skinning(proxy)

	# Recorded on the sportsuit with the configured game-engine rig.
	# Upper torso: spine_03, spine_02, upperarm_l, spine_01.
	# A sub-threshold influence is filtered before normalization.
	_assert_influences(
		skinning,
		proxy.geometry,
		0,
		[12, 11, 15, 10, 0, 0, 0, 0],
		[0.864434003830, 0.120375126600, 0.010799696669, 0.004391174763, 0, 0, 0, 0],
	)
	# Shoulder UV seam: clavicle_l, upperarm_l, neck_01, spine_03.
	# All render copies must retain the same blended influences.
	_assert_influences(
		skinning,
		proxy.geometry,
		44,
		[13, 15, 21, 12, 0, 0, 0, 0],
		[0.437000513077, 0.267681658268, 0.183887720108, 0.111430101097, 0, 0, 0, 0],
	)


func test_direct_mapping() -> void:
	var body := load(BODY) as MHBody
	# Includes direct vertex mappings alongside its three-reference fits.
	var proxy := load("res://characters/visuals/make_human/items/hair/afro01/afro01.mhclo") as MHProxy
	var skinning := body.get_proxy_skinning(proxy)

	# Afro vertex 887 maps only to body vertex 12015: head and neck_01.
	# The other two references have zero fitting factors.
	_assert_influences(
		skinning,
		proxy.geometry,
		887,
		[22, 21, 0, 0, 0, 0, 0, 0],
		[0.992800712585, 0.007199279964, 0, 0, 0, 0, 0, 0],
	)


func test_influence_filtering() -> void:
	var body := load(BODY) as MHBody
	# Has negative fitting factors that yield negative bone contributions.
	var proxy := load(
		"res://characters/visuals/make_human/items/clothes/female_sportsuit01/female_sportsuit01.mhclo"
	) as MHProxy
	var skinning := body.get_proxy_skinning(proxy)

	# spine_01 contributes about -0.00207: rejected despite its magnitude exceeding 0.001.
	# spine_03 and spine_02 are renormalized.
	_assert_influences(
		skinning,
		proxy.geometry,
		792,
		[12, 11, 0, 0, 0, 0, 0, 0],
		[0.979588508606, 0.020411482081, 0, 0, 0, 0, 0, 0],
	)


func test_missing_bone_weights() -> void:
	var body := load(BODY) as MHBody

	# The bundled weights include every bone, but MPFB2 allows missing entries.
	# Omit the empty Root entry from a copy to test that case.
	var rig_weights := MHRigWeights.new()
	rig_weights.bones = body.rig_weights.bones.duplicate()
	rig_weights.bones.erase("Root")

	var skinning := MHSkinning.new()
	skinning.build_from_rig(body.geometry, body.rig, rig_weights)

	assert_eq(skinning.bones, body.skinning.bones, "missing weights must not shift bone indices")
	assert_eq(skinning.weights, body.skinning.weights)
	assert_eq(skinning.render_bones, body.skinning.render_bones)
	assert_eq(skinning.render_weights, body.skinning.render_weights)


func test_influence_pruning() -> void:
	# No bundled proxy needs pruning with the configured rig, so use synthetic weights.
	# Each reference has four normalized influences.
	# References 0 and 2 share bone 3.
	var body := _body_skinning(
		[
			[0.4, 0, 0],
			[0.3, 0, 0],
			[0.2, 0, 0],
			[0.1, 0, 0.1],
			[0, 0.4, 0],
			[0, 0.3, 0],
			[0, 0.2, 0],
			[0, 0.1, 0],
			[0, 0, 0.4],
			[0, 0, 0.3],
			[0, 0, 0.2],
		],
	)

	var skinning := MHSkinning.new()
	skinning.build_from_proxy(body, _proxy(Vector3(0.5, 0.35, 0.15)))

	# Merge bone 3's 0.05 + 0.015 before pruning, ranking it above bone 8's 0.06.
	# The retained contributions sum to 0.89, not the original total of 1.
	# fmt: off
	assert_eq(skinning.bones, [0, 1, 4, 5, 2, 6, 3, 8])
	assert_approx_eq(
		skinning.weights,
		[0.2 / 0.89, 0.15 / 0.89, 0.14 / 0.89, 0.105 / 0.89, 0.1 / 0.89, 0.07 / 0.89, 0.065 / 0.89, 0.06 / 0.89],
	)
	# fmt: on


func _create_instance() -> MHBodyInstance:
	var skeleton := MHSkeleton.new()
	add_child(skeleton)

	var instance := MHBodyInstance.new()
	instance.body = load("res://characters/visuals/make_human/body.tres") as MHBody
	skeleton.add_child(instance)
	instance.skeleton_node = skeleton

	return instance


static func _assert_influences(
	skinning: MHSkinning,
	geometry: MHGeometry,
	vertex_index: int,
	expected_bones: PackedInt32Array,
	expected_weights: PackedFloat32Array,
) -> void:
	var offset := vertex_index * MHSkinning.MAX_INFLUENCES
	var end := offset + MHSkinning.MAX_INFLUENCES
	assert_eq(skinning.bones.slice(offset, end), expected_bones)
	assert_approx_eq(skinning.weights.slice(offset, end), expected_weights)

	var geometry_indices := geometry.topology.geometry_indices
	assert(geometry_indices.has(vertex_index), "sample must belong to the rendered geometry")
	for render_index in geometry_indices.size():
		if geometry_indices[render_index] != vertex_index:
			continue

		offset = render_index * MHSkinning.MAX_INFLUENCES
		end = offset + MHSkinning.MAX_INFLUENCES
		assert_eq(
			skinning.render_bones.slice(offset, end),
			expected_bones,
			"render vertex %d bones" % render_index,
		)
		assert_approx_eq(
			skinning.render_weights.slice(offset, end),
			expected_weights,
			1e-6,
			"render vertex %d weights" % render_index,
		)


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
