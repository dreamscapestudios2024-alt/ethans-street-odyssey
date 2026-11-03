class_name MovementMath
extends RefCounted
## Pure, side-effect-free movement helpers (unit tested in tests/).

static func approach(value: float, target: float, delta_amount: float) -> float:
	if value < target:
		return minf(value + delta_amount, target)
	return maxf(value - delta_amount, target)

## Variable-height jump: releasing early while rising cuts upward velocity.
static func cut_jump(vy: float, cut_factor: float) -> float:
	return vy * cut_factor if vy < 0.0 else vy

## Peak height (px) for an initial upward speed and gravity.
static func jump_height(jump_speed: float, gravity: float) -> float:
	return (jump_speed * jump_speed) / (2.0 * gravity)

## Slope acceleration along ground; floor_normal points away from the surface.
static func slope_accel(floor_normal: Vector2, gravity: float, influence: float) -> float:
	# Rising ramp (normal tilts left, x<0) decelerates a rightward rider.
	return floor_normal.x * gravity * influence

static func speed_tier(speed: float, cruise_start: float, speed_start: float) -> int:
	if speed >= speed_start:
		return 2
	if speed >= cruise_start:
		return 1
	return 0
