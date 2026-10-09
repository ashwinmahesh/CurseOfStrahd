class_name EconomyShapes
extends Control
## The action economy as shapes plus words (combat view spec): Action ● green, Bonus Action ▲ ember, Reaction ◆ plum;
## greyed once spent. Beside the Action, a pip per attack of the Attack action (Extra Attack), lit while it's left; and a
## pointed-at hotbar slot rings the shape it would spend (preview, like Baldur's Gate 3).

var action := true
var bonus := true
var reaction := true
## Attacks one Attack action gives, and how many of them are left (pips only for 2 or more).
var attacks := 1
var attacks_left := 1
## The cost a pointed-at slot would spend ("" none): action, attack, bonus or reaction.
var _preview := ""
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(300, 64)
	set_process(false)


func set_state(a: bool, b: bool, r: bool, per_action: int = 1, left: int = 1) -> void:
	action = a
	bonus = b
	reaction = r
	attacks = per_action
	attacks_left = left
	queue_redraw()


## Rings the shape `cost` would spend while a slot is pointed at ("" to stop). `mid_attack`: an attack that's part of an
## Attack action already started spends one of its pips, not the Action.
func preview(cost: String, mid_attack: bool = false) -> void:
	_preview = "attack_pip" if cost == "attack" and mid_attack else cost
	_time = 0.0
	set_process(_preview != "")
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var spent := Look.color("ui_wine")
	var items := [["Action", action, "moss"], ["Bonus", bonus, "gilt"], ["Reaction", reaction, "mist_blue"]]
	var lit := {"action": 0, "attack": 0, "bonus": 1, "reaction": 2}
	var glow := Color(Look.color("gilt_light"), 0.55 + 0.35 * sin(_time * 6.0))
	for i in items.size():
		var it := items[i] as Array
		var cx := 40.0 + i * 100.0
		var col := Look.color(str(it[2])) if bool(it[1]) else spent
		var edge := Look.color("vellum") if bool(it[1]) else Look.color("ui_oxblood")
		var ringed := int(lit.get(_preview, -1)) == i
		match i:
			0:
				if ringed:
					draw_arc(Vector2(cx, 22), 21, 0, TAU, 32, glow, 3.0)
				draw_circle(Vector2(cx, 22), 16, col)
				draw_arc(Vector2(cx, 22), 16, 0, TAU, 32, edge, 2.0)
			1:
				var tri := PackedVector2Array([Vector2(cx, 4), Vector2(cx + 18, 38), Vector2(cx - 18, 38)])
				if ringed:
					draw_polyline(PackedVector2Array([Vector2(cx, -2), Vector2(cx + 23, 42), Vector2(cx - 23, 42), Vector2(cx, -2)]), glow, 3.0)
				draw_colored_polygon(tri, col)
				draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), edge, 2.0)
			2:
				var dia := PackedVector2Array([Vector2(cx, 3), Vector2(cx + 19, 22), Vector2(cx, 41), Vector2(cx - 19, 22)])
				if ringed:
					draw_polyline(PackedVector2Array([Vector2(cx, -2), Vector2(cx + 24, 22), Vector2(cx, 46), Vector2(cx - 24, 22), Vector2(cx, -2)]), glow, 3.0)
				draw_colored_polygon(dia, col)
				draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]), edge, 2.0)
		var text := str(it[0])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(cx - w / 2.0, 60), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Look.color("vellum") if bool(it[1]) else Look.color("gilt_dark"))
	# Extra Attack: a pip per attack beside the Action, lit while left; the next one rings when an attack is pointed at.
	if attacks > 1:
		for k in attacks:
			var at := Vector2(66.0, 8.0 + k * 10.0)
			var on := k >= attacks - attacks_left
			draw_circle(at, 3.5, Look.color("moss") if on else spent)
			draw_arc(at, 3.5, 0, TAU, 12, Look.color("vellum") if on else Look.color("ui_oxblood"), 1.0)
			if _preview == "attack_pip" and k == attacks - attacks_left:
				draw_arc(at, 6.0, 0, TAU, 16, glow, 2.0)
