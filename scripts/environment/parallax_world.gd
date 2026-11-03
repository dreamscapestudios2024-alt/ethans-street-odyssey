class_name ParallaxWorld
extends Node
## Builds layers 1, 2 and 5 of the five-layer world. Layers 3 and 4 (gameplay
## ground, characters/objects) live in normal world space, parallax 1.0, and
## are never touched here. Parallax is visual only - no collision.

const LAYER1_SCALE := 0.2
const LAYER2_SCALE := 0.4
const LAYER5_SCALE := 1.5
const TILE_W := 3840.0
const GROUND_SCREEN_Y := 820.0

var layer1: ParallaxLayer
var layer2a: ParallaxLayer   ## repeating promenade strip
var layer2: ParallaxLayer
var layer5: ParallaxLayer

func build(parent: Node) -> void:
	var sky := CanvasLayer.new()
	sky.name = "SkyLayer"
	sky.layer = -20
	var sky_rect := ColorRect.new()
	sky_rect.color = Color("8fd3f4")
	sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.add_child(sky_rect)
	parent.add_child(sky)

	var back := ParallaxBackground.new()
	back.name = "BackgroundLayers"
	back.layer = -10
	parent.add_child(back)
	layer1 = _make_layer(back, "Layer1_DistantLandmarks", LAYER1_SCALE, PlaceholderBackdrop.Kind.SKY_LANDMARKS)
	layer2a = _make_promenade(back)   # between the distant landmarks and the shops
	layer2 = _make_layer(back, "Layer2_LocalScenery", LAYER2_SCALE, PlaceholderBackdrop.Kind.LOCAL_SCENERY)

	var front := ParallaxBackground.new()
	front.name = "ForegroundLayer"
	front.layer = 10
	parent.add_child(front)
	layer5 = _make_layer(front, "Layer5_Foreground", LAYER5_SCALE, PlaceholderBackdrop.Kind.FOREGROUND)

## Visual-only repeating promenade: ocean, sand, wall with wave murals and pavement. No collision.
## Scrolls at LAYER2_SCALE and repeats every (texture width x scale) pixels. The strip is trimmed
## vertically only, so the repeat length is exactly the artwork's own seamless width.
func _make_promenade(bg: ParallaxBackground) -> ParallaxLayer:
	var tex := BackdropArt.texture(BackdropArt.PROMENADE_PATH)
	if tex == null:
		push_warning("Promenade strip missing (assets/backgrounds/%s.png); skipping Layer 2a" % BackdropArt.PROMENADE_PATH)
		return null
	var sc := BackdropArt.PROMENADE_SCALE
	var region := BackdropArt.PROMENADE_REGION
	var tile_w := region.size.x * sc
	var pl := ParallaxLayer.new()
	pl.name = "Layer2a_VenicePromenade"
	pl.motion_scale = Vector2(LAYER2_SCALE, 1.0)
	pl.motion_mirroring = Vector2(tile_w, 0.0)
	var top := BackdropArt.HORIZON_WORLD_Y
	var strip := Sprite2D.new()
	strip.name = "PromenadeStrip"
	strip.texture = tex
	strip.centered = false
	strip.region_enabled = true
	strip.region_rect = region
	strip.scale = Vector2(sc, sc)
	strip.position = Vector2(0.0, top)
	pl.add_child(strip)
	# Solid pavement-coloured fill below the strip, so ground that drops away (stairs, down ramps)
	# never exposes the sky colour. Same width as the strip so it repeats with it.
	var fill := ColorRect.new()
	fill.name = "BelowStripFill"
	fill.color = BackdropArt.PROMENADE_BELOW_COLOR
	fill.position = Vector2(0.0, top + region.size.y * sc - 1.0)
	fill.size = Vector2(tile_w, 3000.0)
	pl.add_child(fill)
	bg.add_child(pl)
	return pl

func _make_layer(bg: ParallaxBackground, layer_name: String, scale_x: float, kind: PlaceholderBackdrop.Kind) -> ParallaxLayer:
	var pl := ParallaxLayer.new()
	pl.name = layer_name
	pl.motion_scale = Vector2(scale_x, 1.0)  # horizontal parallax only
	pl.motion_mirroring = Vector2(TILE_W, 0.0)
	var art := PlaceholderBackdrop.new()
	art.kind = kind
	art.tile_width = TILE_W
	art.position = Vector2(0.0, -GROUND_SCREEN_Y)  # art is authored with the ground line at y=820
	pl.add_child(art)
	bg.add_child(pl)
	return pl
