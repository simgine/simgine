class_name BodyModifier
extends Resource
## A body shape modifier from a [CharacterVisual].

## Key that references the modifier in a [CharacterVisual].
@export var key: StringName

## Display name.
@export var name: String

## Editor label that describes the effect of decreasing the value.
@export var min_label: String

## Like [member min_label], but for the effect of increasing the value.
@export var max_label: String

## Display category for the character editor.
@export var category: ModifierCategory
