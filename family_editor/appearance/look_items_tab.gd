class_name LookItemsTab
extends Control
## An appearance tab that groups [LookItem]s into subtabs by slot.

signal item_selected(item: LookItem)

## Whether to show items with permanent slots, or items with the rest.
@export var permanent: bool

@onready var _tabs: TabContainer = $Tabs


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
			list = _create_look_item_list(_tabs, current_slot)

		list.add_look_item(item)

	Log.debug("Created %d look slot tabs", _tabs.get_tab_count())


func _create_look_item_list(tabs: TabContainer, slot: LookSlot) -> LookItemList:
	const LOOK_ITEM_LIST := preload("res://family_editor/appearance/look_item_list.tscn")
	var list: LookItemList = LOOK_ITEM_LIST.instantiate()
	list.name = slot.name
	list.setup(slot)

	list.look_item_selected.connect(item_selected.emit)
	tabs.add_child(list)
	return list


func load_state(visual: CharacterVisual) -> void:
	for look_item_list: LookItemList in _tabs.get_children():
		look_item_list.load_selected(visual)
