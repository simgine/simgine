class_name LookItemsTab
extends TabContainer
## An appearance tab that groups [LookItem]s into subtabs by slot.

signal item_selected(item: LookItem)
signal item_deselected(item: LookItem)
signal preview_requested(item: LookItem)

## Whether to show items with permanent slots, or items with the rest.
@export var permanent: bool


func populate(items: Array[LookItem]) -> void:
	var current_slot: LookSlot = null
	var list: LookItemList
	for item in items:
		if item.slot.permanent != permanent:
			continue

		# LookItem.load_from sorts items by slot,
		# so a new tab starts when the slot changes.
		if item.slot != current_slot:
			current_slot = item.slot
			list = _create_look_item_list(current_slot)

		list.add_look_item(item)

	Log.debug("Created %d look slot tabs", get_tab_count())


func _create_look_item_list(slot: LookSlot) -> LookItemList:
	const LOOK_ITEM_LIST := preload("res://character_editor/appearance/items/look_item_list.tscn")
	var list: LookItemList = LOOK_ITEM_LIST.instantiate()
	list.name = slot.name
	list.setup(slot)

	list.look_item_selected.connect(item_selected.emit)
	list.look_item_deselected.connect(item_deselected.emit)
	list.preview_requested.connect(preview_requested.emit)

	add_child(list)
	return list


func set_item_preview(item: LookItem, texture: ImageTexture) -> void:
	var list := _find_list(item.slot)
	if list:
		list.set_item_preview(item, texture)


## Selects the item's icon in the list of its slot.
func select_item(item: LookItem) -> void:
	var list := _find_list(item.slot)
	if list:
		list.select_item(item)


## Deselects the item's icon in the list of its slot.
func deselect_item(item: LookItem) -> void:
	var list := _find_list(item.slot)
	if list:
		list.deselect_item(item)


func load_state(visual: CharacterVisual) -> void:
	for look_item_list: LookItemList in get_children():
		look_item_list.load_selected(visual)


func _find_list(slot: LookSlot) -> LookItemList:
	for list: LookItemList in get_children():
		if list.name == slot.name:
			return list

	return null
