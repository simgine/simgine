extends TestSuite
## Proxy instance integration.

const ELEGANT_SUIT := preload(
	"res://characters/visuals/make_human/items/clothes/female_elegantsuit01/female_elegantsuit01.mhclo"
)
const SPORTS_SUIT := preload(
	"res://characters/visuals/make_human/items/clothes/female_sportsuit01/female_sportsuit01.mhclo"
)


func test_clothing_lifecycle() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	const BODY_TRIANGLES := 26756
	assert_eq(instance.mesh.surface_get_array_index_len(0), BODY_TRIANGLES * 3)

	var clothing := MHProxyInstance.new()
	clothing.proxy = ELEGANT_SUIT
	instance.add_child(clothing)

	await get_tree().process_frame

	assert_eq(
		instance.mesh.surface_get_array_index_len(0),
		21746 * 3,
		"clothing should hide covered body faces",
	)
	assert(instance.skin)
	assert_eq(clothing.skin, instance.skin)
	assert_eq(clothing.get_node(clothing.skeleton), instance.skeleton_node)
	_assert_skinning(instance, instance.body.skinning)
	_assert_skinning(clothing, instance.body.get_proxy_skinning(clothing.proxy))

	# Recorded clothing source vertices, in meters after fitting and grounding:
	# front torso (1522), outer sleeve (1795), and front skirt hem (386).
	_assert_positions(
		clothing,
		{
			1522: Vector3(-0.000751618587, 1.137916922569, 0.150293931365),
			1795: Vector3(-0.429773181677, 1.006238937378, 0.203491702676),
			386: Vector3(0.000000000000, 0.551250219345, 0.135504558682),
		},
	)

	instance.set_modifier("height", 0.8)

	await get_tree().process_frame

	_assert_positions(
		clothing,
		{
			1522: Vector3(-0.000880602573, 1.464612007141, 0.176758244634),
			1795: Vector3(-0.532414197922, 1.280998587608, 0.256894916296),
			386: Vector3(0.000000000000, 0.757902681828, 0.158879652619),
		},
	)

	assert(instance.skin)
	assert_eq(clothing.skin, instance.skin)
	assert_eq(clothing.get_node(clothing.skeleton), instance.skeleton_node)

	instance.set_modifier("torso-scale-depth-decr-incr", 0.65)

	await get_tree().process_frame

	_assert_positions(
		clothing,
		{
			1522: Vector3(-0.000880602573, 1.464612007141, 0.195925399661),
			1795: Vector3(-0.532414197922, 1.280998587608, 0.256894916296),
			386: Vector3(0.000000000000, 0.757902681828, 0.158879652619),
		},
	)
	assert_eq(instance.mesh.surface_get_array_index_len(0), 21746 * 3)
	_assert_skinning(instance, instance.body.skinning)
	_assert_skinning(clothing, instance.body.get_proxy_skinning(clothing.proxy))

	clothing.queue_free()

	# Deletion happens at frame end, then the body rebuilds its visibility mask.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(instance.mesh.surface_get_array_index_len(0), BODY_TRIANGLES * 3)


func test_proxy_replacement() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	var clothing := MHProxyInstance.new()
	clothing.proxy = ELEGANT_SUIT
	instance.add_child(clothing)

	await get_tree().process_frame

	assert_eq(instance.mesh.surface_get_array_index_len(0), 21746 * 3)

	clothing.proxy = SPORTS_SUIT

	await get_tree().process_frame

	assert_eq(
		instance.mesh.surface_get_array_index_len(0),
		22892 * 3,
		"replacement should discard the previous clothing's delete mask",
	)
	assert_eq(clothing.mesh.surface_get_material(0), SPORTS_SUIT.material)
	assert(instance.skin)
	assert_eq(clothing.skin, instance.skin)
	assert_eq(clothing.get_node(clothing.skeleton), instance.skeleton_node)
	_assert_skinning(clothing, instance.body.get_proxy_skinning(SPORTS_SUIT))

	# Recorded sportsuit torso (0), shoulder (44), and lower hem (1633),
	# in meters after fitting and grounding.
	_assert_positions(
		clothing,
		{
			0: Vector3(0.091119125485, 1.174982547760, -0.055272981524),
			44: Vector3(0.110115773976, 1.387498974800, 0.028883960098),
			1633: Vector3(0.163661763072, 0.076937094331, -0.017548732460),
		},
	)


func test_combined_masks() -> void:
	var instance := _create_instance()

	await get_tree().process_frame

	# The suits overlap, but each also hides body regions the other leaves visible.
	var elegant_suit := MHProxyInstance.new()
	elegant_suit.proxy = ELEGANT_SUIT
	instance.add_child(elegant_suit)

	var sportsuit := MHProxyInstance.new()
	sportsuit.proxy = SPORTS_SUIT
	instance.add_child(sportsuit)

	await get_tree().process_frame

	assert_eq(
		instance.mesh.surface_get_array_index_len(0),
		20036 * 3,
		"both clothing masks should contribute",
	)

	elegant_suit.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(
		instance.mesh.surface_get_array_index_len(0),
		22892 * 3,
		"removing one attachment should preserve the remaining clothing's mask",
	)


func _create_instance() -> MHBodyInstance:
	var skeleton := MHSkeleton.new()
	add_child(skeleton)

	var instance := MHBodyInstance.new()
	instance.body = load("res://characters/visuals/make_human/body.tres") as MHBody
	skeleton.add_child(instance)
	instance.skeleton_node = skeleton

	return instance


static func _assert_positions(
	clothing: MHProxyInstance,
	expected_positions: Dictionary[int, Vector3],
) -> void:
	var surface := clothing.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
	var geometry_indices := clothing.proxy.geometry.topology.geometry_indices
	for vertex_index in expected_positions:
		var render_index := geometry_indices.find(vertex_index)
		assert(render_index >= 0, "vertex %d must belong to the rendered clothing" % vertex_index)
		assert_approx_eq(
			vertices[render_index],
			expected_positions[vertex_index],
			1e-6,
			"clothing vertex %d" % vertex_index,
		)


static func _assert_skinning(instance: MeshInstance3D, expected: MHSkinning) -> void:
	var surface := instance.mesh.surface_get_arrays(0)
	assert_eq(surface[Mesh.ARRAY_BONES], expected.render_bones)

	# Godot stores surface weights as normalized 16-bit integers.
	const WEIGHT_TOLERANCE := 1.0 / 65535.0
	var weights: PackedFloat32Array = surface[Mesh.ARRAY_WEIGHTS]
	assert_eq(weights.size(), expected.render_weights.size())
	for index in weights.size():
		assert(
			absf(weights[index] - expected.render_weights[index]) <= WEIGHT_TOLERANCE,
			"render weight %d should match skinning within mesh quantization" % index,
		)
