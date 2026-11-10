class_name TouchControls
extends CanvasLayer
## On-screen thumb controls for phones/tablets. Each button presses the same input action the
## keyboard uses, so Ethan's controller is unchanged. TouchScreenButton supports true multi-touch
## (hold Push with one thumb while tapping Jump with the other).
##
## Shown automatically on touch devices, or as soon as the first screen touch is seen
## (touch laptops, desktop browsers in device mode). Hidden otherwise.

const TEX := 128
# [action, label, centre (1920x1080 canvas), radius, colour, slide-between-buttons]
const SPEC := [
	["brake", "BRAKE\nBACK", Vector2(150, 930), 105.0, Color("e8504a"), true],
	["push", "PUSH", Vector2(400, 930), 120.0, Color("3fae5a"), true],
	["drift", "DRIFT", Vector2(150, 740), 62.0, Color("e0a030"), false],
	["jump", "JUMP", Vector2(1760, 900), 135.0, Color("3a8fe0"), false],
	["crouch", "CROUCH", Vector2(1490, 960), 90.0, Color("8a6ad0"), false],
	["reset", "RESTART", Vector2(1820, 150), 52.0, Color(0.35, 0.35, 0.4), false],
]

signal shown

var buttons: Dictionary = {}   # action -> TouchScreenButton
static var _tex_cache: Dictionary = {}

func _ready() -> void:
	layer = 30
	add_to_group("touch_controls")
	for s: Array in SPEC:
		_add_button(s[0], s[1], s[2], s[3], s[4], s[5])
	visible = DisplayServer.is_touchscreen_available()
	if visible:
		shown.emit()

func _input(event: InputEvent) -> void:
	if not visible and event is InputEventScreenTouch:
		show_controls()

func show_controls() -> void:
	if not visible:
		visible = true
		shown.emit()

static func _circle_texture(col: Color, pressed: bool) -> ImageTexture:
	var key := "%s_%s" % [col.to_html(), pressed]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var c := (TEX - 1) * 0.5
	var fill := col.lightened(0.25) if pressed else col
	for y in TEX:
		for x in TEX:
			var d := Vector2(x - c, y - c).length()
			if d > TEX * 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > TEX * 0.5 - 6.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.85))               # white rim
			else:
				img.set_pixel(x, y, Color(fill.r, fill.g, fill.b, 0.78 if pressed else 0.5))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

func _add_button(action: String, label: String, center: Vector2, radius: float, col: Color, passby: bool) -> void:
	var b := TouchScreenButton.new()
	b.name = "Btn_" + action
	b.action = action
	b.texture_normal = _circle_texture(col, false)
	b.texture_pressed = _circle_texture(col, true)
	var shape := CircleShape2D.new()
	shape.radius = TEX * 0.5 + 10.0          # slightly generous hit area, in texture pixels
	b.shape = shape
	b.shape_centered = true
	b.passby_press = passby
	var sc := radius * 2.0 / TEX
	b.scale = Vector2(sc, sc)
	b.position = center - Vector2(radius, radius)
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS   # whole layer is shown/hidden instead
	add_child(b)
	buttons[action] = b

	var l := Label.new()
	l.text = label
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", int(clampf(radius * 0.3, 18.0, 34.0)))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(radius * 2.0, radius * 2.0)
	l.position = center - Vector2(radius, radius)
	add_child(l)
