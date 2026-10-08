@tool
@abstract
class_name CharacterVisual
extends Node3D
## Visual representation of a character.

@export var _look: Array[LookItem]:
	set = set_look


func _ready() -> void:
	for index in range(_look.size() - 1, -1, -1):
		var item := _look[index]
		if not item or not _attach_item(item):
			_look.remove_at(index)


## Replaces the old look with a new one.
func set_look(new_look: Array[LookItem]) -> void:
	_remove_conflicts(new_look)

	if is_node_ready():
		for old_item in _look:
			if old_item and not new_look.has(old_item):
				Log.debug("Removing old %s", old_item)
				_detach_item(old_item)

		for index in range(new_look.size() - 1, -1, -1):
			var new_item := new_look[index]
			if new_item and not _look.has(new_item):
				Log.debug("Adding new %s", new_item)
				if not _attach_item(new_item):
					new_look.remove_at(index)

	_look = new_look


static func _remove_conflicts(items: Array[LookItem]) -> void:
	# Iterate backwards so conflicting items can be removed safely.
	for index in range(items.size() - 1, -1, -1):
		var item := items[index]
		if not item or not item.slot:
			# Keep invalid items for editing from the inspector.
			if not Engine.is_editor_hint():
				items.remove_at(index)
			continue

		for later_index in range(index + 1, items.size()):
			var other_item := items[later_index]
			if item.conflicts_with(other_item):
				items.remove_at(index)
				break


func add_look_item(item: LookItem) -> void:
	# Try to attach first since it can fail.
	if not _attach_item(item):
		return

	for index in range(_look.size() - 1, -1, -1):
		var existing_item := _look[index]
		if item.conflicts_with(existing_item):
			_detach_item(existing_item)
			_look.remove_at(index)

	Log.debug("Adding %s", item)
	_look.append(item)


func remove_look_item(item: LookItem) -> void:
	Log.debug("Removing '%s'", item)
	_look.erase(item)
	_detach_item(item)


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


## Resolves the given [BodyModifier] resources into value parameters.
##
## The returned parameters are grouped by category. I.e. all parameters of a
## category are contiguous. The family editor relies on this ordering.
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


## Returns the current value of a modifier.
##
## The node should be ready before calling this.
@abstract
func get_modifier(key: StringName) -> float


## Sets a modifier value.
##
## The node should be ready before calling this.
@abstract
func set_modifier(key: StringName, value: float) -> void
