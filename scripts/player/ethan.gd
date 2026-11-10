class_name Ethan
extends CharacterBody2D
## Ethan's 2D skateboard controller. The node origin is at the board's ground
## contact point (feet). Persistent data lives in GameState, not here, so a
## future CharacterBody3D controller can reuse it. This script only emits
## signals describing what happened.

enum State {
	IDLE, PUSH, CRUISE, SPEED, BRAKE, DRIFT, CROUCH,
	OLLIE, AIRBORNE, LANDING, GRIND, FALL,
}

signal state_changed(old_state: State, new_state: State)
signal jumped
signal landed(impact_speed: float, hard: bool)
signal grind_started(rail: GrindRail)
signal grind_ended(rail: GrindRail, duration: float, by_jump: bool)
signal fell(reason: String)
signal recovered

@export_group("Visuals")
@export var sprite_scale: float = 0.95  ## scales production art to fit the 110px collision body
@export_group("Ground")
@export var max_speed: float = 900.0
@export var max_reverse_speed: float = 650.0   ## top speed rolling backwards (left)
@export var push_accel: float = 520.0
@export var roll_friction: float = 70.0
@export var brake_decel: float = 900.0
@export var drift_decel: float = 420.0
@export var drift_min_speed: float = 300.0
@export var crouch_drag: float = 40.0
@export var idle_speed: float = 8.0
@export var cruise_speed: float = 120.0
@export var speed_threshold: float = 640.0
@export var fast_push_speed: float = 380.0  ## above this the PUSH state plays the aggressive kick-push
@export var slope_influence: float = 0.25
@export_group("Jump")
@export var jump_speed: float = 880.0
@export var crouch_jump_bonus: float = 140.0
@export var jump_cut_factor: float = 0.45
@export var gravity: float = 2200.0
@export var fall_gravity_mult: float = 1.25
@export var max_fall_speed: float = 1800.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12
@export_group("Air")
@export var air_accel: float = 260.0
@export_group("Landing & falling")
@export var landing_time: float = 0.09
@export var hard_landing_speed: float = 1500.0
@export var wall_crash_speed: float = 330.0
@export var fall_time: float = 1.1
@export var fall_friction: float = 700.0
@export var recovery_invulnerable_time: float = 0.8
@export_group("Grind")
@export var grind_jump_speed: float = 800.0
@export var rail_cooldown_time: float = 0.3

var state: State = State.IDLE
var speed: float = 0.0              ## signed ground speed: + rolling right, - rolling left (reverse)
var facing: int = 1                 ## 1 = facing right, -1 = facing left (follows travel direction)
var controls_enabled: bool = true
var last_floor_normal: Vector2 = Vector2.UP

var _coyote := 0.0
var _jump_buffer := 0.0
var _landing_timer := 0.0
var _fall_timer := 0.0
var _invuln := 0.0
var _jump_cut_done := true
var _prev_pos := Vector2.ZERO
var _prev_vy := 0.0
var _rail: GrindRail
var _rail_cooldown := 0.0
var _rail_dist := 0.0
var _rail_time := 0.0
var _spawn := Vector2.ZERO
var _in_hazard := false
var _clear_x := NAN          ## x to end up at after a hazard wipeout (so he never re-falls in the same hole)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	InputSetup.ensure_actions()
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 20.0
	floor_constant_speed = true
	floor_stop_on_slope = false
	floor_block_on_wall = false
	platform_floor_layers = 0
	_spawn = global_position
	_prev_pos = global_position
	sprite.sprite_frames = PlaceholderFrames.build()
	var tex := sprite.sprite_frames.get_frame_texture("idle", 0)
	sprite.centered = true
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.offset = Vector2(0, -tex.get_height() * 0.5)  # sprite bottom == origin (feet)
	sprite.play("idle")

# --- Public API --------------------------------------------------------------

func respawn(at: Vector2) -> void:
	global_position = at
	_prev_pos = at
	velocity = Vector2.ZERO
	speed = 0.0
	facing = 1
	_rail = null
	_invuln = 0.3  # stale hazard overlaps from the old position must not trigger
	_set_state(State.IDLE)

func hazard_hit(reason: String, clear_x: float = NAN, clear_x_left: float = NAN) -> void:
	if state == State.FALL or state == State.GRIND or _invuln > 0.0:
		return
	_begin_fall(reason, clear_x if (facing >= 0 or is_nan(clear_x_left)) else clear_x_left)

func is_grounded_state() -> bool:
	return state in [State.IDLE, State.PUSH, State.CRUISE, State.SPEED,
		State.BRAKE, State.DRIFT, State.CROUCH, State.LANDING]

func current_speed() -> float:
	return velocity.length() if state != State.GRIND else speed

# --- Main loop ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var push := controls_enabled and Input.is_action_pressed("push")
	var brake := controls_enabled and Input.is_action_pressed("brake")
	var crouch := controls_enabled and Input.is_action_pressed("crouch")
	var drift := controls_enabled and Input.is_action_pressed("drift")
	var jump_held := controls_enabled and Input.is_action_pressed("jump")
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_rail_cooldown = maxf(_rail_cooldown - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)

	match state:
		State.GRIND:
			_physics_grind(delta, jump_held, crouch)
		State.FALL:
			_physics_fall(delta)
		State.OLLIE, State.AIRBORNE:
			_physics_air(delta, push, brake, jump_held)
		_:
			_physics_ground(delta, push, brake, crouch, drift)
	_update_visuals(delta)
	_prev_pos = global_position

# --- Ground ------------------------------------------------------------------

func _physics_ground(delta: float, push: bool, brake: bool, crouch: bool, drift: bool) -> void:
	_landing_timer = maxf(_landing_timer - delta, 0.0)
	if not is_on_floor():
		# Rolled off an edge/lip: keep slope velocity, allow coyote jump.
		pass
	_coyote = coyote_time if is_on_floor() else maxf(_coyote - delta, 0.0)
	if is_on_floor():
		last_floor_normal = get_floor_normal()

	# Speed model. Signed: Right/Push accelerates right; Left/Brake slows him, stops him, then rolls
	# him backwards (reverse), mirrored for the other direction. Both pressed = coast.
	var axis := 0
	if push and not brake:
		axis = 1
	elif brake and not push:
		axis = -1
	var opposing := axis != 0 and speed * float(axis) < -5.0   # pressing against the way he is rolling
	if opposing and not crouch:
		var decel := drift_decel if (drift and absf(speed) > drift_min_speed) else brake_decel
		speed = MovementMath.approach(speed, 0.0, decel * delta)
	elif axis != 0 and not crouch:
		var cap := max_speed if axis > 0 else max_reverse_speed
		var factor := clampf(1.0 - absf(speed) / cap, 0.05, 1.0)
		speed = clampf(speed + float(axis) * push_accel * (0.35 + 0.65 * factor) * delta, -max_reverse_speed, max_speed)
	else:
		var drag := roll_friction + (crouch_drag if crouch else 0.0)
		speed = MovementMath.approach(speed, 0.0, drag * delta)
	if is_on_floor():
		speed = clampf(speed + MovementMath.slope_accel(last_floor_normal, gravity, slope_influence) * delta, -max_reverse_speed, max_speed)

	# Jump (buffered, with coyote time)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		_do_jump(crouch)
		return

	var was_on_floor := is_on_floor()
	velocity = Vector2(speed, 0.0)
	if was_on_floor:
		velocity.y = 50.0  # keep pressed to the floor so snapping works on slopes
	var speed_before := speed
	move_and_slide()

	if not is_on_floor():
		if was_on_floor:
			# Left the ground without jumping (ramp lip / ledge end): launch along surface.
			var t := Vector2(-last_floor_normal.y, last_floor_normal.x)
			velocity = t * speed
			_coyote = coyote_time
			_jump_cut_done = true
			_set_state(State.AIRBORNE)
		else:
			_set_state(State.AIRBORNE)
		return
	if is_on_wall() and absf(speed_before) > 1.0:
		var n := get_wall_normal()
		if (speed_before > 0.0 and n.x < -0.5) or (speed_before < 0.0 and n.x > 0.5):
			if absf(speed_before) >= wall_crash_speed:
				_begin_fall("collision")
				return
			speed = 0.0
	_set_state(_pick_ground_state(push, brake, crouch, drift))

func _pick_ground_state(push: bool, brake: bool, crouch: bool, drift: bool) -> State:
	if _landing_timer > 0.0:
		return State.LANDING
	if crouch:
		return State.CROUCH
	var axis := 0
	if push and not brake:
		axis = 1
	elif brake and not push:
		axis = -1
	var mag := absf(speed)
	if axis != 0 and speed * float(axis) < -5.0:            # pressing against the way he rolls
		return State.DRIFT if (drift and mag > drift_min_speed) else State.BRAKE
	if axis != 0:
		return State.SPEED if mag >= speed_threshold else State.PUSH
	if mag < idle_speed:
		return State.IDLE
	if mag >= speed_threshold:
		return State.SPEED
	return State.CRUISE if mag >= cruise_speed else State.IDLE

func _do_jump(crouched: bool) -> void:
	var t := Vector2(-last_floor_normal.y, last_floor_normal.x)
	velocity = t * speed
	velocity.y -= jump_speed + (crouch_jump_bonus if crouched else 0.0)
	_jump_buffer = 0.0
	_coyote = 0.0
	_jump_cut_done = false
	_set_state(State.OLLIE)
	jumped.emit()
	# Detach from floor immediately so snapping doesn't cancel the jump.
	global_position += Vector2(0, -2)
	_try_attach_rail()  # stationary-ish jumps can hit a rail immediately

# --- Air ---------------------------------------------------------------------

func _physics_air(delta: float, push: bool, brake: bool, jump_held: bool) -> void:
	if state == State.OLLIE and not _jump_cut_done and not jump_held and velocity.y < 0.0:
		velocity.y = MovementMath.cut_jump(velocity.y, jump_cut_factor)
		_jump_cut_done = true
	var g := gravity * (fall_gravity_mult if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)
	var ax := 0.0
	if push and not brake:
		ax = air_accel
	elif brake and not push:
		ax = -air_accel
	velocity.x = clampf(velocity.x + ax * delta, -max_reverse_speed, max_speed)
	if state == State.OLLIE and velocity.y >= 0.0:
		_set_state(State.AIRBORNE)

	if _try_attach_rail():
		return
	_prev_vy = velocity.y
	var vx_before := velocity.x
	move_and_slide()
	if is_on_floor():
		last_floor_normal = get_floor_normal()
		var t := Vector2(-last_floor_normal.y, last_floor_normal.x)
		speed = velocity.dot(t) if last_floor_normal != Vector2.UP else velocity.x
		var hard := _prev_vy > hard_landing_speed
		landed.emit(_prev_vy, hard)
		if hard:
			_begin_fall("hard landing")
			return
		_landing_timer = landing_time
		_set_state(State.LANDING)
		return
	if is_on_wall() and not is_on_ceiling():
		var wn := get_wall_normal()
		if (wn.x < -0.5 and vx_before >= wall_crash_speed) or (wn.x > 0.5 and vx_before <= -wall_crash_speed):
			_begin_fall("collision")

# --- Grind -------------------------------------------------------------------

func _try_attach_rail() -> bool:
	if _rail_cooldown > 0.0:
		return false
	for node in get_tree().get_nodes_in_group("grind_rails"):
		var rail := node as GrindRail
		if rail != null and rail.can_attach(global_position, _prev_pos, velocity):
			_start_grind(rail)
			return true
	return false

func _start_grind(rail: GrindRail) -> void:
	_rail = rail
	_rail_dist = rail.distance_along(global_position)
	speed = maxf(velocity.dot(rail.tangent()), rail.min_grind_speed)
	_rail_time = 0.0
	global_position = rail.point_at(_rail_dist)
	velocity = rail.tangent() * speed
	_set_state(State.GRIND)
	grind_started.emit(rail)

func _physics_grind(delta: float, _jump_held: bool, crouch: bool) -> void:
	var rail := _rail
	var t := rail.tangent()
	speed -= rail.friction * delta
	speed += t.y * gravity * rail.slope_influence * delta
	speed = clampf(speed, rail.min_grind_speed, max_speed)
	_rail_dist += speed * delta
	_rail_time += delta
	global_position = rail.point_at(_rail_dist)
	velocity = t * speed
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		velocity = t * speed * rail.jump_off_boost
		velocity.y -= grind_jump_speed
		_end_grind(true)
		_jump_cut_done = true
		_set_state(State.OLLIE)
		return
	if crouch or _rail_dist >= rail.length() - 0.01:
		_end_grind(false)
		_set_state(State.AIRBORNE)

func _end_grind(by_jump: bool) -> void:
	var r := _rail
	_rail = null
	_rail_cooldown = rail_cooldown_time
	if r != null:
		grind_ended.emit(r, _rail_time, by_jump)

# --- Fall / recovery ---------------------------------------------------------

func _begin_fall(reason: String, clear_x: float = NAN) -> void:
	_clear_x = clear_x
	# Stay down for the whole wipeout -> get-up animation (frames / fps), at least `fall_time`.
	var anim_len := 0.0
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("fall"):
		var total := 0.0
		for i in sprite.sprite_frames.get_frame_count("fall"):
			total += sprite.sprite_frames.get_frame_duration("fall", i)  # honours per-frame hold times
		anim_len = total / maxf(sprite.sprite_frames.get_animation_speed("fall"), 0.1)
	_fall_timer = maxf(fall_time, anim_len)
	speed = 0.0
	if _rail != null:
		_end_grind(false)
	_set_state(State.FALL)
	fell.emit(reason)

func _physics_fall(delta: float) -> void:
	if not is_nan(_clear_x) and absf(_clear_x - global_position.x) > 2.0:
		# Slide clear of the hazard (towards the side he was travelling) over the remaining wipeout time.
		velocity.x = clampf((_clear_x - global_position.x) / maxf(_fall_timer, 0.1), -400.0, 400.0)
	else:
		velocity.x = MovementMath.approach(velocity.x, 0.0, fall_friction * delta)
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()
	_fall_timer -= delta
	if _fall_timer <= 0.0 and is_on_floor():
		speed = 0.0
		velocity = Vector2.ZERO
		_invuln = recovery_invulnerable_time
		_clear_x = NAN
		_set_state(State.IDLE)
		recovered.emit()

# --- State & visuals -----------------------------------------------------------

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	state_changed.emit(old, new_state)

const _ANIM_FOR_STATE := {
	State.IDLE: "idle", State.PUSH: "push", State.CRUISE: "cruise", State.SPEED: "speed",
	State.BRAKE: "brake", State.DRIFT: "drift", State.CROUCH: "crouch", State.OLLIE: "jump",
	State.AIRBORNE: "airborne", State.LANDING: "landing", State.GRIND: "grind", State.FALL: "fall",
}

func animation_for_state(s: State) -> String:
	return _ANIM_FOR_STATE[s]

func _update_visuals(delta: float) -> void:
	var travel_x := speed if (is_grounded_state() or state == State.GRIND) else velocity.x
	if absf(travel_x) > 25.0:
		facing = 1 if travel_x > 0.0 else -1
	sprite.flip_h = facing < 0                          # all artwork is drawn facing right
	var anim := animation_for_state(state)
	if state == State.PUSH and absf(speed) >= fast_push_speed and sprite.sprite_frames.has_animation("push_fast"):
		anim = "push_fast"
	if sprite.animation != anim:
		# keep the walk-cycle phase when swapping between the two push variants
		var frame := sprite.frame
		var progress := sprite.frame_progress
		var swap_push := (anim == "push" or anim == "push_fast") and (sprite.animation == "push" or sprite.animation == "push_fast")
		sprite.play(anim)
		if swap_push:
			sprite.set_frame_and_progress(mini(frame, sprite.sprite_frames.get_frame_count(anim) - 1), progress)
	if state == State.PUSH or state == State.CRUISE or state == State.SPEED:
		sprite.speed_scale = clampf(0.6 + absf(speed) / 500.0, 0.6, 2.2)
	else:
		sprite.speed_scale = 1.0
	var target_rot := 0.0
	if state == State.GRIND and _rail != null:
		target_rot = _rail.tangent().angle()
	elif is_grounded_state():
		target_rot = last_floor_normal.angle() + PI * 0.5
	sprite.rotation = lerp_angle(sprite.rotation, target_rot, clampf(18.0 * delta, 0.0, 1.0))
	sprite.modulate.a = 0.6 if (_invuln > 0.0 and int(_invuln * 16.0) % 2 == 0) else 1.0
