class_name ModifierList
extends ScrollContainer

signal modifier_changed(key: StringName, value: float)

@onready var _content: VBoxContainer = %Content


func add_modifier(
	params: BodyModifierParams,
	left_suffix: StringName,
	right_suffix: StringName,
) -> void:
	const MODIFIER_SLIDER := preload("res://family_editor/appearance/modifier_slider.tscn")
	var slider: ModifierSlider = MODIFIER_SLIDER.instantiate()
	slider.setup(params, left_suffix, right_suffix)

	slider.modifier_changed.connect(modifier_changed.emit)
	_content.add_child(slider)


## Loads the shown values without emitting [signal modifier_changed].
func load_values(visual: CharacterVisual) -> void:
	for slider: ModifierSlider in _content.get_children():
		slider.load_value(visual)
