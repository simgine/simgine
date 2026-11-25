extends Node3D

## Emitted when a member is created and added to the family.
signal member_added(character: Character)

## Emitted when the selected member changes.
signal current_member_changed(previous: Character, current: Character)

## The character currently shown on the scene.
##
## Setting it hides the previously active character.
var _current_member: Character


func _create_member(character_type: CharacterType) -> void:
	const DEFAULT_POSE: Pose = preload(
		"res://characters/visuals/make_human/data/poses/callharvey3d_standingnatural/standingnatural.tres"
	)
	Log.info("Creating '%s'", character_type.name)
	var member := character_type.create()
	if not member:
		return

	add_child(member)
	member.visual.set_pose(DEFAULT_POSE)
	member_added.emit(member)


func _remove_member(index: int) -> void:
	var member: Character = get_child(index)
	Log.info("Removing '%s'", member.name)
	remove_child(member)
	member.queue_free()


func _set_current_member(index: int) -> void:
	var member: Character = get_child(index)

	if _current_member == member:
		return

	var previous := _current_member
	if previous:
		previous.visible = false

	Log.info("Selecting '%s'", member.name)
	_current_member = member
	_current_member.visible = true
	current_member_changed.emit(previous, _current_member)
