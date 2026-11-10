class_name Npc
extends Node2D
## A friendly non-player character standing on the street. Ethan rolls past and the NPC calls out a short
## greeting; if Ethan slows down next to them, a conversation opens. Dialogue text lives in a JSON file
## (see resources/dialogue/gus.json) so it can be edited without touching code. NPCs are scenery for
## physics: no collision, they never block Ethan.
##
## Persistent results (relationship, reputation) go to GameState, never into Ethan's controller.

signal conversation_started(npc_id: String)
signal conversation_finished(npc_id: String, first_time: bool, reputation_gain: int)

@export var dialogue_path: String = "res://resources/dialogue/gus.json"
@export var texture_path: String = "res://assets/characters/npcs/vagrant_man.png"
@export var height_px: float = 122.0
@export var face_left: bool = true
@export var bark_range: float = 650.0
@export var prompt_range: float = 260.0
@export var talk_range: float = 170.0
@export var talk_max_speed: float = 70.0     ## Ethan must be this slow to start a conversation
@export var linger_time: float = 0.35
@export var bark_cooldown: float = 12.0

var npc_id := "npc"
var display_name := "Stranger"
var data: Dictionary = {}
var dialogue: DialogueBox
var player: Node2D
var sprite: Sprite2D
var _bubble: Label
var _bubble_time := 0.0
var _bark_cd := 0.0
var _linger := 0.0
var _talking := false
var _t := 0.0

func _ready() -> void:
	z_index = -1                                     # behind Ethan
	_load_dialogue()
	var tex: Texture2D = load(texture_path) if ResourceLoader.exists(texture_path) else null
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	if tex != null:
		sprite.texture = tex
		var sc := height_px / float(tex.get_height())
		sprite.scale = Vector2(-sc if face_left else sc, sc)
		sprite.position = Vector2(0.0, -height_px * 0.5)   # feet on the origin
	add_child(sprite)
	_bubble = Label.new()
	_bubble.name = "Bubble"
	_bubble.add_theme_font_size_override("font_size", 30)
	_bubble.add_theme_color_override("font_color", Color.BLACK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 0.92, 0.96)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = Color.BLACK
	sb.set_content_margin_all(10)
	_bubble.add_theme_stylebox_override("normal", sb)
	_bubble.visible = false
	_bubble.z_index = 10
	add_child(_bubble)

func _load_dialogue() -> void:
	if ResourceLoader.exists(dialogue_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dialogue_path))
		if parsed is Dictionary:
			data = parsed
	npc_id = String(data.get("id", "npc"))
	display_name = String(data.get("name", "Stranger"))

func setup(box: DialogueBox, target: Node2D) -> void:
	dialogue = box
	player = target
	dialogue.finished.connect(_on_dialogue_finished)

func portrait() -> Texture2D:
	if sprite == null or sprite.texture == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = sprite.texture
	var w := sprite.texture.get_width()
	var h := sprite.texture.get_height()
	at.region = Rect2(0, 0, w, h * 0.42)              # head and shoulders
	return at

func _show_bubble(text: String, seconds: float) -> void:
	_bubble.text = text
	_bubble.reset_size()
	_bubble.position = Vector2(-_bubble.size.x * 0.5, -height_px - 18.0 - _bubble.size.y)
	_bubble.visible = true
	_bubble_time = seconds

func _process(delta: float) -> void:
	_t += delta
	if sprite != null and sprite.texture != null:           # slow "breathing" so he is not a statue
		var sc := height_px / float(sprite.texture.get_height())
		var br := 1.0 + 0.012 * sin(_t * 1.8)
		sprite.scale = Vector2((-sc if face_left else sc), sc * br)
		sprite.position.y = -height_px * 0.5 * br
	_bark_cd = maxf(_bark_cd - delta, 0.0)
	if _bubble_time > 0.0:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			_bubble.visible = false
	if player == null or not is_instance_valid(player) or _talking:
		return
	var dx := absf(player.global_position.x - global_position.x)
	var dy := absf(player.global_position.y - global_position.y)
	var speed: float = player.get("speed") if player.get("speed") != null else 0.0
	var near_ground := dy < 200.0
	# greeting as Ethan rolls up (once per approach)
	if near_ground and dx < bark_range and dx > prompt_range and _bark_cd <= 0.0 and speed > talk_max_speed:
		var barks: Array = data.get("barks", [])
		if not barks.is_empty():
			_show_bubble(String(barks.pick_random()), 2.4)
		_bark_cd = bark_cooldown
	# prompt when close
	if near_ground and dx < prompt_range and _bubble_time <= 0.0:
		_show_bubble(String(data.get("prompt", "Slow down to chat")), 0.25)
	# conversation: close and slow for a moment
	if near_ground and dx < talk_range and speed <= talk_max_speed:
		_linger += delta
		if _linger >= linger_time:
			start_conversation()
	else:
		_linger = 0.0

func start_conversation() -> void:
	if _talking or dialogue == null:
		return
	_talking = true
	_bubble.visible = false
	var first := not GameStateAccess.has_met(npc_id)
	var raw: Array = data.get("lines", []) if first else data.get("repeat_lines", data.get("lines", []))
	var lines: Array = _build_lines(raw)
	if player != null and "controls_enabled" in player:
		player.controls_enabled = false
	dialogue.open(display_name, lines, portrait())
	conversation_started.emit(npc_id)

## Turns JSON lines (plain strings, or {speaker, text}) into dialogue entries with name and portrait.
## Speaker "ethan" uses Ethan's name and a head-and-shoulders crop of his idle frame.
func _build_lines(raw: Array) -> Array:
	var out: Array = []
	for item: Variant in raw:
		if item is Dictionary:
			var who := String(item.get("speaker", npc_id))
			if who == "ethan":
				out.append({"name": "Ethan", "text": String(item.get("text", "")), "portrait": _ethan_portrait()})
			else:
				out.append({"name": display_name, "text": String(item.get("text", "")), "portrait": portrait()})
		else:
			out.append({"name": display_name, "text": String(item), "portrait": portrait()})
	return out

func _ethan_portrait() -> Texture2D:
	var path := "res://assets/characters/ethan/idle_00.png"
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	var used := tex.get_image().get_used_rect()          # the figure inside the padded canvas
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(used.position.x, used.position.y, used.size.x, used.size.y * 0.55)   # head, chest and board-free top
	return at

func _on_dialogue_finished() -> void:
	if not _talking:
		return
	var first := not GameStateAccess.has_met(npc_id)
	var gain := int(data.get("reputation", 0)) if first else 0
	if first:
		GameStateAccess.meet(npc_id, gain)
	_talking = false
	_linger = -2.0          # give Ethan a moment to roll away before another chat can start
	_bark_cd = bark_cooldown
	if player != null and "controls_enabled" in player:
		player.controls_enabled = true
	conversation_finished.emit(npc_id, first, gain)
