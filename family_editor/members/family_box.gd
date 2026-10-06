extends HBoxContainer

signal button_pressed(index: int)
signal button_removed(index: int)

var _group := ButtonGroup.new()


func _create_button(_character: Character) -> void:
	const MEMBER_BUTTON := preload("res://family_editor/members/member_button.tscn")
	var button: MemberButton = MEMBER_BUTTON.instantiate()
	button.button_group = _group
	button.pressed.connect(_emit_button_pressed.bind(button))
	button.remove_pressed.connect(_remove_button.bind(button))

	# Insert as second-to-last, so the add button stays last.
	add_child(button)
	move_child(button, -2)

	button.press()

	_update_removal_allowed()


func _remove_button(button: MemberButton) -> void:
	var index := button.get_index()
	remove_child(button)

	_update_removal_allowed()
	button_removed.emit(index)

	if button.button_pressed:
		# If the button was pressed, select the member that shifts into its index.
		# If it was the last member, select the new last one.
		var member_count := _get_member_count()
		var other_button: MemberButton = get_child(mini(index, member_count - 1))
		other_button.press()

	button.queue_free()


## A member can only be removed when there is more than one.
func _update_removal_allowed() -> void:
	var member_count := _get_member_count()
	var allowed := member_count > 1
	for index in member_count:
		var button: MemberButton = get_child(index)
		button.set_removal_allowed(allowed)


func _get_member_count() -> int:
	# The last child is always the add button.
	return get_child_count() - 1


func _emit_button_pressed(button: MemberButton) -> void:
	button_pressed.emit(button.get_index())
