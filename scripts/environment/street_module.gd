class_name StreetModule
extends StaticBody2D
## Configurable side-on 2D street module.
##
## Origin convention: the module's origin is the LEFT end of its entry ground
## line (top surface of a flat sidewalk is y = 0, +y is down). Solid parts
## always extend `ground_depth` below the ground line so modules butt together
## with no gaps. Artwork (_draw / textures) and collision are built separately.
##
## Extendable types (sidewalk, brick wall, garden bed, ledge, handrail) use the
## three-piece scheme LEFT END + tiled MIDDLE + RIGHT END when textures are set.

enum Type {
	SIDEWALK, BRICK_WALL, GARDEN_BED, LEDGE, HANDRAIL,
	RAMP_UP, RAMP_DOWN, STAIRS, STAIRS_RAIL,
	BARRIER, POTHOLE, BIN,
}

const WORLD_LAYER := 1
const HAZARD_LAYER := 4  # bit value for physics layer 3

@export var type: Type = Type.SIDEWALK:
	set(v):
		type = v
		_request_rebuild()
@export var length: float = 800.0:
	set(v):
		length = v
		_request_rebuild()
@export var height: float = 0.0       ## 0 = use the type's default
@export var ground_depth: float = 400.0
@export var rail_height: float = 90.0
@export var step_count: int = 5
@export var step_width: float = 70.0
@export var step_height: float = 34.0
@export var rail_score_multiplier: float = 1.0
@export_group("Optional production art (PNG, side-on)")
@export var texture_left: Texture2D
@export var texture_middle: Texture2D
@export var texture_right: Texture2D
@export var texture_single: Texture2D

var rail: GrindRail
var hazard_area: Area2D
var _built := false

const DEFAULT_HEIGHTS := {
	Type.BRICK_WALL: 120.0, Type.GARDEN_BED: 64.0, Type.LEDGE: 56.0,
	Type.RAMP_UP: 110.0, Type.RAMP_DOWN: 110.0,
	Type.BARRIER: 100.0, Type.BIN: 84.0, Type.POTHOLE: 0.0,
}
const EXTENDABLE := [Type.SIDEWALK, Type.BRICK_WALL, Type.GARDEN_BED, Type.LEDGE, Type.HANDRAIL]
const FIXED_LENGTHS := {Type.BARRIER: 90.0, Type.BIN: 56.0, Type.POTHOLE: 130.0}

func _ready() -> void:
	collision_layer = WORLD_LAYER
	collision_mask = 0
	rebuild()

func _request_rebuild() -> void:
	if is_inside_tree() and _built:
		rebuild()

func is_extendable() -> bool:
	return type in EXTENDABLE

func effective_height() -> float:
	return height if height > 0.0 else float(DEFAULT_HEIGHTS.get(type, 0.0))

func effective_length() -> float:
	match type:
		Type.STAIRS, Type.STAIRS_RAIL:
			return step_count * step_width
		Type.BARRIER, Type.BIN, Type.POTHOLE:
			return float(FIXED_LENGTHS[type])
	return length

## Offset from this module's origin to where the NEXT module's origin belongs.
func end_offset() -> Vector2:
	var dy := 0.0
	match type:
		Type.RAMP_DOWN:
			dy = effective_height()
		Type.STAIRS, Type.STAIRS_RAIL:
			dy = step_count * step_height
	return Vector2(effective_length(), dy)

## Height (px above ground line) of the highest walkable surface.
func surface_height() -> float:
	match type:
		Type.BRICK_WALL, Type.GARDEN_BED, Type.LEDGE:
			return effective_height()
	return 0.0

func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	rail = null
	hazard_area = null
	var w := effective_length()
	var h := effective_height()
	match type:
		Type.SIDEWALK, Type.HANDRAIL, Type.BARRIER, Type.BIN, Type.POTHOLE:
			_add_rect(0.0, 0.0, w, ground_depth)
		Type.BRICK_WALL, Type.GARDEN_BED, Type.LEDGE:
			_add_rect(0.0, -h, w, ground_depth + h)
		Type.RAMP_UP:
			_add_poly([Vector2(0, 0), Vector2(w, -h), Vector2(w, ground_depth), Vector2(0, ground_depth)])
		Type.RAMP_DOWN:
			_add_poly([Vector2(0, 0), Vector2(w, h), Vector2(w, ground_depth), Vector2(0, ground_depth)])
		Type.STAIRS, Type.STAIRS_RAIL:
			for i in range(1, step_count + 1):
				_add_rect((i - 1) * step_width, i * step_height, step_width, ground_depth)
	match type:
		Type.BARRIER:
			_add_rect(0.0, -h, w, h)
		Type.BIN:
			_add_rect(0.0, -h, w, h)
		Type.LEDGE:
			_add_rail(Vector2(0, -h), Vector2(w, -h), 0.9)
		Type.HANDRAIL:
			_add_rail(Vector2(0, -rail_height), Vector2(w, -rail_height), 1.0)
		Type.STAIRS_RAIL:
			_add_rail(Vector2(0, -rail_height), Vector2(w, step_count * step_height - rail_height), 1.4)
		Type.POTHOLE:
			_add_hazard(Rect2(12, -20, w - 24, 50))
	_built = true
	queue_redraw()

func _add_rect(x: float, y: float, w: float, h: float) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w + 1.0, h)  # 1px overlap hides seams between modules
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(x + (w + 1.0) * 0.5, y + h * 0.5)
	add_child(cs)

func _add_poly(points: Array) -> void:
	var cp := CollisionPolygon2D.new()
	cp.polygon = PackedVector2Array(points)
	add_child(cp)

func _add_rail(a: Vector2, b: Vector2, base_multiplier: float) -> void:
	rail = GrindRail.new()
	rail.name = "GrindRail"
	rail.start_point = a
	rail.end_point = b
	rail.score_multiplier = base_multiplier * rail_score_multiplier
	rail.show_debug_line = false
	add_child(rail)

func _add_hazard(rect: Rect2) -> void:
	hazard_area = Area2D.new()
	hazard_area.name = "Hazard"
	hazard_area.collision_layer = HAZARD_LAYER
	hazard_area.collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = rect.get_center()
	hazard_area.add_child(cs)
	add_child(hazard_area)

func _physics_process(_delta: float) -> void:
	if hazard_area == null:
		return
	for body in hazard_area.get_overlapping_bodies():
		if body.has_method("hazard_hit"):
			body.hazard_hit("pothole")

# --- Placeholder artwork ---------------------------------------------------

const C_CONCRETE := Color("c9c4b8")
const C_CONCRETE_DARK := Color("9d988c")
const C_BRICK := Color("b5532f")
const C_BRICK_DARK := Color("8a3a20")
const C_METAL := Color("8fa3b0")
const C_PLANT := Color("4d9a4a")

func _draw() -> void:
	var w := effective_length()
	var h := effective_height()
	if texture_single != null:
		draw_texture(texture_single, Vector2(0, -texture_single.get_height() + 0.0))
		return
	if is_extendable() and texture_middle != null:
		_draw_three_piece(w, h)
		return
	match type:
		Type.SIDEWALK: _draw_slab(w, 0.0, C_CONCRETE)
		Type.BRICK_WALL: _draw_bricks(w, h)
		Type.GARDEN_BED:
			_draw_bricks(w, h)
			draw_rect(Rect2(0, -h - 14, w, 16), C_PLANT)
		Type.LEDGE:
			_draw_slab(w, h, C_CONCRETE)
			draw_rect(Rect2(0, -h, w, 6), C_CONCRETE_DARK)
		Type.HANDRAIL:
			_draw_slab(w, 0.0, C_CONCRETE)
			_draw_posts(w, rail_height, 0.0)
		Type.RAMP_UP:
			draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, -h), Vector2(w, 60), Vector2(0, 60)]), Color("d8a24a"))
			draw_line(Vector2(0, 0), Vector2(w, -h), Color("7a5a1f"), 6.0)
		Type.RAMP_DOWN:
			draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, h), Vector2(w, h + 60), Vector2(0, 60)]), Color("d8a24a"))
			draw_line(Vector2(0, 0), Vector2(w, h), Color("7a5a1f"), 6.0)
		Type.STAIRS, Type.STAIRS_RAIL:
			for i in range(1, step_count + 1):
				var x := (i - 1) * step_width
				var top := i * step_height
				draw_rect(Rect2(x, top, step_width, 70), C_CONCRETE if i % 2 == 0 else C_CONCRETE_DARK)
				draw_rect(Rect2(x, top, step_width, 5), Color.WHITE.darkened(0.15))
			if type == Type.STAIRS_RAIL:
				var a := Vector2(0, -rail_height)
				var b := Vector2(w, step_count * step_height - rail_height)
				draw_line(a, b, C_METAL, 7.0)
				for i in range(0, step_count + 1, 2):
					var p := a.lerp(b, float(i) / step_count)
					draw_line(p, Vector2(p.x, maxf(i * step_height, 0.0)), C_METAL.darkened(0.3), 5.0)
		Type.BARRIER:
			draw_rect(Rect2(0, -h, w, h), Color("f08a24"))
			for i in 4:
				draw_rect(Rect2(0, -h + 10 + i * 22, w, 10), Color.WHITE if i % 2 == 0 else Color("f08a24"))
		Type.POTHOLE:
			_draw_slab(w, 0.0, C_CONCRETE)
			draw_rect(Rect2(12, -2, w - 24, 22), Color("2b2623"))
			draw_rect(Rect2(12, -2, w - 24, 4), Color("55493f"))
		Type.BIN:
			draw_rect(Rect2(0, -h, w, h), Color("3f7f5a"))
			draw_rect(Rect2(-4, -h - 8, w + 8, 10), Color("2c5a40"))
	if type in [Type.BARRIER, Type.BIN]:
		_draw_slab(w, 0.0, C_CONCRETE)

func _draw_slab(w: float, up: float, col: Color) -> void:
	draw_rect(Rect2(0, -up, w, 70 + up), col)
	draw_rect(Rect2(0, -up, w, 6), col.lightened(0.2))
	# end caps (left end / right end) so tileable pieces read as three-piece
	draw_rect(Rect2(0, -up, 4, 70 + up), col.darkened(0.25))
	draw_rect(Rect2(w - 4, -up, 4, 70 + up), col.darkened(0.25))

func _draw_bricks(w: float, h: float) -> void:
	draw_rect(Rect2(0, -h, w, h + 70), C_BRICK)
	var row := 0
	var y := -h
	while y < 70.0:
		draw_line(Vector2(0, y), Vector2(w, y), C_BRICK_DARK, 2.0)
		var x := 0.0 if row % 2 == 0 else 24.0
		while x < w:
			draw_line(Vector2(x, y), Vector2(x, y + 20), C_BRICK_DARK, 2.0)
			x += 48.0
		y += 20.0
		row += 1
	draw_rect(Rect2(-3, -h - 4, w + 6, 10), C_CONCRETE)

func _draw_posts(w: float, rh: float, ground: float) -> void:
	draw_line(Vector2(0, -rh), Vector2(w, -rh), C_METAL, 7.0)
	var x := 0.0
	while x <= w:
		draw_line(Vector2(x, -rh), Vector2(x, ground), C_METAL.darkened(0.3), 6.0)
		x += 200.0
	draw_line(Vector2(w, -rh), Vector2(w, ground), C_METAL.darkened(0.3), 6.0)

func _draw_three_piece(w: float, h: float) -> void:
	var top := -h if type != Type.HANDRAIL and type != Type.SIDEWALK else 0.0
	var lw: float = float(texture_left.get_width()) if texture_left else 0.0
	var rw: float = float(texture_right.get_width()) if texture_right else 0.0
	var th := texture_middle.get_height()
	if texture_left:
		draw_texture(texture_left, Vector2(0, top))
	if texture_right:
		draw_texture(texture_right, Vector2(w - rw, top))
	draw_texture_rect(texture_middle, Rect2(lw, top, maxf(w - lw - rw, 0.0), th), true)
