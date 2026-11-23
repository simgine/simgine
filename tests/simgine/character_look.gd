extends TestSuite

const EYES := preload(
	"res://characters/visuals/make_human/items/eyes/high_poly_eye/high_poly_eyes.tres"
)

const PONYTAIL := preload(
	"res://characters/visuals/make_human/items/hair/ponytail01/ponytail01.tres"
)
const BRAID := preload("res://characters/visuals/make_human/items/hair/braid01/braid01.tres")
const PONYTAIL_BLACK := preload(
	"res://characters/visuals/make_human/items/hair/ponytail01/swatches/dariush086_ponytail01_black/dariush086_ponytail01_black.tres"
)


func test_replace_item() -> void:
	var look := CharacterLook.new()
	look.add(PONYTAIL)

	var events: Array[Array]
	look.item_removed.connect(
		func(item: LookItem) -> void:
			events.append(["removed", item]),
	)
	look.item_added.connect(
		func(item: LookItem) -> void:
			events.append(["added", item]),
	)

	look.add(BRAID)

	assert_eq(events, [["removed", PONYTAIL], ["added", BRAID]])
	assert_eq(look.items, { BRAID: null })


func test_item_validation() -> void:
	var selection: Dictionary[LookItem, LookSwatch]
	selection[null] = PONYTAIL_BLACK
	selection[PONYTAIL] = PONYTAIL_BLACK
	selection[BRAID] = PONYTAIL_BLACK

	expect_warning("Ignoring an invalid")
	expect_warning("does not belong to")
	var look := CharacterLook.new()
	look.items = selection

	assert_eq(look.items, { BRAID: null }, "the later item wins without the foreign swatch")


func test_swatch_changes() -> void:
	var look := CharacterLook.new()
	look.add(PONYTAIL)

	look.item_added.connect(
		func(_item: LookItem) -> void:
			panic("The item was attached again"),
	)
	look.item_removed.connect(
		func(_item: LookItem) -> void:
			panic("The item was detached"),
	)

	var changes: Array[LookSwatch]
	look.item_swatch_changed.connect(
		func(_item: LookItem, swatch: LookSwatch) -> void:
			changes.append(swatch),
	)

	look.set_swatch(PONYTAIL, PONYTAIL_BLACK)
	assert_eq(look.get_swatch(PONYTAIL), PONYTAIL_BLACK)
	assert_eq(changes, [PONYTAIL_BLACK])

	look.set_swatch(PONYTAIL, PONYTAIL_BLACK)
	assert_eq(changes, [PONYTAIL_BLACK])

	look.set_swatch(PONYTAIL, null)
	assert_eq(look.get_swatch(PONYTAIL), null)
	assert_eq(changes, [PONYTAIL_BLACK, null])


func test_clear_items() -> void:
	var look := CharacterLook.new()
	look.add(PONYTAIL)
	look.add(EYES)

	var removed: Array[LookItem]
	look.item_removed.connect(
		func(item: LookItem) -> void:
			removed.append(item),
	)

	look.items = { }

	assert(look.items.is_empty())
	assert_eq(removed, [PONYTAIL, EYES])


func test_save_restore() -> void:
	var look := CharacterLook.new()
	look.add(PONYTAIL)
	look.set_swatch(PONYTAIL, PONYTAIL_BLACK)
	look.add(EYES)

	var file := FileAccess.create_temp(FileAccess.READ, "character_look", "tres")
	var path := file.get_path_absolute()
	assert_eq(ResourceSaver.save(look, path), OK)

	var saved := ResourceLoader.load(path) as CharacterLook
	assert_eq(saved.items, { PONYTAIL: PONYTAIL_BLACK, EYES: null })
