extends Node


func _ready() -> void:
	# The editor should always open with at least one character.
	var add_button: AddMemberButton = %AddMember
	add_button.get_popup().index_pressed.emit(0)
