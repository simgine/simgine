extends Node


func _ready() -> void:
	var types := CharacterType.get_available()
	var add_button: AddMemberButton = %AddMember
	add_button.set_types(types)
	if not types.is_empty():
		# The editor should always open with at least one character.
		$Family.create_member(types[0])
