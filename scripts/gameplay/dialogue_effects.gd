class_name DialogueEffects
extends RefCounted
## Conditions ("when") and effects used by dialogue JSON files. Keeps story logic out of the controller
## and out of the UI. See docs/npcs_and_dialogue.md for the full list.

## when: {"mission": "id", "is": "state" | ["a","b"], "has_item": "x", "not_has_item": "x", "met": bool}
static func matches(npc_id: String, when: Dictionary) -> bool:
	if when.has("mission"):
		var state: String = GameStateAccess.mission_state(String(when["mission"]))
		var wanted: Variant = when.get("is", "none")
		if wanted is Array:
			if not (wanted as Array).has(state):
				return false
		elif String(wanted) != state:
			return false
	if when.has("has_item") and not GameStateAccess.has_item(String(when["has_item"])):
		return false
	if when.has("not_has_item") and GameStateAccess.has_item(String(when["not_has_item"])):
		return false
	if when.has("met") and bool(when["met"]) != GameStateAccess.has_met(npc_id):
		return false
	return true

## requires: {"money": 5, "item": "hot_dog"}  -> can the player pick this option?
static func requirements_met(requires: Dictionary) -> bool:
	if requires.has("money") and GameStateAccess.money() < int(requires["money"]):
		return false
	if requires.has("item") and not GameStateAccess.has_item(String(requires["item"])):
		return false
	return true

## effects: {"cred": {"street": 5}, "money": -5, "mission": {"id": "state"}, "give_item": "x",
##           "take_item": "x", "meet": true, "banner": "text", "travel": {"x": 300}}
## Returns things the level must act on: {"banner": String, "travel": Dictionary}.
static func apply(npc_id: String, effects: Dictionary) -> Dictionary:
	var out := {}
	var cred: Dictionary = effects.get("cred", {})
	for kind: String in cred:
		GameStateAccess.add_cred(kind, int(cred[kind]))
	if effects.has("money"):
		GameStateAccess.add_money(int(effects["money"]))
	var missions: Dictionary = effects.get("mission", {})
	for mission_id: String in missions:
		GameStateAccess.set_mission(mission_id, String(missions[mission_id]))
	if effects.has("give_item"):
		GameStateAccess.give_item(String(effects["give_item"]))
	if effects.has("take_item"):
		GameStateAccess.take_item(String(effects["take_item"]))
	if bool(effects.get("meet", false)):
		GameStateAccess.meet(npc_id)
	if effects.has("banner"):
		out["banner"] = String(effects["banner"])
	if effects.has("travel"):
		out["travel"] = effects["travel"]
	return out
