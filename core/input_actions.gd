class_name InputActions
extends RefCounted
## Registers the game's input actions in code so every agent sees them in one place.
## Keyboard and mouse everywhere; the controller for combat (plan §5.3 acceptance: playable with the controller
## only). The full controller pass comes with accessibility (plan §13 Q5).

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
	# Combat (docs/ui/combat_view.md).
	&"combat_end_turn": [KEY_SPACE],
	&"combat_cancel": [KEY_ESCAPE],
	&"combat_confirm": [KEY_ENTER, KEY_KP_ENTER],
	&"combat_tab_prev": [KEY_Z],
	&"combat_tab_next": [KEY_X],
	&"combat_slot_level_down": [KEY_BRACKETLEFT],
	&"combat_slot_level_up": [KEY_BRACKETRIGHT],
	&"combat_next_target": [KEY_T],
	&"combat_slot_1": [KEY_1],
	&"combat_slot_2": [KEY_2],
	&"combat_slot_3": [KEY_3],
	&"combat_slot_4": [KEY_4],
	&"combat_slot_5": [KEY_5],
	&"combat_slot_6": [KEY_6],
	&"combat_slot_7": [KEY_7],
	&"combat_slot_8": [KEY_8],
	&"combat_slot_9": [KEY_9],
	&"combat_slot_10": [KEY_0],
}

## Controller buttons (Xbox layout names; Godot maps other pads to the same positions).
const PAD_BUTTONS := {
	&"combat_confirm": [JOY_BUTTON_A],
	&"combat_cancel": [JOY_BUTTON_B],
	&"combat_next_target": [JOY_BUTTON_X],
	&"combat_end_turn": [JOY_BUTTON_Y],
	&"combat_radial": [JOY_BUTTON_LEFT_SHOULDER],
	&"combat_use_slot": [JOY_BUTTON_RIGHT_SHOULDER],
	&"combat_slot_level_down": [JOY_BUTTON_DPAD_LEFT],
	&"combat_slot_level_up": [JOY_BUTTON_DPAD_RIGHT],
	&"camera_rotate_left": [JOY_BUTTON_LEFT_STICK],
	&"camera_rotate_right": [JOY_BUTTON_RIGHT_STICK],
	&"cycle_leader": [JOY_BUTTON_BACK],
}

## Controller triggers and sticks: action -> [axis, direction].
const PAD_AXES := {
	&"combat_slot_prev": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	&"combat_slot_next": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	&"cursor_left": [JOY_AXIS_LEFT_X, -1.0],
	&"cursor_right": [JOY_AXIS_LEFT_X, 1.0],
	&"cursor_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"cursor_down": [JOY_AXIS_LEFT_Y, 1.0],
}


static func ensure() -> void:
	for action: StringName in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key: int in BINDINGS[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key as Key
				InputMap.action_add_event(action, ev)
	for action: StringName in PAD_BUTTONS:
		var fresh := not InputMap.has_action(action)
		if fresh:
			InputMap.add_action(action)
		for b: int in PAD_BUTTONS[action]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = b as JoyButton
			if not InputMap.action_has_event(action, jb):
				InputMap.action_add_event(action, jb)
	for action: StringName in PAD_AXES:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.5)
		var spec := PAD_AXES[action] as Array
		var jm := InputEventJoypadMotion.new()
		jm.axis = int(spec[0]) as JoyAxis
		jm.axis_value = float(spec[1])
		InputMap.action_add_event(action, jm)
