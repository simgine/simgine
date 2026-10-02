extends VBoxContainer

@onready var _first_name_edit: LineEdit = %FirstName
@onready var _last_name_edit: LineEdit = %LastName


## Fills the fields when the current member changes.
func set_character(character: Character) -> void:
	_first_name_edit.text = character.first_name
	_last_name_edit.text = character.last_name
