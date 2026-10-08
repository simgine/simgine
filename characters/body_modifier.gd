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


## Loads all modifiers in the given directory recursively.
##
## The result is keyed by [property key].
static func load_from(dir: String) -> Dictionary[StringName, BodyModifier]:
	var modifiers: Dictionary[StringName, BodyModifier] = { }
	_load_recursively(dir, modifiers)
	return modifiers


static func _load_recursively(dir: String, modifiers: Dictionary[StringName, BodyModifier]) -> void:
	for file_name in ResourceLoader.list_directory(dir):
		var path := dir.path_join(file_name)

		if file_name.ends_with("/"):
			_load_recursively(path, modifiers)
			continue

		if file_name.get_extension() not in ["tres", "res"]:
			continue

		var modifier := ResourceLoader.load(path) as BodyModifier
		if not modifier:
			Log.warn("Resource '%s' is not a BodyModifier, skipping", path)
			continue

		if modifier.key.is_empty():
			Log.warn("'%s' has an empty key, skipping", path)
			continue

		if not modifier.category:
			Log.warn("'%s' has no category, skipping", path)
			continue

		if modifiers.has(modifier.key):
			Log.warn("Duplicate key '%s' in '%s', skipping", modifier.key, path)
			continue

		modifiers[modifier.key] = modifier
