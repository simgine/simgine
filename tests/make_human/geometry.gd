extends TestSuite


func test_uv_seams() -> void:
	var geometry := _geometry()
	var surface := geometry.build_surface()

	assert_eq(
		surface[Mesh.ARRAY_VERTEX],
		[
			Vector3.ZERO,
			Vector3.RIGHT,
			Vector3(1, 1, 0),
			Vector3.UP,
			Vector3.RIGHT,
			Vector3(1, 0, 2),
			Vector3(1, 1, 2),
		],
		"UV seams split render vertices and unused helpers are omitted",
	)
	assert_eq(surface[Mesh.ARRAY_TEX_UV], geometry.uvs)
	assert_eq(surface[Mesh.ARRAY_INDEX], [0, 2, 1, 0, 3, 2, 4, 6, 5, 4, 2, 6])


func test_smooth_normals() -> void:
	var geometry := _geometry()
	var surface := geometry.build_surface()

	# Vertex normals come from adding the normals of their triangles.
	# Each triangle contributes (0, 0, 1) on the first quad or (-2, 0, 0) on the second.
	# Vertex 1 uses one triangle from the first quad and two from the second.
	# Vertex 2 uses two from the first and one from the second.
	assert_approx_eq(
		surface[Mesh.ARRAY_NORMAL],
		[
			Vector3.BACK,
			Vector3(-4, 0, 1).normalized(),
			Vector3(-1, 0, 1).normalized(),
			Vector3.BACK,
			Vector3(-4, 0, 1).normalized(), # Same vertex and normal, different UV.
			Vector3.LEFT,
			Vector3.LEFT,
		],
	)

	# Make the second quad half as wide.
	var vertices := geometry.vertices.duplicate()
	vertices[4].z = 1
	vertices[5].z = 1
	var deformed := geometry.build_surface(vertices)

	# Both quads now have equal areas, so each triangle has the same weight.
	assert_approx_eq(
		deformed[Mesh.ARRAY_NORMAL],
		[
			Vector3.BACK,
			Vector3(-2, 0, 1).normalized(),
			Vector3(-1, 0, 2).normalized(),
			Vector3.BACK,
			Vector3(-2, 0, 1).normalized(),
			Vector3.LEFT,
			Vector3.LEFT,
		],
	)
	assert_eq(
		deformed[Mesh.ARRAY_VERTEX],
		[
			Vector3.ZERO,
			Vector3.RIGHT,
			Vector3(1, 1, 0),
			Vector3.UP,
			Vector3.RIGHT,
			Vector3(1, 0, 1),
			Vector3(1, 1, 1),
		],
	)
	assert_eq(deformed[Mesh.ARRAY_TEX_UV], surface[Mesh.ARRAY_TEX_UV])
	assert_eq(deformed[Mesh.ARRAY_INDEX], surface[Mesh.ARRAY_INDEX])
	assert_eq(geometry.vertices[4], Vector3(1, 0, 2))
	assert_eq(geometry.vertices[5], Vector3(1, 1, 2))


static func _geometry() -> MHGeometry:
	# Two quads folded at 90 degrees along their shared edge between vertices 1 and 2.
	# The first is 1x1 in the XY plane, facing +Z. The second is 1x2 in YZ, facing -X.
	# The second has twice the area, so its triangles contribute twice as much to normals.
	var geometry := MHGeometry.new()
	geometry.vertices = [
		Vector3.ZERO,
		Vector3.RIGHT,
		Vector3(1, 1, 0),
		Vector3.UP,
		Vector3(1, 0, 2),
		Vector3(1, 1, 2),
		Vector3(9, 9, 9), # Unused helper vertex.
	]
	geometry.uvs = [
		Vector2.ZERO,
		Vector2.RIGHT,
		Vector2.ONE,
		Vector2.DOWN,
		Vector2(0.5, 0),
		Vector2(0.5, 0.5),
		Vector2(0.5, 1),
	]
	geometry.quads = [_quad([0, 1, 2, 3], [0, 1, 2, 3]), _quad([1, 4, 5, 2], [4, 5, 6, 2])]
	return geometry


static func _quad(vertex_indices: PackedInt32Array, uv_indices: PackedInt32Array) -> MHQuad:
	var quad := MHQuad.new()
	quad.vertex_indices = vertex_indices
	quad.uv_indices = uv_indices
	return quad
