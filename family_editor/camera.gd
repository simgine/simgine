extends Camera3D

@export var zoom_step := 0.25
@export var smoothing_speed := 12.0

@export var min_distance := 0.5
@export var max_distance := 2.0

var _target_distance: float


func _ready() -> void:
	_target_distance = position.z


func _unhandled_input(event: InputEvent) -> void:
	# Ignore scroll if cursor is over any UI control.
	if get_viewport().gui_get_hovered_control():
		return

	if event.is_action_pressed("camera_zoom_in"):
		_zoom(-zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom(zoom_step)


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-smoothing_speed * delta)
	position.z = lerpf(position.z, _target_distance, weight)


func _zoom(delta: float) -> void:
	_target_distance = clampf(_target_distance + delta, min_distance, max_distance)
