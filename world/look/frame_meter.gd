class_name FrameMeter
extends CanvasLayer
## The frame-time meter (Improvement Ideas W17): frames a second, the average and slowest frame of the last half
## second, and the graphics preset, in a corner of the screen. F3 shows and hides it (GameSettings "frame_meter");
## Graphics.apply puts one on the window. The bar is 60 frames a second, 16.7 ms a frame, at 1080p on High.

const NODE_NAME := "FrameMeter"
const KEY := KEY_F3
## How often the numbers update (seconds).
const EVERY := 0.5
const BUDGET_MS := 1000.0 / 60.0

var label: Label
var _frames: Array[float] = []
var _since := 0.0
var _last_usec := 0


func _init() -> void:
	name = NODE_NAME
	layer = 120
	label = Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Look.color("bone"))
	label.add_theme_color_override("font_outline_color", Look.color("void"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	visible = shown()


static func shown() -> bool:
	return bool(GameSettings.value("frame_meter", false))


static func set_shown(on: bool) -> void:
	GameSettings.set_value("frame_meter", on)
	var tree := Engine.get_main_loop() as SceneTree
	var meter := tree.root.get_node_or_null(NODE_NAME) as CanvasLayer if tree != null else null
	if meter != null:
		meter.visible = on


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY:
		set_shown(not visible)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frames.append(float(now - _last_usec) / 1000.0)
	_last_usec = now
	_since += delta
	if _since < EVERY or not visible or _frames.is_empty():
		if _since >= EVERY:
			_since = 0.0
			_frames.clear()
		return
	var total := 0.0
	var worst := 0.0
	for f in _frames:
		total += f
		worst = maxf(worst, f)
	var avg := total / _frames.size()
	label.text = "%d fps  %.1f ms  (slowest %.1f)  %s" % [roundi(1000.0 / avg), avg, worst,
		str(Graphics.LABELS[Graphics.preset()]) if Look.modern() else "Classic"]
	label.add_theme_color_override("font_color", Look.color("bone" if avg <= BUDGET_MS * 1.05 else "flame"))
	_since = 0.0
	_frames.clear()
