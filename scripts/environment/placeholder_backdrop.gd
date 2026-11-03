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
	# Placeholder base first (sky/ocean/hills), then production sprites on top when present.
	match kind:
		Kind.SKY_LANDMARKS: _draw_landmarks()
		Kind.LOCAL_SCENERY: pass
		Kind.FOREGROUND: pass
	var sprites := BackdropArt.layout(kind, tile_width)
	for it: Dictionary in sprites:
		var tex: Texture2D = it["tex"]
		var sc: float = it["scale"]
		draw_texture_rect(tex, Rect2(it["pos"], tex.get_size() * sc), false)
	if sprites.is_empty():
		match kind:
			Kind.LOCAL_SCENERY: _draw_scenery()
			Kind.FOREGROUND: _draw_foreground()

func _draw_landmarks() -> void:
	# Ocean horizon and soft hills; pier/lifeguard sprites are added by BackdropArt.
	draw_rect(Rect2(0, 560, tile_width, 800), Color("3b8fc4"))
	draw_rect(Rect2(0, 556, tile_width, 8), Color("a6d8f0"))
	for i in 6:
		var x := i * tile_width / 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 556), Vector2(x + 260, 420), Vector2(x + 520, 556)]), Color("8aa56a").darkened(0.1 * (i % 2)))
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
		x += w + 140.0
		i += 1

func _draw_foreground() -> void:
	var x := 600.0
	while x < tile_width:
		draw_rect(Rect2(x, 380, 18, 760), Color("2c3138"))
		x += 1700.0
