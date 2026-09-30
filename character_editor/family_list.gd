extends HBoxContainer


func _create_button(character: Character) -> void:
	var button := Button.new()
	button.text = character.name
	add_child(button)
