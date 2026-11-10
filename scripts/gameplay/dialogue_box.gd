class_name DialogueBox
extends CanvasLayer
## Bottom-of-screen conversation panel: speaker name, portrait, typed-out text. Any key, click or tap
## advances (first press completes the line, next press moves on). Reusable for every NPC and, later,
## for the comic-book dialogue scenes.

signal finished
signal choice_made(choice_id: String)

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
var _choices_box: VBoxContainer
var _choice_options: Array = []
var choices_active := false

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
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	_choices_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices_box.visible = false
	col.add_child(_choices_box)
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
	_clear_choices()
	if entry is Dictionary and (entry as Dictionary).has("choices"):
		_show_choices(entry)
		return
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

func _clear_choices() -> void:
	_text.visible = true
	choices_active = false
	_choice_options = []
	_choices_box.visible = false
	for c in _choices_box.get_children():
		_choices_box.remove_child(c)
		c.queue_free()
	_panel.offset_top = -270.0

func _show_choices(entry: Dictionary) -> void:
	_name.text = String(entry.get("name", _default_name))
	_portrait.texture = entry.get("portrait", _default_portrait)
	_portrait.visible = _portrait.texture != null
	_text.text = String(entry.get("text", ""))
	_text.visible = not _text.text.is_empty()           # no empty gap above the reply options
	_text.visible_characters = -1
	_hint.modulate.a = 0.0
	_choice_options = entry["choices"]
	var n := _choice_options.size()
	_panel.offset_top = -(250.0 + 78.0 * n)
	for i in n:
		var opt: Dictionary = _choice_options[i]
		var b := Button.new()
		var label: String = "%d.  %s" % [i + 1, String(opt.get("text", ""))]
		if opt.has("suffix"):
			label += "   (%s)" % String(opt["suffix"])
		b.text = label
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 30)
		b.custom_minimum_size = Vector2(0, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not bool(opt.get("enabled", true))
		var id := String(opt.get("id", str(i)))
		b.pressed.connect(func() -> void: choose(id))
		_choices_box.add_child(b)
	_choices_box.visible = true
	choices_active = true

## Picks an option (ignored if it is disabled or no choice is showing). The listener may call
## insert_lines() from choice_made to add the branch; the box then moves on.
func choose(choice_id: String) -> bool:
	if not choices_active or _gap < 0.12:
		return false
	for opt: Dictionary in _choice_options:
		if String(opt.get("id", "")) == choice_id:
			if not bool(opt.get("enabled", true)):
				return false
			_gap = 0.0
			choices_active = false
			choice_made.emit(choice_id)
			_index += 1
			if _index >= _lines.size():
				close()
			else:
				_show_line()
			return true
	return false

## Inserts lines directly after the current entry (used for the branch picked in a choice).
func insert_lines(extra: Array) -> void:
	_lines = _lines.slice(0, _index + 1) + extra + _lines.slice(_index + 1)

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
	if choices_active:
		if event is InputEventKey and event.pressed and not event.echo:
			var idx := -1
			match event.keycode:
				KEY_1, KEY_KP_1: idx = 0
				KEY_2, KEY_KP_2: idx = 1
				KEY_3, KEY_KP_3: idx = 2
			if idx >= 0 and idx < _choice_options.size():
				choose(String((_choice_options[idx] as Dictionary).get("id", "")))
		get_viewport().set_input_as_handled()
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
	_clear_choices()
	is_open = false
	visible = false
	finished.emit()
