extends Camera3D

const MAX_PITCH := deg_to_rad(80.0)

@export var orbit_center := Vector3(0, 1.0, 0)
@export var orbit_speed := 0.005
@export var zoom_step := 0.25
@export var smoothing_speed := 12.0

@export var min_distance := 0.5
@export var max_distance := 2.0

var _yaw := 0.0
var _pitch := deg_to_rad(15.0)
var _distance := 2.0

var _target_yaw := _yaw
var _target_pitch := _pitch
var _target_distance := _distance


func _ready() -> void:
	_update_transform()


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-smoothing_speed * delta)

	_yaw = lerp_angle(_yaw, _target_yaw, weight)
	_pitch = lerpf(_pitch, _target_pitch, weight)
	_distance = lerpf(_distance, _target_distance, weight)

	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion and Input.is_action_pressed("camera_rotate"):
		_rotate(mouse_motion.relative)
		return

	if event.is_action_pressed("camera_zoom_in"):
		_zoom(-zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom(zoom_step)


func _rotate(movement: Vector2) -> void:
	_target_yaw -= movement.x * orbit_speed
	_target_pitch = clampf(_target_pitch + movement.y * orbit_speed, -MAX_PITCH, MAX_PITCH)


func _zoom(delta: float) -> void:
	_target_distance = clampf(_target_distance + delta, min_distance, max_distance)


func _update_transform() -> void:
	var offset := Vector3.BACK * _distance
	offset = offset.rotated(Vector3.RIGHT, -_pitch)
	offset = offset.rotated(Vector3.UP, _yaw)

	global_position = orbit_center + offset
	look_at(orbit_center)
