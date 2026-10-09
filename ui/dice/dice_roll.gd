class_name DiceRoll
extends PanelContainer
## The big d20 (docs/ui/d20_roll.md, G11): the emerald die (D20Die) rolling a d20 test, and beside it who rolls what
## against which DC; once the die lands, the roll in words (both dice under Advantage or Disadvantage, each part of the
## bonus, anything added after), the total and the verdict, gold and glowing for a natural 20, red for a natural 1.
## One panel for every big roll the player makes: a check in a conversation (DialogueUI keeps it at the top until the
## next beat), a check in the overworld (picking a lock, forcing a door, picking a pocket, climbing out of a pit) and
## the heroes' saving throws and death saves in a fight. Those last two come through show_roll: the panel comes up on
## its own layer, rolls, holds the result a moment and goes; the caller can await it.
##
## A roll is a Dictionary (from_test makes one from a D20Test): kind ("check", "save", "death_save" or "attack"),
## natural (the kept d20), rolls (both d20s under Advantage or Disadvantage), total, target (the DC or AC, 0 if the
## player doesn't know it), success, critical, fumble, who, label ("Persuasion", "Dexterity saving throw"), and
## optionally parts [{label, value}], modifier, extra, extra_label, advantage, disadvantage, auto_failed and verdict
## (the word for the result, else one fits the kind).

signal finished

const WIDTH := 640.0
const DIE := 168.0
## How long show_roll's result stays up after the die lands, at pace 1.
const HOLD_SECONDS := 1.15
## Over the HUDs (10) and conversations (20), under the menus and screens (30).
const LAYER := 26
## Where show_roll's panel sits: this share of the screen's height from the top.
const TOP_SHARE := 0.16
## A natural 20's rays fade out by this long after the die lands.
const RAYS_SECONDS := 2.0

var result: Dictionary = {}
var die: D20Die
## Seconds are multiplied by this (fast combat).
var pace := 1.0
## show_roll's panel: holds the result, then goes on its own; a click, key or button skips the roll, then closes it.
var auto_close := false

var _slot: Control
var _halo: TextureRect
var _rays: Rays
var _title: Label
var _parts: Label
var _total: Label
var _verdict: Label
var _tag: Label
var _held := 0.0
var _closing := false
var _shake := 0.0

## show_roll's panel up now: a roll asked for meanwhile (a botched disarm springs its trap) waits for it.
static var _showing: WeakRef = null


func _init() -> void:
	name = "DiceRoll"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := UiKit.style("ui_black", "gilt_dark", 2, 0.94)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(14)
	s.shadow_color = Color(Look.color("emerald_deep"), 0.55)
	s.shadow_size = 10
	add_theme_stylebox_override("panel", s)
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_top = 64
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_slot = Control.new()
	_slot.name = "DieSlot"
	_slot.custom_minimum_size = Vector2(DIE, DIE)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_slot)
	# Behind the die: its glow on landing (and a natural 20's rays).
	_halo = TextureRect.new()
	_halo.texture = _halo_texture()
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_halo.modulate.a = 0.0
	_slot.add_child(_halo)
	_rays = Rays.new()
	_rays.modulate.a = 0.0
	_slot.add_child(_rays)
	die = D20Die.new()
	die.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot.add_child(die)
	die.landed.connect(_landed)
	_slot.resized.connect(_place_glow)
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
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	_total = UiKit.label("", 36, "vellum")
	_total.add_theme_font_override("font", UiParts.figure_font())
	line.add_child(_total)
	_verdict = UiKit.label("", 25, "bile")
	_verdict.add_theme_font_override("font", UiKit.display_font())
	_verdict.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_verdict)
	_tag = UiKit.label("", 13, "gilt_light")
	_tag.add_theme_font_override("font", UiParts.caps_font())
	_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_tag)
	set_process(false)


## Rolls the big d20 on its own layer over `host`'s scene and returns a signal that fires once it has gone. The panel
## sits in the top third of the screen; fast combat plays it quicker (saves and death saves). A roll asked for while
## another is up waits for it. Without motion (headless runs, still captures) it shows the result and the signal fires
## on the next frame, so awaiting it never stalls a test.
static func show_roll(host: Node, roll_: Dictionary) -> Signal:
	var layer := CanvasLayer.new()
	layer.name = "BigRoll"
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var catcher := Control.new()
	catcher.name = "Catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP if UiMotion.on() else Control.MOUSE_FILTER_IGNORE
	layer.add_child(catcher)
	var panel := DiceRoll.new()
	panel.auto_close = true
	if str(roll_.get("kind", "check")) in ["save", "death_save", "attack"]:
		panel.pace = GameSettings.combat_pace()
	layer.add_child(panel)
	catcher.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			panel.skip())
	host.add_child(layer)
	panel.place_for_screen()
	var before := _showing.get_ref() as DiceRoll if _showing != null else null
	if UiMotion.on() and before != null and not before._closing:
		layer.visible = false
		before.finished.connect(func() -> void:
			if is_instance_valid(panel):
				layer.visible = true
				panel.roll(roll_), CONNECT_ONE_SHOT)
	else:
		panel.roll(roll_)
	_showing = weakref(panel)
	if not UiMotion.on():
		# Nothing moves: the result shows (for a still capture) and the caller goes on next frame.
		panel._closing = true
		host.get_tree().process_frame.connect(func() -> void:
			panel.finished.emit()
			layer.queue_free(), CONNECT_ONE_SHOT)
	return panel.finished


## Whether a big roll shows anything at all (no in headless runs).
static func wanted() -> bool:
	return DisplayServer.get_name() != "headless"


## A roll from a D20Test (Creature.roll_check, roll_save, roll_d20), for show_roll.
static func from_test(t: D20Test, who: String, label: String, kind: String = "") -> Dictionary:
	var k := kind
	if k == "":
		k = {D20Test.Kind.ABILITY_CHECK: "check", D20Test.Kind.SAVING_THROW: "save", D20Test.Kind.ATTACK_ROLL: "attack"}[t.kind]
	var parts: Array = []
	if t.breakdown != null:
		for part: Dictionary in t.breakdown.parts:
			parts.append({"label": str(part["label"]), "value": int(part["value"])})
	return {"kind": k, "natural": t.kept, "rolls": t.rolls.duplicate(), "total": t.total, "target": t.target,
		"success": t.success, "critical": t.critical or (t.kept == 20 and not t.auto_failed),
		"fumble": t.natural_one or (t.kept == 1 and not t.auto_failed), "who": who, "label": label, "parts": parts,
		"modifier": t.modifier, "extra": t.extra, "extra_label": t.extra_label, "advantage": t.advantage,
		"disadvantage": t.disadvantage, "auto_failed": t.auto_failed}


## A conversation's check beat (DialogueRunner._check_beat) as a roll.
static func from_beat(b: Dictionary) -> Dictionary:
	var kept := int(b.get("kept", 0))
	var failed := bool(b.get("auto_failed", false))
	return {"kind": "check", "natural": kept, "rolls": (b.get("rolls", []) as Array).duplicate(), "total": int(b.get("total", 0)),
		"target": int(b.get("dc", 0)), "success": bool(b.get("success", false)), "critical": kept == 20 and not failed,
		"fumble": kept == 1 and not failed, "who": str(b.get("who", "")), "label": str(b.get("skill", "")),
		"parts": b.get("parts", []), "modifier": int(b.get("modifier", 0)), "extra": int(b.get("extra", 0)),
		"extra_label": str(b.get("extra_label", "")), "advantage": bool(b.get("advantage", false)),
		"disadvantage": bool(b.get("disadvantage", false)), "auto_failed": failed}


## Puts show_roll's panel across the top third of the screen, never wider than it.
func place_for_screen() -> void:
	var screen := get_viewport_rect().size
	var w := minf(WIDTH, screen.x - 32.0)
	offset_left = -w / 2.0
	offset_right = w / 2.0
	offset_top = roundf(screen.y * TOP_SHARE)


## Shows `roll_` and throws the die to it. The words about the roll come once the die lands.
func roll(roll_: Dictionary) -> void:
	result = roll_
	var rolls := roll_.get("rolls", []) as Array
	var kept := int(roll_.get("natural", 0))
	var failed := bool(roll_.get("auto_failed", false))
	_title.text = title_text(roll_)
	_parts.text = parts_text(roll_)
	_total.text = UiParts.figures(str(int(roll_.get("total", 0)))) if not failed else ""
	_verdict.text = verdict_text(roll_)
	var won := bool(roll_.get("success", false))
	_verdict.add_theme_color_override("font_color", Look.color("bile" if won else "vampire_red"))
	var tone := ""
	if bool(roll_.get("critical", false)):
		tone = "crit"
		_tag.text = "Natural 20"
		_tag.add_theme_color_override("font_color", Look.color("gilt_light"))
		_total.add_theme_color_override("font_color", Look.color("gilt_light"))
	elif bool(roll_.get("fumble", false)):
		tone = "fumble"
		_tag.text = "Natural 1"
		_tag.add_theme_color_override("font_color", Look.color("vampire_red"))
		_total.add_theme_color_override("font_color", Look.color("vellum"))
	else:
		_tag.text = ""
		_total.add_theme_color_override("font_color", Look.color("vellum"))
	# Under Advantage or Disadvantage the other die rolls too and lands beside the kept one, smaller and grey.
	var other := 0
	if rolls.size() == 2:
		other = int(rolls[1]) if int(rolls[0]) == kept else int(rolls[0])
	_slot.custom_minimum_size = Vector2(DIE * (D20Die.TWO_WIDE if other > 0 else 1.0), DIE)
	die.tone = tone
	die.dim = failed
	die.pace = pace
	_held = 0.0
	_halo.modulate.a = 0.0
	_rays.modulate.a = 0.0
	_place_glow()
	if not UiMotion.on() or failed:
		die.show_landed(maxi(kept, 1), other)
		_reveal(1.0)
		_glow_at(1.0)
		set_process(auto_close and UiMotion.on())
		return
	_reveal(0.0)
	die.roll(kept, other)
	set_process(true)


## A click, a key or a button: the rolling die lands at once; a landed one's panel closes (show_roll's).
func skip() -> void:
	if _closing:
		return
	if die.rolling():
		die.finish()
	elif auto_close:
		close()


## Fades out and frees show_roll's layer, then `finished`.
func close() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	var layer := get_parent()
	var tw := UiMotion.tween_for(self)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		finished.emit()
		layer.queue_free())


## For captures that step time by hand: the die and the words at `t` seconds since the throw.
func seek(t: float) -> void:
	die.manual = true
	set_process(false)
	die.seek(t)
	var since := t - D20Die.ROLL_SECONDS * pace
	_reveal(clampf(since / 0.22, 0.0, 1.0) if since >= 0.0 else 0.0)
	_glow_at(since)


func _input(event: InputEvent) -> void:
	if not auto_close or _closing or result.is_empty():   # (a roll still waiting its turn has none yet)
		return
	var pressed := (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) \
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	if pressed:
		skip()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if die.manual:
		return
	var since := die._t - D20Die.ROLL_SECONDS * pace
	if since >= 0.0:
		_reveal(clampf(since / 0.22, 0.0, 1.0))
	_glow_at(since)
	if auto_close and not die.rolling():
		_held += delta
		if _held >= HOLD_SECONDS * clampf(pace, 0.6, 1.0):
			close()
	elif not auto_close and since > RAYS_SECONDS + 0.2:
		set_process(false)   # a conversation's die stays up at rest until the next beat


func _landed() -> void:
	if not die.manual:
		if die.tone == "crit":
			Audio.sfx("radiant_chime", 0.0)
		elif die.tone == "fumble":
			Audio.sfx("thud_heavy", 0.0, -2.0)
	_shake = 0.3 if die.tone == "fumble" else 0.0


## The words after the title: hidden while the die tumbles, then the total and verdict stamp in (0 to 1).
func _reveal(k: float) -> void:
	_parts.modulate.a = k
	_total.modulate.a = k
	_verdict.modulate.a = k
	_tag.modulate.a = k
	var pop := 1.0 + 0.35 * (1.0 - k) if k > 0.0 else 1.0
	for c: Control in [_total, _verdict]:
		c.pivot_offset = c.size / 2.0
		c.scale = Vector2(pop, pop)


## The glow behind the die `since` seconds after it landed (before then, none): a flare that settles to a soft light;
## a natural 20 also throws slow golden rays, and a natural 1 shudders the die.
func _glow_at(since: float) -> void:
	if since < 0.0:
		_halo.modulate.a = 0.0
		_rays.modulate.a = 0.0
		return
	var flare := exp(-since / 0.18)
	var colour := "emerald_light"
	if die.tone == "crit":
		colour = "wick"
	elif die.tone == "fumble":
		colour = "vampire_red"
	_halo.self_modulate = Look.color(colour)
	_halo.modulate.a = (0.45 + 0.55 * flare) if not die.dim else 0.15
	var sc := 1.0 + 0.25 * flare
	_halo.scale = Vector2(sc, sc)
	if die.tone == "crit":
		_rays.modulate.a = clampf(since / 0.15, 0.0, 1.0) * (0.55 + 0.45 * flare) * clampf((RAYS_SECONDS - since) / 0.8, 0.0, 1.0)
		_rays.spin = since * 0.35
		_rays.queue_redraw()
	var jolt := maxf(0.0, _shake - since) / maxf(_shake, 0.001) if _shake > 0.0 else 0.0
	die.position = Vector2(sin(since * 70.0) * 5.0 * jolt, 0.0)


func _place_glow() -> void:
	# Centred on the kept die, which sits at the left of a two-dice box.
	var side := DIE * 1.45
	var c := Vector2(DIE / 2.0, DIE / 2.0)
	_halo.size = Vector2(side, side)
	_halo.position = c - _halo.size / 2.0
	_halo.pivot_offset = _halo.size / 2.0
	_rays.size = Vector2(side * 1.5, side * 1.5)
	_rays.position = c - _rays.size / 2.0


static func _halo_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.75))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.35, Color(1, 1, 1, 0.32))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	return t


## Who rolls what against which DC: "Godrick Pendlebrook: Persuasion, DC 14".
static func title_text(r: Dictionary) -> String:
	var who := str(r.get("who", ""))
	var what := str(r.get("label", ""))
	var dc := int(r.get("target", 0))
	var text := "%s: %s" % [who, what] if who != "" else what
	if dc > 0 and str(r.get("kind", "")) != "death_save":   # a death save is always against 10
		text += ", %s %d" % ["AC" if str(r.get("kind", "")) == "attack" else "DC", dc]
	return text


## The roll in words: each die, then each part of the bonus, then anything added after.
static func parts_text(r: Dictionary) -> String:
	if bool(r.get("auto_failed", false)):
		return "An automatic failure"
	var rolls := r.get("rolls", []) as Array
	var bits: Array[String] = []
	if rolls.size() == 2:
		bits.append("d20 %s: %d and %d, the %s kept" % ["Advantage" if bool(r.get("advantage", false)) else "Disadvantage",
			int(rolls[0]), int(rolls[1]), "higher" if bool(r.get("advantage", false)) else "lower"])
	else:
		bits.append("d20: %d" % int(r.get("natural", 0)))
	var parts := r.get("parts", []) as Array
	if parts.is_empty() and int(r.get("modifier", 0)) != 0:
		parts = [{"label": "Bonus", "value": int(r["modifier"])}]
	for p: Variant in parts:
		var d := p as Dictionary
		bits.append("%s %+d" % [str(d["label"]), int(d["value"])])
	if int(r.get("extra", 0)) != 0:
		bits.append("%s %+d" % [str(r.get("extra_label", "Extra")) if str(r.get("extra_label", "")) != "" else "Extra", int(r["extra"])])
	return " · ".join(bits)


## The word for the result: the roll's own `verdict`, else one that fits its kind.
static func verdict_text(r: Dictionary) -> String:
	if str(r.get("verdict", "")) != "":
		return str(r["verdict"])
	var won := bool(r.get("success", false))
	match str(r.get("kind", "check")):
		"save":
			return "Saved" if won else "Failed"
		"attack":
			if bool(r.get("critical", false)) and won:
				return "Critical Hit"
			return "Hit" if won else "Miss"
	return "Success" if won else "Failure"


## A natural 20's slow golden rays behind the die.
class Rays:
	extends Control
	var spin := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		var gold := Look.color("wick")
		for i in 12:
			var a := spin + TAU * float(i) / 12.0
			var w := 0.07 if i % 2 == 0 else 0.04
			var tip := c + Vector2(cos(a), sin(a)) * r
			var pts := PackedVector2Array([c + Vector2(cos(a - w), sin(a - w)) * r * 0.18, tip,
				c + Vector2(cos(a + w), sin(a + w)) * r * 0.18])
			draw_polygon(pts, PackedColorArray([Color(gold, 0.55), Color(gold, 0.0), Color(gold, 0.55)]))
