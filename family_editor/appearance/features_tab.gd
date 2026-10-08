class_name FeaturesTab
extends Control

signal item_selected(item: LookItem)

var _current_tabs: TabContainer

## Lazily initialized containers for different [CharacterVisual] types.
var _cached_tabs: Dictionary[GDScript, TabContainer]


func show_character(visual: CharacterVisual) -> void:
	var key: GDScript = visual.get_script()
	if not _cached_tabs.has(key):
		var new_tabs := TabContainer.new()
		new_tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(new_tabs)
		_populate_tabs(new_tabs, visual)
		_cached_tabs[key] = new_tabs

	var tabs := _cached_tabs[key]
	if _current_tabs != tabs:
		if _current_tabs:
			_current_tabs.hide()

		_current_tabs = tabs
		_current_tabs.show()

	_load_selected(visual)


func _populate_tabs(tabs: TabContainer, visual: CharacterVisual) -> void:
	var current_slot: LookSlot = null
	var list: LookItemList
	for item in LookItem.load_from(visual.get_item_dir()):
		if not item.slot.permanent:
			continue

		# Backends emit items grouped by slot,
		# so a new tab starts when the slot changes.
		if item.slot != current_slot:
			current_slot = item.slot
			list = _create_look_item_list(tabs, current_slot)

		list.add_look_item(item)

	Log.debug("Created %d look slot tabs", tabs.get_tab_count())


func _create_look_item_list(tabs: TabContainer, slot: LookSlot) -> LookItemList:
	const LOOK_ITEM_LIST := preload("res://family_editor/appearance/look_item_list.tscn")
	var list: LookItemList = LOOK_ITEM_LIST.instantiate()
	list.name = slot.name
	list.setup(slot)

	list.look_item_selected.connect(item_selected.emit)
	tabs.add_child(list)
	return list


func _load_selected(visual: CharacterVisual) -> void:
	for look_item_list: LookItemList in _current_tabs.get_children():
		look_item_list.load_selected(visual)
