class_name BossBar
extends CanvasLayer
## Boss presentation (G3, lane 21): a fight with Strahd or another boss (narrative/combat/bosses.json, and any foe with
## legendary actions) opens on an entrance (letterbox bars, the camera close and low on the boss, its name and title
## across the bottom of the screen, a sting over the music) and keeps a name plate and health bar for each boss, up to
## three side by side, just above the hotbar. As everywhere for foes, the bar shows how hurt a boss looks, never its
## exact Hit Points: it drops a quarter at a time, deep red once Bloodied. Legendary Resistance left shows beside the
## title. CombatView builds it, plays the entrance, refreshes it with the HUD and fades it with the HUD.

const DATA := "res://narrative/combat/bosses.json"
## At most this many plates (the coven, the brides).
const MOST := 3
## The plates' row: its width, the room it leaves for the hotbar under it, and a plate's height.
const ROW_WIDTH := 1000.0
const ABOVE_HOTBAR := 252.0
const PLATE_HEIGHT := 70.0
## How many steps the bar drops in (quarters).
const STEPS := 4
## The entrance: the letterbox bars' height, the seconds it takes in and out, and how long the name holds.
const LETTERBOX := 92.0
const BARS_IN := 0.45
const ENTRANCE := 2.6
## The sound over the music as the name shows, unless a boss names its own (`sting`): several play together.
const STING: Array[String] = ["toll", "thunder_boom"]

## The screens and captures that turn the entrance off; headless runs (the tests) never play it.
static var entrances := true
static var _data: Dictionary = {}

var e: Encounter
var bosses: Array[Combatant] = []
var _row: HBoxContainer
## Boss id -> {plate, bar_box, bar, step, words}.
var _plates: Dictionary = {}
var _top: ColorRect
var _bottom: ColorRect
var _card: VBoxContainer


func _init() -> void:
	name = "BossBar"
	layer = 10


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA)) as Dictionary
	return _data


## Whether the entrance plays (never headless).
static func entrance_on() -> bool:
	return entrances and DisplayServer.get_name() != "headless"


## What makes `c` a boss: {"title": ...} (the title may be ""), or {} for any other creature. Only foes count.
static func entry(c: Combatant) -> Dictionary:
	if c.side != &"enemy" or not c.creature is Monster:
		return {}
	var m := c.creature as Monster
	var spec := ((data().get("bosses", {}) as Dictionary).get(str(m.data.get("id", "")), {}) as Dictionary)
	if spec.has("names"):
		var names := spec["names"] as Dictionary
		if names.has(c.name()):
			return {"title": str(names[c.name()]), "sting": spec.get("sting", [])}
	elif not spec.is_empty():
		return {"title": str(spec.get("title", "")), "sting": spec.get("sting", [])}
	if not (m.data.get("legendary_actions", {}) as Dictionary).is_empty():
		return {"title": ""}
	return {}


## The bosses standing in `enc` at its start, the greatest first (legendary actions, then Challenge Rating), up to MOST.
static func bosses_in(enc: Encounter) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in enc.combatants:
		if c.is_alive() and not entry(c).is_empty():
			out.append(c)
	out.sort_custom(func(a: Combatant, b: Combatant) -> bool: return _rank(a) > _rank(b))
	return out.slice(0, MOST)


static func _rank(c: Combatant) -> float:
	var m := c.creature as Monster
	return m.cr + (100.0 if not (m.data.get("legendary_actions", {}) as Dictionary).is_empty() else 0.0)


## How hurt `c` looks, in steps of the bar: STEPS unhurt, down to 1 near death, 0 once it's down or gone.
static func step_of(c: Combatant) -> int:
	var cr := c.creature
	if cr.dead or cr.hp <= 0 or not c.is_alive():
		return 0
	return clampi(ceili(float(cr.hp) * STEPS / maxf(1.0, cr.max_hp())), 1, STEPS)


# --- The plates ---------------------------------------------------------------------------------------------------

func build(enc: Encounter, bosses_: Array[Combatant]) -> void:
	e = enc
	bosses = bosses_
	_row = HBoxContainer.new()
	_row.anchor_left = 0.5
	_row.anchor_right = 0.5
	_row.anchor_top = 1.0
	_row.anchor_bottom = 1.0
	_row.offset_left = -ROW_WIDTH / 2.0
	_row.offset_right = ROW_WIDTH / 2.0
	_row.offset_top = -ABOVE_HOTBAR - PLATE_HEIGHT
	_row.offset_bottom = -ABOVE_HOTBAR
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 28)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	var width := plate_width(bosses.size())
	for c in bosses:
		_row.add_child(_plate(c, width))
	refresh()


## A plate's width for `n` bosses side by side.
static func plate_width(n: int) -> float:
	return 620.0 if n <= 1 else (ROW_WIDTH - 28.0 * (n - 1)) / n


func _plate(c: Combatant, width: float) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, PLATE_HEIGHT)
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size := 26 if bosses.size() == 1 else (21 if bosses.size() == 2 else 18)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 10)
	name_row.add_child(_flourish(false))
	# The name in the book hand, cut short with an ellipsis if it can't fit between the flourishes.
	var title := UiKit.label(c.name(), size, "gilt_light")
	title.add_theme_font_override("font", UiKit.display_font())
	title.add_theme_constant_override("outline_size", 7)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	var wide := UiKit.display_font().get_string_size(c.name(), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 6.0
	title.custom_minimum_size = Vector2(minf(wide, width - 76.0), size + 8)
	name_row.add_child(title)
	name_row.add_child(_flourish(true))
	box.add_child(name_row)
	var bar_box := CenterContainer.new()
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar_box)
	var words := UiKit.label("", 13, "parchment")
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_theme_font_override("font", UiParts.caps_font())
	words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.clip_text = true
	words.custom_minimum_size = Vector2(width, 0)
	box.add_child(words)
	_plates[c.id] = {"plate": box, "bar_box": bar_box, "bar": null, "step": -1, "words": words, "width": width}
	return box


## A short gilt rule ending in a lozenge, either side of a boss's name.
func _flourish(right: bool) -> Control:
	return UiParts.drawn(Vector2(26, 20), func(c: Control) -> void:
		var y := c.size.y / 2.0 + 2.0
		var gilt := Look.color("gilt")
		var tip := c.size.x - 4.0 if right else 4.0
		var from := 0.0 if right else 9.0
		var to := c.size.x - 9.0 if right else c.size.x
		c.draw_line(Vector2(from, y), Vector2(to, y), Color(gilt, 0.85), 1.2, true)
		UiParts.diamond(c, Vector2(tip, y), 4.0, gilt, true))


## Brings each plate up to date: the bar's step (rolling down to it), and the line under it.
func refresh() -> void:
	for c in bosses:
		var p := _plates.get(c.id, {}) as Dictionary
		if p.is_empty():
			continue
		var step := step_of(c)
		if step != int(p["step"]):
			p["step"] = step
			var old := p["bar"] as Control
			if old != null:
				old.queue_free()
			var fill := "vampire_red" if c.creature.is_bloodied() else "crimson"
			var bar := UiParts.bar(step, STEPS, 0.0, "", fill, Callable(), float(p["width"]), 16.0)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			UiParts.roll_bar(bar, "boss:%d" % c.get_instance_id(), step)
			(p["bar_box"] as Control).add_child(bar)
			p["bar"] = bar
		(p["words"] as Label).text = _words(c)
		# A boss that fell or left the fight (Strahd's mist) dims.
		var gone := step == 0 or (e != null and e.legendary.departed.has(c.id))
		(p["plate"] as Control).modulate.a = 0.55 if gone else 1.0


## The line under a boss's bar: its title and Legendary Resistance left, or how it left the fight.
func _words(c: Combatant) -> String:
	var parts: Array[String] = []
	var title := str(entry(c).get("title", ""))
	var gone := str(e.legendary.departed.get(c.id, "")) if e != null else ""
	if gone == "mist":
		return "Fled as mist"
	if gone != "":
		return "Withdrew from the fight"
	if c.creature.dead or not c.is_alive():
		return "Defeated" if title == "" else "%s · Defeated" % title
	if title != "":
		parts.append(title)
	var resist := int(Legendary.data_of(c).get("legendary_resistance", 0))
	if resist > 0:
		var used := int(c.get_meta("legendary_resistance_used", 0))
		parts.append("Legendary Resistance %s" % ("◆".repeat(maxi(resist - used, 0)) + "◇".repeat(mini(used, resist))))
	return "  ·  ".join(parts)


# --- The entrance -------------------------------------------------------------------------------------------------

## Letterbox bars close in and `c`'s name and title rise over the bottom one; the sting plays.
func show_entrance(c: Combatant) -> void:
	_top = _letterbox(true)
	_bottom = _letterbox(false)
	_card = VBoxContainer.new()
	_card.anchor_left = 0.0
	_card.anchor_right = 1.0
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_top = -LETTERBOX - 120.0
	_card.offset_bottom = -LETTERBOX + 20.0
	_card.alignment = BoxContainer.ALIGNMENT_END
	_card.add_theme_constant_override("separation", 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := str(entry(c).get("title", ""))
	if title != "":
		var t := UiKit.label(title.to_upper(), 20, "parchment")
		t.add_theme_font_override("font", UiParts.caps_font())
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card.add_child(t)
	var n := UiKit.label(c.name(), 60, "gilt_light")
	n.add_theme_font_override("font", UiKit.display_font())
	n.add_theme_constant_override("outline_size", 12)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(n)
	_card.add_child(UiParts.drawn(Vector2(0, 16), func(d: Control) -> void:
		UiParts.title_rule(d, Vector2(d.size.x / 2.0, 6.0), minf(260.0, d.size.x * 0.3))))
	add_child(_card)
	_card.modulate.a = 0.0
	_row.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_top, "offset_bottom", LETTERBOX, BARS_IN)
	tw.tween_property(_bottom, "offset_top", -LETTERBOX, BARS_IN)
	tw.tween_property(_card, "modulate:a", 1.0, 0.6).set_delay(0.35)
	# The name drifts up a little as it shows.
	tw.tween_property(_card, "offset_top", _card.offset_top - 14.0, 1.6).set_delay(0.35)
	tw.tween_property(_card, "offset_bottom", _card.offset_bottom - 14.0, 1.6).set_delay(0.35)
	tw.tween_callback(func() -> void: BossBar.sting(c)).set_delay(0.35)


## The bars open and the name fades; the plates above the hotbar come up in their place.
func hide_entrance() -> void:
	if _card == null:
		return
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_card, "modulate:a", 0.0, 0.35)
	tw.tween_property(_top, "offset_bottom", 0.0, BARS_IN)
	tw.tween_property(_bottom, "offset_top", 0.0, BARS_IN)
	tw.tween_property(_row, "modulate:a", 1.0, 0.5).set_delay(0.3)
	tw.chain().tween_callback(func() -> void:
		for n: Node in [_card, _top, _bottom]:
			n.queue_free()
		_card = null)


## Whether the entrance is showing.
func entrance_showing() -> bool:
	return _card != null


func _letterbox(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Look.color("void")
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0
	r.anchor_bottom = 0.0 if top else 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


## The sting over the music as `c`'s name shows: its own sounds, or STING.
static func sting(c: Combatant) -> void:
	var ids: Array = entry(c).get("sting", []) as Array
	if ids.is_empty():
		ids = STING
	for i in ids.size():
		if i == 0:
			Audio.sting(str(ids[i]))
		else:
			Audio.sfx(str(ids[i]), 0.0)
