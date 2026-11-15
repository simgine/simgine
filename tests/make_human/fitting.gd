extends TestSuite


func test_fitting() -> void:
	var proxy := MHProxy.new()
	proxy.geometry = MHGeometry.new()
	# Proxy's original positions.
	# Fitting should replace them with positions calculated from the body.
	proxy.geometry.vertices = [
		Vector3(9, 9, 9),
		Vector3(10, 9, 9),
		Vector3(10, 10, 9),
		Vector3(9, 10, 9),
	]
	proxy.geometry.uvs = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]

	var quad := MHQuad.new()
	quad.vertex_indices = [0, 1, 2, 3]
	quad.uv_indices = [0, 1, 2, 3]
	proxy.geometry.quads = [quad]

	proxy.ref_a = [1, 0, 2, 3]
	proxy.ref_b = [1, 1, 3, 0]
	proxy.ref_c = [1, 2, 0, 2]
	proxy.weights = [
		Vector3(1, 0, 0),
		Vector3(0.25, 0.25, 0.5),
		Vector3(0.5, 0.25, 0.25),
		Vector3(0.25, 0.5, 0.25),
	]
	proxy.offsets = [
		Vector3.ZERO,
		Vector3(0.5, -1, 2),
		Vector3(-1, 0.5, -0.25),
		Vector3(1, -0.5, 0.5),
	]
	proxy.x_scale = _scale(4, 5, 4)
	proxy.y_scale = _scale(5, 4, 6)
	proxy.z_scale = _scale(4, 5, 8)

	var body_vertices: PackedVector3Array = [
		Vector3.ZERO,
		Vector3(4, 0, 0),
		Vector3(0, 4, 0),
		Vector3(0, 0, 4),
		Vector3(8, 18, 32),
		Vector3.ZERO,
	]
	var original_body_vertices := body_vertices.duplicate()
	var original_proxy_vertices := proxy.geometry.vertices.duplicate()

	# Body vertices 4 and 5 are 8 apart on X, 18 on Y, and 32 on Z.
	# Divide by factors 4, 6, and 8, so offsets are multiplied by (2, 3, 4).
	# Each fitted position is the weighted body position plus the scaled offset.
	const FITTED_VERTICES: PackedVector3Array = [
		Vector3(4, 0, 0), # Body vertex 1, with no offset.
		Vector3(2, -1, 8), # (1, 2, 0) + (1, -3, 8).
		Vector3(-2, 3.5, 0), # (0, 2, 1) + (-2, 1.5, -1).
		Vector3(2, -0.5, 3), # (0, 1, 1) + (2, -1.5, 2).
	]
	var surface := proxy.build_fitted_surface(body_vertices)
	assert_eq(surface[Mesh.ARRAY_VERTEX], FITTED_VERTICES)

	# Fitting must not change either source array.
	assert_eq(body_vertices, original_body_vertices)
	assert_eq(proxy.geometry.vertices, original_proxy_vertices)

	# Move every body vertex by the same amount. Distances stay the same,
	# so the fitted proxy should move by that amount without changing shape.
	const TRANSLATION := Vector3(7, -5, 3)
	var translated_vertices := body_vertices.duplicate()
	for index in translated_vertices.size():
		translated_vertices[index] += TRANSLATION

	var expected_vertices := FITTED_VERTICES.duplicate()
	for index in expected_vertices.size():
		expected_vertices[index] += TRANSLATION

	var translated_body_vertices := translated_vertices.duplicate()
	var translated_surface := proxy.build_fitted_surface(translated_vertices)
	assert_eq(translated_surface[Mesh.ARRAY_VERTEX], expected_vertices)
	assert_eq(translated_vertices, translated_body_vertices)
	assert_eq(proxy.geometry.vertices, original_proxy_vertices)


static func _scale(min_vertex: int, max_vertex: int, factor: float) -> MHScale:
	var scale := MHScale.new()
	scale.min_vertex = min_vertex
	scale.max_vertex = max_vertex
	scale.factor = factor
	return scale
