class_name DialogueBusts
extends Control
## The big dialogue art (Improvement Ideas G1; docs/ui/busts.md): half-body busts either side of the conversation box,
## the hero speaking for the party on the left and whoever they're talking to on the right, both behind the box. The one
## talking is lit and the other dims; each breathes slowly. A bust is art/busts/<portrait id>[_<mood>].webp, cut out of
## its background (tools/art/build_busts.py); anyone without one shows only their small portrait in the box. DialogueUI
## feeds it each line.

const DIR := "res://art/busts/"
## A bust is this share of the screen's height, its feet at the bottom edge.
const HEIGHT_SHARE := 0.86
const DIM := Color(0.55, 0.55, 0.62)
## The slow breath: the bust grows this much and back over this long.
const BREATH := 0.012
const BREATH_SECONDS := 2.8

var left: TextureRect
var right: TextureRect
## The bust each side shows now (its path, "" for none).
var left_id := ""
var right_id := ""
## The side that is talking: "left", "right" or "" (the Narrator, or nobody yet).
var lit := ""


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
	if bool(beat.get("narrator", false)):
		_light("")
		return
	var mood := str(beat.get("mood", ""))
	var art := str(beat.get("portrait", ""))
	if mood != "" and art.ends_with("_" + mood):
		art = art.trim_suffix("_" + mood)
	if bool(beat.get("party", false)):
		_show_side(true, art, "")
		_light("left" if left_id != "" else "")
	else:
		if left_id == "":
			_show_side(true, party_art, "")
		_show_side(false, art, mood)
		_light("right" if right_id != "" else "")


## Q13: the player picked another party member to speak; their bust takes the left side.
func party_speaker(art_id: String) -> void:
	_show_side(true, art_id, "")


func _show_side(on_left: bool, art_id: String, mood: String) -> void:
	var rect := left if on_left else right
	var path := path_for(art_id, mood)
	var key := path
	if key == (left_id if on_left else right_id):
		return
	if on_left:
		left_id = key
	else:
		right_id = key
	rect.texture = load(path) as Texture2D if path != "" else null
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
