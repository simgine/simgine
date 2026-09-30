class_name BodyModifierParams
extends RefCounted
## Associates a [BodyModifier] with parameters from a [CharacterVisual].

## Associated modifier.
var modifier: BodyModifier

## Inclusive range of accepted values.
var value_range: Vector2

## Default modifier value.
var default_value: float

## Whether the modifier has separate left and right values.
var has_left_and_right: bool


func _init(
	p_modifier: BodyModifier,
	p_value_range: Vector2,
	p_default_value: float,
	p_has_left_and_right := false,
) -> void:
	modifier = p_modifier
	value_range = p_value_range
	default_value = p_default_value
	has_left_and_right = p_has_left_and_right
