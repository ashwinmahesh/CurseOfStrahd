class_name ForegroundFraming
extends CanvasLayer
## Branches framing the view in the woods (Visual Polish Plan 11, after Octopath Traveler 2's foreground foliage): a
## few fern fronds in each bottom corner, out of focus and nearly black, swaying a little, as if the camera looked past
## them (shaders/post/foreground_leaf.gdshader, the plants' own leaf cards). Only
## on wild outdoor maps where the land around is wooded (ArenaBoard.WILD themes, a mood whose surround has trees), only
## while exploring: they fade out for fights, conversations and other screens, and as the camera tilts to the horizon.
## They keep to the bottom corners, clear of the middle where the party stands. Modern finish only; cosmetic.

const SHADER := preload("res://shaders/post/foreground_leaf.gdshader")
const ATLAS := "res://art/plants/cards.png"
const CELLS := "res://art/plants/cards.json"
## Over the world (and the depth blur's corners), under the place's blur dissolve (5) and the HUD (10).
const LAYER := 2
## The woods' density (the mood's surround `trees`) from which the branches show.
const WOODED := 0.6
## Each frond: its leaf card (an upright one, its stem at the bottom middle), the screen corner it grows from (0..1),
## its height as a share of the screen's, the angle it leans at (degrees from upright, toward the middle), how much of
## it shows on screen (a share of its height), and whether it's mirrored.
const BRANCHES := [
	{"cell": "fern_a", "corner": Vector2(0.0, 1.0), "height": 0.62, "angle": 40.0, "reach": 0.62, "flip": false},
	{"cell": "fern_b", "corner": Vector2(0.06, 1.0), "height": 0.42, "angle": 14.0, "reach": 0.55, "flip": true},
	{"cell": "fern_b", "corner": Vector2(1.0, 1.0), "height": 0.58, "angle": -42.0, "reach": 0.6, "flip": true},
	{"cell": "fern_brown", "corner": Vector2(0.95, 1.0), "height": 0.38, "angle": -12.0, "reach": 0.5, "flip": false},
]
## How far each sways (degrees) and how fast; seconds to fade in or out.
const SWAY := 1.6
const SWAY_SPEED := 0.45
const FADE := 0.5
## How strongly they show at full.
const OPACITY := 0.85

## Captures and the perf probe turn them off to compare (look_capture's LOOK_OFF=framing).
static var enabled := true

var atmosphere: Atmosphere
var view: Node
var shown := 0.0
var _branches: Array[TextureRect] = []
var _time := 0.0


static func set_enabled(on: bool) -> void:
	enabled = on


## Whether a place frames its view: a wild outdoor map with wooded land round it, in the Modern finish.
static func wanted(atmo: Atmosphere) -> bool:
	if not Look.modern() or atmo == null or not atmo.outdoors or atmo.board == null:
		return false
	if not atmo.board.theme in ArenaBoard.WILD:
		return false
	return float((atmo.mood.get("surround", {}) as Dictionary).get("trees", 0.0)) >= WOODED


## The framing for `atmo`'s place, added to it; null where the place doesn't want it.
static func build(atmo: Atmosphere, view_: Node) -> ForegroundFraming:
	if not wanted(atmo):
		return null
	var f := ForegroundFraming.new()
	f.name = "ForegroundFraming"
	f.atmosphere = atmo
	f.view = view_
	f.layer = LAYER
	f._time = float(hash(atmo.loc_id) % 1000)
	atmo.add_child(f)
	return f


func _ready() -> void:
	var cells := (JSON.parse_string(FileAccess.get_file_as_string(CELLS)) as Dictionary)["cells"] as Dictionary
	var atlas := load(ATLAS) as Texture2D
	for b: Dictionary in BRANCHES:
		var box := cells[str(b["cell"])] as Array
		var t := AtlasTexture.new()
		t.atlas = atlas
		var s := Vector2(atlas.get_size())
		t.region = Rect2(float(box[0]) * s.x, float(box[1]) * s.y, (float(box[2]) - float(box[0])) * s.x,
			(float(box[3]) - float(box[1])) * s.y)
		var r := TextureRect.new()
		r.name = "%s%d" % [str(b["cell"]).capitalize().replace(" ", ""), _branches.size()]
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.flip_h = bool(b["flip"])
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var m := ShaderMaterial.new()
		m.shader = SHADER
		r.material = m
		r.set_meta("spec", b)
		add_child(r)
		_branches.append(r)
	_update(0.0, true)


func _process(delta: float) -> void:
	_update(delta, false)


## Whether the branches should show now: exploring, no fight, the camera not tilted out to the horizon.
func target() -> float:
	if not enabled or not is_instance_valid(view):
		return 0.0
	if bool(view.get("in_combat")) or ModeController.mode != ModeController.Mode.EXPLORATION:
		return 0.0
	var rig := view.get("rig") as CameraRig
	if rig != null and rig.horizon_shown > 0.05:
		return 0.0
	return 1.0


func _update(delta: float, now: bool) -> void:
	_time += delta
	var goal := target()
	shown = goal if now else move_toward(shown, goal, delta / FADE)
	visible = shown > 0.001
	if not visible:
		return
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var key := atmosphere.sun.light_color if atmosphere != null and atmosphere.sun != null else Color(0.5, 0.5, 0.6)
	for i in _branches.size():
		var r := _branches[i]
		var b := r.get_meta("spec") as Dictionary
		var h := float(b["height"]) * size.y
		var tex := r.texture as AtlasTexture
		var w := h * tex.region.size.x / maxf(tex.region.size.y, 1.0)
		r.size = Vector2(w, h)
		# Grows from its corner: the card's base (bottom middle) sits just off screen, its tip leaning in.
		r.pivot_offset = Vector2(w * 0.5, h)
		var corner := (b["corner"] as Vector2) * size
		var lean := float(b["angle"]) + sin(_time * SWAY_SPEED * TAU + float(i) * 2.1) * SWAY
		r.rotation = deg_to_rad(lean)
		var into := (1.0 - float(b["reach"])) * h
		var down := Vector2(sin(r.rotation), -cos(r.rotation)) * -into
		r.position = corner + down - r.pivot_offset
		var m := r.material as ShaderMaterial
		m.set_shader_parameter("opacity", OPACITY * smoothstep(0.0, 1.0, shown))
		m.set_shader_parameter("blur", 4.0 + log(size.y / 1080.0) / log(2.0))
		m.set_shader_parameter("rim", key)
