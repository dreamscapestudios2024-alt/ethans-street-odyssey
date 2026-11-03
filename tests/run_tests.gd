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
	test_promenade()
	root.remove_child(_holder)
	_holder.free()
	await test_splash()
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

func test_splash() -> void:
	print("Splash screen and music")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/splash_screen.tscn", "game starts on the splash screen")
	var scene: PackedScene = load("res://scenes/ui/splash_screen.tscn")
	check(scene != null, "splash scene loads")
	var splash: Control = scene.instantiate()
	root.add_child(splash)
	await _step(3)
	var art: TextureRect = splash.get_node("SplashArt")
	check(art.texture != null and art.texture.get_width() == 1672, "splash art is loaded")
	check(splash.get_node("StartHint") != null, "start hint present")
	var music: Node = root.get_node("Music")
	check(music != null, "Music autoload exists")
	check(ResourceLoader.exists("res://assets/audio/ethan_at_the_curb.mp3"), "title song file present")
	check(music.is_track_playing(), "title song starts on the splash screen")
	check(music.player.stream is AudioStreamMP3 and music.player.stream.loop, "song loops")
	music.set_muted(true)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "mute silences the Master bus")
	music.set_muted(false)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "unmute restores it")
	check(not music.play_track("res://assets/audio/does_not_exist.mp3"), "missing track is ignored safely")
	var toggle: MusicToggle = null
	for c in splash.get_children():
		if c is MusicToggle:
			toggle = c
	check(toggle != null and toggle.text.strip_edges() == "Mute audio", "splash has a 'Mute audio' checkbox")
	if toggle != null:
		check(toggle.focus_mode == Control.FOCUS_NONE, "checkbox ignores keyboard (Space stays jump)")
		toggle.button_pressed = true            # user ticks the box
		check(music.muted and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "ticking the checkbox mutes all game audio")
		toggle.button_pressed = false
		check(not music.muted and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "unticking it restores audio")
		music.set_muted(true)                   # e.g. via the M key
		check(toggle.button_pressed, "checkbox follows the M key / saved state")
		music.set_muted(false)
	root.remove_child(splash)
	splash.free()

func test_promenade() -> void:
	print("Promenade background (Layer 2a)")
	var tex: Texture2D = BackdropArt.texture(BackdropArt.PROMENADE_PATH)
	check(tex != null, "promenade PNG is present")
	if tex == null:
		return
	check(tex.get_width() == int(BackdropArt.PROMENADE_REGION.size.x), "strip width untouched (seamless repeat length)")
	var img := tex.get_image()
	check(img.detect_alpha() != Image.ALPHA_NONE and img.get_pixel(5, 5).a < 0.05, "transparency preserved")
	# seam: right edge column joins the left edge column about as smoothly as neighbouring columns
	var y0 := int(BackdropArt.PROMENADE_REGION.position.y)
	var h := int(BackdropArt.PROMENADE_REGION.size.y)
	var seam := 0.0
	var inner := 0.0
	var w := tex.get_width()
	for y in range(y0, y0 + h):
		seam += _px_diff(img.get_pixel(w - 1, y), img.get_pixel(0, y))
		inner += _px_diff(img.get_pixel(w / 2, y), img.get_pixel(w / 2 + 1, y))
	check(seam / h < 25.0, "no visible seam at repeat boundary (diff %.1f)" % (seam / h))
	var holder := Node2D.new()
	_holder.add_child(holder)
	var pw := ParallaxWorld.new()
	pw.build(holder)
	check(pw.layer2a != null, "promenade layer built")
	check(is_equal_approx(pw.layer2a.motion_scale.x, 0.4) and pw.layer2a.motion_scale.y == 1.0, "scrolls at 0.4x horizontally, fixed vertically")
	check(is_equal_approx(pw.layer2a.motion_mirroring.x, w * BackdropArt.PROMENADE_SCALE), "repeats every texture width (no gap/overlap)")
	var bg := pw.layer2a.get_parent()
	check(bg.get_child(0) == pw.layer1 and bg.get_child(1) == pw.layer2a and bg.get_child(2) == pw.layer2, "layer order: distant -> promenade -> shops")
	var has_collision := false
	var stack: Array[Node] = [pw.layer2a]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionObject2D or n is CollisionShape2D or n is CollisionPolygon2D or n is GrindRail:
			has_collision = true
		stack.append_array(n.get_children())
	check(not has_collision, "promenade is visual only (no collision, no grind rails)")
	var strip: Sprite2D = pw.layer2a.get_node("PromenadeStrip")
	check(is_equal_approx(strip.position.y, BackdropArt.HORIZON_WORLD_Y), "strip sits on the horizon above the sidewalk")
	_holder.remove_child(holder)
	holder.free()

func _px_diff(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0 * 255.0 + absf(a.a - b.a) * 255.0

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
	# End of level: an invisible wall stops Ethan (the last street is lower than the start)
	var last: StreetModule = lvl.course.modules[lvl.course.modules.size() - 1]
	e.respawn(Vector2(lvl.level_end_x - 1500.0, last.position.y - 5.0))
	await _step(20)
	Input.action_press("push")
	await _step(900)
	Input.action_release("push")
	check(e.global_position.x < lvl.level_end_x and e.global_position.y < last.position.y + 50.0, "end wall stops Ethan (x %d, end %d)" % [int(e.global_position.x), int(lvl.level_end_x)])

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
