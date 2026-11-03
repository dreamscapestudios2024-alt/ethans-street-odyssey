class_name MusicToggle
extends CheckBox
## "Mute audio" checkbox, top-right of the screen. Checked = all game audio muted. Stays in sync with
## the M key and with the saved preference (all state lives in the Music autoload).

const BOX := 30
static var _icon_off: ImageTexture
static var _icon_on: ImageTexture

## High-contrast checkbox icons drawn in code (the default theme icons are tiny and low-contrast on this art).
static func _make_icon(checked: bool) -> ImageTexture:
	var img := Image.create(BOX, BOX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var border := Color.BLACK
	var fill := Color("ff7043") if checked else Color(1, 1, 1, 0.95)
	for y in BOX:
		for x in BOX:
			var edge := x < 3 or y < 3 or x >= BOX - 3 or y >= BOX - 3
			img.set_pixel(x, y, border if edge else fill)
	if checked:  # white tick
		var pts := [Vector2i(7, 15), Vector2i(8, 16), Vector2i(9, 17), Vector2i(10, 18), Vector2i(11, 19), Vector2i(12, 18),
			Vector2i(13, 17), Vector2i(14, 16), Vector2i(15, 15), Vector2i(16, 14), Vector2i(17, 13), Vector2i(18, 12),
			Vector2i(19, 11), Vector2i(20, 10), Vector2i(21, 9), Vector2i(22, 8)]
		for p in pts:
			for dx in 3:
				for dy in 3:
					img.set_pixel(p.x + dx - 1, p.y + dy - 1, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _ready() -> void:
	if _icon_off == null:
		_icon_off = _make_icon(false)
		_icon_on = _make_icon(true)
	add_theme_icon_override("unchecked", _icon_off)
	add_theme_icon_override("checked", _icon_on)
	add_theme_icon_override("unchecked_disabled", _icon_off)
	add_theme_icon_override("checked_disabled", _icon_on)
	text = " Mute audio"
	focus_mode = Control.FOCUS_NONE         # Space/Enter must never toggle it (Space is jump)
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 8)
	scale = Vector2(1.5, 1.5)
	reset_size()
	# top-right corner of the 1920x1080 canvas
	pivot_offset = Vector2(size.x, 0.0)
	position = Vector2(1920.0 - size.x - 28.0, 18.0)
	var music := _music()
	if music != null:
		set_pressed_no_signal(music.muted)
		music.muted_changed.connect(_on_music_muted_changed)
	toggled.connect(_on_toggled)

func _music() -> Node:
	return get_node_or_null("/root/Music")

func _on_toggled(pressed: bool) -> void:
	var music := _music()
	if music != null:
		music.set_muted(pressed)

func _on_music_muted_changed(is_muted: bool) -> void:
	set_pressed_no_signal(is_muted)
