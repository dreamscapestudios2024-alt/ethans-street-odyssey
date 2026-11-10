class_name Npc
extends Node2D
## A friendly non-player character standing on the street. Ethan rolls past and the NPC calls out a short
## greeting; if Ethan slows down next to them, a conversation opens. Dialogue lives in a JSON file
## (see resources/dialogue/gus.json): a list of conversations, each with an optional "when" condition
## (mission state, items), lines, optional choices with branches, and effects. NPCs are scenery for
## physics: no collision, they never block Ethan.
##
## Persistent results (relationships, missions, items, money, credibility) go to GameState via
## DialogueEffects - never into Ethan's controller.

signal conversation_started(npc_id: String)
signal conversation_finished(npc_id: String)
signal banner_requested(text: String)
signal travel_requested(x: float, banner: String)

@export var dialogue_path: String = "res://resources/dialogue/gus.json"
@export var texture_path: String = "res://assets/characters/npcs/vagrant_man.png"
@export var height_px: float = 122.0
@export var art_faces_right: bool = true   ## which way the source artwork looks
@export var auto_face: bool = true         ## turn to face Ethan, whichever side he is on
@export var bark_range: float = 650.0
@export var prompt_range: float = 260.0
@export var talk_range: float = 170.0
@export var talk_max_speed: float = 70.0     ## Ethan must be this slow to start a conversation
@export var linger_time: float = 0.35
@export var bark_cooldown: float = 12.0

var npc_id := "npc"
var display_name := "Stranger"
var data: Dictionary = {}
var conversation: Dictionary = {}            ## the conversation currently being played
var dialogue: DialogueBox
var player: Node2D
var sprite: Sprite2D
var _bubble: Label
var _bubble_time := 0.0
var _bark_cd := 0.0
var _linger := 0.0
var _talking := false
var _pending: Dictionary = {}                ## effects/outputs to act on once the dialogue closes
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
		sprite.scale = Vector2(sc, sc)
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
	dialogue.choice_made.connect(_on_choice_made)

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
		var dir := 1.0                                       # 1 = keep the artwork as drawn
		if auto_face and player != null and is_instance_valid(player):
			var player_right := player.global_position.x > global_position.x
			dir = 1.0 if (player_right == art_faces_right) else -1.0
		sprite.scale = Vector2(sc * dir, sc * br)
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
	var raw_speed: float = player.get("speed") if player.get("speed") != null else 0.0
	var speed := absf(raw_speed)                              # reversing counts as moving too
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

## First conversation whose "when" condition matches the current game state.
func pick_conversation() -> Dictionary:
	var list: Array = data.get("conversations", [])
	for c: Variant in list:
		var conv: Dictionary = c
		if DialogueEffects.matches(npc_id, conv.get("when", {})):
			return conv
	return {}

func start_conversation() -> void:
	if _talking or dialogue == null:
		return
	conversation = pick_conversation()
	if conversation.is_empty():
		return
	_talking = true
	_pending = {}
	_bubble.visible = false
	if player != null and "controls_enabled" in player:
		player.controls_enabled = false
	dialogue.open(display_name, _build_lines(conversation.get("lines", [])), portrait())
	conversation_started.emit(npc_id)

## Turns JSON lines into dialogue entries: plain strings, {speaker, text}, or {choice: [...]}.
## Speaker "ethan" uses Ethan's name and portrait; anyone else is this NPC.
func _build_lines(raw: Array) -> Array:
	var out: Array = []
	for item: Variant in raw:
		if item is Dictionary:
			var d: Dictionary = item
			if d.has("choice"):
				var options: Array = []
				for o: Variant in d["choice"]:
					var opt: Dictionary = (o as Dictionary).duplicate()
					var ok := DialogueEffects.requirements_met(opt.get("requires", {}))
					opt["enabled"] = ok
					if not ok and opt.has("need_text"):
						opt["suffix"] = String(opt["need_text"])
					elif ok and opt.has("cost_text"):
						opt["suffix"] = String(opt["cost_text"])
					options.append(opt)
				out.append({"name": "Ethan", "text": String(d.get("text", "")), "portrait": _ethan_portrait(), "choices": options})
				continue
			var who := String(d.get("speaker", npc_id))
			if who == "ethan":
				out.append({"name": "Ethan", "text": String(d.get("text", "")), "portrait": _ethan_portrait()})
			else:
				out.append({"name": display_name, "text": String(d.get("text", "")), "portrait": portrait()})
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
	at.region = Rect2(used.position.x, used.position.y, used.size.x, used.size.y * 0.55)
	return at

func _on_choice_made(choice_id: String) -> void:
	if not _talking:
		return
	var branches: Dictionary = conversation.get("branches", {})
	var branch: Dictionary = branches.get(choice_id, {})
	if branch.is_empty():
		return
	_merge_outputs(DialogueEffects.apply(npc_id, branch.get("effects", {})))
	dialogue.insert_lines(_build_lines(branch.get("lines", [])))

func _merge_outputs(out: Dictionary) -> void:
	if out.has("banner"):
		_pending["banner"] = out["banner"]
	if out.has("travel"):
		_pending["travel"] = out["travel"]

func _on_dialogue_finished() -> void:
	if not _talking:
		return
	if conversation.has("effects"):
		_merge_outputs(DialogueEffects.apply(npc_id, conversation["effects"]))
	_talking = false
	_linger = -2.0          # give Ethan a moment to roll away before another chat can start
	_bark_cd = bark_cooldown
	if player != null and "controls_enabled" in player:
		player.controls_enabled = true
	conversation_finished.emit(npc_id)
	var travel: Dictionary = _pending.get("travel", {})
	if _pending.has("banner"):
		banner_requested.emit(String(_pending["banner"]))
	if not travel.is_empty():
		travel_requested.emit(float(travel.get("x", 0.0)), String(travel.get("banner", "")))
	_pending = {}
