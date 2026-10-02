extends HBoxContainer

signal button_pressed(index: int)

var _group := ButtonGroup.new()


func _create_button(character: Character) -> void:
	var button := Button.new()
	button.text = character.name
	button.button_group = _group
	button.toggle_mode = true
	button.button_pressed = true
	button.pressed.connect(_emit_button_pressed.bind(button))

	# Insert as second-to-last, so the add button stays last.
	add_child(button)
	move_child(button, -2)

	_emit_button_pressed(button)


func _emit_button_pressed(button: Button) -> void:
	button_pressed.emit(button.get_index())
