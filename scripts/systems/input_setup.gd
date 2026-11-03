class_name InputSetup
extends RefCounted
## Registers the game's input actions in code so bindings are diff-able and
## testable. Idempotent: safe to call from several places.

const BINDINGS := {
	"push": [KEY_D, KEY_RIGHT],
	"brake": [KEY_A, KEY_LEFT],
	"crouch": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"drift": [KEY_SHIFT],
	"reset": [KEY_R],
}

static func ensure_actions() -> void:
	for action: String in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
			for keycode: int in BINDINGS[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = keycode as Key
				InputMap.action_add_event(action, ev)
