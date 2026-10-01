extends HBoxContainer

signal member_pressed(character: Character)

var _group := ButtonGroup.new()


func _create_button(character: Character) -> void:
	var button := Button.new()
	button.text = character.name
	button.button_group = _group
	button.toggle_mode = true
	button.button_pressed = true
	button.pressed.connect(member_pressed.emit.bind(character))
	add_child(button)

	# Setting `button_pressed` programmatically doesn't emit `pressed`,
	# so trigger the selection explicitly.
	member_pressed.emit(character)
