extends Node3D

signal member_added(character: Character)

@export var rotate_speed := 0.005

## The character currently shown on the scene.
##
## Setting it hides the previously active character.
var _current_member: Character


func _unhandled_input(event: InputEvent) -> void:
	var mouse_motion := event as InputEventMouseMotion
	if _current_member and mouse_motion and Input.is_action_pressed("editor_rotate"):
		_current_member.rotation.y += mouse_motion.relative.x * rotate_speed


func _create_member(character_type: CharacterType) -> void:
	var member := character_type.create()
	if not member:
		return

	add_child(member)
	Log.debug("Created member '%s'", member.name)
	member_added.emit(member)


func _set_current_member(index: int) -> void:
	var member: Character = get_child(index)

	if _current_member == member:
		return

	if _current_member:
		_current_member.visible = false

	_current_member = member
	_current_member.visible = true
