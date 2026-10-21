class_name LookItemPreview
extends SubViewport
## Renders previews for [LookItem]s in a scene from [method CharacterVisual.get_preview_scene_path].

signal preview_ready(item: LookItem, texture: ImageTexture)

var _visual: CharacterVisual

var _queue: Array[LookItem]
var _rendering := false

## Item currently layered on the base look.
var _layered_item: LookItem

## Base look items displaced by [member _layered_item].
var _displaced: Array[LookItem]


func setup(scene_path: String) -> void:
	_visual = _load_visual(scene_path)


func request_preview(item: LookItem) -> void:
	assert(not _queue.has(item))
	_queue.append(item)
	if not _rendering:
		_rendering = true
		_render_pending()


func _render_pending() -> void:
	while not _queue.is_empty():
		await _render_next(_queue.pop_front())

	_rendering = false


func _render_next(item: LookItem) -> void:
	Log.debug("Rendering the preview of %s", item)
	_restore_base_look()

	# Record conflicting items to restore before the next item.
	for look_item: LookItem in _visual.look.items:
		if item.conflicts_with(look_item):
			_displaced.append(look_item)

	_visual.look.add(item)
	_layered_item = item

	# Wait for the attachment rebuild, which is deferred.
	await get_tree().process_frame

	if not _activate_camera(item.slot):
		return

	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame

	var image := get_texture().get_image()
	if not image:
		Log.debug("Skipping the preview of '%s': no rendered image", item.name)
		return

	preview_ready.emit(item, ImageTexture.create_from_image(image))


func _restore_base_look() -> void:
	if _layered_item:
		_visual.look.remove(_layered_item)
	for displaced_item in _displaced:
		_visual.look.add(displaced_item)
	_displaced.clear()
	_layered_item = null


func _activate_camera(slot: LookSlot) -> bool:
	var camera_name := slot.preview_camera
	var camera := _visual.get_node_or_null(camera_name) as Camera3D
	if not camera:
		Log.error("Preview camera '%s' of the '%s' slot is missing", camera_name, slot.name)
		return false

	camera.current = true
	return true


func _load_visual(scene_path: String) -> CharacterVisual:
	var scene := ResourceLoader.load(scene_path) as PackedScene
	if not scene:
		Log.error("Unable to load the preview scene '%s'", scene_path)
		return null

	var node := scene.instantiate()
	var visual := node as CharacterVisual
	if not visual:
		Log.error("The preview scene '%s' root is not a CharacterVisual", scene_path)
		node.free()
		return null

	add_child(visual)
	return visual
