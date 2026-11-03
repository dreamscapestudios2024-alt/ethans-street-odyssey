class_name Hud
extends CanvasLayer
## Minimal debug/score HUD.

var _score: Label
var _info: Label
var _banner: Label
var _banner_time := 0.0

func _ready() -> void:
	layer = 20
	_score = _label(Vector2(40, 24), 56)
	_info = _label(Vector2(40, 100), 28)
	_banner = _label(Vector2(0, 220), 72)
	_banner.size = Vector2(1920, 100)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var help := _label(Vector2(40, 990), 24)
	help.text = "A/D or ←/→ push & brake   Space jump (hold = higher)   S crouch   Shift+brake drift   R restart"

func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l

func set_score(v: int) -> void:
	_score.text = "SCORE %d" % v

func set_info(text: String) -> void:
	_info.text = text

func show_banner(text: String, seconds: float = 1.2) -> void:
	_banner.text = text
	_banner_time = seconds

func _process(delta: float) -> void:
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			_banner.text = ""
