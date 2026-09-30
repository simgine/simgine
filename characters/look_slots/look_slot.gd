@tool
class_name LookSlot
extends Resource

@export var conflicts: Array[LookSlot]


func conflicts_with(other: LookSlot) -> bool:
	if not other:
		return false

	if other == self:
		return true

	return other in conflicts or self in other.conflicts
