class_name InputActions
extends RefCounted
## Registers the game's input actions in code so every agent sees them in one place.
## Keyboard and mouse for now; controller bindings come with the accessibility pass (plan §13 Q5).

const BINDINGS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"camera_rotate_left": [KEY_Q],
	&"camera_rotate_right": [KEY_E],
	&"cycle_leader": [KEY_TAB],
	&"select_member_1": [KEY_1],
	&"select_member_2": [KEY_2],
	&"select_member_3": [KEY_3],
	&"select_member_4": [KEY_4],
	&"quick_save": [KEY_F5],
	&"quick_load": [KEY_F9],
	&"toggle_palette": [KEY_P],
}


static func ensure() -> void:
	for action: StringName in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
