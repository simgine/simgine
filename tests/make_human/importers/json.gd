extends TestSuite


func requires_editor() -> bool:
	return true


func test_target() -> void:
	var importer := MHJSONImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/targets/target.json",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)
	assert(saver.resource as MHTargetRegistry)


func test_macro() -> void:
	var importer := MHJSONImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/targets/macrodetails/macro.json",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)
	assert(saver.resource as MHMacroRegistry)


func test_vertex_groups() -> void:
	var importer := MHJSONImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/mesh_metadata/basemesh_vertex_groups.json",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)
	assert(saver.resource as MHVertexGroups)


func test_rig() -> void:
	var importer := MHJSONImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/rigs/rig.default.json",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)

	# The bundled JSON lists some children before their parents.
	var rig := saver.resource as MHRig
	var visited: Dictionary[StringName, bool]
	for bone_name in rig.bones:
		var parent_name := rig.bones[bone_name].parent_name
		if parent_name:
			assert(
				parent_name in visited,
				"parent %s must precede child %s" % [parent_name, bone_name],
			)
		visited[bone_name] = true


func test_weights() -> void:
	var importer := MHJSONImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/rigs/weights.game_engine.json",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)
	assert(saver.resource as MHRigWeights)


func test_pose() -> void:
	var importer := MHJSONImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/poses/default_fk/t-pose.json",
		"",
		{
			"rig": "res://characters/visuals/make_human/data/rigs/rig.default.json",
			"bone_map": "",
			"reference_pose": "",
		},
		[],
		[],
	)
	assert_eq(error, OK)
	assert(saver.resource as MHNativePose)


func test_retargeted_pose() -> void:
	var importer := MHJSONImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/poses/default_fk/t-pose.json",
		"",
		{
			"rig": "res://characters/visuals/make_human/data/rigs/rig.default.json",
			"bone_map": "res://characters/visuals/make_human/data/rigs/default_bone_map.tres",
			"reference_pose": "res://characters/visuals/make_human/data/poses/default_fk/t-pose.json",
		},
		[],
		[],
	)
	assert_eq(error, OK)
	var pose := saver.resource as MHPose

	for bone_name: StringName in ["LeftHand", "LeftFoot"]:
		var rest := pose.profile.get_reference_pose(pose.profile.find_bone(bone_name))
		assert_approx_eq(
			Basis(pose.rotations[bone_name]),
			rest.basis,
			1e-6,
			"'%s' should match the profile rest pose when the source pose is also the reference"
			% bone_name,
		)
	assert(pose.translations.is_empty())
