class_name LookItemList
extends ItemList

signal look_item_selected(item: LookItem)
signal look_item_deselected(item: LookItem)
signal preview_requested(item: LookItem)

var _slot: LookSlot
var _items: Array[LookItem]
var _item_indices: Dictionary[LookItem, int]

## Items whose previews were already requested.
var _previewed: Dictionary[LookItem, bool]

static var _placeholder: Texture2D = _create_placeholder()


static func _create_placeholder() -> Texture2D:
	var image := Image.create_empty(150, 200, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0.15))
	return ImageTexture.create_from_image(image)


func _ready() -> void:
	get_v_scroll_bar().value_changed.connect(_check_visible_previews.unbind(1))
	resized.connect(_check_visible_previews)
	visibility_changed.connect(_check_visible_previews)


func setup(slot: LookSlot) -> void:
	_slot = slot
	multi_selected.connect(_on_multi_selected)


func add_look_item(item: LookItem) -> void:
	_items.append(item)
	var index := add_item("", _placeholder)
	set_item_tooltip(index, item.name)
	_item_indices[item] = index
	_check_visible_previews()


func load_selected(visual: CharacterVisual) -> void:
	var item := visual.get_look_item(_slot)
	if item and _item_indices.has(item):
		select(_item_indices[item])
	else:
		# Unlike `deselect_all()`, `deselect()` preserves the navigation cursor.
		for index in get_selected_items():
			deselect(index)


## Sets the rendered preview as the item's icon.
func set_item_preview(item: LookItem, texture: ImageTexture) -> void:
	set_item_icon(_item_indices[item], texture)


func _on_multi_selected(index: int, selected: bool) -> void:
	# Undo the selection and only emit signals.
	# The state later reloads from CharacterVisual because attachment can fail.
	if selected:
		deselect(index)
		look_item_selected.emit(_items[index])
	else:
		select(index)
		# Ignore deselection if the slot is required.
		if not _slot.permanent:
			look_item_deselected.emit(_items[index])


func _check_visible_previews() -> void:
	if not is_visible_in_tree() or _previewed.size() == _items.size():
		return

	var item_range := get_visible_item_range()
	for index in range(item_range[0], item_range[1]):
		var item := _items[index]
		if not _previewed.has(item):
			_previewed[item] = true
			preview_requested.emit(item)


## Returns the visible items as a `[first, end)` index range.
func get_visible_item_range() -> Vector2i:
	var items_count := _items.size()
	if items_count == 0:
		return Vector2i(0, 0)

	var icon_size := get_fixed_icon_size()
	assert(icon_size != Vector2i.ZERO)
	var panel := get_theme_stylebox("panel")
	var content_height := size.y - (panel.get_margin(SIDE_TOP) + panel.get_margin(SIDE_BOTTOM))
	var row_height := icon_size.y + get_theme_constant("v_separation")

	var scroll_bar := get_v_scroll_bar()
	var first_row := int(scroll_bar.value / row_height)
	var last_row := int((scroll_bar.value + content_height) / row_height)
	if float(last_row) * row_height >= scroll_bar.value + content_height:
		# The window's bottom edge landed exactly on a row boundary.
		last_row -= 1

	var columns := get_max_columns()
	assert(columns > 0)
	@warning_ignore("integer_division")
	var rows := (items_count + columns - 1) / columns

	last_row = mini(last_row, rows - 1)

	var start := first_row * columns
	var end := mini(last_row * columns + columns, items_count)

	return Vector2i(start, end)
