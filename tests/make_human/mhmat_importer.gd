extends TestSuite


func requires_editor() -> bool:
	return true


func test_textures() -> void:
	var importer := MHMatImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/items/clothes/female_elegantsuit01/female_elegantsuit01.mhmat",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)

	var material := saver.resource as StandardMaterial3D
	assert(material.albedo_texture)
	assert(material.normal_texture)
	assert(material.ao_texture)


func test_subsurface_scattering() -> void:
	var importer := MHMatImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/items/skins/young_caucasian_female2/young_caucasian_female2.mhmat",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)
	var material := saver.resource as StandardMaterial3D
	assert(material.subsurf_scatter_enabled)


func test_transparency() -> void:
	var importer := MHMatImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/items/eyes/high_poly_eye/materials/brown.mhmat",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)
	var material := saver.resource as StandardMaterial3D
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
