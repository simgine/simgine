extends VBoxContainer

signal modifier_changed(key: StringName, value: float)

var _current_tabs: TabContainer

## Lazily initialized containers for different [CharacterVisual] types.
var _cached_tabs: Dictionary[GDScript, TabContainer]


## Shows the modifiers of the given character.
func set_character(character: Character) -> void:
	Log.debug("Loading modifiers for '%s'", character.name)

	var key: GDScript = character.visual.get_script()
	if not _cached_tabs.has(key):
		var new_tabs := TabContainer.new()
		new_tabs.name = character.name
		new_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(new_tabs)
		_populate_tabs(new_tabs, character.visual)
		_cached_tabs[key] = new_tabs

	var tabs := _cached_tabs[key]
	if _current_tabs != tabs:
		if _current_tabs:
			_current_tabs.hide()

		_current_tabs = tabs
		_current_tabs.show()

	_load_values(character.visual)


func _populate_tabs(tabs: TabContainer, visual: CharacterVisual) -> void:
	# Backends emit modifiers grouped by category,
	# so a new page starts when the category changes.
	var current_category: ModifierCategory = null
	var tab_content: VBoxContainer
	for param in visual.get_available_modifiers():
		if param.modifier.category != current_category:
			current_category = param.modifier.category

			const MODIFIERS_TAB := preload("res://family_editor/modifiers_tab.tscn")
			var tab: ModifiersTab = MODIFIERS_TAB.instantiate()
			tab.name = current_category.name
			tabs.add_child(tab)
			tab_content = tab.content

		_create_modifier(tab_content, visual, param)

	Log.debug("Created %d modifier category tabs", tabs.get_tab_count())


func _create_modifier(
	content: VBoxContainer,
	visual: CharacterVisual,
	param: BodyModifierParams,
) -> void:
	const MODIFIER_BOX := preload("res://family_editor/modifier_box.tscn")
	var modifier: ModifierBox = MODIFIER_BOX.instantiate()
	modifier.setup(param, visual.get_left_modifier_suffix(), visual.get_right_modifier_suffix())

	modifier.modifier_changed.connect(modifier_changed.emit)
	content.add_child(modifier)


func _load_values(visual: CharacterVisual) -> void:
	for tab: ModifiersTab in _current_tabs.get_children():
		for modifier_box: ModifierBox in tab.content.get_children():
			modifier_box.load_value(visual)
