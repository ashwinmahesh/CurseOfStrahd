class_name PadGlyphs
extends RefCounted
## The pad's button pictures and names (U6, docs/ui/controller.md): Kenney's Input Prompts (CC0,
## art/sourced/kenney_input_prompts) for the Xbox, PlayStation and Nintendo layouts. A button is named by its place on
## the pad, as Godot names it (the Xbox layout): "a" is the bottom face button, which is Cross on a PlayStation pad and
## B on a Nintendo one. Settings' "Button icons" can fix the family; otherwise it follows the pad in use
## (PadNav.family).

const DIR := "res://art/sourced/kenney_input_prompts/"
const FAMILIES: Array[String] = ["xbox", "playstation", "nintendo"]

## Each family's picture per button place (paths under DIR).
const FILES := {
	"xbox": {
		"a": "Xbox Series/Default/xbox_button_a.png", "b": "Xbox Series/Default/xbox_button_b.png",
		"x": "Xbox Series/Default/xbox_button_x.png", "y": "Xbox Series/Default/xbox_button_y.png",
		"lb": "Xbox Series/Default/xbox_lb.png", "rb": "Xbox Series/Default/xbox_rb.png",
		"lt": "Xbox Series/Default/xbox_lt.png", "rt": "Xbox Series/Default/xbox_rt.png",
		"ls": "Xbox Series/Default/xbox_ls.png", "rs": "Xbox Series/Default/xbox_rs.png",
		"start": "Xbox Series/Default/xbox_button_menu.png", "back": "Xbox Series/Default/xbox_button_view.png",
		"stick_l": "Xbox Series/Default/xbox_stick_l.png", "stick_r": "Xbox Series/Default/xbox_stick_r.png",
		"stick_r_horizontal": "Xbox Series/Default/xbox_stick_r_horizontal.png",
		"stick_r_vertical": "Xbox Series/Default/xbox_stick_r_vertical.png",
		"dpad": "Xbox Series/Default/xbox_dpad.png",
		"dpad_up": "Xbox Series/Default/xbox_dpad_up.png", "dpad_down": "Xbox Series/Default/xbox_dpad_down.png",
		"dpad_left": "Xbox Series/Default/xbox_dpad_left.png", "dpad_right": "Xbox Series/Default/xbox_dpad_right.png",
		"dpad_horizontal": "Xbox Series/Default/xbox_dpad_horizontal.png",
		"dpad_vertical": "Xbox Series/Default/xbox_dpad_vertical.png",
	},
	"playstation": {
		"a": "PlayStation Series/Default/playstation_button_cross.png",
		"b": "PlayStation Series/Default/playstation_button_circle.png",
		"x": "PlayStation Series/Default/playstation_button_square.png",
		"y": "PlayStation Series/Default/playstation_button_triangle.png",
		"lb": "PlayStation Series/Default/playstation_trigger_l1.png",
		"rb": "PlayStation Series/Default/playstation_trigger_r1.png",
		"lt": "PlayStation Series/Default/playstation_trigger_l2.png",
		"rt": "PlayStation Series/Default/playstation_trigger_r2.png",
		"ls": "PlayStation Series/Default/playstation_button_l3.png",
		"rs": "PlayStation Series/Default/playstation_button_r3.png",
		"start": "PlayStation Series/Default/playstation5_button_options.png",
		"back": "PlayStation Series/Default/playstation5_button_create.png",
		"stick_l": "PlayStation Series/Default/playstation_stick_l.png",
		"stick_r": "PlayStation Series/Default/playstation_stick_r.png",
		"stick_r_horizontal": "PlayStation Series/Default/playstation_stick_r_horizontal.png",
		"stick_r_vertical": "PlayStation Series/Default/playstation_stick_r_vertical.png",
		"dpad": "PlayStation Series/Default/playstation_dpad.png",
		"dpad_up": "PlayStation Series/Default/playstation_dpad_up.png",
		"dpad_down": "PlayStation Series/Default/playstation_dpad_down.png",
		"dpad_left": "PlayStation Series/Default/playstation_dpad_left.png",
		"dpad_right": "PlayStation Series/Default/playstation_dpad_right.png",
		"dpad_horizontal": "PlayStation Series/Default/playstation_dpad_horizontal.png",
		"dpad_vertical": "PlayStation Series/Default/playstation_dpad_vertical.png",
	},
	"nintendo": {
		# Nintendo's letters sit the other way round: the bottom button is B and the right one A.
		"a": "Nintendo Switch/Default/switch_button_b.png", "b": "Nintendo Switch/Default/switch_button_a.png",
		"x": "Nintendo Switch/Default/switch_button_y.png", "y": "Nintendo Switch/Default/switch_button_x.png",
		"lb": "Nintendo Switch/Default/switch_button_l.png", "rb": "Nintendo Switch/Default/switch_button_r.png",
		"lt": "Nintendo Switch/Default/switch_button_zl.png", "rt": "Nintendo Switch/Default/switch_button_zr.png",
		"ls": "Nintendo Switch/Default/switch_stick_l_press.png", "rs": "Nintendo Switch/Default/switch_stick_r_press.png",
		"start": "Nintendo Switch/Default/switch_button_plus.png",
		"back": "Nintendo Switch/Default/switch_button_minus.png",
		"stick_l": "Nintendo Switch/Default/switch_stick_l.png", "stick_r": "Nintendo Switch/Default/switch_stick_r.png",
		"stick_r_horizontal": "Nintendo Switch/Default/switch_stick_r_horizontal.png",
		"stick_r_vertical": "Nintendo Switch/Default/switch_stick_r_vertical.png",
		"dpad": "Nintendo Switch/Default/switch_dpad.png",
		"dpad_up": "Nintendo Switch/Default/switch_dpad_up.png", "dpad_down": "Nintendo Switch/Default/switch_dpad_down.png",
		"dpad_left": "Nintendo Switch/Default/switch_dpad_left.png",
		"dpad_right": "Nintendo Switch/Default/switch_dpad_right.png",
		"dpad_horizontal": "Nintendo Switch/Default/switch_dpad_horizontal.png",
		"dpad_vertical": "Nintendo Switch/Default/switch_dpad_vertical.png",
	},
}

## Each family's name for a button, for plain text.
const NAMES := {
	"xbox": {"a": "A", "b": "B", "x": "X", "y": "Y", "lb": "LB", "rb": "RB", "lt": "LT", "rt": "RT", "ls": "L3",
		"rs": "R3", "start": "Menu", "back": "View", "stick_l": "Left stick", "stick_r": "Right stick",
		"dpad": "D-pad", "dpad_up": "D-pad up", "dpad_down": "D-pad down", "dpad_left": "D-pad left",
		"dpad_right": "D-pad right"},
	"playstation": {"a": "Cross", "b": "Circle", "x": "Square", "y": "Triangle", "lb": "L1", "rb": "R1", "lt": "L2",
		"rt": "R2", "ls": "L3", "rs": "R3", "start": "Options", "back": "Create", "stick_l": "Left stick",
		"stick_r": "Right stick", "dpad": "D-pad", "dpad_up": "D-pad up", "dpad_down": "D-pad down",
		"dpad_left": "D-pad left", "dpad_right": "D-pad right"},
	"nintendo": {"a": "B", "b": "A", "x": "Y", "y": "X", "lb": "L", "rb": "R", "lt": "ZL", "rt": "ZR", "ls": "L3",
		"rs": "R3", "start": "+", "back": "−", "stick_l": "Left stick", "stick_r": "Right stick", "dpad": "D-pad",
		"dpad_up": "D-pad up", "dpad_down": "D-pad down", "dpad_left": "D-pad left", "dpad_right": "D-pad right"},
}

const BUTTONS := {
	JOY_BUTTON_A: "a", JOY_BUTTON_B: "b", JOY_BUTTON_X: "x", JOY_BUTTON_Y: "y", JOY_BUTTON_BACK: "back",
	JOY_BUTTON_START: "start", JOY_BUTTON_LEFT_STICK: "ls", JOY_BUTTON_RIGHT_STICK: "rs",
	JOY_BUTTON_LEFT_SHOULDER: "lb", JOY_BUTTON_RIGHT_SHOULDER: "rb", JOY_BUTTON_DPAD_UP: "dpad_up",
	JOY_BUTTON_DPAD_DOWN: "dpad_down", JOY_BUTTON_DPAD_LEFT: "dpad_left", JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}

static var _cache: Dictionary = {}


## The family whose pictures show: Settings' choice, else the pad in use.
static func family() -> String:
	var forced := str(GameSettings.value("pad_icons", "auto"))
	if forced in FAMILIES:
		return forced
	return PadNav.current.family if PadNav.current != null else "xbox"


## A button place for a pad event: "a", "lb", "dpad_up", "lt", "stick_l" ...; "" for anything else.
static func place_of(ev: InputEvent) -> String:
	var jb := ev as InputEventJoypadButton
	if jb != null:
		return str(BUTTONS.get(jb.button_index, ""))
	var jm := ev as InputEventJoypadMotion
	if jm != null:
		match jm.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "lt"
			JOY_AXIS_TRIGGER_RIGHT:
				return "rt"
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "stick_l"
			JOY_AXIS_RIGHT_X:
				return "stick_r_horizontal"
			JOY_AXIS_RIGHT_Y:
				return "stick_r_vertical"
	return ""


## The place of the first pad button or axis bound to `action`, or "".
static func place_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		var p := place_of(ev)
		if p != "":
			return p
	return ""


## The picture of button place `place` (in `fam`, else the family showing), or null.
static func texture(place: String, fam: String = "") -> Texture2D:
	var f := fam if fam != "" else family()
	var rel := str((FILES.get(f, {}) as Dictionary).get(place, ""))
	if rel == "":
		return null
	if not _cache.has(rel):
		_cache[rel] = load(DIR + rel) as Texture2D
	return _cache[rel] as Texture2D


## The name of button place `place` in plain text ("A", "Cross", "B" on a Nintendo pad).
static func name_of(place: String, fam: String = "") -> String:
	var f := fam if fam != "" else family()
	return str((NAMES.get(f, {}) as Dictionary).get(place, place.capitalize()))


## BBCode for a RichTextLabel: the button's picture at `size` pixels, tinted like the text.
static func bbcode(place: String, size: int = 22) -> String:
	var rel := str((FILES.get(family(), {}) as Dictionary).get(place, ""))
	if rel == "":
		return "[b]%s[/b]" % name_of(place)
	return "[img=%dx%d]%s[/img]" % [size, size, DIR + rel]


# --- Words that name keys or buttons --------------------------------------------------------------

## Labels (or any object's text property) that name keys on the keyboard and buttons on a pad: [WeakRef, keys, pad,
## property]. PadNav redraws them when the device or the pad's family changes.
static var _hints: Array = []


## `keys` while the mouse and keyboard are in use, else `pad` with {a}, {b}, {x}, {y}, {lb}, {rb}, {lt}, {rt}, {ls},
## {rs}, {start} and {back} as the pad family's names for those buttons ("{b}: close" reads "Circle: close" on a
## PlayStation pad).
static func words(keys: String, pad: String) -> String:
	return names(pad) if PadNav.active() else keys


## `text` with {a}, {b} ... as the pad family's names for those buttons, whatever the device (a controls card's
## controller line).
static func names(text: String) -> String:
	var out := text
	for place: String in ["a", "b", "x", "y", "lb", "rb", "lt", "rt", "ls", "rs", "start", "back"]:
		out = out.replace("{%s}" % place, name_of(place))
	return out


## Shows words(keys, pad) on `o` now and whenever the device changes, for as long as `o` lives.
static func hint(o: Object, keys: String, pad: String, property: StringName = &"text") -> void:
	_hints.append([weakref(o), keys, pad, property])
	o.set(property, words(keys, pad))


static func refresh_hints() -> void:
	for i in range(_hints.size() - 1, -1, -1):
		var h := _hints[i] as Array
		var o: Object = (h[0] as WeakRef).get_ref()
		if o == null:
			_hints.remove_at(i)
			continue
		o.set(h[3] as StringName, words(str(h[1]), str(h[2])))
