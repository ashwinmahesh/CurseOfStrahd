class_name Cursors
extends RefCounted
## The game's mouse cursors (docs/plans/ui_polish.md, art from tools/art/build_cursors.gd): a gilt pointer, and what
## the mouse is over in the world shown by the cursor itself: a gauntlet to use something, a speech scroll to talk,
## crossed swords to attack, a padlock for what's locked, a magnifying glass to look. They take the place of system
## shapes, so a button that asks for the pointing hand gets the gauntlet too.

## Our cursor -> [the system shape it stands in for, its hotspot at 48 px].
const SLOTS := {
	"pointer": [Input.CURSOR_ARROW, Vector2(4, 3)],
	"use": [Input.CURSOR_POINTING_HAND, Vector2(14, 10)],
	"talk": [Input.CURSOR_HELP, Vector2(24, 24)],
	"attack": [Input.CURSOR_CROSS, Vector2(24, 24)],
	"locked": [Input.CURSOR_FORBIDDEN, Vector2(24, 24)],
	"walk": [Input.CURSOR_MOVE, Vector2(24, 24)],
	"look": [Input.CURSOR_CAN_DROP, Vector2(18, 18)],
}

static var _installed := false
static var _current := "pointer"


## Sets the cursors once (no window in a headless run, so nothing to set there).
static func install() -> void:
	if _installed or DisplayServer.get_name() == "headless":
		return
	_installed = true
	for name: String in SLOTS:
		var path := "res://art/ui/cursors/%s.png" % name
		if ResourceLoader.exists(path):
			var slot := SLOTS[name] as Array
			Input.set_custom_mouse_cursor(load(path) as Texture2D, int(slot[0]) as Input.CursorShape, slot[1] as Vector2)


## Hands the system shapes back (the scene that installed them is leaving): the cursors' textures can't outlive the
## renderer at exit. The next scene installs them again.
static func uninstall() -> void:
	if not _installed:
		return
	_installed = false
	_current = "pointer"
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	for name: String in SLOTS:
		Input.set_custom_mouse_cursor(null, int((SLOTS[name] as Array)[0]) as Input.CursorShape)


## The cursor over the world (where no control asks for its own): one of SLOTS' names.
static func show(name: String) -> void:
	if name == _current or not SLOTS.has(name):
		return
	_current = name
	Input.set_default_cursor_shape(int((SLOTS[name] as Array)[0]) as Input.CursorShape)


## Which cursor a thing in the world gets (LocationView.thing_at): talk to people, a padlock on what's locked, a lens
## on what's only to look at, the gauntlet for the rest; the pointer for the floor and the party.
static func for_thing(thing: Dictionary) -> String:
	if thing.is_empty():
		return "pointer"
	var label := str(thing.get("label", ""))
	match str(thing["kind"]):
		"npc":
			return "talk"
		"door", "container":
			return "locked" if label.ends_with("(locked)") else "use"
		"prop":
			return "look" if label.begins_with("Look at") or label.begins_with("Examine") or label.begins_with("Read") else "use"
	return "use"
