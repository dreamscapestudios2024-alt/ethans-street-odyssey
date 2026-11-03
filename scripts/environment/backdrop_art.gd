class_name BackdropArt
extends RefCounted
## Sprite layouts for the parallax layers (art from assets/backgrounds/layerN/*.png).
## Coordinates are in the layer art's own space (ground line at y = 820, see ParallaxWorld).
## Missing files are skipped, so layers degrade gracefully to the placeholder base drawing.

const DIR := "res://assets/backgrounds/"
const GROUND_Y := 820.0

static var _cache: Dictionary = {}

static func texture(rel: String) -> Texture2D:
	if _cache.has(rel):
		return _cache[rel]
	var path := DIR + rel + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[rel] = tex  # strong ref (also caches misses)
	return tex

## [{tex, pos (top-left, art space), scale}] for a layer kind, packed left to right in one tile.
static func layout(kind: int, tile_w: float) -> Array:
	var items: Array = []
	match kind:
		PlaceholderBackdrop.Kind.SKY_LANDMARKS:
			items.append(_place("layer1/lifeguard", 280.0, 585.0, 1.0))
			items.append(_place("layer1/pier", 1450.0, 585.0, 1.4))
			items.append(_place("layer1/gazebo", 2750.0, 600.0, 1.0))
		PlaceholderBackdrop.Kind.LOCAL_SCENERY:
			var seq := ["layer2/shop_skate", "layer2/palm", "layer2/shop_surf", "layer2/shop_cafe",
				"layer2/mural_venice", "layer2/palm", "layer2/shop_market", "layer2/house_yellow"]
			var x := 30.0
			for key: String in seq:
				var tex := texture(key)
				if tex == null:
					continue
				var sc := 1.5 if key.contains("shop") or key.contains("mural") or key.contains("house") else 1.7
				if x + tex.get_width() * sc > tile_w:
					break
				items.append(_place(key, x, GROUND_Y + 25.0, sc))
				x += tex.get_width() * sc + 40.0
		PlaceholderBackdrop.Kind.FOREGROUND:
			items.append(_place("layer5/palm", 700.0, GROUND_Y + 150.0, 2.6))
			items.append(_place("layer5/bush", 1250.0, GROUND_Y + 190.0, 2.0))
			items.append(_place("layer5/lamp", 2000.0, GROUND_Y + 150.0, 2.4))
			items.append(_place("layer5/bush_flowers", 2750.0, GROUND_Y + 190.0, 2.2))
			items.append(_place("layer5/lamp_double", 3350.0, GROUND_Y + 150.0, 2.2))
	return items.filter(func(i: Dictionary) -> bool: return i["tex"] != null)

## `base` is the y of the sprite's bottom edge.
static func _place(key: String, x: float, base: float, scale: float) -> Dictionary:
	var tex := texture(key)
	var pos := Vector2.ZERO
	if tex != null:
		pos = Vector2(x, base - tex.get_height() * scale)
	return {"tex": tex, "pos": pos, "scale": scale}
