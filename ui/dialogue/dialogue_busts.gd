class_name DialogueBusts
extends Control
## The big dialogue art (Improvement Ideas G1; docs/ui/busts.md): half-body busts either side of the conversation box,
## the hero speaking for the party on the left and whoever they're talking to on the right, both behind the box. The one
## talking is lit and the other dims; each breathes slowly. A bust is art/busts/<portrait id>[_<mood>].webp, cut out of
## its background (tools/art/build_busts.py); anyone without one shows only their small portrait in the box. DialogueUI
## feeds it each line.
##
## The two face each other (owner, 2026-10-08): the left bust faces right and the right bust faces left, each mirrored
## when drawn the other way (data/busts/facing.json records which way each was drawn). A line's `[away]` cue turns a
## bust its back on the other side: the speaker's own, or on a Narrator line the one being spoken to (`[away:party]` the
## party's speaker). It holds through Narrator lines until that side speaks again.

const DIR := "res://art/busts/"
## A bust is this share of the screen's height, its feet at the bottom edge.
const HEIGHT_SHARE := 0.86
const DIM := Color(0.55, 0.55, 0.62)
## The slow breath: the bust grows this much and back over this long.
const BREATH := 0.012
const BREATH_SECONDS := 2.8
const FACING_FILE := "res://data/busts/facing.json"
const MOODS: Array[String] = ["smile", "angry", "afraid", "sad", "sly", "weary"]

static var _facing: Dictionary = {}
## False draws every bust as it was drawn, never mirrored: the "before" picture in captures (tools/capture/ui_capture.gd).
static var mirror := true

var left: TextureRect
var right: TextureRect
## The bust each side shows now (its path, "" for none).
var left_id := ""
var right_id := ""
## The side that is talking: "left", "right" or "" (the Narrator, or nobody yet).
var lit := ""
## Whether each side has turned its back on the other (the `[away]` cue).
var left_away := false
var right_away := false


func _init() -> void:
	name = "DialogueBusts"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	left = _side(true)
	right = _side(false)
	resized.connect(_layout)
	_layout()


## The bust for `art_id` in `mood` (its own picture for the mood, else its neutral one), or "".
static func path_for(art_id: String, mood: String = "") -> String:
	if art_id == "":
		return ""
	for id: String in ([art_id + "_" + mood] if mood != "" and mood != "neutral" else []) + [art_id]:
		if ResourceLoader.exists(DIR + id + ".webp"):
			return DIR + id + ".webp"
	return ""


## A line of the conversation: a party member's goes on the left and lights it, anyone else's on the right; the
## Narrator dims both. `party_art` is the art id of the hero speaking for the party, shown on the left meanwhile.
func line(beat: Dictionary, party_art: String) -> void:
	var away := str(beat.get("away", ""))
	if bool(beat.get("narrator", false)):
		# A Narrator line turns the one being spoken to (or, with away:party, the party's speaker); the turn holds.
		if away == "speaker":
			_turn(false, true)
		elif away == "party":
			_turn(true, true)
		_light("")
		return
	var mood := str(beat.get("mood", ""))
	var art := str(beat.get("portrait", ""))
	if mood != "" and art.ends_with("_" + mood):
		art = art.trim_suffix("_" + mood)
	if bool(beat.get("party", false)):
		_show_side(true, art, "")
		_turn(true, away != "")
		_light("left" if left_id != "" else "")
	else:
		if left_id == "":
			_show_side(true, party_art, "")
		_show_side(false, art, mood)
		_turn(false, away == "speaker")
		if away == "party":
			_turn(true, true)
		_light("right" if right_id != "" else "")


## Which way a bust (its path or file name) was drawn facing: "left" or "right" (data/busts/facing.json). A mood's bust
## faces as its person's does unless listed itself.
static func native_facing(path: String) -> String:
	if _facing.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FACING_FILE))
		_facing = (data as Dictionary).get("facing", {}) as Dictionary if data is Dictionary else {"": ""}
	var stem := path.get_file().get_basename()
	if _facing.has(stem):
		return str(_facing[stem])
	for mood in MOODS:
		if stem.ends_with("_" + mood) and _facing.has(stem.trim_suffix("_" + mood)):
			return str(_facing[stem.trim_suffix("_" + mood)])
	return "right"


## Whether a bust drawn as `path` is mirrored on its side: the left faces right and the right faces left, unless turned away.
static func mirrored(path: String, on_left: bool, away: bool) -> bool:
	var wanted := "right" if on_left != away else "left"
	return mirror and path != "" and native_facing(path) != wanted


## Turns a side away from the other (or back), mirroring its bust to match.
func _turn(on_left: bool, away: bool) -> void:
	if on_left:
		left_away = away
	else:
		right_away = away
	_face(on_left)


func _face(on_left: bool) -> void:
	var rect := left if on_left else right
	var flip := mirrored(left_id if on_left else right_id, on_left, left_away if on_left else right_away)
	if rect.flip_h != flip and rect.visible and UiMotion.on():
		rect.modulate.a = 0.4   # a quick turn: the bust dips and comes back facing the other way
		UiMotion.tween_for(rect).tween_property(rect, "modulate:a", 1.0, 0.2)
	rect.flip_h = flip


## Q13: the player picked another party member to speak; their bust takes the left side.
func party_speaker(art_id: String) -> void:
	_show_side(true, art_id, "")


func _show_side(on_left: bool, art_id: String, mood: String) -> void:
	var rect := left if on_left else right
	var path := path_for(art_id, mood)
	var key := path
	if key == (left_id if on_left else right_id):
		return
	# Someone new on a side faces the other side.
	if on_left:
		left_id = key
		left_away = false
	else:
		right_id = key
		right_away = false
	rect.texture = load(path) as Texture2D if path != "" else null
	rect.flip_h = mirrored(path, on_left, left_away if on_left else right_away)
	rect.visible = path != ""
	if path != "" and UiMotion.on():
		rect.modulate.a = 0.0
		UiMotion.tween_for(rect).tween_property(rect, "modulate:a", 1.0, 0.25)


func _light(side: String) -> void:
	lit = side
	for pair: Array in [[left, "left"], [right, "right"]]:
		var rect := pair[0] as TextureRect
		var to := Color.WHITE if side == str(pair[1]) else DIM
		if UiMotion.on():
			UiMotion.tween_for(rect).tween_property(rect, "self_modulate", to, 0.2)
		else:
			rect.self_modulate = to


func _side(on_left: bool) -> TextureRect:
	var t := TextureRect.new()
	t.name = "Left" if on_left else "Right"
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.visible = false
	add_child(t)
	if UiMotion.on():
		# A slow breath, the two sides out of step.
		var tw := UiMotion.tween_for(t).set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if not on_left:
			tw.tween_interval(BREATH_SECONDS / 2.0)
		tw.tween_property(t, "scale", Vector2(1.0, 1.0 + BREATH), BREATH_SECONDS / 2.0)
		tw.tween_property(t, "scale", Vector2.ONE, BREATH_SECONDS / 2.0)
	return t


func _layout() -> void:
	var h := size.y * HEIGHT_SHARE
	var w := h * 0.66
	for pair: Array in [[left, true], [right, false]]:
		var t := pair[0] as TextureRect
		t.size = Vector2(w, h)
		t.position = Vector2(-w * 0.04 if bool(pair[1]) else size.x - w * 0.96, size.y - h)
		t.pivot_offset = Vector2(w / 2.0, h)
