class_name PartyScreen
extends CanvasLayer
## Party overview and marching order (docs/ui/party_management.md pm_01, pm_03): a card per character with the framed
## portrait, Hit Points bar (Bloodied in words), Armor Class, Initiative, Speed and passive Perception, Hit Point
## Dice, spell slots and resources as lozenges, conditions as tags and the level-up badge; the marching order (the
## leader walks first; order matters for traps) with each member's passive Perception, Stealth and darkvision; and the
## party skill table (best character per skill) and gaps from PartyCoverage.

var root: Node
var st: StoryState
var _frame: VBoxContainer


func _init() -> void:
	name = "PartyScreen"
	layer = 30


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	_frame = UiKit.screen_frame(self, "Party", Vector2(1500, 850))
	_draw()


func _draw() -> void:
	while _frame.get_child_count() > 0:
		var c := _frame.get_child(0)
		_frame.remove_child(c)
		c.queue_free()
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_frame.add_child(UiParts.fill_scroll(page))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	for i in st.party.size():
		cols.add_child(_column(st.party[i], i))
	page.add_child(cols)
	if not st.fallen.is_empty():
		var lost: Array[String] = []
		for f in st.fallen:
			lost.append("%s, who %s (day %d)" % [f["name"], f["how"], int(f["day"])])
		page.add_child(UiKit.label("Remembered: " + "; ".join(lost), 15, "rose", 1400))
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 24)
	page.add_child(lower)
	lower.add_child(_marching_order())
	lower.add_child(_skill_table())


func _column(ch: Character, i: int) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 88.0, ch.hp <= 0, ch.dead))
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UiKit.title(ch.name)
	n.add_theme_font_size_override("font_size", 22)
	who.add_child(n)
	who.add_child(UiKit.label(ch.class_summary(), 14, "gilt", 220))
	if st.can_level_up(ch):
		var badge := UiParts.pill("▲ Level up ready", "bile")
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		who.add_child(badge)
	head.add_child(who)
	col.add_child(head)
	var hp_head := HBoxContainer.new()
	hp_head.add_child(UiParts.caption("Hit Points", 11))
	hp_head.add_child(UiParts.gap())
	if ch.dead:
		hp_head.add_child(UiParts.pill("Dead", "vampire_red"))
	elif ch.hp <= 0:
		hp_head.add_child(UiParts.pill("Stable" if ch.stable else "Unconscious", "vampire_red"))
	elif ch.is_bloodied():
		hp_head.add_child(UiParts.pill("Bloodied", "vampire_red"))
	col.add_child(hp_head)
	col.add_child(UiParts.hp_bar(ch, 320.0, 22.0))
	if ch.hp <= 0 and not ch.dead:
		var saves := HBoxContainer.new()
		saves.add_theme_constant_override("separation", 8)
		saves.add_child(UiKit.label("Death saves", 13, "parchment"))
		saves.add_child(UiParts.pips(3, ch.death_successes, "bile"))
		saves.add_child(UiParts.pips(3, ch.death_failures, "vampire_red"))
		col.add_child(saves)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 6)
	var init := ch.initiative_bonus()
	var perc := ch.passive_score(&"perception")
	tiles.add_child(_tile("AC", str(ch.ac_value()), ch.armor_class(), "Armor Class"))
	tiles.add_child(_tile("Init", init.signed(), init, "Initiative"))
	tiles.add_child(_tile("Speed", "%d" % ch.speed().total(), ch.speed(), "Speed"))
	tiles.add_child(_tile("Percep.", str(perc.total()), perc, "Passive Perception"))
	col.add_child(tiles)
	var hd := ch.hit_dice()
	for d: String in hd:
		var e := hd[d] as Dictionary
		col.add_child(_pip_line("Hit Point Dice d%s" % d, int(e["total"]), int(e["total"]) - int(e["spent"]), "gilt_light"))
	var slots := ch.spell_slots()
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	for l in slots.size():
		if slots[l] > 0:
			var chip := HBoxContainer.new()
			chip.add_theme_constant_override("separation", 4)
			chip.add_child(UiParts.caption(ActionCatalog._ordinal(l + 1), 11))
			chip.add_child(UiParts.pips(slots[l], ch.slots_left(l + 1), "moonlight"))
			flow.add_child(chip)
	if flow.get_child_count() > 0:
		col.add_child(UiParts.caption("Spell slots", 11))
		col.add_child(flow)
	else:
		flow.free()
	for res_id: String in ch.resources:
		var r := ch.resources[res_id] as Dictionary
		col.add_child(_pip_line(str(r["name"]), ch.resource_max(res_id), ch.resource_left(res_id), "gilt_light"))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 4)
	tags.add_theme_constant_override("v_separation", 4)
	for c in ch.active_conditions():
		tags.add_child(UiParts.pill(str(c).capitalize(), "rose"))
	if ch.exhaustion > 0:
		tags.add_child(UiParts.pill("Exhaustion %d" % ch.exhaustion, "rose"))
	if ch.concentration != null:
		tags.add_child(UiParts.pill("Concentrating: %s" % ch.concentration.name, "moonlight"))
	if tags.get_child_count() > 0:
		col.add_child(tags)
	else:
		tags.free()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.add_child(UiParts.small_button("Sheet", func() -> void: root.call("open_screen", "sheet", i), "character"))
	if st.can_level_up(ch):
		var up := UiParts.small_button("Level up", func() -> void: root.call("open_screen", "level_up", i))
		UiParts.light_up(up)
		buttons.add_child(up)
	col.add_child(buttons)
	var card := UiParts.card("ui_oxblood", "gilt_dark", 0.5, 12)
	card.custom_minimum_size = Vector2(345, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(col)
	return card


## A small number with its caption above: "AC 16". Hover: its Breakdown.
func _tile(caption: String, value: String, b: Breakdown, title: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	var cap := UiParts.caption(caption, 10)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	var v := UiParts.figure(value, 20)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(v)
	var card := UiParts.card("ui_black", "gilt_dark", 0.8, 4)
	card.custom_minimum_size = Vector2(74, 0)
	card.add_child(box)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return UiParts.tipped(card, func() -> Control: return UiParts.breakdown_tip(b, title, value))


func _pip_line(text: String, total: int, left: int, colour: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UiKit.label(text, 14, "vellum" if left > 0 else "bone")
	l.custom_minimum_size = Vector2(160, 0)
	l.clip_text = true
	row.add_child(l)
	row.add_child(UiParts.pips(total, left, colour))
	return row


func _marching_order() -> Control:
	var order := VBoxContainer.new()
	order.add_theme_constant_override("separation", 6)
	order.custom_minimum_size = Vector2(660, 0)
	order.add_child(UiParts.section("Marching order"))
	for i in st.party.size():
		var ch := st.party[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var rank := i + 1
		row.add_child(UiParts.drawn(Vector2(30, 30), func(c: Control) -> void:
			var at := c.size / 2.0
			c.draw_circle(at, 13.0, Look.color("ui_black"))
			c.draw_arc(at, 13.0, 0.0, TAU, 32, Look.color("gilt_light" if rank == 1 else "gilt"), 2.0, true)
			UiParts.centred_text(c, UiParts.figure_font(), str(rank), at, 16, Look.color("ivory"), 3)))
		row.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 40.0, ch.hp <= 0, ch.dead))
		var n := UiKit.label(("★ " if i == 0 else "") + ch.name, 16, "gilt_light" if i == 0 else "vellum")
		n.custom_minimum_size = Vector2(170, 0)
		row.add_child(n)
		row.add_child(_fact("Perception", str(ch.passive_score(&"perception").total())))
		row.add_child(_fact("Stealth", ch.skill_bonus(&"stealth").signed()))
		row.add_child(_fact("Darkvision", ("%d ft" % ch.darkvision()) if ch.darkvision() > 0 else "none"))
		row.add_child(UiParts.gap())
		var up := UiParts.small_button("▲", func() -> void: _move(i, -1))
		up.disabled = i == 0
		up.tooltip_text = "Walk earlier"
		row.add_child(up)
		var down := UiParts.small_button("▼", func() -> void: _move(i, 1))
		down.disabled = i == st.party.size() - 1
		down.tooltip_text = "Walk later"
		row.add_child(down)
		order.add_child(UiParts.row(row, Callable(), i == 0))
	var best_spotter := 0
	for i in st.party.size():
		if st.party[i].passive_score(&"perception").total() > st.party[best_spotter].passive_score(&"perception").total():
			best_spotter = i
	if best_spotter == st.party.size() - 1 and st.party.size() > 1:
		order.add_child(UiKit.label("Tip: your best spotter walks last; traps are noticed by whoever comes near first.", 13, "gilt", 640))
	return order


func _fact(caption: String, value: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -3)
	box.custom_minimum_size = Vector2(78, 0)
	box.add_child(UiParts.caption(caption, 10))
	box.add_child(UiParts.figure(value, 16, "vellum"))
	return box


func _skill_table() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(UiParts.section("Best at each skill"))
	var cov := PartyCoverage.analyze(st.party)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 0)
	var table := cov["skills"] as Dictionary
	var keys: Array = table.keys()
	keys.sort()
	for k: String in keys:
		var e := table[k] as Dictionary
		var prof := bool(e["proficient"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.custom_minimum_size = Vector2(225, 24)
		row.add_child(UiParts.mark(1 if prof else 0))
		var sk := UiKit.label(k.replace("_", " ").capitalize().replace(" Of ", " of "), 14, "vellum" if prof else "bone")
		sk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sk)
		row.add_child(UiKit.label(str(e["name"]).get_slice(" ", 0), 12, "parchment"))
		var v := UiParts.figure(UiKit.signed(int(e["bonus"])), 15, "ivory" if prof else "bone")
		v.custom_minimum_size = Vector2(28, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		grid.add_child(row)
	var card := UiParts.card("ui_oxblood", "gilt_dark", 0.45, 8)
	card.add_child(grid)
	box.add_child(card)
	for g: String in cov["gaps"]:
		box.add_child(UiKit.label("◇ " + g, 13, "gilt", 700))
	return box


func _move(i: int, step: int) -> void:
	var j := clampi(i + step, 0, st.party.size() - 1)
	var a := st.party[i]
	st.party[i] = st.party[j]
	st.party[j] = a
	if root.has_method("rebuild"):
		root.call("rebuild")
	_draw()
