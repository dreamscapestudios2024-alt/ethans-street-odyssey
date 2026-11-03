class_name StreetArt
extends RefCounted
## Production artwork specs for StreetModule types (cut from the supplied street-element
## sheet by tools/slice_sheet.py / extract step; PNGs live in assets/street_modules/).
## All values are measured in the PNG's own pixels; `scale` converts to world pixels.
## Types without an entry (or with missing files) fall back to placeholder drawing.

const DIR := "res://assets/street_modules/"

# solid_top: pixel row where the walkable surface begins (plants/decor above it are not solid).
const SPEC := {
	StreetModule.Type.SIDEWALK: {"file": "sidewalk", "scale": 1.3, "solid_top": 6},
	StreetModule.Type.BRICK_WALL: {"file": "brick_wall", "scale": 1.2, "solid_top": 5},
	StreetModule.Type.GARDEN_BED: {"file": "garden_bed", "scale": 0.9, "solid_top": 38},
	StreetModule.Type.LEDGE: {"file": "ledge", "scale": 1.1, "solid_top": 3},
	StreetModule.Type.HANDRAIL: {"file": "handrail", "scale": 1.4, "bar_top": 11},
	StreetModule.Type.RAMP_UP: {"file": "ramp", "flip": false},
	StreetModule.Type.RAMP_DOWN: {"file": "ramp", "flip": true},
	StreetModule.Type.BARRIER: {"file": "barrier"},
	StreetModule.Type.BIN: {"file": "bin"},
	# Art ascends to the right; it is flipped so the stairs descend left to right.
	# block_x: first tread's left edge; top_y/floor_y: top tread surface / floor line;
	# rail_hi / rail_lo: grind line end points (high end first) in unflipped art pixels.
	StreetModule.Type.STAIRS_RAIL: {"file": "stairs_rail", "scale": 1.7, "block_x": 62, "top_y": 40,
		"floor_y": 123, "treads": 4, "rail_hi": Vector2(190, 20), "rail_lo": Vector2(20, 81)},
}

static func spec(type: int) -> Dictionary:
	return SPEC.get(type, {})

## Strong references: a texture held only by a local variable inside _draw() can be freed
## before the frame renders, which draws it as a white rectangle.
static var _cache: Dictionary = {}

static func texture(type: int) -> Texture2D:
	var s: Dictionary = spec(type)
	if s.is_empty():
		return null
	var path: String = DIR + String(s["file"]) + ".png"
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		_cache[path] = tex
		return tex
	return null

static func ground_texture() -> Texture2D:
	return texture(StreetModule.Type.SIDEWALK)
