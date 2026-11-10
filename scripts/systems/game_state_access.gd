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

static func meet(npc_id: String, reputation_gain: int) -> void:
	var gs := _gs()
	if gs == null:
		return
	gs.relationships[npc_id] = int(gs.relationships.get(npc_id, 0)) + 1
	gs.reputation += reputation_gain
	gs.stat_changed.emit("reputation", float(gs.reputation))
