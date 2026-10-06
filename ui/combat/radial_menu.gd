class_name RadialMenu
extends Control
## The controller's radial menu (cb_03): hold LB, point the right stick at a wedge, release (or press A) to pick.
## Eight wedges: Attacks, Spells, Class, Items, Common, Move, End Turn, Inspect.

signal picked(choice: String)

const CHOICES: Array[String] = ["Attacks", "Spells", "Class", "Items", "Common", "Move", "End Turn", "Inspect"]
const RADIUS := 150.0

var selected := -1


func _init() -> void:
	custom_minimum_size = Vector2(RADIUS * 2 + 40, RADIUS * 2 + 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Points the selection at a stick direction (deadzone 0.4).
func aim(stick: Vector2) -> void:
	if stick.length() < 0.4:
		return
	var angle := fposmod(stick.angle() + PI / 2.0 + PI / CHOICES.size(), TAU)
	var idx := int(angle / (TAU / CHOICES.size())) % CHOICES.size()
	if idx != selected:
		selected = idx
		queue_redraw()


func confirm() -> void:
	if visible and selected >= 0:
		picked.emit(CHOICES[selected])
	visible = false


func open() -> void:
	selected = -1
	visible = true
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var font := get_theme_default_font()
	draw_circle(c, RADIUS + 14, Color(Look.color("ink"), 0.92))
	var n := CHOICES.size()
	for i in n:
		var a0 := -PI / 2.0 + i * TAU / n - PI / n
		var a1 := a0 + TAU / n
		var pts := PackedVector2Array([c])
		for k in 9:
			var a := lerpf(a0, a1, k / 8.0)
			pts.append(c + Vector2(cos(a), sin(a)) * RADIUS)
		draw_colored_polygon(pts, Look.color("plum") if i == selected else Look.color("grave"))
		draw_polyline(pts + PackedVector2Array([c]), Look.color("bone_dark"), 2.0)
		var mid := (a0 + a1) / 2.0
		var p := c + Vector2(cos(mid), sin(mid)) * RADIUS * 0.66
		var text := CHOICES[i]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, p - Vector2(w / 2.0, -6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Look.color("vellum"))
	draw_circle(c, 34, Look.color("ink"))
	var hint := "LB"
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, c - Vector2(hw / 2.0, -6), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Look.color("parchment"))
