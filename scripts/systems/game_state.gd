extends Node
## Persistent, engine-node-agnostic game state (autoload "GameState").
## Deliberately knows nothing about CharacterBody2D so a future
## CharacterBody3D controller can share the same data.

signal score_changed(score: int)
signal stat_changed(stat_name: String, value: float)

const SAVE_PATH := "user://savegame.json"
const BACKPACK_SLOTS := 6

var score: int = 0
var health: float = 100.0
var energy: float = 100.0
var mental_wellbeing: float = 100.0
var reputation: int = 0
var money: int = 20
var street_cred: int = 0
var gangsta_cred: int = 0
var moral_cred: int = 0
var followers: int = 0
var backpack: Array[String] = []
var relationships: Dictionary = {}  # npc_id -> int
var missions: Dictionary = {}       # mission_id -> state String

func _ready() -> void:
	InputSetup.ensure_actions()

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

func reset_run() -> void:
	score = 0
	score_changed.emit(score)

func add_to_backpack(item_id: String) -> bool:
	if backpack.size() >= BACKPACK_SLOTS:
		return false
	backpack.append(item_id)
	stat_changed.emit("backpack", float(backpack.size()))
	return true

func has_item(item_id: String) -> bool:
	return backpack.has(item_id)

func remove_item(item_id: String) -> bool:
	var i := backpack.find(item_id)
	if i < 0:
		return false
	backpack.remove_at(i)
	stat_changed.emit("backpack", float(backpack.size()))
	return true

func add_money(amount: int) -> void:
	money += amount
	stat_changed.emit("money", float(money))

## kind: "street", "gangsta" or "moral"
func add_cred(kind: String, amount: int) -> void:
	match kind:
		"street": street_cred += amount
		"gangsta": gangsta_cred += amount
		"moral": moral_cred += amount
		_: return
	stat_changed.emit(kind + "_cred", 0.0)

func mission_state(mission_id: String) -> String:
	return String(missions.get(mission_id, "none"))

func set_mission(mission_id: String, state: String) -> void:
	missions[mission_id] = state
	stat_changed.emit("mission", 0.0)

func set_stat(stat_name: String, value: float) -> void:
	set(stat_name, value)
	stat_changed.emit(stat_name, value)

func to_dict() -> Dictionary:
	return {
		"score": score, "health": health, "energy": energy,
		"mental_wellbeing": mental_wellbeing, "reputation": reputation,
		"followers": followers, "backpack": backpack, "money": money,
		"street_cred": street_cred, "gangsta_cred": gangsta_cred, "moral_cred": moral_cred,
		"relationships": relationships, "missions": missions,
	}

func from_dict(d: Dictionary) -> void:
	score = int(d.get("score", 0))
	health = float(d.get("health", 100.0))
	energy = float(d.get("energy", 100.0))
	mental_wellbeing = float(d.get("mental_wellbeing", 100.0))
	reputation = int(d.get("reputation", 0))
	followers = int(d.get("followers", 0))
	money = int(d.get("money", 20))
	street_cred = int(d.get("street_cred", 0))
	gangsta_cred = int(d.get("gangsta_cred", 0))
	moral_cred = int(d.get("moral_cred", 0))
	backpack.assign(d.get("backpack", []))
	relationships = d.get("relationships", {})
	missions = d.get("missions", {})

func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		from_dict(parsed)
		return true
	return false
