class_name GameStateAccess
extends RefCounted
## Small helper so gameplay scripts can talk to the GameState autoload without depending on its
## global name (autoload identifiers are not available to scripts run with --script in tests).

static func _gs() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameState") if tree != null else null

static func has_met(npc_id: String) -> bool:
	var gs := _gs()
	return gs != null and int(gs.relationships.get(npc_id, 0)) > 0

static func meet(npc_id: String) -> void:
	var gs := _gs()
	if gs != null:
		gs.relationships[npc_id] = int(gs.relationships.get(npc_id, 0)) + 1

static func money() -> int:
	var gs := _gs()
	return int(gs.money) if gs != null else 0

static func add_money(amount: int) -> void:
	var gs := _gs()
	if gs != null:
		gs.add_money(amount)

static func add_cred(kind: String, amount: int) -> void:
	var gs := _gs()
	if gs != null:
		gs.add_cred(kind, amount)

static func mission_state(mission_id: String) -> String:
	var gs := _gs()
	return String(gs.mission_state(mission_id)) if gs != null else "none"

static func set_mission(mission_id: String, state: String) -> void:
	var gs := _gs()
	if gs != null:
		gs.set_mission(mission_id, state)

static func has_item(item_id: String) -> bool:
	var gs := _gs()
	return gs != null and gs.has_item(item_id)

static func give_item(item_id: String) -> bool:
	var gs := _gs()
	return gs != null and gs.add_to_backpack(item_id)

static func take_item(item_id: String) -> bool:
	var gs := _gs()
	return gs != null and gs.remove_item(item_id)
