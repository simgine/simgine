extends Node3D

signal member_added(character: Character)

@export var rotate_speed := 0.005

## The character currently shown on the scene.
##
## Setting it hides the previously active character.
var current_member: Character:
	set = set_current_member


func create_member(character_type: CharacterType) -> void:
	var member := character_type.create()
	if not member:
		return

	add_child(member)
	Log.debug("Created member '%s'", member.name)
	member_added.emit(member)


func _unhandled_input(event: InputEvent) -> void:
	var mouse_motion := event as InputEventMouseMotion
	if current_member and mouse_motion and Input.is_action_pressed("rotate_character"):
		current_member.rotation.y += mouse_motion.relative.x * rotate_speed


func set_current_member(member: Character) -> void:
	assert(member.get_parent() == self)

	if current_member == member:
		return

	if current_member:
		current_member.visible = false

	current_member = member
	current_member.visible = true
