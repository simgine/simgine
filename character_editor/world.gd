extends Node3D

signal character_spawned(character: Character)


func _spawn_character(character_type: CharacterType) -> void:
	var character := character_type.create()
	if not character:
		return

	add_child(character)
	Log.debug("Created character '%s'", character.name)
	character_spawned.emit(character)
