extends Node3D

signal member_added(character: Character)

@export var rotate_speed := 0.005

## The character currently shown on the scene.
##
## Setting it hides the previously active character.
var current_member: Character:
	set = set_current_member


func create_member(character_type: CharacterType) -> void:
	var character := character_type.create()
	if not character:
		return

	add_child(character)
	Log.debug("Created character '%s'", character.name)
	member_added.emit(character)


func _unhandled_input(event: InputEvent) -> void:
	var mouse_motion := event as InputEventMouseMotion
	if current_member and mouse_motion and Input.is_action_pressed("rotate_character"):
		current_member.rotation.y += mouse_motion.relative.x * rotate_speed


func set_current_member(character: Character) -> void:
	if current_member == character:
		return

	if current_member:
		current_member.visible = false

	current_member = character

	if character:
		assert(character.get_parent() == self)
		character.visible = true
