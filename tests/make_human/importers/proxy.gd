extends TestSuite


func requires_editor() -> bool:
	return true


func test_proxy() -> void:
	var importer := MHProxyImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/items/eyebrows/eyebrow001/eyebrow001.mhclo",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)

	var proxy := saver.resource as MHProxy
	assert(proxy.geometry)
	assert(proxy.material)
	assert_eq(proxy.ref_a.size(), 124)
	assert_eq(proxy.weights.size(), 124)
	assert_eq(proxy.offsets.size(), 124)
	assert_eq(proxy.delete_verts.size(), 0)


func test_single_index() -> void:
	var importer := MHProxyImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/items/eyelashes/eyelashes01/eyelashes01.mhclo",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)

	var proxy := saver.resource as MHProxy
	assert(proxy.geometry)
	assert(proxy.material)
	assert_eq(proxy.ref_a.size(), 250)
	assert_eq(proxy.weights.size(), 250)
	assert_eq(proxy.weights[0], Vector3(1.0, 0.0, 0.0))
	assert_eq(proxy.offsets[0], Vector3.ZERO)


func test_delete_verts() -> void:
	var importer := MHProxyImporter.new()

	var saver := TestResourceSaver.new()
	ResourceSaver.add_resource_format_saver(saver, true)

	var error := importer._import(
		"res://characters/visuals/make_human/items/clothes/female_elegantsuit01/female_elegantsuit01.mhclo",
		"",
		{ },
		[],
		[],
	)
	assert_eq(error, OK)

	var proxy := saver.resource as MHProxy
	assert(proxy.geometry)
	assert(proxy.material)
	assert_eq(proxy.ref_a.size(), 2205)
	assert_eq(proxy.delete_verts.size(), 214)
