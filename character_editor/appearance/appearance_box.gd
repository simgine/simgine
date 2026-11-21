extends VBoxContainer
## The appearance section of the character editor.
##
## Shows the [AppearanceTabs] for each [CharacterVisual] type and keeps
## them in sync with the member's look.

signal modifier_changed(key: StringName, value: float)
signal item_selected(item: LookItem)
signal item_deselected(item: LookItem)

var _current_tabs: AppearanceTabs

## Cached tab sets for different [CharacterVisual] types.
var _visual_tabs: Dictionary[GDScript, AppearanceTabs]


func _load_state(character: Character) -> void:
	Log.debug("Loading appearance for '%s'", character.name)

	var visual := character.visual
	var key: GDScript = visual.get_script()
	if not _visual_tabs.has(key):
		_visual_tabs[key] = _create_tabs(visual)

	var tabs := _visual_tabs[key]
	if _current_tabs != tabs:
		if _current_tabs:
			_current_tabs.hide()

		_current_tabs = tabs
		tabs.show()

	tabs.load_state(visual)


func _create_tabs(visual: CharacterVisual) -> AppearanceTabs:
	const APPEARANCE_TABS := preload("res://character_editor/appearance/appearance_tabs.tscn")
	var tabs: AppearanceTabs = APPEARANCE_TABS.instantiate()

	# The tabs must be in the tree before populating,
	# since we access @onready members later.
	add_child(tabs)

	tabs.body_tabs.modifier_changed.connect(modifier_changed.emit)
	tabs.body_tabs.populate(visual)

	var items := LookItem.load_from(visual.get_item_dir())

	tabs.features_tabs.item_selected.connect(item_selected.emit)
	tabs.features_tabs.item_deselected.connect(item_deselected.emit)
	tabs.features_tabs.populate(items)

	tabs.wardrobe_tabs.item_selected.connect(item_selected.emit)
	tabs.wardrobe_tabs.item_deselected.connect(item_deselected.emit)
	tabs.wardrobe_tabs.populate(items)

	tabs.preview.setup(visual.get_preview_scene_path())

	return tabs


func _select_item(item: LookItem) -> void:
	_current_tabs.select_item(item)


func _deselect_item(item: LookItem) -> void:
	_current_tabs.deselect_item(item)
