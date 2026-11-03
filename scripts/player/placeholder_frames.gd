class_name PlaceholderFrames
extends RefCounted
## Builds Ethan's SpriteFrames. Production art drop-in:
## put PNGs at res://assets/characters/ethan/<animation>_<NN>.png
## (NN = 00, 01, ... or 1, 2, ...) and they replace the placeholder for that
## animation automatically. See docs/asset_specifications.md.

const ANIMATIONS := {
	# name: [placeholder_frame_count, fps, loop]  (production PNG count may differ)
	"idle": [2, 4.0, true], "push": [4, 12.0, true], "push_fast": [4, 15.0, true], "cruise": [2, 8.0, true],
	"speed": [2, 12.0, true], "brake": [2, 10.0, true], "drift": [2, 10.0, true],
	"crouch": [1, 8.0, false], "jump": [2, 12.0, false], "airborne": [2, 6.0, true],
	"landing": [1, 14.0, false], "grind": [2, 8.0, true], "fall": [3, 8.0, false],
}
const ASSET_DIR := "res://assets/characters/ethan/"
const FRAME_SIZE := Vector2i(128, 128)  ## placeholder only; production art may differ

static func build() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim: String in ANIMATIONS:
		var info: Array = ANIMATIONS[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, info[1])
		sf.set_animation_loop(anim, info[2])
		var textures := _load_production(anim)
		if textures.is_empty():
			for i in int(info[0]):
				textures.append(ImageTexture.create_from_image(_draw_frame(anim, i)))
		for t in textures:
			sf.add_frame(anim, t)
	return sf

static func _load_production(anim: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for start in [0, 1]:
		var i: int = start
		while true:
			var path := "%s%s_%02d.png" % [ASSET_DIR, anim, i]
			if not ResourceLoader.exists(path):
				break
			out.append(load(path))
			i += 1
		if not out.is_empty():
			break
	return out

# --- procedural placeholder figure (side view, facing right) ----------------

static func _draw_frame(anim: String, frame: int) -> Image:
	var img := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := FRAME_SIZE.x / 2
	var base := FRAME_SIZE.y  # feet/board bottom at the image bottom edge
	var lean := 0
	var crouch := 0
	var arms_up := false
	var kick := 0
	var board_lift := 0
	var f := frame
	match anim:
		"idle": crouch = f * 2
		"push": kick = [0, 14, 22, 8][f]; lean = 4
		"cruise": lean = 3; crouch = 6 + f * 2
		"speed": lean = 12; crouch = 16 + f * 2
		"brake": lean = -8; kick = 18 + f * 4
		"drift": lean = -14; crouch = 20; kick = 8
		"crouch": crouch = 30; lean = 6
		"jump": arms_up = true; board_lift = 10 + f * 6; crouch = 12
		"airborne": arms_up = true; board_lift = 14; crouch = 6 + f * 4
		"landing": crouch = 34; lean = 4
		"grind": lean = 6; crouch = 14; board_lift = 2
		"fall": lean = -20 + f * 20; crouch = 50 - f * 10; arms_up = true
	var deck_y := base - 14 - board_lift
	# board + wheels
	_rect(img, cx - 34, deck_y, 68, 6, Color("30343a"))
	_rect(img, cx - 28, deck_y + 6, 10, 8, Color("f4c542"))
	_rect(img, cx + 18, deck_y + 6, 10, 8, Color("f4c542"))
	var hip_y := deck_y - 38 + crouch
	# legs
	_rect(img, cx - 14 - kick / 2, hip_y, 9, deck_y - hip_y, Color("2e4a8f"))
	_rect(img, cx + 8, hip_y, 9, deck_y - hip_y, Color("2e4a8f"))
	_rect(img, cx + 6, deck_y - 6, 18, 6, Color("e8e8e8"))
	# torso, arms, head
	var torso_top := hip_y - 36 + crouch / 3
	_rect(img, cx - 10 + lean / 2, torso_top, 22, hip_y - torso_top, Color("ff7043"))
	var arm_y := torso_top + 4 if not arms_up else torso_top - 18
	_rect(img, cx + 8 + lean / 2, arm_y, 8, 22, Color("ffd5a8"))
	_rect(img, cx - 18 + lean / 2, arm_y, 8, 22, Color("ffd5a8"))
	_circle(img, cx + lean, torso_top - 12, 12, Color("ffd5a8"))
	_rect(img, cx + lean - 12, torso_top - 26, 24, 8, Color("2b2b2b"))  # cap
	return img

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var r := Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)

static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r:
				var px := cx + x
				var py := cy + y
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, c)
