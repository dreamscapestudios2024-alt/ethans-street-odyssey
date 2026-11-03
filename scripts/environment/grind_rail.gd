class_name GrindRail
extends Node2D
## A reusable grind line. Start/end are in this node's local space and the
## rail runs left (start) to right (end). Ethan attaches via can_attach().

enum Approach { ANY, LEFT_TO_RIGHT }

@export var start_point: Vector2 = Vector2.ZERO
@export var end_point: Vector2 = Vector2(400, 0)
@export var approach: Approach = Approach.LEFT_TO_RIGHT
@export var min_entry_speed: float = 150.0
@export var entry_tolerance: float = 26.0     ## vertical px either side of the line
@export var entry_x_margin: float = 8.0
@export var max_entry_rise_speed: float = 140.0  ## cannot attach while rising faster
@export var min_grind_speed: float = 260.0
@export var friction: float = 40.0            ## px/s^2 lost while grinding
@export var slope_influence: float = 0.6
@export var score_per_second: int = 100
@export var score_multiplier: float = 1.0     ## difficulty value
@export var jump_off_boost: float = 1.0
@export var show_debug_line: bool = true

func _ready() -> void:
	add_to_group("grind_rails")

func global_start() -> Vector2:
	return to_global(start_point)

func global_end() -> Vector2:
	return to_global(end_point)

func length() -> float:
	return global_start().distance_to(global_end())

func tangent() -> Vector2:
	return (global_end() - global_start()).normalized()

## Rail height (global y) at a global x, or NAN when outside the span.
func y_at(gx: float, margin: float = 0.0) -> float:
	var a := global_start()
	var b := global_end()
	if gx < a.x - margin or gx > b.x + margin:
		return NAN
	if is_equal_approx(a.x, b.x):
		return a.y
	return lerpf(a.y, b.y, clampf((gx - a.x) / (b.x - a.x), 0.0, 1.0))

## Distance along rail (0..length) closest to a global point.
func distance_along(p: Vector2) -> float:
	return clampf((p - global_start()).dot(tangent()), 0.0, length())

func point_at(dist: float) -> Vector2:
	return global_start() + tangent() * clampf(dist, 0.0, length())

func can_attach(feet: Vector2, prev_feet: Vector2, velocity: Vector2) -> bool:
	if approach == Approach.LEFT_TO_RIGHT and velocity.x < min_entry_speed:
		return false
	if velocity.length() < min_entry_speed:
		return false
	if velocity.y < -max_entry_rise_speed:
		return false
	var ry := y_at(feet.x, entry_x_margin)
	if is_nan(ry):
		return false
	var d_now := feet.y - ry
	var py := y_at(prev_feet.x, 1.0e9)
	var d_prev := prev_feet.y - py
	if absf(d_now) <= entry_tolerance:
		return true
	return d_prev < 0.0 and d_now > 0.0  # crossed the line this frame

func _draw() -> void:
	if show_debug_line:
		draw_line(start_point, end_point, Color(0.75, 0.78, 0.82), 6.0)
		draw_line(start_point, end_point, Color(1, 1, 1, 0.6), 2.0)
