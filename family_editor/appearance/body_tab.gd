class_name BodyTab
extends Control

signal modifier_changed(key: StringName, value: float)

@onready var _tabs: TabContainer = $Tabs


func populate(visual: CharacterVisual) -> void:
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

			list = _create_modifier_list(_tabs, current_category)

		list.add_modifier(param, left_suffix, right_suffix)

	Log.debug("Created %d modifier category tabs", _tabs.get_tab_count())


func _create_modifier_list(tabs: TabContainer, category: ModifierCategory) -> ModifierList:
	const MODIFIER_LIST := preload("res://family_editor/appearance/modifier_list.tscn")
	var list: ModifierList = MODIFIER_LIST.instantiate()
	list.name = category.name

	list.modifier_changed.connect(modifier_changed.emit)
	tabs.add_child(list)
	return list


func load_state(visual: CharacterVisual) -> void:
	for list: ModifierList in _tabs.get_children():
		list.load_values(visual)
