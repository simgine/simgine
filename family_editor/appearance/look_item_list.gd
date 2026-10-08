class_name LookItemList
extends ItemList

signal look_item_selected(item: LookItem)

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
	item_selected.connect(_emit_look_item_selected)


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
		deselect_all()


func _emit_look_item_selected(index: int) -> void:
	look_item_selected.emit(_items[index])
