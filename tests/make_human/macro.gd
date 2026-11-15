extends TestSuite


func test_interpolation() -> void:
	var combination := MHMacroCombination.new()
	combination.dimensions = ["gender"]
	combination.targets = { "female": _target(Vector3.RIGHT * 4), "male": _target(Vector3.UP * 4) }

	var registry := MHMacroRegistry.new()
	registry.macrotargets = { "gender": _macro([_part(-0.01, 1.01, "female", "male")]) }
	registry.combinations = [combination]

	var vertices: PackedVector3Array = [Vector3.ZERO]
	registry.apply(vertices, { "gender": 0.245 })
	assert_approx_eq(vertices, [Vector3(3, 1, 0)])

	vertices = [Vector3.ZERO]
	registry.apply(vertices, { "gender": 0.755 })
	assert_approx_eq(vertices, [Vector3(1, 3, 0)])

	vertices = [Vector3.ZERO]
	registry.apply(vertices, { })
	assert_approx_eq(vertices, [Vector3(2, 2, 0)], 1e-6, "omitted scalar modifiers default to 0.5")


func test_neutral_values() -> void:
	var height := MHMacroCombination.new()
	height.dimensions = ["height"]
	height.targets = {
		"minheight": _target(Vector3.DOWN * 4),
		"maxheight": _target(Vector3.UP * 4),
	}

	var proportions := MHMacroCombination.new()
	proportions.dimensions = ["proportions"]
	proportions.targets = {
		"uncommonproportions": _target(Vector3.LEFT * 4),
		"idealproportions": _target(Vector3.RIGHT * 4),
	}

	var registry := MHMacroRegistry.new()
	registry.macrotargets = {
		"height": _macro([_part(-0.01, 0.49, "minheight", ""), _part(0.51, 1.01, "", "maxheight")]),
		"proportions": _macro(
			[
				_part(-0.01, 0.4999, "uncommonproportions", ""),
				_part(0.5, 1.01, "", "idealproportions"),
			],
		),
	}
	registry.combinations = [height, proportions]

	var vertices: PackedVector3Array = [Vector3.ZERO]
	registry.apply(vertices, { "height": 0.24, "proportions": 0.24495 })
	assert_approx_eq(vertices, [Vector3(-2, -2, 0)])

	vertices = [Vector3.ZERO]
	registry.apply(vertices, { "height": 0.76, "proportions": 0.755 })
	assert_approx_eq(vertices, [Vector3(2, 2, 0)])

	vertices = [Vector3.ZERO]
	registry.apply(vertices, { "height": 0.5, "proportions": 0.5 })
	assert_eq(
		vertices,
		[Vector3.ZERO],
		"neutral values between interpolation parts apply no target",
	)


func test_combinations() -> void:
	var combination := MHMacroCombination.new()
	combination.dimensions = ["gender", "age"]
	combination.targets = {
		"female-baby": _target(Vector3.RIGHT, 0),
		"female-young": _target(Vector3.RIGHT, 1),
		"male-baby": _target(Vector3.RIGHT, 2),
		"male-young": _target(Vector3.RIGHT, 3),
	}

	var registry := MHMacroRegistry.new()
	registry.macrotargets = {
		"gender": _macro([_part(-0.01, 1.01, "female", "male")]),
		"age": _macro([_part(-0.01, 1.01, "baby", "young")]),
	}
	registry.combinations = [combination]

	var vertices: PackedVector3Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	registry.apply(vertices, { "gender": 0.245, "age": 0.755 })
	# Gender weights (0.75, 0.25) multiplied by age weights (0.25, 0.75).
	assert_approx_eq(
		vertices,
		[
			Vector3.RIGHT * 0.1875,
			Vector3.RIGHT * 0.5625,
			Vector3.RIGHT * 0.0625,
			Vector3.RIGHT * 0.1875,
		],
	)


func test_races() -> void:
	var combination := MHMacroCombination.new()
	combination.dimensions = ["race"]
	combination.targets = {
		"african": _target(Vector3.RIGHT),
		"asian": _target(Vector3.UP),
		"caucasian": _target(Vector3.BACK),
	}

	var registry := MHMacroRegistry.new()
	registry.combinations = [combination]

	var vertices: PackedVector3Array = [Vector3.ZERO]
	registry.apply(vertices, { "african": 0.2, "asian": 0.3, "caucasian": 0.4 })
	assert_approx_eq(
		vertices,
		[Vector3(0.2, 0.3, 0.4)],
		1e-6,
		"race weights are applied without normalization",
	)

	vertices = [Vector3.ZERO]
	registry.apply(vertices, { "african": 0.2 })
	assert_approx_eq(
		vertices,
		[Vector3(0.2, 0.33, 0.33)],
		1e-6,
		"all omitted race modifiers default to 0.33",
	)


func test_component_restrictions() -> void:
	var combination := MHMacroCombination.new()
	combination.dimensions = ["gender", "cupsize"]
	combination.allowed_components = { "gender": PackedStringArray(["female"]) }
	combination.targets = {
		"female-mincup": _target(Vector3.RIGHT * 4),
		"female-maxcup": _target(Vector3.UP * 4),
		"male-mincup": _target(Vector3.BACK * 4),
		"male-maxcup": _target(Vector3.BACK * 4),
	}

	var registry := MHMacroRegistry.new()
	registry.macrotargets = {
		"gender": _macro([_part(-0.01, 1.01, "female", "male")]),
		"cupsize": _macro([_part(-0.01, 1.01, "mincup", "maxcup")]),
	}
	registry.combinations = [combination]

	var vertices: PackedVector3Array = [Vector3.ZERO]
	registry.apply(vertices, { "gender": 0.245, "cupsize": 0.245 })
	assert_approx_eq(
		vertices,
		[Vector3(2.25, 0.75, 0)],
		1e-6,
		"restricting components preserves their original weights",
	)

	combination.allowed_components = { "gender": PackedStringArray(["male"]) }
	vertices = [Vector3.ZERO]
	registry.apply(vertices, { "gender": 0.245, "cupsize": 0.245 })
	assert_approx_eq(vertices, [Vector3.BACK])


func test_weight_exclusions() -> void:
	var combination := MHMacroCombination.new()
	combination.dimensions = ["gender", "cupsize"]
	combination.weight_exclusions = ["gender"]
	combination.targets = {
		"female-mincup": _target(Vector3.RIGHT * 4),
		"female-maxcup": _target(Vector3.UP * 4),
		"male-mincup": _target(Vector3.BACK * 4),
		"male-maxcup": _target(Vector3.BACK * 4),
	}

	var registry := MHMacroRegistry.new()
	registry.macrotargets = {
		"gender": _macro([_part(-0.01, 1.01, "female", "male")]),
		"cupsize": _macro([_part(-0.01, 1.01, "mincup", "maxcup")]),
	}
	registry.combinations = [combination]

	var vertices: PackedVector3Array = [Vector3.ZERO]
	registry.apply(vertices, { "gender": 0.245, "cupsize": 0.245 })
	assert_approx_eq(vertices, [Vector3(3, 1, 4)])

	vertices = [Vector3.ZERO]
	registry.apply(vertices, { "gender": 1.0, "cupsize": 0.245 })
	assert_approx_eq(
		vertices,
		[Vector3(3, 1, 4)],
		1e-6,
		"gender has no effect because its weight is excluded",
	)


func test_missing_combination() -> void:
	var combination := MHMacroCombination.new()
	combination.dimensions = ["age", "proportions"]
	# Omit the baby target, as in the bundled proportion assets.
	# Its active combination should be skipped without changing the young target's weight.
	combination.targets = { "young-idealproportions": _target(Vector3.RIGHT * 8) }

	var registry := MHMacroRegistry.new()
	registry.macrotargets = {
		"age": _macro([_part(-0.01, 1.01, "baby", "young")]),
		"proportions": _macro(
			[
				_part(-0.01, 0.4999, "uncommonproportions", ""),
				_part(0.5, 1.01, "", "idealproportions"),
			],
		),
	}
	registry.combinations = [combination]

	var vertices: PackedVector3Array = [Vector3.ZERO]
	registry.apply(vertices, { "age": 0.245, "proportions": 0.755 })
	assert_approx_eq(vertices, [Vector3.RIGHT], 1e-6, "missing combinations are skipped")


static func _target(offset: Vector3, vertex_index: int = 0) -> MHTarget:
	var target := MHTarget.new()
	target.vertex_indices = [vertex_index]
	target.offsets = [offset]
	return target


static func _macro(parts: Array[MHMacroPart]) -> MHMacro:
	var macro := MHMacro.new()
	macro.parts = parts
	return macro


static func _part(lowest: float, highest: float, low: String, high: String) -> MHMacroPart:
	var part := MHMacroPart.new()
	part.lowest = lowest
	part.highest = highest
	part.low = low
	part.high = high
	return part
