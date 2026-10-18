class_name LookItemPreview
extends SubViewport
## Renders previews for [LookItem]s in a scene from [method CharacterVisual.get_preview_scene_path].

signal preview_ready(item: LookItem, texture: ImageTexture)

var _visual: CharacterVisual

## Default look from the preview scene.
##
## Previewed items layered on top of it.
var _base_look: Array[LookItem]

var _queue: Array[LookItem]
var _rendering := false


func setup(scene_path: String) -> void:
	_visual = _load_visual(scene_path)
	_base_look = _visual.get_look()


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
	Log.debug("rendering preview for %s", item.name)

	# The thumbnail shows the item on the base look from the preview scene.
	# The item is appended last, so it overrides the base item of its slot.
	var look := _base_look.duplicate()
	look.append(item)
	_visual.set_look(look)

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
