class_name PlaceholderBackdrop
extends Node2D
## Draws placeholder parallax art for one tile of a given layer. Replace by
## assigning `texture` (PNG with alpha) - see docs/asset_specifications.md.

enum Kind { SKY_LANDMARKS, LOCAL_SCENERY, FOREGROUND }

@export var kind: Kind = Kind.SKY_LANDMARKS
@export var tile_width: float = 3840.0
@export var texture: Texture2D
@export var texture_position: Vector2 = Vector2.ZERO

func _draw() -> void:
	if texture != null:
		draw_texture(texture, texture_position)
		return
	match kind:
		Kind.SKY_LANDMARKS: _draw_landmarks()
		Kind.LOCAL_SCENERY: _draw_scenery()
		Kind.FOREGROUND: _draw_foreground()

func _draw_landmarks() -> void:
	# Ocean horizon, distant pier, hills with a Hollywood-sign nod.
	draw_rect(Rect2(0, 560, tile_width, 600), Color("3b8fc4"))
	draw_rect(Rect2(0, 556, tile_width, 8), Color("a6d8f0"))
	for i in 6:
		var x := i * tile_width / 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 556), Vector2(x + 260, 420), Vector2(x + 520, 556)]), Color("8aa56a").darkened(0.1 * (i % 2)))
	draw_rect(Rect2(tile_width * 0.55, 520, 520, 14), Color("6e5a46"))  # pier deck
	for i in 9:
		draw_rect(Rect2(tile_width * 0.55 + i * 60.0, 534, 8, 40), Color("54443a"))
	var sx := tile_width * 0.18
	for ch in "VENICE":
		draw_rect(Rect2(sx, 462, 34, 44), Color.WHITE)
		sx += 44.0
	draw_circle(Vector2(tile_width * 0.8, 200), 90.0, Color("ffe08a"))

func _draw_scenery() -> void:
	var x := 0.0
	var i := 0
	var cols := [Color("f2a65a"), Color("7fc8a9"), Color("e86f8a"), Color("f7d96b"), Color("8fb8ed")]
	while x < tile_width:
		var w := 360.0 + (i % 3) * 70.0
		var h := 300.0 + (i % 4) * 60.0
		draw_rect(Rect2(x, 820 - h, w, h), cols[i % cols.size()])
		draw_rect(Rect2(x, 820 - h, w, 14), cols[i % cols.size()].darkened(0.25))
		for wx in range(int(x) + 30, int(x + w) - 70, 110):
			draw_rect(Rect2(wx, 820 - h + 60, 70, 90), Color("39566e"))
		# palm tree between shops
		var px := x + w + 40.0
		draw_line(Vector2(px, 820), Vector2(px + 10, 480), Color("7a5a3a"), 14.0)
		for a in 5:
			draw_line(Vector2(px + 10, 480), Vector2(px + 10 + cos(a * 1.2 - 2.4) * 120, 480 + sin(a * 1.2 - 2.4) * 70 + 40), Color("3f8f4a"), 10.0)
		x += w + 140.0
		i += 1

func _draw_foreground() -> void:
	var x := 600.0
	while x < tile_width:
		# lamp post
		draw_rect(Rect2(x, 380, 18, 760), Color("2c3138"))
		draw_rect(Rect2(x - 40, 370, 100, 14), Color("2c3138"))
		draw_circle(Vector2(x - 30, 392), 14.0, Color("ffe9a0"))
		x += 1700.0
	var gx := 200.0
	while gx < tile_width:
		draw_circle(Vector2(gx, 1090), 70.0, Color("2f7f3c", 0.9))
		gx += 900.0
