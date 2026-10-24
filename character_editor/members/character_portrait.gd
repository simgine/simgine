class_name CharacterPortrait
extends TextureRect
## A 3D portrait of a [Character]'s head.

## The camera distance from the head.
@export var _distance: float = 0.6

@onready var _viewport: SubViewport = $Viewport
@onready var _camera: Camera3D = %Camera


func _ready() -> void:
	texture = _viewport.get_texture()


## Shows the given visual.
func setup(visual: CharacterVisual) -> void:
	# Wait for queued rebuilds before reading the head position.
	visual.look_changed.connect(_refresh.bind(visual), CONNECT_DEFERRED)
	visual.body_changed.connect(_refresh.bind(visual), CONNECT_DEFERRED)

	# Rendering immediately after a scene change can capture an empty portrait.
	await get_tree().process_frame
	# process_frame fires before deferred calls are flushed, so the skeleton
	# rebuild may still be queued. Wait for it before reading the head position.
	_refresh.call_deferred(visual)


func _refresh(visual: CharacterVisual) -> void:
	var focus := visual.get_bone_position("Head")
	_camera.position = focus + Vector3(0.0, 0.0, _distance)
	_camera.look_at(focus, Vector3.UP)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
