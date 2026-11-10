class_name DialogueBox
extends CanvasLayer
## Bottom-of-screen conversation panel: speaker name, portrait, typed-out text. Any key, click or tap
## advances (first press completes the line, next press moves on). Reusable for every NPC and, later,
## for the comic-book dialogue scenes.

signal finished

const TYPE_SPEED := 55.0          ## characters per second
const MIN_ADVANCE_GAP := 0.18     ## swallow double events (touch also emits an emulated mouse click)

var is_open := false
var _lines: Array = []
var _index := 0
var _panel: PanelContainer
var _name: Label
var _text: Label
var _hint: Label
var _portrait: TextureRect
var _typed := 0.0
var _gap := 0.0
var _default_name := ""
var _default_portrait: Texture2D

func _ready() -> void:
	layer = 40
	visible = false
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 120.0
	_panel.offset_right = -120.0
	_panel.offset_top = -270.0
	_panel.offset_bottom = -40.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.1, 1.0)
	sb.border_color = Color("ffd23f")
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(170, 170)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 38)
	_name.add_theme_color_override("font_color", Color("ffd23f"))
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_name)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 34)
	_text.add_theme_color_override("font_color", Color.WHITE)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)
	_hint = Label.new()
	_hint.text = "tap or press any key"
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hint)

func open(speaker: String, lines: Array, portrait: Texture2D = null) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_default_name = speaker
	_default_portrait = portrait
	_show_line()
	visible = true
	is_open = true
	_gap = 0.0

func _show_line() -> void:
	var entry: Variant = _lines[_index]
	if entry is Dictionary:                       # {name, text, portrait} - per-line speaker
		_text.text = String(entry.get("text", ""))
		if entry.has("name"):
			_name.text = String(entry["name"])
		_portrait.texture = entry.get("portrait", _default_portrait)
		_portrait.visible = _portrait.texture != null
	else:
		_text.text = String(entry)
		_name.text = _default_name
		_portrait.texture = _default_portrait
		_portrait.visible = _default_portrait != null
	_text.visible_characters = 0
	_typed = 0.0
	_hint.modulate.a = 0.0

func _process(delta: float) -> void:
	if not is_open:
		return
	_gap += delta
	if _text.visible_characters < _text.text.length():
		_typed += delta * TYPE_SPEED
		_text.visible_characters = int(_typed)
	else:
		_hint.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var press := false
	if event is InputEventKey:
		press = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		press = event.pressed
	elif event is InputEventJoypadButton:
		press = event.pressed
	if press and _gap >= MIN_ADVANCE_GAP:
		advance()
		get_viewport().set_input_as_handled()

func advance() -> void:
	_gap = 0.0
	if _text.visible_characters < _text.text.length():
		_text.visible_characters = _text.text.length()      # first press completes the line
		return
	_index += 1
	if _index >= _lines.size():
		close()
	else:
		_show_line()

func close() -> void:
	is_open = false
	visible = false
	finished.emit()
