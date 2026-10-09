class_name ScreenPulse
extends CanvasLayer
## A pulse over the picture at a fight's big moments (Visual Polish Plan 3, shaders/post/screen_pulse.gdshader): as a
## fight breaks out the world streaks toward the party, drains of colour and flashes for a beat (Octopath's encounter
## swirl, done in place: nobody moves); a critical hit, a killing blow and a big spell landing get a shorter one at
## the creature struck or the spot hit, on top of CombatImpact's freeze and push-in. One per window, made on first use
## and hidden between pulses, so it costs nothing the rest of the time. Over the world, under every menu and the HUD.
## Like CombatImpact's moments: never in headless runs, and fast combat (Settings) shortens it.

const SHADER := preload("res://shaders/post/screen_pulse.gdshader")
## Over the world (the 3D view draws first) and under every menu and the HUD (they're on layer 1 and up).
const LAYER := -5
## Each kind: seconds in all, the share of them spent rising, then the streaks, the colour fringe, the drain of
## colour, the flash and its palette colour.
const KINDS := {
	"engage": {"time": 0.75, "rise": 0.25, "blur": 1.0, "fringe": 1.0, "drain": 0.75, "flash": 0.3, "tint": "frost"},
	"crit": {"time": 0.4, "rise": 0.2, "blur": 0.45, "fringe": 0.8, "drain": 0.25, "flash": 0.22, "tint": "frost"},
	"kill": {"time": 0.5, "rise": 0.2, "blur": 0.7, "fringe": 0.6, "drain": 0.55, "flash": 0.14, "tint": "blood"},
	"spell": {"time": 0.5, "rise": 0.25, "blur": 0.55, "fringe": 0.5, "drain": 0.15, "flash": 0.18, "tint": "candle"},
}
const GROUP := &"screen_pulse"

## Captures turn the pulses off for their before shots (and the perf probe, perf_run.py --effects ScreenPulse).
static var enabled := true
## Tests ask for pulses in headless runs.
static var headless_too := false
## Each window's layer (viewport instance id -> ScreenPulse), also while it waits to join the window.
static var _layers: Dictionary = {}

var _rect: ColorRect
var _mat: ShaderMaterial
var _tw: Tween = null
## A pulse asked for before the layer had joined the window: [kind's settings, where].
var _pending: Array = []


static func set_enabled(on: bool) -> void:
	enabled = on


## Whether pulses play now.
static func on() -> bool:
	return enabled and (headless_too or DisplayServer.get_name() != "headless")


## Plays pulse `kind` (KINDS) toward `at` in the world (the middle of the screen when it's off screen or not given),
## in the window `from` is in. The window's pulse layer, or null when nothing plays.
static func play(from: Node, kind: String, at: Vector3 = Vector3.INF) -> ScreenPulse:
	if not on() or from == null or not from.is_inside_tree() or not KINDS.has(kind):
		return null
	var p := _for(from)
	if p.is_inside_tree():
		p._play(KINDS[kind] as Dictionary, at)
	else:
		p._pending = [KINDS[kind], at]
	return p


## The window's pulse layer, made on first use: a child of the window itself, so it outlasts a place or a fight. It
## joins the window at the end of the frame (a fight can start while the window is still setting up its children).
static func _for(from: Node) -> ScreenPulse:
	var vp := from.get_viewport()
	var key := vp.get_instance_id()
	var have: Variant = _layers.get(key)
	if is_instance_valid(have) and not (have as Node).is_queued_for_deletion():
		return have as ScreenPulse
	var p := ScreenPulse.new()
	p.name = "ScreenPulse"
	p.layer = LAYER
	p.visible = false
	p._mat = ShaderMaterial.new()
	p._mat.shader = SHADER
	p._rect = ColorRect.new()
	p._rect.name = "Pulse"
	p._rect.material = p._mat
	p._rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p._rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(p._rect)
	_layers[key] = p
	vp.add_child.call_deferred(p)
	return p


func _ready() -> void:
	add_to_group(GROUP)
	if not _pending.is_empty():
		_play(_pending[0] as Dictionary, _pending[1] as Vector3)
		_pending = []


func _exit_tree() -> void:
	for key: Variant in _layers.keys():
		if _layers[key] == self:
			_layers.erase(key)


## Where `at` falls on the screen (0..1), or the middle.
func _screen_point(at: Vector3) -> Vector2:
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	if at == Vector3.INF or cam == null or cam.is_position_behind(at):
		return Vector2(0.5, 0.5)
	var size := vp.get_visible_rect().size
	var p := cam.unproject_position(at) / size
	return Vector2(clampf(p.x, 0.05, 0.95), clampf(p.y, 0.05, 0.95))


func _play(k: Dictionary, at: Vector3) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var size := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("centre", _screen_point(at))
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	for p: String in ["blur", "fringe", "drain", "flash"]:
		_mat.set_shader_parameter(p, float(k[p]))
	_mat.set_shader_parameter("tint", Look.color(str(k["tint"])))
	var seconds := float(k["time"]) * GameSettings.combat_pace()
	var rise := seconds * float(k["rise"])
	visible = true
	_set_amount(0.0)
	# Real time: a heavy hit's freeze and the last foe's slow motion (Engine.time_scale) don't hold it up.
	_tw = create_tween()
	_tw.set_ignore_time_scale(true)
	_tw.tween_method(_set_amount, 0.0, 1.0, rise).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tw.tween_method(_set_amount, 1.0, 0.0, seconds - rise).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tw.tween_callback(func() -> void: visible = false)


func _set_amount(k: float) -> void:
	_mat.set_shader_parameter("amount", k)


## How far into its pulse the layer is now (0 when none plays).
func amount() -> float:
	return float(_mat.get_shader_parameter("amount")) if visible else 0.0
