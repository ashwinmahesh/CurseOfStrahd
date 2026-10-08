class_name FocusRing
extends CanvasLayer
## The pad's focus frame (U6; docs/ui/character_creation.md: "a thick candle frame plus a ▸ marker"): a gilt frame
## with a soft candle glow round whatever has focus, gliding from one choice to the next, and a ▸ at its left. PadNav
## shows it only while the pad is in use. It sits just under the rules cards (TipCards, 120), over every screen.

## How far the frame stands outside the control, in pixels.
const OUTSET := 4.0
## How quickly it glides to a new choice (the share of the way left that it closes each second, as a rate).
const GLIDE := 22.0

var _rect := Rect2()
var _goal := Rect2()
var _shown := false
var _t := 0.0
var _canvas: Control
var _frame: StyleBoxFlat


func _init() -> void:
	name = "FocusRing"
	layer = 119
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_canvas = Control.new()
	_canvas.name = "Frame"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	_frame = StyleBoxFlat.new()
	_frame.draw_center = false
	_frame.set_border_width_all(3)
	_frame.set_corner_radius_all(6)
	_frame.shadow_size = 9


## Frames `r` (viewport coordinates), gliding there from wherever it was.
func target(r: Rect2) -> void:
	_goal = r.grow(OUTSET)
	if not _shown or not UiMotion.on():
		_rect = _goal
	_shown = true
	visible = true


func hide_ring() -> void:
	_shown = false
	visible = false


## Where the frame is drawn now (gliding toward the choice with focus).
func framed() -> Rect2:
	return _rect if _shown else Rect2()


## The choice the frame is going to, grown by OUTSET.
func goal() -> Rect2:
	return _goal if _shown else Rect2()


func _process(delta: float) -> void:
	if not _shown:
		return
	_t += delta
	var k := 1.0 - exp(-GLIDE * delta)
	_rect = Rect2(_rect.position.lerp(_goal.position, k), _rect.size.lerp(_goal.size, k))
	_canvas.queue_redraw()


func _paint() -> void:
	var gold := Look.color("gilt_light")
	var glow := 0.3 + 0.12 * sin(_t * 4.0)
	_frame.border_color = gold
	_frame.shadow_color = Color(Look.color("gilt"), glow)
	_frame.draw(_canvas.get_canvas_item(), _rect)
	# The ▸ at the frame's left, when there's room for it on the screen.
	if _rect.position.x > 16.0:
		var c := Vector2(_rect.position.x - 9.0, _rect.get_center().y)
		var tri := PackedVector2Array([c + Vector2(-6, -7), c + Vector2(4, 0), c + Vector2(-6, 7)])
		_canvas.draw_colored_polygon(tri, gold)
		_canvas.draw_polyline(tri + PackedVector2Array([tri[0]]), Look.color("void"), 1.0, true)
