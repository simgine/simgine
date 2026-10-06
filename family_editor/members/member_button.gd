class_name MemberButton
extends Button

signal remove_pressed

@onready var _remove_button: Button = $RemoveButton

var _removal_allowed := false


func _ready() -> void:
	mouse_entered.connect(_update_remove_button)
	mouse_exited.connect(_update_remove_button)
	_remove_button.mouse_entered.connect(_update_remove_button)
	_remove_button.mouse_exited.connect(_update_remove_button)
	_remove_button.pressed.connect(remove_pressed.emit)


func press() -> void:
	button_pressed = true
	# Setting `button_pressed` programmatically doesn't emit `pressed`,
	# so trigger it manually.
	pressed.emit()


## Sets whether the remove button should be shown.
func set_removal_allowed(allowed: bool) -> void:
	_removal_allowed = allowed
	_update_remove_button()


func _update_remove_button() -> void:
	# Moving onto the remove button makes this button not hovered,
	# so we need to check both.
	var hovered := is_hovered() or _remove_button.is_hovered()
	_remove_button.visible = _removal_allowed and hovered
