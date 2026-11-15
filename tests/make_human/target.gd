extends TestSuite


func test_simple() -> void:
	var first := MHTargetCategory.new()
	first.targets = {
		"horizontal": _target([0, 2], [Vector3.RIGHT * 2, Vector3.BACK * 2]),
		"unset": _target([1], [Vector3.ONE]),
	}

	var second := MHTargetCategory.new()
	second.targets = { "vertical": _target([0], [Vector3.UP * 4]) }

	var registry := _registry([first, second])
	var vertices: PackedVector3Array = [Vector3.ONE, Vector3.ONE, Vector3.ZERO]
	registry.apply(vertices, { "horizontal": 0.5, "vertical": 0.25 })

	assert_eq(vertices, [Vector3(2, 2, 1), Vector3.ONE, Vector3.BACK])


func test_opposites() -> void:
	var category := MHTargetCategory.new()
	category.label = "size"
	category.opposites = MHTargetOpposites.new()
	category.opposites.negative_unsided = "shrink"
	category.opposites.positive_unsided = "grow"
	category.targets = {
		"shrink": _target([0], [Vector3.LEFT * 2]),
		"grow": _target([0], [Vector3.RIGHT * 4]),
	}

	var registry := _registry([category])
	const BASE_VERTICES: PackedVector3Array = [Vector3.ZERO]
	var vertices := BASE_VERTICES.duplicate()
	registry.apply(vertices, { "size": -0.5 })
	assert_eq(vertices[0], Vector3.LEFT)

	vertices = BASE_VERTICES.duplicate()
	registry.apply(vertices, { "size": 0.0 })
	assert_eq(vertices[0], Vector3.ZERO)

	vertices = BASE_VERTICES.duplicate()
	registry.apply(vertices, { "size": 0.25 })
	assert_eq(vertices[0], Vector3.RIGHT)


func test_sided() -> void:
	var category := MHTargetCategory.new()
	category.label = "width"
	category.has_left_and_right = true
	category.opposites = MHTargetOpposites.new()
	category.opposites.negative_left = "l-shrink"
	category.opposites.positive_left = "l-grow"
	category.opposites.negative_right = "r-shrink"
	category.opposites.positive_right = "r-grow"
	category.targets = {
		"l-shrink": _target([0], [Vector3.LEFT * 2]),
		"l-grow": _target([0], [Vector3.RIGHT * 4]),
		"r-shrink": _target([1], [Vector3.DOWN * 2]),
		"r-grow": _target([1], [Vector3.UP * 4]),
	}

	var registry := _registry([category])
	const BASE_VERTICES: PackedVector3Array = [Vector3.ZERO, Vector3.ZERO]
	var vertices := BASE_VERTICES.duplicate()
	registry.apply(vertices, { "width/left": -0.5, "width/right": 0.25 })
	assert_eq(vertices, [Vector3.LEFT, Vector3.UP])

	vertices = BASE_VERTICES.duplicate()
	registry.apply(vertices, { "width/left": 0.25, "width/right": -0.5 })
	assert_eq(vertices, [Vector3.RIGHT, Vector3.DOWN])

	vertices = BASE_VERTICES.duplicate()
	registry.apply(vertices, { "width/left": -0.5 })
	assert_eq(vertices, [Vector3.LEFT, Vector3.ZERO])


static func _target(indices: PackedInt32Array, offsets: PackedVector3Array) -> MHTarget:
	var target := MHTarget.new()
	target.vertex_indices = indices
	target.offsets = offsets
	return target


static func _registry(categories: Array[MHTargetCategory]) -> MHTargetRegistry:
	var section := MHTargetSection.new()
	section.categories = categories

	var registry := MHTargetRegistry.new()
	registry.sections = [section]

	return registry
