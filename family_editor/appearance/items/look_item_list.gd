class_name LookItemList
extends ItemList

signal look_item_selected(item: LookItem)
signal look_item_deselected(item: LookItem)

var _slot: LookSlot
var _items: Array[LookItem]
var _item_indices: Dictionary[LookItem, int]

static var _placeholder: Texture2D = _create_placeholder()


static func _create_placeholder() -> Texture2D:
	var image := Image.create_empty(150, 200, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0.15))
	return ImageTexture.create_from_image(image)


func setup(slot: LookSlot) -> void:
	_slot = slot
	multi_selected.connect(_on_multi_selected)


func add_look_item(item: LookItem) -> void:
	_items.append(item)
	var index := add_item("", _placeholder)
	set_item_tooltip(index, item.name)
	_item_indices[item] = index


func load_selected(visual: CharacterVisual) -> void:
	var item := visual.get_look_item(_slot)
	if item and _item_indices.has(item):
		select(_item_indices[item])
	else:
		# Unlike `deselect_all()`, `deselect()` preserves the navigation cursor.
		for index in get_selected_items():
			deselect(index)


func _on_multi_selected(index: int, selected: bool) -> void:
	if not selected and _slot.permanent:
		# Deny deselection if the represented slot is required.
		select(index)
		return

	if selected:
		look_item_selected.emit(_items[index])
	else:
		look_item_deselected.emit(_items[index])
