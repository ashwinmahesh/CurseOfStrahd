class_name EconomyShapes
extends Control
## The action economy as shapes plus words (combat view spec): Action ● green, Bonus Action ▲ ember, Reaction ◆ plum;
## greyed once spent.

var action := true
var bonus := true
var reaction := true


func _init() -> void:
	custom_minimum_size = Vector2(300, 64)


func set_state(a: bool, b: bool, r: bool) -> void:
	action = a
	bonus = b
	reaction = r
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var spent := Look.color("ash_violet")
	var items := [["Action", action, "moss"], ["Bonus", bonus, "ember"], ["Reaction", reaction, "plum"]]
	for i in items.size():
		var it := items[i] as Array
		var cx := 40.0 + i * 100.0
		var col := Look.color(str(it[2])) if bool(it[1]) else spent
		var edge := Look.color("vellum") if bool(it[1]) else Look.color("grave")
		match i:
			0:
				draw_circle(Vector2(cx, 22), 16, col)
				draw_arc(Vector2(cx, 22), 16, 0, TAU, 32, edge, 2.0)
			1:
				var tri := PackedVector2Array([Vector2(cx, 4), Vector2(cx + 18, 38), Vector2(cx - 18, 38)])
				draw_colored_polygon(tri, col)
				draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), edge, 2.0)
			2:
				var dia := PackedVector2Array([Vector2(cx, 3), Vector2(cx + 19, 22), Vector2(cx, 41), Vector2(cx - 19, 22)])
				draw_colored_polygon(dia, col)
				draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]), edge, 2.0)
		var text := str(it[0])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(cx - w / 2.0, 60), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Look.color("vellum") if bool(it[1]) else Look.color("bone_dark"))
