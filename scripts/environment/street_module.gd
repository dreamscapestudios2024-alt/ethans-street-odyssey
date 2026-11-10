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
@export var use_art: bool = true  ## use art from StreetArt when available (else placeholder drawing)
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

func _art() -> Texture2D:
	return StreetArt.texture(type) if use_art else null

func _art_spec() -> Dictionary:
	return StreetArt.spec(type) if (use_art and _art() != null) else {}

func effective_height() -> float:
	if height > 0.0:
		return height
	var sp := _art_spec()
	if sp.has("solid_top") and type != Type.SIDEWALK:
		var t := _art()
		return (t.get_height() - float(sp["solid_top"])) * float(sp["scale"])
	return float(DEFAULT_HEIGHTS.get(type, 0.0))

func effective_rail_height() -> float:
	var sp := _art_spec()
	if sp.has("bar_top"):
		return (_art().get_height() - float(sp["bar_top"])) * float(sp["scale"])
	return rail_height

func _stairs_dims() -> Vector3:
	## (step_count, step_width, step_height) - from art when present.
	var sp := _art_spec()
	if type == Type.STAIRS_RAIL and sp.has("treads"):
		var t := _art()
		var n := int(sp["treads"])
		var sc := float(sp["scale"])
		return Vector3(n, (t.get_width() - float(sp["block_x"])) * sc / n, (float(sp["floor_y"]) - float(sp["top_y"])) * sc / n)
	return Vector3(step_count, step_width, step_height)

func effective_length() -> float:
	match type:
		Type.STAIRS, Type.STAIRS_RAIL:
			var d := _stairs_dims()
			return d.x * d.y
		Type.BARRIER, Type.BIN, Type.POTHOLE:
			var t := _art()
			if t != null and type != Type.POTHOLE:
				return t.get_width() * effective_height() / t.get_height()
			return float(FIXED_LENGTHS[type])
	return length

## Offset from this module's origin to where the NEXT module's origin belongs.
func end_offset() -> Vector2:
	var dy := 0.0
	match type:
		Type.RAMP_DOWN:
			dy = effective_height()
		Type.STAIRS, Type.STAIRS_RAIL:
			var d := _stairs_dims()
			dy = d.x * d.z
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
			# Tread 1 is flush with the ground on the left; the floor sits n*step_height lower.
			var d := _stairs_dims()
			for i in range(1, int(d.x) + 1):
				_add_rect((i - 1) * d.y, (i - 1) * d.z, d.y, ground_depth + d.x * d.z)
	match type:
		Type.BARRIER:
			_add_rect(0.0, -h, w, h)
		Type.BIN:
			_add_rect(0.0, -h, w, h)
		Type.LEDGE:
			_add_rail(Vector2(0, -h), Vector2(w, -h), 0.9)
		Type.HANDRAIL:
			var rh := effective_rail_height()
			_add_rail(Vector2(0, -rh), Vector2(w, -rh), 1.0)
		Type.STAIRS_RAIL:
			_add_stairs_rail(w)
		Type.POTHOLE:
			_add_hazard(Rect2(12, -20, w - 24, 50))
	_built = true
	queue_redraw()

func _add_stairs_rail(w: float) -> void:
	var d := _stairs_dims()
	var sp := _art_spec()
	var a := Vector2(0, -rail_height)
	var b := Vector2(w, d.x * d.z - rail_height)
	if sp.has("rail_hi"):
		var t := _art()
		var sc := float(sp["scale"])
		# unflip: x' = art_width - x; module x = (x' - 0) * sc ; module y = (y - top_y) * sc
		var hi: Vector2 = sp["rail_hi"]
		var lo: Vector2 = sp["rail_lo"]
		a = Vector2((t.get_width() - hi.x) * sc, (hi.y - float(sp["top_y"])) * sc)
		b = Vector2((t.get_width() - lo.x) * sc, (lo.y - float(sp["top_y"])) * sc)
	_add_rail(a, b, 1.4)

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
			body.hazard_hit("pothole", global_position.x + effective_length() + 36.0, global_position.x - 36.0)

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
	if type == Type.POTHOLE and use_art and StreetArt.ground_texture() != null:
		_draw_ground(w)
		_draw_pothole(w)
		return
	if _draw_art(w, h):
		return
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

const GROUND_FILL := Color("8d8d98")
const TILE_OVERLAP := 5.0  ## px: tiles overlap slightly so outlines meet without gaps

func _draw_tiles(tex: Texture2D, sc: float, x0: float, x1: float, y: float) -> void:
	var tw := tex.get_width() * sc
	var th := tex.get_height() * sc
	var x := x0
	var step := maxf(tw - TILE_OVERLAP, 1.0)
	while x < x1 - 0.01:
		var draw_w := minf(tw, x1 - x)
		var src := Rect2(0, 0, draw_w / sc, tex.get_height())
		draw_texture_rect_region(tex, Rect2(x, y, draw_w, th), src)
		x += step

func _draw_ground(w: float) -> void:
	var g := StreetArt.ground_texture()
	if g == null:
		draw_rect(Rect2(0, 0, w, ground_depth), GROUND_FILL)
		return
	var sp := StreetArt.spec(Type.SIDEWALK)
	var sc := float(sp["scale"])
	var top := -float(sp["solid_top"]) * sc
	draw_rect(Rect2(0, 4.0, w, ground_depth), GROUND_FILL)  # also fills seams between slab tiles
	_draw_tiles(g, sc, 0.0, w, top)

func _draw_pothole(w: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(w * 0.5 + cos(a) * (w * 0.5 - 8.0), 6.0 + sin(a) * 15.0))
	draw_colored_polygon(pts, Color("2b2623"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("0f0d0c"), 3.0)
	draw_rect(Rect2(w * 0.25, 4.0, w * 0.5, 4.0), Color("55493f"))

func _draw_art_rect(tex: Texture2D, rect: Rect2, flip_h: bool) -> void:
	if not flip_h:
		draw_texture_rect(tex, rect, false)
		return
	draw_set_transform(Vector2(rect.position.x + rect.size.x, rect.position.y), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(tex, Rect2(Vector2.ZERO, rect.size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Draws production art. Returns false to fall back to the placeholder drawing.
func _draw_art(w: float, h: float) -> bool:
	var tex := _art()
	if tex == null:
		return false
	var sp := _art_spec()
	var sc: float = float(sp.get("scale", 1.0))
	match type:
		Type.SIDEWALK:
			_draw_ground(w)
		Type.BRICK_WALL, Type.GARDEN_BED, Type.LEDGE:
			_draw_ground(w)
			_draw_tiles(tex, sc, 0.0, w, -h - float(sp["solid_top"]) * sc)
		Type.HANDRAIL:
			_draw_ground(w)
			_draw_tiles(tex, sc, 0.0, w, -effective_rail_height() - float(sp["bar_top"]) * sc)
		Type.RAMP_UP, Type.RAMP_DOWN:
			var flip: bool = bool(sp.get("flip", false))
			var rect := Rect2(0, -h, w, h) if type == Type.RAMP_UP else Rect2(0, 0, w, h)
			if type == Type.RAMP_DOWN:
				draw_rect(Rect2(0, h - 2.0, w, ground_depth), GROUND_FILL)
			else:
				draw_rect(Rect2(0, -2.0, w, ground_depth), GROUND_FILL)
			_draw_art_rect(tex, rect, flip)
		Type.BARRIER, Type.BIN:
			_draw_ground(w)
			draw_texture_rect(tex, Rect2(0, -h, w, h), false)
		Type.STAIRS_RAIL:
			var d := _stairs_dims()
			draw_rect(Rect2(0, d.x * d.z - 2.0, w + 60.0, ground_depth), GROUND_FILL)
			for i in range(int(d.x)):  # solid fill behind the art, matching the stepped collision
				draw_rect(Rect2(i * d.y, i * d.z + 4.0, d.y + 1.0, d.x * d.z), GROUND_FILL)
			# flipped: art is anchored so its top tread surface is y=0 and its stair block starts at x=0
			var tw := tex.get_width() * sc
			var th := tex.get_height() * sc
			_draw_art_rect(tex, Rect2(0, -float(sp["top_y"]) * sc, tw, th), true)
		_:
			return false
	return true

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
