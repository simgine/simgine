extends TestSuite
## Body shape and mesh geometry.


func test_uv_seam_normals() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# Neck vertex 745 has two UVs but shares one smooth normal across the seam.
	var geometry_indices := instance.body.geometry.topology.geometry_indices
	var seam_indices: PackedInt32Array
	for render_index in geometry_indices.size():
		if geometry_indices[render_index] == 745:
			seam_indices.append(render_index)
	assert_eq(seam_indices.size(), 2)

	var surface := instance.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = surface[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = surface[Mesh.ARRAY_TEX_UV]
	assert_approx_eq(
		[uvs[seam_indices[0]], uvs[seam_indices[1]]],
		[Vector2(0.343712002039, 0.046560000628), Vector2(0.930362999439, 0.656949996948)],
	)
	for render_index in seam_indices:
		assert_approx_eq(
			normals[render_index],
			Vector3(-0.952099800110, -0.296429157257, 0.075071737170),
		)

	instance.set_modifier("height", 0.8)

	await get_tree().process_frame

	surface = instance.mesh.surface_get_arrays(0)
	normals = surface[Mesh.ARRAY_NORMAL]
	assert_eq(surface[Mesh.ARRAY_TEX_UV], uvs)
	for render_index in seam_indices:
		assert_approx_eq(
			normals[render_index],
			Vector3(-0.948856115341, -0.308167397976, 0.068591743708),
			1e-6,
			"seam normals should be rebuilt after deformation",
		)


func test_modifier_properties() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# Collect property list to verify they're visible in the inspector.
	# Checkig on the instance would just trigger `_get()`.
	var property_names: Dictionary[StringName, bool]
	for property in instance.get_property_list():
		property_names[property.name] = true

	assert("modifiers/height" in property_names)
	instance.set("modifiers/height", 0.8)
	assert_eq(instance.get_modifier("height"), 0.8)
	assert_eq(instance.get("modifiers/height"), 0.8)

	assert("modifiers/race/african" in property_names)
	instance.set("modifiers/race/african", 0.2)
	assert_eq(instance.get_modifier("african"), 0.2)
	assert_eq(instance.get("modifiers/race/african"), 0.2)

	assert("modifiers/torso/torso-scale-depth-decr-incr" in property_names)
	instance.set("modifiers/torso/torso-scale-depth-decr-incr", 0.65)
	assert_eq(instance.get_modifier("torso-scale-depth-decr-incr"), 0.65)
	assert_eq(instance.get("modifiers/torso/torso-scale-depth-decr-incr"), 0.65)

	assert("modifiers/arms/lowerarm-fat-decr-incr/left" in property_names)
	instance.set("modifiers/arms/lowerarm-fat-decr-incr/left", -0.6)
	assert_eq(instance.get_modifier("lowerarm-fat-decr-incr/left"), -0.6)
	assert_eq(instance.get("modifiers/arms/lowerarm-fat-decr-incr/left"), -0.6)


func test_modifiers() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# Recorded from body.tres at default modifiers, in meters after grounding.
	var initial_positions: Dictionary[int, Vector3] = {
		881: Vector3(0.0, 1.659430980682, 0.050173383206), # Crown: overall height.
		5796: Vector3(-0.167987123132, 0.003242790699, 0.156755611300), # Sole: near ground.
		8985: Vector3(0.525523960590, 0.889064371586, 0.276422828436), # Outer left hand.
		4093: Vector3(0.0, 1.124921679497, 0.139985859394), # Front torso.
	}
	_assert_positions(instance, initial_positions)

	instance.set_modifier("head-round", 0.65)

	await get_tree().process_frame

	_assert_positions(
		instance,
		{
			881: Vector3(0.0, 1.655530929565, 0.051538385451),
			4093: Vector3(0.0, 1.124921679497, 0.139985859394),
		},
	)

	instance.set_modifier("head-round", MHTargetRegistry.DEFAULT_VALUE)

	await get_tree().process_frame

	_assert_positions(instance, initial_positions)


func test_opposite_modifiers() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# Recorded crown and front-torso positions, in meters after grounding.
	var initial_positions: Dictionary[int, Vector3] = {
		881: Vector3(0.0, 1.659430980682, 0.050173383206),
		4093: Vector3(0.0, 1.124921679497, 0.139985859394),
	}
	_assert_positions(instance, initial_positions)

	instance.set_modifier("torso-scale-depth-decr-incr", 0.65)

	await get_tree().process_frame

	_assert_positions(
		instance,
		{
			881: Vector3(0.0, 1.659430980682, 0.050173383206),
			4093: Vector3(0.0, 1.124921679497, 0.157665863633),
		},
	)

	instance.set_modifier("torso-scale-depth-decr-incr", MHTargetRegistry.DEFAULT_VALUE)

	await get_tree().process_frame

	_assert_positions(instance, initial_positions)


func test_sided_modifiers() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# Recorded left (10098) and right (3469) forearm samples.
	var initial_left := instance.morphed_vertices[10098]
	instance.set_modifier("lowerarm-fat-decr-incr/left", -0.6)
	instance.set_modifier("lowerarm-fat-decr-incr/right", 0.8)

	await get_tree().process_frame

	_assert_positions(
		instance,
		{
			10098: Vector3(0.385108053684, 1.123149514198, 0.083278357983),
			3469: Vector3(-0.363518625498, 1.043293118477, 0.124034881592),
		},
	)

	instance.set_modifier("lowerarm-fat-decr-incr/left", MHTargetRegistry.DEFAULT_VALUE)

	await get_tree().process_frame

	_assert_positions(
		instance,
		{ 10098: initial_left, 3469: Vector3(-0.363518625498, 1.043293118477, 0.124034881592) },
	)


func test_macro_modifiers() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# Recorded crown and front-torso positions, in meters after grounding.
	var initial_positions: Dictionary[int, Vector3] = {
		881: Vector3(0.0, 1.659430980682, 0.050173383206),
		4093: Vector3(0.0, 1.124921679497, 0.139985859394),
	}
	_assert_positions(instance, initial_positions)

	# Recorded crown and front-torso positions, in meters after grounding.
	instance.set_modifier("height", 0.8)
	instance.set_modifier("gender", 0.25)
	instance.set_modifier("age", 0.75)

	await get_tree().process_frame

	_assert_positions(
		instance,
		{
			881: Vector3(0.0, 2.035971641541, 0.071170903742),
			4093: Vector3(0.0, 1.427052021027, 0.161469981074),
		},
	)

	# No proportions targets at its default value, so check a non-default value too.
	instance.set_modifier("proportions", 0.75)

	await get_tree().process_frame

	_assert_positions(
		instance,
		{
			881: Vector3(0.0, 2.039295196533, 0.071170903742),
			4093: Vector3(0.0, 1.429024219513, 0.158694237471),
		},
	)

	instance.set_modifier("height", MHMacroRegistry.DEFAULT_VALUE)
	instance.set_modifier("gender", MHMacroRegistry.DEFAULT_VALUE)
	instance.set_modifier("age", MHMacroRegistry.DEFAULT_VALUE)
	instance.set_modifier("proportions", MHMacroRegistry.DEFAULT_VALUE)

	await get_tree().process_frame

	_assert_positions(instance, initial_positions)


func test_macro_weight_exclusions() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# Recorded breast vertex, in meters after grounding.
	var initial_positions: Dictionary[int, Vector3] = {
		1834: Vector3(-0.086785726249, 1.183422803879, 0.139404252172),
	}
	_assert_positions(instance, initial_positions)

	# Breast targets select the female component without multiplying by its gender weight.
	instance.set_modifier("gender", 0.25)
	instance.set_modifier("cupsize", 0.8)
	instance.set_modifier("firmness", 0.7)

	await get_tree().process_frame

	_assert_positions(instance, { 1834: Vector3(-0.081886738539, 1.108692646027, 0.153901517391) })

	instance.set_modifier("gender", MHMacroRegistry.DEFAULT_VALUE)
	instance.set_modifier("cupsize", MHMacroRegistry.DEFAULT_VALUE)
	instance.set_modifier("firmness", MHMacroRegistry.DEFAULT_VALUE)

	await get_tree().process_frame

	_assert_positions(instance, initial_positions)


func test_race_modifiers() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# Recorded crown and front-torso positions, in meters after grounding.
	var initial_positions: Dictionary[int, Vector3] = {
		881: Vector3(0.0, 1.659430980682, 0.050173383206),
		4093: Vector3(0.0, 1.124921679497, 0.139985859394),
	}
	_assert_positions(instance, initial_positions)

	instance.set_modifier("african", 0.2)
	instance.set_modifier("asian", 0.3)
	instance.set_modifier("caucasian", 0.5)

	await get_tree().process_frame

	_assert_positions(
		instance,
		{
			881: Vector3(0.0, 1.654455184937, 0.050955366343),
			4093: Vector3(0.0, 1.121914863586, 0.139595344663),
		},
	)

	for race in MHMacroRegistry.RACES:
		instance.set_modifier(race, MHMacroRegistry.DEFAULT_RACE_VALUE)

	await get_tree().process_frame

	_assert_positions(instance, initial_positions)


func test_instance_isolation() -> void:
	var first := _create_instance()
	var second := _create_instance()
	var body := first.body
	assert_eq(second.body, body)
	var source_vertices := body.geometry.vertices.duplicate()

	await get_tree().process_frame

	var initial_positions: Dictionary[int, Vector3] = {
		881: second.morphed_vertices[881],
		4093: second.morphed_vertices[4093],
	}
	_assert_positions(first, initial_positions)

	first.set_modifier("height", 0.8)
	first.set_modifier("torso-scale-depth-decr-incr", 0.65)

	await get_tree().process_frame

	var modified_positions: Dictionary[int, Vector3] = {
		881: Vector3(0.0, 2.078630208969, 0.061192732304),
		4093: Vector3(0.0, 1.448368668556, 0.182198420167),
	}
	_assert_positions(first, modified_positions)
	_assert_positions(second, initial_positions)
	assert_eq(body.geometry.vertices, source_vertices, "shared source geometry is unchanged")

	second.set_modifier("height", MHMacroRegistry.DEFAULT_VALUE)

	await get_tree().process_frame

	_assert_positions(second, initial_positions)
	_assert_positions(first, modified_positions)
	assert_eq(body.geometry.vertices, source_vertices, "rebuilding preserves source geometry")


func _create_instance() -> MHBodyInstance:
	var skeleton := MHSkeleton.new()
	add_child(skeleton)

	var instance := MHBodyInstance.new()
	instance.body = load("res://characters/visuals/make_human/body.tres") as MHBody
	skeleton.add_child(instance)
	instance.skeleton_node = skeleton

	return instance


static func _assert_positions(
	instance: MHBodyInstance,
	expected_positions: Dictionary[int, Vector3],
) -> void:
	var surface := instance.mesh.surface_get_arrays(0)
	var rendered_vertices: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
	var geometry_indices := instance.body.geometry.topology.geometry_indices
	for vertex_index in expected_positions:
		var expected := expected_positions[vertex_index]
		assert_approx_eq(
			instance.morphed_vertices[vertex_index],
			expected,
			1e-6,
			"body vertex %d" % vertex_index,
		)
		var render_index := geometry_indices.find(vertex_index)
		assert(render_index >= 0, "sample must belong to the rendered body")
		assert_approx_eq(
			rendered_vertices[render_index],
			expected,
			1e-6,
			"render vertex %d" % vertex_index,
		)
