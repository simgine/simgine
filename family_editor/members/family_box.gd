extends HBoxContainer

signal button_pressed(index: int)
signal button_removed(index: int)
signal removal_allowed_changed(allowed: bool)

var _group := ButtonGroup.new()
var _removal_allowed := false


func _create_button(_character: Character) -> void:
	const MEMBER_BUTTON := preload("res://family_editor/members/member_button.tscn")
	var button: MemberButton = MEMBER_BUTTON.instantiate()
	button.button_group = _group
	button.pressed.connect(_emit_button_pressed.bind(button))
	button.remove_pressed.connect(_remove_button.bind(button))
	removal_allowed_changed.connect(button.set_removal_allowed)

	# Insert as second-to-last, so the add button stays last.
	add_child(button)
	move_child(button, -2)

	button.press()

	# Set the initial because the signal only fires on change.
	button.set_removal_allowed(_removal_allowed)
	_update_removal_allowed()


func _remove_button(button: MemberButton) -> void:
	var index := button.get_index()
	remove_child(button)
	removal_allowed_changed.disconnect(button.set_removal_allowed)
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
	var allowed := _get_member_count() > 1
	if allowed != _removal_allowed:
		_removal_allowed = allowed
		removal_allowed_changed.emit(allowed)


func _get_member_count() -> int:
	# The last child is always the add button.
	return get_child_count() - 1


func _emit_button_pressed(button: MemberButton) -> void:
	button_pressed.emit(button.get_index())
