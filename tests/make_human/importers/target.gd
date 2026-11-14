extends TestSuite


func requires_editor() -> bool:
	return true


func test_local() -> void:
	var importer := MHTargetImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/targets/arms/l-lowerarm-fat-decr.target",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)

	var target := saver.resource as MHTarget
	assert_eq(target.vertex_indices.size(), 297)
	assert_eq(target.offsets.size(), 297)


func test_macro() -> void:
	var importer := MHTargetImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/targets/macrodetails/caucasian-male-old.target",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)

	var target := saver.resource as MHTarget
	assert_eq(target.vertex_indices.size(), 19158)
	assert_eq(target.offsets.size(), 19158)
