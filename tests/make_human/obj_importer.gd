extends TestSuite


func requires_editor() -> bool:
	return true


func test_body_geometry() -> void:
	var importer := MHObjImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/data/3dobjs/base.obj",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)

	var geometry := saver.resource as MHBodyGeometry
	assert_eq(geometry.vertices.size(), 19158)
	assert_eq(geometry.uvs.size(), 21334)
	assert_eq(geometry.quads.size(), 13378)


func test_geometry() -> void:
	var importer := MHObjImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/items/eyebrows/eyebrow001/eyebrow001.obj",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)

	var geometry := saver.resource as MHGeometry
	assert(geometry is not MHBodyGeometry)
	assert_eq(geometry.vertices.size(), 124)
	assert_eq(geometry.uvs.size(), 126)
	assert_eq(geometry.quads.size(), 96)
