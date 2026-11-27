extends VBoxContainer
## The appearance section of the character editor.
##
## Shows the [AppearanceTabs] for each [CharacterVisual] type and keeps
## them in sync with the member's look.

var _current_tabs: AppearanceTabs

## Cached tab sets for different [CharacterVisual] types.
var _visual_tabs: Dictionary[GDScript, AppearanceTabs]


func _on_current_member_changed(previous: Character, current: Character) -> void:
	if previous:
		var previous_tabs := _visual_tabs[previous.visual.get_script()]
		_disconnect_visual(previous_tabs, previous.visual)

	Log.debug("Loading appearance for '%s'", current.name)
	var visual := current.visual
	var key: GDScript = visual.get_script()
	if not _visual_tabs.has(key):
		_visual_tabs[key] = _create_tabs(visual)

	var tabs := _visual_tabs[key]
	if _current_tabs != tabs:
		if _current_tabs:
			_current_tabs.hide()

		_current_tabs = tabs
		tabs.show()

	_connect_visual(tabs, visual)
	tabs.load_state(visual)


## Mirrors the gender slider when the profile switches the member's gender.
func _mirror_gender_slider() -> void:
	_current_tabs.body_tabs.gender_slider.mirror_value()


static func _disconnect_visual(tabs: AppearanceTabs, visual: CharacterVisual) -> void:
	tabs.body_tabs.modifier_changed.disconnect(visual.set_modifier)
	tabs.features_tabs.item_selected.disconnect(visual.look.apply)
	tabs.features_tabs.item_deselected.disconnect(visual.look.remove)
	tabs.wardrobe_tabs.item_selected.disconnect(visual.look.apply)
	tabs.wardrobe_tabs.item_deselected.disconnect(visual.look.remove)
	visual.look.item_added.disconnect(tabs.select_item)
	visual.look.item_removed.disconnect(tabs.deselect_item)


static func _connect_visual(tabs: AppearanceTabs, visual: CharacterVisual) -> void:
	tabs.body_tabs.modifier_changed.connect(visual.set_modifier)
	tabs.features_tabs.item_selected.connect(visual.look.apply)
	tabs.features_tabs.item_deselected.connect(visual.look.remove)
	tabs.wardrobe_tabs.item_selected.connect(visual.look.apply)
	tabs.wardrobe_tabs.item_deselected.connect(visual.look.remove)
	visual.look.item_added.connect(tabs.select_item.unbind(1))
	visual.look.item_removed.connect(tabs.deselect_item)


func _create_tabs(visual: CharacterVisual) -> AppearanceTabs:
	const APPEARANCE_TABS := preload("res://character_editor/appearance/appearance_tabs.tscn")
	var tabs: AppearanceTabs = APPEARANCE_TABS.instantiate()

	# The tabs must be in the tree before populating,
	# since we access @onready members later.
	add_child(tabs)

	tabs.body_tabs.populate(visual)

	var items := LookItem.load_from(visual.get_item_dir())
	tabs.features_tabs.populate(items)
	tabs.wardrobe_tabs.populate(items)

	tabs.preview.load_scene(visual.get_preview_scene_path())

	return tabs
