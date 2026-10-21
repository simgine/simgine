@tool
@abstract
class_name CharacterVisual
extends Node3D
## Visual representation of a character.

## Emitted when the look items change.
signal look_changed

## Emitted when the body modifiers change.
signal body_changed

## Currently equipped items.
@export var look: CharacterLook = CharacterLook.new():
	set = _set_look


func _ready() -> void:
	_connect_look(look)
	for item in look.items:
		if item:
			_attach_item(item)


## Replaces the old look with a new one.
func _set_look(new_look: CharacterLook) -> void:
	if look == new_look:
		return

	# The look from the inspector may come with invalid or conflicting items.
	new_look.remove_invalid()

	var changed := false
	if is_node_ready():
		Log.trace("Removing old look")
		_disconnect_look(look)
		for item in look.items:
			if item and not new_look.items.has(item):
				_detach_item(item)
				changed = true

		Log.trace("Adding new look")
		_connect_look(new_look)
		for new_item in new_look.items:
			if new_item and not look.items.has(new_item):
				_attach_item(new_item)
				changed = true

	look = new_look
	if changed:
		look_changed.emit()


func _connect_look(new_look: CharacterLook) -> void:
	new_look.item_added.connect(_attach_item)
	new_look.item_removed.connect(_detach_item)
	new_look.item_added.connect(look_changed.emit.unbind(1))
	new_look.item_removed.connect(look_changed.emit.unbind(1))


func _disconnect_look(old_look: CharacterLook) -> void:
	old_look.item_added.disconnect(_attach_item)
	old_look.item_removed.disconnect(_detach_item)
	old_look.item_added.disconnect(look_changed.emit)
	old_look.item_removed.disconnect(look_changed.emit)


## Displays item's visual.
##
## Returns `false` if nothing was attached.
## The node should be ready before calling this.
@abstract
func _attach_item(item: LookItem) -> bool


## Removes item's visual.
##
## Does nothing if the item is not attached.
## The node should be ready before calling this.
@abstract
func _detach_item(item: LookItem) -> void


## Returns a directory where to search for [LookItem] resources.
@abstract
func get_item_dir() -> String


## Returns the directory where to recursively search for [BodyModifier] resources.
@abstract
func get_modifiers_dir() -> String


## Returns the path to the scene of the model used to preview [LookItem]s.
##
## The scene's root must be a [CharacterVisual].
@abstract
func get_preview_scene_path() -> String


## Resolves the given [BodyModifier] resources into value parameters.
##
## The returned parameters are grouped by category. I.e. all parameters of a
## category are contiguous. The character editor relies on this ordering.
##
## All matched modifiers will be removed from [param modifiers].
@abstract
func resolve_modifier_params(
	modifiers: Dictionary[StringName, BodyModifier]
) -> Array[BodyModifierParams]


## Returns the suffix used to reference the left value of a sided modifier.
@abstract
func get_left_modifier_suffix() -> StringName


## Returns the suffix used to reference the right value of a sided modifier.
@abstract
func get_right_modifier_suffix() -> StringName


## Returns the position of the given bone in world space.
@abstract
func get_bone_position(bone: String) -> Vector3


## Returns the current value of a modifier.
##
## The node should be ready before calling this.
@abstract
func get_modifier(key: StringName) -> float


## Sets a modifier value.
##
## The node should be ready before calling this.
func set_modifier(key: StringName, value: float) -> void:
	_apply_modifier(key, value)
	body_changed.emit()


## Applies a modifier value to the visual.
@abstract
func _apply_modifier(key: StringName, value: float) -> void
