extends TestSuite


func requires_editor() -> bool:
	return true


func test_skeleton_save_cycles() -> void:
	var skeleton := MHSkeleton.new()
	add_child(skeleton)

	var names: PackedStringArray = ["root", "left", "right"]
	var parents: PackedInt32Array = [-1, 0, 0]
	var rests: Array[Transform3D] = [
		Transform3D(Basis(Vector3.UP, 0.4), Vector3(1, 2, 3)),
		Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(-2, 3, 1)),
		Transform3D(Basis(Vector3.BACK, 0.9), Vector3(4, 1, -2)),
	]
	var poses: Array[Transform3D] = [
		Transform3D(Basis(Vector3.BACK, 0.3).scaled_local(Vector3(1, 2, 3)), Vector3(2, -1, 4)),
		Transform3D(Basis(Vector3.UP, -0.5).scaled_local(Vector3(2, 3, 1)), Vector3(-3, 2, 1)),
		Transform3D(Basis(Vector3.RIGHT, 0.8).scaled_local(Vector3(3, 1, 2)), Vector3(1, 4, -2)),
	]
	var enabled: Array[bool] = [true, false, true]
	for bone_index in names.size():
		skeleton.add_bone(names[bone_index])
		skeleton.set_bone_parent(bone_index, parents[bone_index])
		skeleton.set_bone_rest(bone_index, rests[bone_index])
		skeleton.set_bone_pose(bone_index, poses[bone_index])
		skeleton.set_bone_enabled(bone_index, enabled[bone_index])

	skeleton.motion_scale = 2.5

	# A second save catches snapshots left over from the first restoration.
	for cycle in range(1, 3):
		var packed := PackedScene.new()
		# pack() doesn't send editor save notifications itself.
		skeleton.notification(Node.NOTIFICATION_EDITOR_PRE_SAVE)
		assert_eq(
			skeleton.get_bone_count(),
			0,
			"save cycle %d must temporarily remove bones before packing" % cycle,
		)
		var error := packed.pack(skeleton)
		skeleton.notification(Node.NOTIFICATION_EDITOR_POST_SAVE)
		assert_eq(error, OK, "save cycle %d must pack successfully" % cycle)

		# Saving must preserve the live skeleton's hierarchy and full per-bone state.
		assert_eq(
			skeleton.get_bone_count(),
			names.size(),
			"save cycle %d must restore the original number of bones" % cycle,
		)
		for bone_index in names.size():
			assert_eq(
				skeleton.get_bone_name(bone_index),
				names[bone_index],
				"save cycle %d must restore the name of bone %d" % [cycle, bone_index],
			)
			assert_eq(
				skeleton.get_bone_parent(bone_index),
				parents[bone_index],
				"save cycle %d must restore the parent of bone '%s'" % [cycle, names[bone_index]],
			)
			assert_approx_eq(
				skeleton.get_bone_rest(bone_index),
				rests[bone_index],
				1e-6,
				"save cycle %d must restore the rest of bone '%s'" % [cycle, names[bone_index]],
			)
			assert_approx_eq(
				skeleton.get_bone_pose(bone_index),
				poses[bone_index],
				1e-6,
				"save cycle %d must restore the pose of bone '%s'" % [cycle, names[bone_index]],
			)
			assert_eq(
				skeleton.is_bone_enabled(bone_index),
				enabled[bone_index],
				"save cycle %d must restore the enabled flag of bone '%s'"
				% [cycle, names[bone_index]],
			)
		assert_eq(
			skeleton.motion_scale,
			2.5,
			"save cycle %d must leave the live skeleton's motion scale unchanged" % cycle,
		)

		# Generated state must stay out of the scene even though it remains live.
		var properties := _packed_properties(packed)
		for property_name in properties:
			assert(
				not property_name.begins_with("bones/"),
				"save cycle %d must not pack generated bone property '%s'" % [cycle, property_name],
			)
		assert(
			not properties.has("motion_scale"),
			"save cycle %d must not pack the generated motion scale" % cycle,
		)


func test_proxy_scene() -> void:
	var proxy := _proxy()
	var instance := MHProxyInstance.new()
	instance.proxy = proxy
	instance.transform = Transform3D(
		Basis(Vector3.UP, 0.6).scaled(Vector3(2, 3, 4)),
		Vector3(5, -2, 3),
	)
	instance.visible = false
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = StandardMaterial3D.new()
	add_child(instance)

	# Populate generated fields so exclusion isn't tested against empty defaults.
	var generated_mesh := instance.mesh
	var generated_skin := Skin.new()
	instance.skin = generated_skin
	instance.skeleton = "../GeneratedSkeleton"
	assert(generated_mesh)

	# Packing omits generated fields without clearing them on the live instance.
	var packed := PackedScene.new()
	assert_eq(packed.pack(instance), OK)
	var properties := _packed_properties(packed)
	for property_name: String in ["mesh", "skin", "skeleton"]:
		assert(not properties.has(property_name), "generated %s must not be packed" % property_name)

	assert_eq(instance.mesh, generated_mesh)
	assert_eq(instance.skin, generated_skin)
	assert_eq(instance.skeleton, ^"../GeneratedSkeleton")

	# Settings should survive instantiation.
	var restored := packed.instantiate() as MHProxyInstance
	assert_eq(restored.proxy, proxy)
	assert_approx_eq(restored.transform, instance.transform)
	assert_eq(restored.visible, false)
	assert_eq(restored.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(restored.material_override, instance.material_override)
	assert_eq(restored.mesh, null, "standalone geometry is built on ready, not serialized")

	# Enter the tree rebuilds standalone geometry without body skeleton bindings.
	add_child(restored)

	assert_eq(restored.skin, null)
	assert_eq(restored.skeleton, ^"")
	assert_eq(restored.mesh.get_surface_count(), 1)
	assert_eq(restored.mesh.surface_get_material(0), proxy.material)
	var arrays := restored.mesh.surface_get_arrays(0)
	var expected := proxy.geometry.build_surface()
	for array_type: Mesh.ArrayType in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		assert_eq(
			arrays[array_type],
			expected[array_type],
			"standalone mesh must reconstruct for ArrayType %d" % array_type,
		)


static func _packed_properties(packed: PackedScene) -> Dictionary[StringName, Variant]:
	var state := packed.get_state()
	assert_eq(state.get_node_count(), 1)

	var properties: Dictionary[StringName, Variant]
	for property_index in state.get_node_property_count(0):
		properties[state.get_node_property_name(0, property_index)] = state.get_node_property_value(
			0,
			property_index,
		)
	return properties


static func _proxy() -> MHProxy:
	var quad := MHQuad.new()
	quad.vertex_indices = [0, 1, 2, 3]
	quad.uv_indices = [0, 1, 2, 3]

	var proxy := MHProxy.new()
	proxy.geometry = MHGeometry.new()
	proxy.geometry.vertices = [Vector3.ZERO, Vector3.RIGHT, Vector3(1, 1, 0), Vector3.UP]
	proxy.geometry.uvs = [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	proxy.geometry.quads = [quad]
	proxy.material = StandardMaterial3D.new()
	proxy.material.albedo_color = Color(0.2, 0.4, 0.6)

	return proxy
