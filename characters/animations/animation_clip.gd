class_name AnimationClip
extends Resource
## An animation with metadata.

## Name of the clip.
@export var name: StringName

## The skeleton profile compatible with this animation.
##
## Only visuals with the same [method CharacterVisual.get_skeleton_profile]
## can play the clip.
@export var skeleton_profile: StringName

## Requirements the request context must satisfy, e.g. "feminine".
##
## Clips without tags fit every context and act as the fallback.
@export var tags: Array[StringName]

## Library that holds the animation.
@export var library: AnimationLibrary

## Name of the animation to play from [property library].
@export var animation: StringName

## All clips, keyed by [member name].
##
## [Array] holds [AnimationClip]s with that name.
## Automatically loaded on first access.
static var clips: Dictionary[StringName, Array]:
	get:
		if clips.is_empty():
			clips = _load_all()
		return clips


## Loads all clips recursively.
##
## Invalid clips are skipped with a warning.
static func _load_all() -> Dictionary[StringName, Array]:
	var loaded_clips: Dictionary[StringName, Array]
	_load_recursively("res://characters/animations/", loaded_clips)
	return loaded_clips


static func _load_recursively(dir: String, loaded_clips: Dictionary[StringName, Array]) -> void:
	for entry in ResourceLoader.list_directory(dir):
		var path := dir.path_join(entry)

		if entry.ends_with("/"):
			_load_recursively(path, loaded_clips)
			continue

		if entry.get_extension() not in ["tres", "res"]:
			continue

		var clip := ResourceLoader.load(path) as AnimationClip
		if not clip:
			Log.warn("Loaded resource '%s' is not an AnimationClip, skipping", path)
			continue

		if not clip.skeleton_profile:
			Log.warn("'%s' has no skeleton profile, skipping", path)
			return

		if not clip.name:
			Log.warn("'%s' has no name, skipping", path)
			return

		if not clip.library:
			Log.warn("'%s' has no library, skipping", path)
			return

		if not clip.animation:
			Log.warn("'%s' has no animation name, skipping", path)
			return

		if not clip.library.has_animation(clip.animation):
			Log.warn("'%s' has no animation '%s' in its library, skipping", path, clip.animation)
			return

		var name_clips: Array[AnimationClip] = loaded_clips.get_or_add(
			clip.name,
			[] as Array[AnimationClip],
		)
		for other in name_clips:
			if clip.tags.size() == other.tags.size() and clip.matches(other.tags):
				Log.warn(
					"'%s' conflicts with an earlier clip named '%s', skipping",
					path,
					clip.name,
				)
				return

		name_clips.append(clip)


## Returns the best matching clip, or `null` if none matches.
##
## Clips must match [param profile] and have all their [member tags] in
## [param context]. The clip with the most tags wins.
static func resolve(
	clip_name: StringName,
	profile: StringName,
	context: Array[StringName],
) -> AnimationClip:
	if not clips.has(clip_name):
		return null

	var best: AnimationClip = null
	for clip: AnimationClip in clips[clip_name]:
		if clip.skeleton_profile != profile:
			continue

		if not clip.matches(context):
			continue

		if not best or clip.tags.size() > best.tags.size():
			best = clip

	return best


## Returns whether [param context] satisfies every tag required by this clip.
func matches(context: Array[StringName]) -> bool:
	for tag in tags:
		if not context.has(tag):
			return false

	return true


func _to_string() -> String:
	return "AnimationClip('%s', name='%s')" % [skeleton_profile, name]
