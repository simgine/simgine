extends TestSuite

const QUAD_INDICES: PackedInt32Array = [0, 1, 2, 3]
const INITIAL_VERTICES: PackedVector3Array = [
	Vector3.ZERO,
	Vector3.RIGHT,
	Vector3(1, 1, 0),
	Vector3.UP,
	Vector3.DOWN, # Non-rendered helper below ground.
]


func test_modifier_updates() -> void:
	var instance := _instance(_body(), _proxy())

	await get_tree().process_frame

	# The source quad spans Y=10..20 dm and its helper is at Y=0 dm.
	# After conversion and grounding, the quad spans Y=0..1 m and the helper is at -1 m.
	_assert_positions(instance, INITIAL_VERTICES)

	var expected := INITIAL_VERTICES.duplicate()

	instance.set_modifier("height", 0.75)

	await get_tree().process_frame

	expected[2] += Vector3.UP
	_assert_positions(instance, expected, "height updates the body and attachment")

	instance.set_modifier("width", 1.0)

	await get_tree().process_frame

	expected[2] += Vector3.RIGHT
	_assert_positions(instance, expected, "local update preserves macro")

	instance.set_modifier("width", 0.5)

	await get_tree().process_frame

	expected[2] -= Vector3.RIGHT * 0.5
	_assert_positions(
		instance,
		expected,
		"changing width replaces its previous contribution while preserving macro deformation",
	)

	instance.set_modifier("height", MHMacroRegistry.DEFAULT_VALUE)
	instance.set_modifier("width", MHTargetRegistry.DEFAULT_VALUE)

	await get_tree().process_frame

	_assert_positions(instance, INITIAL_VERTICES, "restoring defaults removes all deformation")


func test_instance_isolation() -> void:
	var body := _body()
	var proxy := _proxy()
	var source_body_vertices := body.geometry.vertices.duplicate()
	var source_proxy_vertices := proxy.geometry.vertices.duplicate()

	var first := _instance(body, proxy)
	var second := _instance(body, proxy)

	await get_tree().process_frame

	_assert_positions(first, INITIAL_VERTICES)
	_assert_positions(second, INITIAL_VERTICES)

	first.set_modifier("height", 0.75)
	first.set_modifier("width", 1.0)

	await get_tree().process_frame

	var expected := INITIAL_VERTICES.duplicate()
	expected[2] += Vector3.UP + Vector3.RIGHT
	_assert_positions(first, expected)
	_assert_positions(second, INITIAL_VERTICES, "modifying first leaves second unchanged")

	# Rebuild the second instance too, to detect a corrupted shared base or macro cache.
	second.set_modifier("width", MHTargetRegistry.DEFAULT_VALUE)

	await get_tree().process_frame

	_assert_positions(first, expected, "rebuilding second instance leaves first unchanged")
	_assert_positions(second, INITIAL_VERTICES)
	assert_eq(body.geometry.vertices, source_body_vertices)
	assert_eq(proxy.geometry.vertices, source_proxy_vertices)


static func _assert_positions(
	instance: MHBodyInstance,
	expected: PackedVector3Array,
	msg: String = "",
) -> void:
	assert_approx_eq(instance.morphed_vertices, expected, 1e-6, msg)

	var rendered := expected.slice(0, 4)
	assert_approx_eq(instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], rendered, 1e-6, msg)

	var attachment: MHProxyInstance = instance.get_node("Attachment")
	assert_approx_eq(attachment.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], rendered, 1e-6, msg)


func _instance(body: MHBody, proxy: MHProxy) -> MHBodyInstance:
	var instance := MHBodyInstance.new()
	var skeleton := MHSkeleton.new()
	instance.add_child(skeleton)
	instance.skeleton_node = skeleton
	instance.body = body

	var attachment := MHProxyInstance.new()
	attachment.name = "Attachment"
	attachment.proxy = proxy
	instance.add_child(attachment)
	add_child(instance)

	return instance


static func _body() -> MHBody:
	var body := MHBody.new()
	body.geometry = MHBodyGeometry.new()
	body.geometry.vertices = [
		Vector3(0, 10, 0),
		Vector3(10, 10, 0),
		Vector3(10, 20, 0),
		Vector3(0, 20, 0),
		Vector3.ZERO, # Helper, excluded from rendered faces and the ground search.
	]
	body.geometry.uvs = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	body.geometry.quads = [_quad()]
	body.vertex_groups = MHVertexGroups.new()
	body.vertex_groups.ranges = { "body": PackedInt32Array([0, 3]) }

	# At height=0.75, vertex 2 moves up 1 m. At width=1.0, it moves right 1 m.
	var part := MHMacroPart.new()
	part.lowest = 0.5
	part.highest = 1.0
	part.high = "tall"

	var macro := MHMacro.new()
	macro.parts = [part]

	var combination := MHMacroCombination.new()
	combination.dimensions = ["height"]
	combination.targets = { "tall": _target(Vector3.UP * 20) }

	body.macro_registry = MHMacroRegistry.new()
	body.macro_registry.macrotargets = { "height": macro }
	body.macro_registry.combinations = [combination]

	var category := MHTargetCategory.new()
	category.targets = { "width": _target(Vector3.RIGHT * 10) }

	var section := MHTargetSection.new()
	section.categories = [category]

	body.target_registry = MHTargetRegistry.new()
	body.target_registry.sections = [section]

	# A single bone supplies valid skinning without testing skeleton mathematics.
	var bone := MHBone.new()
	bone.head = MHRigPosition.new()
	bone.head.strategy = MHRigPosition.Strategy.VERTEX
	bone.head.vertex_indices = [0]
	bone.tail = MHRigPosition.new()
	bone.tail.strategy = MHRigPosition.Strategy.VERTEX
	bone.tail.vertex_indices = [3]
	body.rig = MHRig.new()
	body.rig.bones = { "root": bone }

	var bone_weights := MHBoneWeights.new()
	bone_weights.vertices = [0, 1, 2, 3, 4]
	bone_weights.weights = [1, 1, 1, 1, 1]

	body.rig_weights = MHRigWeights.new()
	body.rig_weights.bones = { "root": bone_weights }

	return body


static func _proxy() -> MHProxy:
	var proxy := MHProxy.new()
	proxy.geometry = MHGeometry.new()
	proxy.geometry.vertices = [
		Vector3.ZERO,
		Vector3.RIGHT * 10,
		Vector3(10, 10, 0),
		Vector3.UP * 10,
	]
	proxy.geometry.uvs = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	proxy.geometry.quads = [_quad()]
	# Mirror the body quad exactly, so both meshes have the same expected positions.
	proxy.ref_a = QUAD_INDICES
	proxy.ref_b = QUAD_INDICES
	proxy.ref_c = QUAD_INDICES
	proxy.weights = [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT]
	proxy.offsets = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]

	var scale := MHScale.new()
	scale.min_vertex = 0
	scale.max_vertex = 2
	scale.factor = 1.0
	proxy.x_scale = scale
	proxy.y_scale = scale
	proxy.z_scale = scale

	return proxy


static func _quad() -> MHQuad:
	var quad := MHQuad.new()
	quad.vertex_indices = QUAD_INDICES
	quad.uv_indices = QUAD_INDICES
	return quad


static func _target(offset: Vector3) -> MHTarget:
	var target := MHTarget.new()
	target.vertex_indices = [2]
	target.offsets = [offset]
	return target
