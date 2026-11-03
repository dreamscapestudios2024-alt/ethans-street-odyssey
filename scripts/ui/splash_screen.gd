extends Control
## Title screen: shows the splash art, plays the title song, starts the game on any input.
## The art already contains its own "PRESS START" banner.

const NEXT_SCENE := "res://scenes/levels/venice_beach/venice_beach.tscn"
const SPLASH_TEXTURE := "res://assets/ui/splash_screen.png"
const IGNORE_INPUT_SECONDS := 0.4     ## ignore the key press that launched the game
const GAME_VOLUME_DB := -6.0          ## the song keeps playing in the level, a little quieter

var _elapsed := 0.0
var _starting := false
var _art: TextureRect
var _fade: ColorRect
var _hint: Label

func _ready() -> void:
	InputSetup.ensure_actions()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Decorative controls must not swallow clicks/taps, or "click anywhere to start" never fires.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_art = TextureRect.new()
	_art.name = "SplashArt"
	if ResourceLoader.exists(SPLASH_TEXTURE):
		_art.texture = load(SPLASH_TEXTURE) as Texture2D
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.pivot_offset = Vector2(960, 540)
	add_child(_art)

	_hint = Label.new()
	_hint.name = "StartHint"
	_hint.text = "Press any key, click or tap to start"
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color.WHITE)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)   # bottom-left corner, clear of the PRESS START banner
	_hint.offset_left = 28.0
	_hint.offset_top = -44.0
	_hint.offset_bottom = -10.0
	add_child(_hint)

	add_child(MusicToggle.new())

	_fade = ColorRect.new()
	_fade.name = "FadeToBlack"
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)   # fade in

	var music := _music()
	if music != null:
		music.play_track(music.TITLE_TRACK, 0.0, true)

func _music() -> Node:
	return get_node_or_null("/root/Music")

func _process(delta: float) -> void:
	_elapsed += delta
	var pulse := 1.0 + 0.012 * sin(_elapsed * 2.0)   # gentle "breathing" zoom
	_art.scale = Vector2(pulse, pulse)
	_hint.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_elapsed * 4.0))

func _unhandled_input(event: InputEvent) -> void:
	if _starting or _elapsed < IGNORE_INPUT_SECONDS:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo and not event.is_action("mute")
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		start_game()

func start_game() -> void:
	if _starting:
		return
	_starting = true
	var music := _music()
	if music != null:
		music.ensure_playing()          # unlocks audio in browsers
		music.fade_to(GAME_VOLUME_DB, 1.2)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.5)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file(NEXT_SCENE))
