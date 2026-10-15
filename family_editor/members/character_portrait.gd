class_name CharacterPortrait
extends TextureRect
## A 3D portrait of a [Character]'s head.

## The camera distance from the head.
@export var _distance: float = 0.6

@onready var _viewport: SubViewport = $Viewport
@onready var _camera: Camera3D = $Viewport/Camera


func _ready() -> void:
	texture = _viewport.get_texture()


## Shows the given visual.
func setup(visual: CharacterVisual) -> void:
	visual.changed.connect(_refresh.bind(visual))
	# The skeleton is built deferred, so the initial refresh waits for it.
	_refresh.call_deferred(visual)


func _refresh(visual: CharacterVisual) -> void:
	var focus := visual.get_head_position()
	_camera.position = focus + Vector3(0.0, 0.0, _distance)
	_camera.look_at(focus, Vector3.UP)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
