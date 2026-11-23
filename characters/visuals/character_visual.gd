@tool
@abstract
class_name CharacterVisual
extends Node3D
## Visual representation of a character.

enum AnimationStyle {
	FEMININE,
	MASCULINE,
}

## Emitted when the attached items or their swatches change.
signal look_changed

## Emitted when the body modifiers change.
signal body_changed

## Currently attached items.
@export var look: CharacterLook = CharacterLook.new():
	set = _set_look

## Animation style of the character.
var anim_style: AnimationStyle


func _ready() -> void:
	_connect_look(look)
	for item in look.items:
		_attach_item_with_swatch(item)


## Replaces the old look with a new one.
func _set_look(new_look: CharacterLook) -> void:
	if look == new_look:
		return

	var previous := look
	look = new_look
	if not is_node_ready():
		return

	var changed := false
	Log.trace("Removing old look")
	_disconnect_look(previous)
	for item in previous.items:
		if item and not look.items.has(item):
			_detach_item(item)
			changed = true

	Log.trace("Adding new look")
	_connect_look(look)
	for item in look.items:
		if not previous.items.has(item):
			_attach_item_with_swatch(item)
			changed = true
			continue

		var swatch := look.get_swatch(item)
		if previous.get_swatch(item) != swatch:
			_apply_item_swatch(item, swatch)
			changed = true

	if changed:
		look_changed.emit()


func _connect_look(new_look: CharacterLook) -> void:
	new_look.item_added.connect(_attach_item_with_swatch)
	new_look.item_removed.connect(_detach_item)
	new_look.item_swatch_changed.connect(_update_item_swatch)
	new_look.item_added.connect(look_changed.emit.unbind(1))
	new_look.item_removed.connect(look_changed.emit.unbind(1))


func _disconnect_look(old_look: CharacterLook) -> void:
	old_look.item_added.disconnect(_attach_item_with_swatch)
	old_look.item_removed.disconnect(_detach_item)
	old_look.item_swatch_changed.disconnect(_update_item_swatch)
	old_look.item_added.disconnect(look_changed.emit)
	old_look.item_removed.disconnect(look_changed.emit)


func _attach_item_with_swatch(item: LookItem) -> void:
	if not _attach_item(item):
		return

	var swatch := look.get_swatch(item)
	if swatch:
		_apply_item_swatch(item, swatch)


func _update_item_swatch(item: LookItem, swatch: LookSwatch) -> void:
	_apply_item_swatch(item, swatch)
	look_changed.emit()


## Displays item's visual.
##
## Returns `false` if nothing was attached.
## The node should be ready before calling this.
@abstract
func _attach_item(item: LookItem) -> bool


## Applies a swatch to an attached item, or restores its default when null.
@abstract
func _apply_item_swatch(item: LookItem, swatch: LookSwatch) -> void


## Removes item's visual.
##
## Does nothing if the item is not attached.
## The node should be ready before calling this.
@abstract
func _detach_item(item: LookItem) -> void


## Returns the attached item's mesh instance, or [code]null[/code] if it has none.
@abstract
func get_item_mesh(_item: LookItem) -> MeshInstance3D


## Returns a directory where to search for [LookItem] resources.
@abstract
func get_item_dir() -> String


## Returns a directory where to search for [Pose] resources.
@abstract
func get_pose_dir() -> String


## Returns the directory where to recursively search for [BodyModifier] resources.
@abstract
func get_modifiers_dir() -> String


## Returns the path to the scene of the model used to preview [LookItem]s.
##
## The scene's root must be a [CharacterVisual].
@abstract
func get_preview_scene_path() -> String


## Returns the visual's skeleton profile identifier, e.g. "SkeletonProfileHumanoid".
##
## Used to filter [AnimationClip]s by [member AnimationClip.skeleton_profile].
@abstract
func get_skeleton_profile() -> StringName


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


## Returns the name of the modifier that controls the character's gender.
@abstract
func get_gender_modifier_name() -> StringName


## Sets a modifier value.
##
## The node should be ready before calling this.
func set_modifier(key: StringName, value: float) -> void:
	_apply_modifier(key, value)
	body_changed.emit()


## Applies a modifier value to the visual.
@abstract
func _apply_modifier(key: StringName, value: float) -> void


## Applies [param pose] to the character's skeleton, or resets it to rest if null.
##
## The node should be ready before calling this.
@abstract
func set_pose(pose: Pose) -> void
