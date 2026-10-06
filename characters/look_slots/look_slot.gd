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

@export var conflicts: Array[LookSlot]


func conflicts_with(other: LookSlot) -> bool:
	if not other:
		return false

	if other == self:
		return true

	return other in conflicts or self in other.conflicts
