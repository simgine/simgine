extends Node3D

enum Drag {
	NONE,
	PANNING,
	ROTATING,
}

@export var zoom_step := 0.25
@export var pan_speed := 0.0015
@export var rotate_speed := 0.005
@export var smoothing_speed := 12.0

@export var min_distance := 0.5
@export var max_distance := 2.5

## Keeps the character in view while panning in the camera's view plane.
const _PAN_MIN := Vector2(-1.2, -0.5)
const _PAN_MAX := Vector2(1.2, 1.7)
const _PITCH_LIMIT := deg_to_rad(80.0)

var _target_offset: Vector3 # X and Y are pan, Z is zoom distance.
var _target_rotation := Vector2.ZERO
var _drag: Drag = Drag.NONE

@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	_target_offset = _camera.position
	_target_rotation = Vector2(rotation.x, rotation.y)


func _unhandled_input(event: InputEvent) -> void:
	if get_viewport().gui_get_hovered_control():
		return

	if event.is_action_pressed("camera_pan"):
		_drag = Drag.PANNING
	elif event.is_action_pressed("camera_rotate"):
		_drag = Drag.ROTATING
	elif event is InputEventMouseMotion:
		match _drag:
			Drag.PANNING:
				_pan(event.relative)
			Drag.ROTATING:
				_rotate(event.relative)
	elif event.is_action_pressed("camera_zoom_in"):
		_zoom(-zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom(zoom_step)


func _input(event: InputEvent) -> void:
	# End the drag even if a UI control consumes the release.
	match _drag:
		Drag.PANNING:
			if event.is_action_released("camera_pan"):
				_drag = Drag.NONE
		Drag.ROTATING:
			if event.is_action_released("camera_rotate"):
				_drag = Drag.NONE


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-smoothing_speed * delta)
	rotation.x = lerp_angle(rotation.x, _target_rotation.x, weight)
	rotation.y = lerp_angle(rotation.y, _target_rotation.y, weight)
	_camera.position = _camera.position.lerp(_target_offset, weight)


func _pan(relative: Vector2) -> void:
	_target_offset += Vector3(-relative.x, relative.y, 0.0) * pan_speed * _target_offset.z
	_target_offset.x = clampf(_target_offset.x, _PAN_MIN.x, _PAN_MAX.x)
	_target_offset.y = clampf(_target_offset.y, _PAN_MIN.y, _PAN_MAX.y)


func _rotate(relative: Vector2) -> void:
	_target_rotation -= Vector2(relative.y, relative.x) * rotate_speed
	_target_rotation.x = clampf(_target_rotation.x, -_PITCH_LIMIT, _PITCH_LIMIT)
	_target_rotation.y = wrapf(_target_rotation.y, -PI, PI)


func _zoom(delta: float) -> void:
	_target_offset.z = clampf(_target_offset.z + delta, min_distance, max_distance)
