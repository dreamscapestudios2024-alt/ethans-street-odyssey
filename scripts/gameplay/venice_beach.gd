extends Node2D
## Stage 1 demo level: assembles world layers, street modules, Ethan, camera,
## HUD and scoring. Scene-specific logic only; shared systems live elsewhere.

const ETHAN_SCENE := preload("res://scenes/characters/ethan.tscn")
const FALL_Y := 2200.0

var ethan: Ethan
var gus: Npc
var dialogue: DialogueBox
var camera: FollowCamera
var hud: Hud
var course: CourseBuilder
var parallax := ParallaxWorld.new()
var _grind_points := 0.0
var _start := Vector2(200, 0)
var level_end_x := 0.0

func _ready() -> void:
	parallax.build(self)
	var ground := Node2D.new()
	ground.name = "Layer3_GameplayGround"
	add_child(ground)
	course = CourseBuilder.new(Vector2(-1800.0, 0.0))  # layout starts with a 1800px lead-in so x=0 is the start line
	course.build(ground, VeniceBeachLayout.layout())
	level_end_x = course.cursor.x
	_add_end_stop(ground, level_end_x)

	# Set dressing and NPCs sit behind Ethan (added before him) and never collide with him.
	var npcs := Node2D.new()
	npcs.name = "Layer4a_NPCs"
	add_child(npcs)
	_add_prop(npcs, "res://assets/street_modules/shopping_cart.png", Vector2(1010.0, 0.0), 72.0)
	_add_prop(npcs, "res://assets/street_modules/tent_blue.png", Vector2(1330.0, 0.0), 112.0)
	gus = Npc.new()
	gus.name = "Gus"
	gus.position = Vector2(1170.0, 0.0)
	npcs.add_child(gus)

	var actors := Node2D.new()
	actors.name = "Layer4_Characters"
	add_child(actors)
	ethan = ETHAN_SCENE.instantiate()
	ethan.position = _start
	actors.add_child(ethan)

	camera = FollowCamera.new()
	camera.name = "FollowCamera"
	camera.target = ethan
	camera.zoom = Vector2(1.5, 1.5)
	add_child(camera)
	camera.make_current()
	camera.snap_to_target()

	hud = Hud.new()
	add_child(hud)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	gus.setup(dialogue, ethan)
	gus.conversation_finished.connect(_on_conversation_finished)
	add_child(TouchControls.new())
	GameState.reset_run()
	GameState.score_changed.connect(hud.set_score)
	hud.set_score(0)

	ethan.grind_started.connect(func(_r: GrindRail) -> void: _grind_points = 0.0)
	ethan.grind_ended.connect(_on_grind_ended)
	ethan.landed.connect(func(_s: float, hard: bool) -> void:
		if not hard: GameState.add_score(10))
	ethan.fell.connect(func(reason: String) -> void:
		hud.show_banner("WIPEOUT! (%s)" % reason, 1.4))
	ethan.recovered.connect(func() -> void: hud.show_banner("Back up!", 0.8))

## Invisible wall so Ethan can never skate off the end of the demo into empty space.
func _add_end_stop(parent: Node, x: float) -> void:
	var body := StaticBody2D.new()
	body.name = "EndStop"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60.0, 8000.0)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(x + 30.0 - 400.0, 0.0)        # 400px of runway before the true end; spans every ground height
	body.add_child(cs)
	parent.add_child(body)

func _add_prop(parent: Node, path: String, base: Vector2, height_px: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	var sp := Sprite2D.new()
	sp.texture = tex
	var sc := height_px / float(tex.get_height())
	sp.scale = Vector2(sc, sc)
	sp.position = base + Vector2(0.0, -height_px * 0.5)   # bottom edge on the ground line
	sp.z_index = -2
	parent.add_child(sp)

func _on_conversation_finished(npc_id: String, first_time: bool, reputation_gain: int) -> void:
	if first_time:
		hud.show_banner("Met %s!  +%d reputation" % [gus.display_name, reputation_gain], 2.2)

func _on_grind_ended(rail: GrindRail, duration: float, _by_jump: bool) -> void:
	var pts := int(duration * rail.score_per_second * rail.score_multiplier)
	GameState.add_score(pts)
	hud.show_banner("50-50 GRIND +%d" % pts, 1.2)

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset") or ethan.global_position.y > FALL_Y:
		restart()
	if ethan.global_position.x > level_end_x - 200.0:
		hud.show_banner("END OF DEMO - press R to restart", 0.3)
	hud.set_info("%s   speed %d" % [Ethan.State.keys()[ethan.state], int(ethan.current_speed())])

func restart() -> void:
	ethan.respawn(_start)
	camera.snap_to_target()
	GameState.reset_run()
