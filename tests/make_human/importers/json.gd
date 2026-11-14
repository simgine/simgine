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
	assert(saver.resource as MHRig)


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
		"res://characters/visuals/make_human/data/poses/default_fk/callharvey3d_standingnatural.json",
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
	assert(saver.resource as MHPose)
