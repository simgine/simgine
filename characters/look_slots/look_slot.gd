@tool
class_name LookSlot
extends Resource
## A slot for [LookItem].

## Display name.
@export var name: String

## Whether the slot is part of the character's permanent look.
##
## Permanent slots are always filled with an item and are excluded from look sets.
@export var permanent: bool

@export var conflicts: Array[LookSlot] = _create_empty_conflicts()


# Works around a Godot bug: using `= []` makes this script keep a default array
# that points back to the script through its LookSlot type, even when empty.
# This prevents Godot from freeing the script at exit. Creating the array here
# gives each instance its own array without storing it as the script's default.
static func _create_empty_conflicts() -> Array[LookSlot]:
	return []


func conflicts_with(other: LookSlot) -> bool:
	if not other:
		return false

	if other == self:
		return true

	return other in conflicts or self in other.conflicts
