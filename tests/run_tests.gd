extends SceneTree
## Headless tests. Run:  godot --headless --path . --script tests/run_tests.gd
## Exit code 0 = all passed.

var _fails := 0
var _checks := 0
var _holder: Node2D

func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		printerr("  FAIL ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	test_math()
	test_modules()
	test_rail()
	root.remove_child(_holder)
	_holder.free()
	await test_gameplay()
	print("\n%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)

func test_math() -> void:
	print("MovementMath")
	check(MovementMath.approach(0.0, 10.0, 3.0) == 3.0, "approach up")
	check(MovementMath.approach(5.0, 0.0, 9.0) == 0.0, "approach clamps")
	check(MovementMath.cut_jump(-800.0, 0.5) == -400.0, "jump cut while rising")
	check(MovementMath.cut_jump(300.0, 0.5) == 300.0, "no cut while falling")
	check(is_equal_approx(MovementMath.jump_height(880.0, 2200.0), 176.0), "jump height")
	check(MovementMath.slope_accel(Vector2(-0.4, -0.9), 2200.0, 0.7) < 0.0, "uphill decelerates")
	check(MovementMath.speed_tier(700.0, 120.0, 640.0) == 2, "speed tier")

func _module(spec: Dictionary) -> StreetModule:
	var m := StreetModule.new()
	m.type = spec["type"]
	for k: String in spec:
		if k != "type":
			m.set(k, spec[k])
	_holder.add_child(m)
	return m

func test_modules() -> void:
	print("StreetModule")
	var T := StreetModule.Type
	var s := _module({"type": T.SIDEWALK, "length": 500.0})
	check(s.end_offset() == Vector2(500, 0), "sidewalk end offset")
	s.length = 900.0
	check(s.end_offset().x == 900.0, "sidewalk extends horizontally")
	var st := _module({"type": T.STAIRS, "step_count": 5, "step_width": 70.0, "step_height": 30.0})
	check(st.end_offset() == Vector2(350, 150), "stairs descend left-to-right")
	check(st.get_child_count() == 5, "one collider per step")
	var ledge := _module({"type": T.LEDGE, "length": 600.0})
	check(ledge.rail != null and is_equal_approx(ledge.rail.end_point.y, -ledge.surface_height()) and ledge.rail.end_point.x == 600.0, "ledge has grind rail on its top edge")
	var bed := _module({"type": T.GARDEN_BED})
	check(bed.rail == null and bed.surface_height() > 40.0, "garden bed solid, not grindable")
	check(_module({"type": T.RAMP_DOWN, "length": 300.0}).end_offset().y == 110.0, "descending ramp drops cursor")
	check(_module({"type": T.POTHOLE}).hazard_area != null, "pothole hazard area")
	var course := CourseBuilder.new()
	course.build(_holder, VeniceBeachLayout.layout())
	check(course.modules.size() == VeniceBeachLayout.layout().size(), "course places all modules")
	for i in range(1, course.modules.size()):
		var prev := course.modules[i - 1]
		check(course.modules[i].position.is_equal_approx(prev.position + prev.end_offset()), "module %d aligned" % i)

func test_rail() -> void:
	print("GrindRail")
	var r := GrindRail.new()
	r.start_point = Vector2(0, 0)
	r.end_point = Vector2(400, 0)
	_holder.add_child(r)
	check(r.can_attach(Vector2(100, -5), Vector2(98, -20), Vector2(400, 200)), "attach near line")
	check(not r.can_attach(Vector2(100, -80), Vector2(98, -90), Vector2(400, 200)), "no attach far above")
	check(not r.can_attach(Vector2(100, 0), Vector2(98, 20), Vector2(400, -600)), "no attach while rising fast")
	check(not r.can_attach(Vector2(100, 0), Vector2(98, -4), Vector2(20, 100)), "no attach too slow")
	check(not r.can_attach(Vector2(900, 0), Vector2(898, -4), Vector2(400, 100)), "no attach outside span")

func _step(n: int) -> void:
	for i in n:
		await physics_frame

func _new_level() -> Node2D:
	var scene: PackedScene = load("res://scenes/levels/venice_beach/venice_beach.tscn")
	var lvl: Node2D = scene.instantiate()
	root.add_child(lvl)
	await _step(2)
	return lvl

func test_gameplay() -> void:
	print("Gameplay simulation")
	InputSetup.ensure_actions()
	var lvl := await _new_level()
	var e: Ethan = lvl.ethan
	await _step(30)
	check(e.is_on_floor() and absf(e.global_position.y) < 2.0, "Ethan stands on sidewalk (y %.1f floor %s)" % [e.global_position.y, e.is_on_floor()])
	check(e.state == Ethan.State.IDLE, "idle at start")

	Input.action_press("push")
	await _step(120)
	check(e.speed > 150.0, "accelerates (speed %d)" % int(e.speed))
	check(e.state in [Ethan.State.PUSH, Ethan.State.CRUISE, Ethan.State.SPEED], "push/cruise state")
	Input.action_release("push")
	await _step(30)
	check(e.speed > 50.0, "momentum persists after release")
	var before := e.speed
	Input.action_press("brake")
	await _step(60)
	Input.action_release("brake")
	check(e.speed < before * 0.5, "braking slows")
	await _step(60)

	# Jump + land
	e.respawn(Vector2(200, 0))
	await _step(20)
	Input.action_press("jump")
	await _step(6)
	check(e.state == Ethan.State.OLLIE or e.state == Ethan.State.AIRBORNE, "ollie from standstill")
	var top_y := e.global_position.y
	Input.action_release("jump")
	await _step(150)
	check(e.is_on_floor() and e.state != Ethan.State.FALL, "lands again")
	check(top_y < -20.0, "left the ground")

	# Jump onto the garden bed
	var bed: StreetModule
	for m in lvl.course.modules:
		if m.type == StreetModule.Type.GARDEN_BED:
			bed = m
	var bx0 := bed.position.x
	var bx1 := bx0 + bed.effective_length()
	e.respawn(Vector2(bx0 - 200.0, 0))
	await _step(20)
	e.speed = 420.0
	Input.action_press("jump")
	await _step(45)  # hold ~0.37s for a full-height ollie
	Input.action_release("jump")
	await _step(110)
	check(e.global_position.x > bx0 and e.global_position.x < bx1, "over the bed (x %d, bed %d..%d)" % [int(e.global_position.x), int(bx0), int(bx1)])
	check(absf(e.global_position.y + bed.surface_height()) < 1.5, "landed on elevated bed top (y %.1f vs -%.1f, %s)" % [e.global_position.y, bed.surface_height(), Ethan.State.keys()[e.state]])

	# Hit the bed wall at speed -> fall and recover
	e.respawn(Vector2(bx0 - 400.0, 0))
	await _step(20)
	e.speed = 600.0
	await _step(120)
	check(e.state == Ethan.State.FALL, "crash into wall causes fall")
	await _step(420)
	check(e.state != Ethan.State.FALL, "recovers from fall")

	# Handrail grind: find rail module
	var rail: GrindRail
	for m in lvl.course.modules:
		if m.type == StreetModule.Type.HANDRAIL:
			rail = m.rail
	check(rail != null, "handrail present in level")
	var rs := rail.global_start()
	e.respawn(Vector2(rs.x - 260.0, 0.0))
	await _step(20)
	e.speed = 520.0
	Input.action_press("jump")
	var grinded := false
	var max_grind_frames := 0
	for i in 400:
		await physics_frame
		if e.state == Ethan.State.GRIND:
			grinded = true
			max_grind_frames += 1
		if i == 45:
			Input.action_release("jump")
	check(grinded, "grinds the handrail (%d frames)" % max_grind_frames)
	check(e.state != Ethan.State.GRIND and e.global_position.x > rail.global_end().x - 20.0, "exits rail and continues")
	var gs: Node = root.get_node("GameState")
	check(gs.score > 0, "grind scored (%d)" % gs.score)
	check(e.state != Ethan.State.FALL, "no fall after rail")
	Input.action_release("jump")

	# Pothole: rolling into it causes a fall
	var pit: StreetModule
	var stairs: StreetModule
	var ramp: StreetModule
	for m in lvl.course.modules:
		match m.type:
			StreetModule.Type.POTHOLE: pit = m
			StreetModule.Type.STAIRS_RAIL: stairs = m
			StreetModule.Type.RAMP_UP: ramp = m
	e.respawn(Vector2(pit.position.x - 300.0, 0.0))
	await _step(20)
	e.speed = 300.0
	await _step(150)
	check(e.state == Ethan.State.FALL, "pothole causes fall")
	await _step(420)
	check(e.state != Ethan.State.FALL, "recovers after pothole")
	await _step(300)  # long enough for the post-recovery invulnerability to expire
	check(e.state != Ethan.State.FALL, "does not fall again in the same pothole")

	# Ramp: ride the kicker and get launched
	e.respawn(Vector2(ramp.position.x - 200.0, 0.0))
	await _step(20)
	e.speed = 700.0
	var peak := 0.0
	for i in 200:
		await physics_frame
		peak = minf(peak, e.global_position.y)
	check(peak < -100.0, "ramp climbs and launches Ethan (peak %d)" % int(peak))

	# Stairs: roll down without crashing, end lower than start
	e.respawn(Vector2(stairs.position.x - 150.0, 0.0))
	await _step(20)
	e.speed = 450.0
	await _step(240)
	check(e.global_position.x > stairs.position.x + stairs.end_offset().x - 50.0, "passes down the stairs")
	check(e.global_position.y > 100.0, "ends lower than the start (y %d)" % int(e.global_position.y))
	# Stairs handrail grind
	e.respawn(Vector2(stairs.position.x - 180.0, stairs.position.y))
	await _step(20)
	e.speed = 520.0
	Input.action_press("jump")
	var stair_grind := false
	for i in 300:
		await physics_frame
		stair_grind = stair_grind or e.state == Ethan.State.GRIND
		if i == 50:
			Input.action_release("jump")
	check(stair_grind, "grinds the stairs handrail")
	check(e.state != Ethan.State.FALL, "no fall after stairs rail")
	Input.action_release("jump")
	lvl.queue_free()
	await _step(2)
