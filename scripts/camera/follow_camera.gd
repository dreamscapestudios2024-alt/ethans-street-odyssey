class_name FollowCamera
extends Camera2D
## Smooth side-scroller camera: follows the target with a speed-based
## look-ahead. Driven from _physics_process (no built-in smoothing) so it never
## fights the physics tick and doesn't jitter.

@export var target: Node2D
@export var max_look_ahead: float = 340.0
@export var look_ahead_speed_ref: float = 900.0
@export var look_ahead_response: float = 3.0   ## higher = snappier
@export var follow_response_x: float = 14.0
@export var follow_response_y: float = 5.0
@export var vertical_offset: float = -170.0    ## keeps Ethan in the lower third
@export var vertical_dead_zone: float = 40.0

var _look := 0.0
var _focus_y := 0.0

func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	if target != null:
		snap_to_target()

func snap_to_target() -> void:
	_look = 0.0
	_focus_y = target.global_position.y + vertical_offset
	global_position = Vector2(target.global_position.x, _focus_y)

func look_ahead_for_speed(speed: float) -> float:
	return clampf(speed / look_ahead_speed_ref, 0.0, 1.0) * max_look_ahead

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var spd: float = target.velocity.x if "velocity" in target else 0.0
	var wanted := look_ahead_for_speed(absf(spd)) * signf(spd)
	_look = lerpf(_look, wanted, 1.0 - exp(-look_ahead_response * delta))
	var desired_y: float = target.global_position.y + vertical_offset
	if absf(desired_y - _focus_y) > vertical_dead_zone:
		_focus_y = lerpf(_focus_y, desired_y, 1.0 - exp(-follow_response_y * delta))
	var gx := lerpf(global_position.x, target.global_position.x + _look, 1.0 - exp(-follow_response_x * delta))
	global_position = Vector2(gx, _focus_y)
