class_name RadialMenu
extends Control
## The controller's radial menu (cb_03): hold LB, point the right stick at a wedge, release (or press A) to pick.
## The bar scheme's eight wedges: Attacks, Spells, Class, Items, Common, Tactical (the camera from above; it was Move,
## which B already does), End Turn, Inspect. The wheels scheme
## (Settings, Game, Controller fights: Wheels; owner pick 2026-10-09, after Baldur's Gate 3 on console) holds the actual
## actions instead: the hotbar filter's slots, an icon and a name a wedge, up to PAGE at a time (open_items).

signal picked(choice: String)
## A slot picked on a wheel: its index among the items it was opened with.
signal picked_item(index: int)

const CHOICES: Array[String] = ["Attacks", "Spells", "Class", "Items", "Common", "Tactical", "End Turn", "Inspect"]
const RADIUS := 150.0
## Wedges on one wheel page.
const PAGE := 10

var selected := -1
## The wheel's actions ([{label, icon: Texture2D or null, enabled}]); empty for the bar scheme's eight wedges.
var items: Array[Dictionary] = []
## Under the hub: the filter and page shown, and what the D-pad does.
var title := ""


func _init() -> void:
	custom_minimum_size = Vector2(RADIUS * 2 + 40, RADIUS * 2 + 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _count() -> int:
	return items.size() if not items.is_empty() else CHOICES.size()


## Points the selection at a stick direction (deadzone 0.4).
func aim(stick: Vector2) -> void:
	if stick.length() < 0.4:
		return
	var n := _count()
	var angle := fposmod(stick.angle() + PI / 2.0 + PI / n, TAU)
	var idx := int(angle / (TAU / n)) % n
	if idx != selected:
		selected = idx
		queue_redraw()


func confirm() -> void:
	if visible and selected >= 0:
		if items.is_empty():
			picked.emit(CHOICES[selected])
		elif bool(items[selected].get("enabled", true)):
			picked_item.emit(selected)
	visible = false


func open() -> void:
	items = []
	title = ""
	selected = -1
	visible = true
	queue_redraw()


## Opens (or, while open, refills) the wheel with `items_` under `title_`, keeping the pick when it's still there.
func open_items(items_: Array[Dictionary], title_: String) -> void:
	items = items_.slice(0, PAGE)
	title = title_
	if selected >= items.size():
		selected = -1
	visible = true
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var font := get_theme_default_font()
	draw_circle(c, RADIUS + 14, Color(Look.color("ui_black"), 0.92))
	var n := _count()
	# The wedges first, then their icons and names over them, so no wedge paints over its neighbour's name.
	for i in n:
		var a0 := -PI / 2.0 + i * TAU / n - PI / n
		var a1 := a0 + TAU / n
		var pts := PackedVector2Array([c])
		for k in 9:
			var a := lerpf(a0, a1, k / 8.0)
			pts.append(c + Vector2(cos(a), sin(a)) * RADIUS)
		var on := items.is_empty() or bool(items[i].get("enabled", true))
		draw_colored_polygon(pts, Look.color("blood") if i == selected else (Look.color("ui_oxblood") if on else Look.color("ui_black")))
		draw_polyline(pts + PackedVector2Array([c]), Look.color("gilt_dark"), 2.0)
	for i in n:
		var mid := -PI / 2.0 + i * TAU / n
		var on := items.is_empty() or bool(items[i].get("enabled", true))
		var p := c + Vector2(cos(mid), sin(mid)) * RADIUS * 0.66
		var text := CHOICES[i] if items.is_empty() else str(items[i].get("label", ""))
		var fs := 16 if items.is_empty() else 12
		if not items.is_empty():
			var tex := items[i].get("icon") as Texture2D
			if tex != null:
				draw_texture_rect(tex, Rect2(p - Vector2(15, 26), Vector2(30, 30)), false, Color.WHITE if on else Color(1, 1, 1, 0.35))
			p.y += 14.0
			while text.length() > 4 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > TAU * RADIUS * 0.66 / n - 8.0:
				text = text.substr(0, text.length() - 2) + "…"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, p - Vector2(w / 2.0, -6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Look.color("vellum") if on else Look.color("bone"))
	draw_circle(c, 34 if items.is_empty() else 40, Look.color("ui_black"))
	# A wheel's hub names the action pointed at in full (its wedge may cut it short), else the filter and page.
	var hint := "LB" if items.is_empty() else (str(items[selected].get("label", "")) if selected >= 0 and selected < items.size() else title)
	if not items.is_empty():
		while hint.length() > 4 and font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > 76.0:
			hint = hint.substr(0, hint.length() - 2) + "…"
	var hs := 16 if items.is_empty() else 11
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
	draw_string(font, c - Vector2(hw / 2.0, -6 if items.is_empty() else -2), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Look.color("parchment"))
	if not items.is_empty():
		var sub := "▲▼ filter"
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, c - Vector2(sw / 2.0, -16), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Look.color("gilt_dark"))
