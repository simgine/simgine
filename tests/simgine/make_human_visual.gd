extends TestSuite

const PONYTAIL := preload(
	"res://characters/visuals/make_human/items/hair/ponytail01/ponytail01.tres"
)
const PONYTAIL_BLACK := preload(
	"res://characters/visuals/make_human/items/hair/ponytail01/swatches/dariush086_ponytail01_black/dariush086_ponytail01_black.tres"
)
const SKIN := preload(
	"res://characters/visuals/make_human/items/skins/young_caucasian_female2/young_caucasian_female2.tres"
)
const VISUAL := preload("res://characters/visuals/make_human/make_human_visual.tscn")


func test_proxy_swatch() -> void:
	var visual := VISUAL.instantiate() as MakeHumanVisual
	add_child(visual)
	visual.look.apply(PONYTAIL)

	await get_tree().process_frame

	var hair := visual.get_item_mesh(PONYTAIL)
	var original := hair.get_active_material(0)
	var swatch_material := load(PONYTAIL_BLACK.asset_path) as Material
	var changes: Array[Material]
	visual.look_changed.connect(
		func() -> void:
			changes.append(hair.get_active_material(0)),
	)

	visual.look.apply(PONYTAIL, PONYTAIL_BLACK)
	assert_eq(hair.get_active_material(0), swatch_material)
	assert_eq(visual.body_instance.material_override, null)

	visual.look.apply(PONYTAIL, null)
	assert_eq(hair.get_active_material(0), original)
	assert_eq(changes, [swatch_material, original])


func test_look_replacement() -> void:
	var look1 := CharacterLook.new()
	look1.apply(PONYTAIL, PONYTAIL_BLACK)

	var visual := VISUAL.instantiate() as MakeHumanVisual
	visual.look = look1
	add_child(visual)

	var hair := visual.get_item_mesh(PONYTAIL)
	var swatch_material := load(PONYTAIL_BLACK.asset_path) as Material
	assert_eq(hair.material_override, swatch_material)

	var look2 := CharacterLook.new()
	look2.apply(PONYTAIL)
	visual.look = look2
	assert_eq(visual.get_item_mesh(PONYTAIL), hair)
	assert_eq(hair.material_override, null)

	look2.apply(PONYTAIL, PONYTAIL_BLACK)
	assert_eq(hair.material_override, swatch_material)

	look1.apply(PONYTAIL, null)
	assert_eq(
		hair.material_override,
		swatch_material,
		"the old look must no longer drive the visual",
	)


func test_body_material_swatch() -> void:
	var skin := SKIN.duplicate() as LookItem
	var swatch := LookSwatch.new() # TODO: use a real asset once skins get swatches.
	swatch.asset_path = PONYTAIL_BLACK.asset_path
	skin.swatches.append(swatch)

	var visual := VISUAL.instantiate() as MakeHumanVisual
	add_child(visual)
	visual.look.apply(skin, swatch)

	var swatch_material := load(swatch.asset_path) as Material
	assert_eq(visual.body_instance.material_override, swatch_material)
	assert_eq(visual.get_item_mesh(skin), null)

	visual.look.apply(skin, null)
	assert_eq(visual.body_instance.material_override, load(skin.asset_path) as Material)

	visual.look.apply(skin, swatch)
	assert_eq(visual.body_instance.material_override, swatch_material)

	visual.look.remove(skin)
	assert_eq(visual.body_instance.material_override, null)


func test_body_material_slot() -> void:
	var item := LookItem.new()
	item.slot = PONYTAIL.slot
	item.asset_path = PONYTAIL_BLACK.asset_path

	var visual := VISUAL.instantiate() as MakeHumanVisual
	add_child(visual)
	visual.look.apply(SKIN)

	expect_error("must be an MHProxy or a PackedScene")
	visual.look.apply(item)
	assert_eq(visual.body_instance.material_override, load(SKIN.asset_path) as Material)
