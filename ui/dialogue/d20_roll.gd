class_name D20Roll
extends PanelContainer
## G11, the big d20 (docs/ui/d20_roll.md): a check in a conversation rolls a large d20 at the top of the screen instead
## of only a line of text. The die tumbles through numbers and lands on the roll; beside it, who rolls what against which
## DC, every part of the bonus, both dice under Advantage or Disadvantage (the one not kept dimmed), anything added after
## (Tactical Mind), the total and the result. An aid spent on a failed check (Heroic Inspiration) rolls it again. Motion
## is off in headless runs and still captures (UiMotion), where it shows the landed die at once.

const WIDTH := 600.0
const DIE := 132.0
const TUMBLE_SECONDS := 0.75

var beat: Dictionary = {}
var die: D20Face
var second: D20Face
var _title: Label
var _parts: Label
var _total: Label
var _verdict: Label
var _rng := RandomNumberGenerator.new()   # cosmetic: the numbers the die tumbles through


func _init() -> void:
	name = "D20Roll"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := UiKit.style("ui_black", "gilt_dark", 2, 0.94)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(14)
	add_theme_stylebox_override("panel", s)
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_top = 64
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var dice := HBoxContainer.new()
	dice.add_theme_constant_override("separation", 6)
	dice.alignment = BoxContainer.ALIGNMENT_CENTER
	dice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dice)
	die = D20Face.new(DIE)
	dice.add_child(die)
	second = D20Face.new(DIE * 0.62)
	second.size_flags_vertical = Control.SIZE_SHRINK_END
	dice.add_child(second)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_title = UiKit.label("", 19, "gilt_light")
	_title.add_theme_font_override("font", UiKit.display_font())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_parts = UiKit.label("", 15, "vellum")
	_parts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_parts)
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", 14)
	col.add_child(result)
	_total = UiKit.label("", 34, "vellum")
	_total.add_theme_font_override("font", UiKit.display_font())
	result.add_child(_total)
	_verdict = UiKit.label("", 24, "bile")
	_verdict.add_theme_font_override("font", UiKit.display_font())
	_verdict.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.add_child(_verdict)


## Shows a check beat (DialogueRunner `check`) and rolls the die to it.
func show_check(b: Dictionary) -> void:
	beat = b
	var rolls := b.get("rolls", []) as Array
	var kept := int(b.get("kept", 0))
	var dc := int(b.get("dc", 0))
	_title.text = "%s: %s, DC %d" % [str(b.get("who", "")), str(b.get("skill", "")), dc]
	_parts.text = parts_text(b)
	_total.text = str(int(b.get("total", 0)))
	var won := bool(b.get("success", false))
	_verdict.text = "Success" if won else "Failure"
	_verdict.add_theme_color_override("font_color", Look.color("bile" if won else "vampire_red"))
	# Under Advantage or Disadvantage the other die sits beside the kept one, dimmed.
	second.visible = rolls.size() == 2
	if rolls.size() == 2:
		second.number = int(rolls[1]) if int(rolls[0]) == kept else int(rolls[0])
		second.dim = true
		second.queue_redraw()
	die.dim = bool(b.get("auto_failed", false))
	if not UiMotion.on():
		_land(kept)
		return
	_total.modulate.a = 0.0
	_verdict.modulate.a = 0.0
	var tw := UiMotion.tween_for(die)
	tw.tween_method(_tumble, 0.0, 1.0, TUMBLE_SECONDS)
	tw.tween_callback(_land.bind(kept))
	tw.tween_property(_total, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(_verdict, "modulate:a", 1.0, 0.15)


## The die mid-tumble (`t` from 0 to 1): a new face every frame, rocking less as it settles.
func _tumble(t: float) -> void:
	die.number = _rng.randi_range(1, 20)
	die.rotation = sin(t * 20.0) * 0.35 * (1.0 - t)
	die.queue_redraw()


func _land(kept: int) -> void:
	die.number = kept
	die.rotation = 0.0
	die.pivot_offset = die.size / 2.0
	die.queue_redraw()
	_total.modulate.a = 1.0
	_verdict.modulate.a = 1.0
	if UiMotion.on():
		Audio.sfx("click")
		var pop := UiMotion.tween_for(die).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		die.scale = Vector2(1.15, 1.15)
		pop.tween_property(die, "scale", Vector2.ONE, 0.2)


## The roll in words: each die, then each part of the bonus, then anything added after.
static func parts_text(b: Dictionary) -> String:
	if bool(b.get("auto_failed", false)):
		return "An automatic failure"
	var rolls := b.get("rolls", []) as Array
	var bits: Array[String] = []
	if rolls.size() == 2:
		bits.append("d20 %s: %d and %d, the %s kept" % ["Advantage" if bool(b.get("advantage", false)) else "Disadvantage",
			int(rolls[0]), int(rolls[1]), "higher" if bool(b.get("advantage", false)) else "lower"])
	else:
		bits.append("d20: %d" % int(b.get("kept", 0)))
	var parts := b.get("parts", []) as Array
	if parts.is_empty() and int(b.get("modifier", 0)) != 0:
		parts = [{"label": "Bonus", "value": int(b["modifier"])}]
	for p: Variant in parts:
		var d := p as Dictionary
		bits.append("%s %+d" % [str(d["label"]), int(d["value"])])
	if int(b.get("extra", 0)) != 0:
		bits.append("%s %+d" % [str(b.get("extra_label", "Extra")) if str(b.get("extra_label", "")) != "" else "Extra", int(b["extra"])])
	return " · ".join(bits)


## The die itself: a d20's outline (a hexagon with its top facet) in oxblood and gilt, the number in the middle.
class D20Face:
	extends Control
	var number := 20
	var dim := false
	var side := 100.0

	func _init(side_: float) -> void:
		side = side_
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(func() -> void: pivot_offset = size / 2.0)

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 3.0
		var hex := PackedVector2Array()
		for i in 6:
			var a := deg_to_rad(60.0 * i - 90.0)
			hex.append(c + Vector2(cos(a), sin(a)) * r)
		var fill := Look.color("ui_oxblood").lerp(Look.color("ui_black"), 0.5 if dim else 0.0)
		draw_colored_polygon(hex, fill)
		var edge := Look.color("gilt") if not dim else Look.color("gilt_dark")
		var closed := hex.duplicate()
		closed.append(hex[0])
		draw_polyline(closed, edge, 3.0, true)
		# The facets: an inner triangle touching three of the corners' midpoints, and lines out to the corners.
		var tri := PackedVector2Array([c + Vector2(0, -r * 0.55), c + Vector2(r * 0.48, r * 0.3), c + Vector2(-r * 0.48, r * 0.3), c + Vector2(0, -r * 0.55)])
		draw_polyline(tri, Color(edge, 0.55), 1.5, true)
		for k in 3:
			draw_line(tri[k], hex[k * 2], Color(edge, 0.35), 1.2, true)
		var font := UiKit.display_font()
		var fs := int(r * 0.62)
		var text := str(number)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col := Look.color("vellum") if not dim else Look.color("parchment")
		if number == 20 and not dim:
			col = Look.color("gilt_light")
		elif number == 1 and not dim:
			col = Look.color("vampire_red")
		draw_string_outline(font, c + Vector2(-w / 2.0, fs * 0.38), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Look.color("void"))
		draw_string(font, c + Vector2(-w / 2.0, fs * 0.38), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
