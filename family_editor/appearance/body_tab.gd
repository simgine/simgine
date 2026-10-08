class_name BodyTab
extends Control

signal modifier_changed(key: StringName, value: float)

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

	_load_values(visual)


func _populate_tabs(tabs: TabContainer, visual: CharacterVisual) -> void:
	var current_category: ModifierCategory = null
	var list: ModifierList
	var modifiers := BodyModifier.load_from(visual.get_modifiers_dir())
	var params := visual.resolve_modifier_params(modifiers)
	for modifier_name in modifiers:
		var modifier := modifiers[modifier_name]
		Log.warn(
			"BodyModifier '%s' is not supported by the visual, skipping",
			modifier.resource_path,
		)

	var left_suffix := visual.get_left_modifier_suffix()
	var right_suffix := visual.get_right_modifier_suffix()
	for param in params:
		# Backends emit modifiers grouped by category,
		# so a new tab starts when the category changes.
		if param.modifier.category != current_category:
			current_category = param.modifier.category

			list = _create_modifier_list(tabs, current_category)

		list.add_modifier(param, left_suffix, right_suffix)

	Log.debug("Created %d modifier category tabs", tabs.get_tab_count())


func _create_modifier_list(tabs: TabContainer, category: ModifierCategory) -> ModifierList:
	const MODIFIER_LIST := preload("res://family_editor/appearance/modifier_list.tscn")
	var list: ModifierList = MODIFIER_LIST.instantiate()
	list.name = category.name

	list.modifier_changed.connect(modifier_changed.emit)
	tabs.add_child(list)
	return list


func _load_values(visual: CharacterVisual) -> void:
	for list: ModifierList in _current_tabs.get_children():
		list.load_values(visual)
