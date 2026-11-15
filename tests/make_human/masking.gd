extends TestSuite


func test_conservative_mask() -> void:
	var geometry := MHGeometry.new()
	geometry.vertices = [
		Vector3.ZERO,
		Vector3.RIGHT,
		Vector3(1, 1, 0),
		Vector3.UP,
		Vector3(2, 0, 0),
		Vector3(2, 1, 0),
	]
	geometry.uvs = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]

	var hidden := _quad([0, 1, 2, 3])
	var neighbor := _quad([1, 4, 5, 2])

	for reverse_order: bool in [false, true]:
		geometry.quads = [hidden, neighbor]
		if reverse_order:
			geometry.quads.reverse()

		var mask: PackedByteArray = [1, 1, 1, 1, 0, 0]
		geometry.make_mask_conservative(mask)

		assert_eq(
			mask,
			[1, 0, 0, 1, 0, 0],
			"only shared boundary vertices are unmasked with reverse_order=%s" % reverse_order,
		)

		var indices := geometry.filter_indices(mask)
		var source_indices: PackedInt32Array
		for render_index in indices:
			source_indices.append(geometry.topology.geometry_indices[render_index])

		assert_eq(
			source_indices,
			[1, 5, 4, 1, 2, 5],
			"only the neighbor survives with reverse_order=%s" % reverse_order,
		)
		assert_eq(
			geometry.build_surface([], null, mask, indices)[Mesh.ARRAY_INDEX],
			indices,
			"the surface uses the filtered indices with reverse_order=%s" % reverse_order,
		)


func test_exact_mapping() -> void:
	var proxy := _proxy(_geometry(1), Vector3i(1, 0, 2), Vector3(1, 0, 0))
	var mask: PackedByteArray

	proxy.transfer_delete_mask([0, 1, 0], mask)
	assert_eq(mask, [1, 1, 1, 1], "the exact reference alone hides the face")
	assert_eq(proxy.geometry.filter_indices(mask), [])

	proxy.transfer_delete_mask([1, 0, 1], mask)
	assert_eq(mask, [0, 0, 0, 0], "unused references must not hide an exact mapping")
	assert_eq(proxy.geometry.filter_indices(mask), _face_indices([0]))


func test_weighted_mapping() -> void:
	var proxy := _proxy(_geometry(1), Vector3i(0, 1, 2), Vector3(0.8, 0.15, 0.05))
	var mask: PackedByteArray

	for bits in 8:
		var body_mask: PackedByteArray = [bits & 1, (bits >> 1) & 1, (bits >> 2) & 1]

		var hidden_count := int(body_mask[0]) + int(body_mask[1]) + int(body_mask[2])
		var hidden := hidden_count >= 2
		proxy.transfer_delete_mask(body_mask, mask)

		assert_eq(
			mask,
			[1, 1, 1, 1] if hidden else [0, 0, 0, 0],
			"weighted mappings hide when at least two references are hidden with body_mask=%s"
			% body_mask,
		)


func test_clothing() -> void:
	var instance := MHBodyInstance.new()
	instance.body = _body()
	add_child(instance)

	await get_tree().process_frame

	_assert_faces(instance, [0, 1, 2, 3], "all faces are visible without clothing")

	# Delete-only proxies isolate equipment masking from fitting and skeleton updates.
	var first := MHProxyInstance.new()
	first.proxy = MHProxy.new()
	first.proxy.delete_verts = [0, 7]
	instance.add_child(first)

	await get_tree().process_frame

	_assert_faces(instance, [2, 3], "the inclusive range hides faces 0 and 1")

	var second := MHProxyInstance.new()
	second.proxy = MHProxy.new()
	second.proxy.delete_verts = [4, 10, 11, 11]
	instance.add_child(second)

	await get_tree().process_frame

	_assert_faces(instance, [3], "overlapping ranges and the singleton hide faces 0, 1, and 2")

	var replacement := MHProxy.new()
	replacement.delete_verts = [8, 11]
	first.proxy = replacement

	await get_tree().process_frame

	_assert_faces(
		instance,
		[0, 3],
		"replacement restores face 0 while the second item still hides face 1",
	)

	instance.remove_child(second)
	second.free()

	await get_tree().process_frame

	_assert_faces(
		instance,
		[0, 1, 3],
		"removal restores face 1 while the replacement still hides face 2",
	)

	instance.remove_child(first)
	first.free()

	await get_tree().process_frame

	_assert_faces(instance, [0, 1, 2, 3], "removing the last item restores every face")
	instance.free()


static func _assert_faces(instance: MHBodyInstance, faces: PackedInt32Array, msg: String) -> void:
	assert_eq(instance.mesh.get_surface_count(), 1, msg)
	assert_eq(instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX], _face_indices(faces), msg)


static func _face_indices(faces: PackedInt32Array) -> PackedInt32Array:
	var indices: PackedInt32Array
	for face in faces:
		var first := face * 4
		indices.append_array([first, first + 2, first + 1, first, first + 3, first + 2])

	return indices


static func _body() -> MHBody:
	var source := _geometry(4)

	var body := MHBody.new()
	body.geometry = MHBodyGeometry.new()
	body.geometry.vertices = source.vertices
	body.geometry.uvs = source.uvs
	body.geometry.quads = source.quads
	body.vertex_groups = MHVertexGroups.new()
	body.vertex_groups.ranges = { "body": PackedInt32Array([0, 15]) }
	body.macro_registry = MHMacroRegistry.new()
	body.target_registry = MHTargetRegistry.new()
	body.rig = MHRig.new()
	body.rig.bones = { "root": MHBone.new() }

	var bone_weights := MHBoneWeights.new()
	for vertex_index in body.geometry.vertices.size():
		bone_weights.vertices.append(vertex_index)
		bone_weights.weights.append(1.0)

	body.rig_weights = MHRigWeights.new()
	body.rig_weights.bones = { "root": bone_weights }

	return body


static func _proxy(geometry: MHGeometry, references: Vector3i, fit_weights: Vector3) -> MHProxy:
	var proxy := MHProxy.new()
	proxy.geometry = geometry
	for vertex_index in geometry.vertices.size():
		proxy.ref_a.append(references.x)
		proxy.ref_b.append(references.y)
		proxy.ref_c.append(references.z)
		proxy.weights.append(fit_weights)
		proxy.offsets.append(Vector3.ZERO)

	return proxy


static func _geometry(quad_count: int) -> MHGeometry:
	# Disconnected quads let each delete range affect a distinct, identifiable face.
	var geometry := MHGeometry.new()
	geometry.uvs = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	for quad_index in quad_count:
		var origin := Vector3(quad_index * 2, 0, 0)
		var first := geometry.vertices.size()
		geometry.vertices.append_array(
			[origin, origin + Vector3.RIGHT, origin + Vector3(1, 1, 0), origin + Vector3.UP],
		)
		geometry.quads.append(_quad([first, first + 1, first + 2, first + 3]))

	return geometry


static func _quad(vertex_indices: PackedInt32Array) -> MHQuad:
	var quad := MHQuad.new()
	quad.vertex_indices = vertex_indices
	quad.uv_indices = [0, 1, 2, 3]

	return quad
