class_name LookItemPreview
extends SubViewport
## Renders previews for [LookItem]s in a scene from [method CharacterVisual.get_preview_scene_path].

var _visual: CharacterVisual

var _queue: Array[PreviewRequest]
var _rendering := false

## Item currently layered on the base look.
var _layered_item: LookItem

## Base look items displaced by [member _layered_item], with their swatches.
var _displaced: Dictionary[LookItem, LookSwatch]


func load_scene(scene_path: String) -> void:
	var scene := ResourceLoader.load(scene_path) as PackedScene
	if not scene:
		Log.error("Unable to load the preview scene '%s'", scene_path)
		return

	var node := scene.instantiate()
	var visual := node as CharacterVisual
	if not visual:
		Log.error("The preview scene '%s' root is not a CharacterVisual", scene_path)
		node.free()
		return

	add_child(visual)
	_visual = visual


func _queue_preview(item: LookItem, swatch: LookSwatch, texture: ImageTexture) -> void:
	var request := PreviewRequest.new()
	request.item = item
	request.swatch = swatch
	request.texture = texture
	_queue.append(request)

	if _rendering:
		return

	_rendering = true
	while not _queue.is_empty():
		await _render_preview(_queue.pop_front())

	_rendering = false


func _render_preview(request: PreviewRequest) -> void:
	var item := request.item
	var swatch := request.swatch
	if swatch:
		Log.debug("Rendering the preview of %s with %s", item, swatch)
	else:
		Log.debug("Rendering the preview of %s", item)
	_restore_base_look()
	_set_item(item, swatch)

	# Wait for the attachment rebuild, which is deferred.
	await get_tree().process_frame

	var slot := item.slot
	var camera := _visual.get_node_or_null(slot.preview_camera) as Camera3D
	if not camera:
		Log.error("Preview camera '%s' of the '%s' slot is missing", slot.preview_camera, slot.name)
		return

	camera.current = true

	# Render item separately if the requested camera has a non-default cull mask.
	const DEFAULT_CULL_MASK := (1 << 20) - 1
	var mesh := _visual.get_item_mesh(item)
	var use_camera_layers := mesh and camera.cull_mask != DEFAULT_CULL_MASK
	var original_layers: int
	if use_camera_layers:
		original_layers = mesh.layers
		mesh.layers = camera.cull_mask

	render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame

	var image := get_texture().get_image()

	if use_camera_layers:
		mesh.layers = original_layers

	if not image:
		Log.debug("Skipping the preview of '%s': no rendered image", item.name)
		return

	request.texture.set_image(image)


func _restore_base_look() -> void:
	if _layered_item:
		_visual.look.remove(_layered_item)
	for displaced_item in _displaced:
		_visual.look.add(displaced_item, _displaced[displaced_item])
	_displaced.clear()
	_layered_item = null


func _set_item(item: LookItem, swatch: LookSwatch) -> void:
	# Record conflicting items to restore before the next item.
	# Items in the base look conflict with themselves, so they are recorded too.
	for look_item: LookItem in _visual.look.items:
		if item.conflicts_with(look_item):
			_displaced[look_item] = _visual.look.get_swatch(look_item)

	if _visual.look.items.has(item):
		# The item is part of the base look, so only its swatch changes.
		_visual.look.set_swatch(item, swatch)
	else:
		_visual.look.add(item, swatch)
	_layered_item = item


class PreviewRequest:
	## The item to render.
	var item: LookItem

	## The swatch to render with. Null renders the default appearance.
	var swatch: LookSwatch

	## The texture the rendered image is filled into in place.
	var texture: ImageTexture
