class_name InputActions
extends RefCounted
## Registers the game's input actions in code so every agent sees them in one place, with the player's own keys laid
## over the defaults (Settings, Keys: Improvement Ideas U5; kept in user://settings.cfg as "keys", action -> keys, only
## where they differ). Keyboard and mouse everywhere; the controller for combat (plan §5.3 acceptance: playable with
## the controller only). The full controller pass comes with accessibility (plan §13 Q5).
## Escape (menus, back, cancel) and F1 (the controls card) can't be changed, so there's always a way back.

## The default keys: the first is an action's key, the second its alternate.
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
	# Exploring (world/game_root.gd reads these through as_default).
	&"open_sheet": [KEY_C],
	&"open_inventory": [KEY_I],
	&"open_journal": [KEY_J],
	&"open_party": [KEY_P],
	&"open_map": [KEY_M],
	&"rest": [KEY_R],
	&"wait": [KEY_H],
	&"search": [KEY_F],
	&"sneak": [KEY_V],
	&"split": [KEY_G],
	&"show_names": [KEY_ALT],
	&"plan_mode": [KEY_T],
	&"plan_round": [KEY_SPACE],
	# Hold to see what each foe in plain view can see (U10; always shown while sneaking).
	&"show_sight": [KEY_L],
	# Combat (docs/ui/combat_view.md).
	&"combat_end_turn": [KEY_SPACE],
	&"combat_cancel": [KEY_ESCAPE],
	&"combat_confirm": [KEY_ENTER, KEY_KP_ENTER],
	&"combat_tab_prev": [KEY_Z],
	&"combat_tab_next": [KEY_X],
	&"combat_slot_level_down": [KEY_BRACKETLEFT],
	&"combat_slot_level_up": [KEY_BRACKETRIGHT],
	&"combat_next_target": [KEY_T],
	&"combat_toggle_log": [KEY_L],
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

## The keys the player can change, in the Keys page's order: [action, what it does, list]. Two commands of one list
## can't share a key; "both" commands (walking, the camera, Tab) work in either mode, so they clash with every list.
const COMMANDS := [
	[&"move_forward", "Walk forward", "both"],
	[&"move_back", "Walk back", "both"],
	[&"move_left", "Walk left", "both"],
	[&"move_right", "Walk right", "both"],
	[&"camera_rotate_left", "Turn the camera left", "both"],
	[&"camera_rotate_right", "Turn the camera right", "both"],
	[&"cycle_leader", "Next party member", "both"],
	[&"select_member_1", "Lead: first", "explore"],
	[&"select_member_2", "Lead: second", "explore"],
	[&"select_member_3", "Lead: third", "explore"],
	[&"select_member_4", "Lead: fourth", "explore"],
	[&"open_sheet", "Character", "explore"],
	[&"open_inventory", "Inventory", "explore"],
	[&"open_journal", "Journal", "explore"],
	[&"open_party", "Party", "explore"],
	[&"open_map", "Map", "explore"],
	[&"rest", "Rest", "explore"],
	[&"wait", "Wait some hours", "explore"],
	[&"search", "Search", "explore"],
	[&"sneak", "Sneak", "explore"],
	[&"split", "Split the party", "explore"],
	[&"show_names", "Show names (hold)", "explore"],
	[&"show_sight", "Show what foes see (hold)", "explore"],
	[&"plan_mode", "Turn-based exploring", "explore"],
	[&"plan_round", "End the round (turn-based)", "explore"],
	[&"quick_save", "Quicksave", "explore"],
	[&"quick_load", "Load the quicksave", "explore"],
	[&"combat_end_turn", "End the turn", "fight"],
	[&"combat_confirm", "Confirm", "fight"],
	[&"combat_next_target", "Next target", "fight"],
	[&"combat_tab_prev", "Previous hotbar tab", "fight"],
	[&"combat_tab_next", "Next hotbar tab", "fight"],
	[&"combat_slot_level_down", "Lower spell slot", "fight"],
	[&"combat_slot_level_up", "Higher spell slot", "fight"],
	[&"combat_toggle_log", "Combat log", "fight"],
	[&"combat_slot_1", "Hotbar slot 1", "fight"],
	[&"combat_slot_2", "Hotbar slot 2", "fight"],
	[&"combat_slot_3", "Hotbar slot 3", "fight"],
	[&"combat_slot_4", "Hotbar slot 4", "fight"],
	[&"combat_slot_5", "Hotbar slot 5", "fight"],
	[&"combat_slot_6", "Hotbar slot 6", "fight"],
	[&"combat_slot_7", "Hotbar slot 7", "fight"],
	[&"combat_slot_8", "Hotbar slot 8", "fight"],
	[&"combat_slot_9", "Hotbar slot 9", "fight"],
	[&"combat_slot_10", "Hotbar slot 10", "fight"],
]
const LISTS := {"both": "Walking and the camera", "explore": "Exploring", "fight": "Fights"}
## Keys that keep their job: Escape always goes back, F1 always shows the controls.
const FIXED: Array[int] = [KEY_ESCAPE, KEY_F1]

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
	# Exploration: the left stick walks the leader (the keys are in BINDINGS).
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_back": [JOY_AXIS_LEFT_Y, 1.0],
}

## Key names that read better as the mark on the key.
const KEY_NAMES := {KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]", KEY_ESCAPE: "Esc", KEY_KP_ENTER: "Num Enter",
	KEY_COMMA: ",", KEY_PERIOD: ".", KEY_SEMICOLON: ";", KEY_APOSTROPHE: "'", KEY_SLASH: "/", KEY_BACKSLASH: "\\",
	KEY_MINUS: "-", KEY_EQUAL: "=", KEY_QUOTELEFT: "`", KEY_PAGEUP: "Page Up", KEY_PAGEDOWN: "Page Down",
	KEY_CTRL: "Ctrl", KEY_META: "Cmd", KEY_CAPSLOCK: "Caps Lock", KEY_BACKSPACE: "Backspace"}

static var _keys_set := false


static func ensure() -> void:
	for action: StringName in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_keys_set = false
	if not _keys_set:
		apply()
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
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		var spec := PAD_AXES[action] as Array
		var jm := InputEventJoypadMotion.new()
		jm.axis = int(spec[0]) as JoyAxis
		jm.axis_value = float(spec[1])
		if not InputMap.action_has_event(action, jm):
			InputMap.action_add_event(action, jm)


## Puts each action's current keys in the InputMap (the controller's buttons and sticks stay).
static func apply() -> void:
	_keys_set = true
	for action: StringName in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		for key in keys(action):
			if key != KEY_NONE:
				var ev := InputEventKey.new()
				ev.physical_keycode = key as Key
				InputMap.action_add_event(action, ev)


# --- The player's keys ----------------------------------------------------------------------------

## An action's keys now: [key, alternate], KEY_NONE where there's none.
static func keys(action: StringName) -> Array[int]:
	var saved := GameSettings.value("keys", {}) as Dictionary
	var src := (saved[str(action)] if saved.has(str(action)) else BINDINGS.get(action, [])) as Array
	var out: Array[int] = [KEY_NONE, KEY_NONE]
	for i in mini(src.size(), 2):
		out[i] = int(src[i])
	return out


## Puts `key` on `action` as its key (slot 0) or alternate (slot 1). A command that clashes and had the key takes this
## one's old key in its place (a swap, so nothing is lost by accident). Returns a note of what moved, or why not.
static func bind(action: StringName, slot: int, key: int) -> String:
	if key in FIXED:
		return "Esc and F1 keep their jobs."
	var mine := keys(action)
	var old := mine[slot]
	if old == key:
		return ""
	var note := ""
	var other_slot := mine.find(key)
	if other_slot >= 0:
		mine[other_slot] = old   # its own key and alternate trade places
	else:
		for other: StringName in clashing(action):
			var theirs := keys(other)
			var at := theirs.find(key)
			if at < 0:
				continue
			theirs[at] = old
			_store(other, _tidy(theirs))
			var now := key_text(other)
			note = "%s was %s's; %s is now on %s." % [key_name(key), name_of(other), name_of(other), now] if now != "" \
				else "%s was %s's; %s has no key now." % [key_name(key), name_of(other), name_of(other)]
	mine[slot] = key
	_store(action, _tidy(mine))
	apply()
	return note


## Takes the key (slot 0) or alternate (slot 1) off `action`.
static func clear(action: StringName, slot: int) -> void:
	var mine := keys(action)
	mine[slot] = KEY_NONE
	_store(action, _tidy(mine))
	apply()


## Every key back to the game's own.
static func reset() -> void:
	GameSettings.set_value("keys", {})
	apply()


## Whether any key differs from the defaults.
static func changed() -> bool:
	return not (GameSettings.value("keys", {}) as Dictionary).is_empty()


## The commands `action` can't share a key with: those of its list, and "both" ones with everyone.
static func clashing(action: StringName) -> Array[StringName]:
	var mine := list_of(action)
	var out: Array[StringName] = []
	for c: Array in COMMANDS:
		var other := c[0] as StringName
		if other != action and (mine == "both" or str(c[2]) == "both" or str(c[2]) == mine):
			out.append(other)
	return out


static func list_of(action: StringName) -> String:
	for c: Array in COMMANDS:
		if c[0] == action:
			return str(c[2])
	return ""


static func name_of(action: StringName) -> String:
	for c: Array in COMMANDS:
		if c[0] == action:
			return str(c[1])
	return str(action).capitalize()


## A key left only as the alternate becomes the key.
static func _tidy(k: Array[int]) -> Array[int]:
	if k[0] == KEY_NONE and k[1] != KEY_NONE:
		return [k[1], KEY_NONE]
	return k


static func _store(action: StringName, k: Array[int]) -> void:
	var saved := (GameSettings.value("keys", {}) as Dictionary).duplicate()
	var defaults := keys_default(action)
	if k == defaults:
		saved.erase(str(action))
	else:
		saved[str(action)] = k.duplicate()
	GameSettings.set_value("keys", saved)


static func keys_default(action: StringName) -> Array[int]:
	var src := BINDINGS.get(action, []) as Array
	var out: Array[int] = [KEY_NONE, KEY_NONE]
	for i in mini(src.size(), 2):
		out[i] = int(src[i])
	return out


# --- What the screens show ------------------------------------------------------------------------

## A key as its mark reads ("C", "Space", "[", "F5"), or "" for none.
static func key_name(key: int) -> String:
	if key == KEY_NONE:
		return ""
	if KEY_NAMES.has(key):
		return str(KEY_NAMES[key])
	return OS.get_keycode_string(key as Key)


## The key (slot 0) or alternate (slot 1) of `action` as it reads, or "".
static func key_text(action: StringName, slot: int = 0) -> String:
	return key_name(keys(action)[slot])


## `text` with each {action} replaced by its key and {action:1} by its alternate ("{open_journal} journal" reads
## "J journal" until the player moves it). {walk} is the four walking keys, with the arrows if they're the alternates.
static func fill(text: String) -> String:
	var keys_now := PackedStringArray()
	var alts := PackedStringArray()
	for a: StringName in [&"move_forward", &"move_left", &"move_back", &"move_right"]:
		keys_now.append(key_text(a))
		alts.append(key_text(a, 1))
	var walk := " ".join(keys_now)
	if alts == PackedStringArray(["Up", "Left", "Down", "Right"]):
		walk += " or the arrows"
	elif not alts.has(""):
		walk += " or " + " ".join(alts)
	var out := text.replace("{walk}", walk)
	var re := RegEx.create_from_string("\\{([a-z_0-9]+)(?::([01]))?\\}")
	for m in re.search_all(text):
		var action := StringName(m.get_string(1))
		if BINDINGS.has(action):
			var shown := key_text(action, int(m.get_string(2)) if m.get_string(2) != "" else 0)
			out = out.replace(m.get_string(), shown if shown != "" else "(no key)")
	return out


## For code that matches keys by their defaults (world/game_root.gd's exploring keys): the default key of the
## command of `lists` that `ev` now triggers, KEY_NONE for a default key the player has moved elsewhere, and any
## other key as itself. So `match InputActions.as_default(ev): KEY_J: ...` opens the journal on the player's key.
static func as_default(ev: InputEventKey, lists: Array[String] = ["both", "explore"]) -> Key:
	var k := ev.physical_keycode
	var moved := false
	for c: Array in COMMANDS:
		if not str(c[2]) in lists:
			continue
		var action := c[0] as StringName
		var now := keys(action)
		var defaults := keys_default(action)
		var at := now.find(int(k))
		if at >= 0:
			return (defaults[at] if defaults[at] != KEY_NONE else defaults[0]) as Key
		if defaults.has(int(k)):
			moved = true
	return KEY_NONE if moved else k
