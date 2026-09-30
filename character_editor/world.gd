extends Node3D

signal character_spawned(character: Character)

## The character currently shown on the scene.
##
## Setting it hides the previously selected character.
var selected_character: Character:
	set = set_selected_character


func spawn_character(character_type: CharacterType) -> void:
	var character := character_type.create()
	if not character:
		return

	add_child(character)
	Log.debug("Created character '%s'", character.name)
	character_spawned.emit(character)


func set_selected_character(character: Character) -> void:
	if selected_character == character:
		return

	if selected_character:
		selected_character.visible = false

	selected_character = character

	if character:
		character.visible = true
