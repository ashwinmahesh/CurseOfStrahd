class_name PartyScreen
extends CanvasLayer
## Party overview and marching order (docs/ui/party_management.md pm_01, pm_03): each character's Hit Points (with
## Bloodied in words), Hit Point Dice, spell slots, resources, conditions and the level-up badge; the marching order
## (the leader walks first; order matters for traps) with each member's passive Perception, Stealth and darkvision;
## and the party skill table (best character per skill) and gaps from PartyCoverage.

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
	while _frame.get_child_count() > 1:
		var c := _frame.get_child(1)
		_frame.remove_child(c)
		c.queue_free()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	for i in st.party.size():
		cols.add_child(_column(st.party[i], i))
	_frame.add_child(cols)
	if not st.fallen.is_empty():
		var lost: Array[String] = []
		for f in st.fallen:
			lost.append("%s, who %s (day %d)" % [f["name"], f["how"], int(f["day"])])
		_frame.add_child(UiKit.label("Remembered: " + "; ".join(lost), 15, "ui_wine", 1400))
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 30)
	_frame.add_child(lower)
	var order := VBoxContainer.new()
	order.add_child(UiKit.header("Marching order"))
	for i in st.party.size():
		var ch := st.party[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UiKit.label("%d. %s%s" % [i + 1, "★ " if i == 0 else "", ch.name], 15, "gilt_light" if i == 0 else "vellum"))
		row.add_child(UiKit.label("Passive Perception %d · Stealth %s · Darkvision %s" % [ch.passive_score(&"perception").total(),
			ch.skill_bonus(&"stealth").signed(), ("%d ft" % ch.darkvision()) if ch.darkvision() > 0 else "none"], 13, "parchment"))
		var up := UiKit.button("▲", func() -> void: _move(i, -1), 13)
		up.disabled = i == 0
		row.add_child(up)
		var down := UiKit.button("▼", func() -> void: _move(i, 1), 13)
		down.disabled = i == st.party.size() - 1
		row.add_child(down)
		order.add_child(row)
	var best_spotter := 0
	for i in st.party.size():
		if st.party[i].passive_score(&"perception").total() > st.party[best_spotter].passive_score(&"perception").total():
			best_spotter = i
	if best_spotter == st.party.size() - 1 and st.party.size() > 1:
		order.add_child(UiKit.label("Tip: your best spotter walks last; traps are noticed by whoever comes near first.", 13, "gilt", 600))
	lower.add_child(order)
	var cov := PartyCoverage.analyze(st.party)
	var skills := VBoxContainer.new()
	skills.add_child(UiKit.header("Best at each skill"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	var table := cov["skills"] as Dictionary
	var keys: Array = table.keys()
	keys.sort()
	for k: String in keys:
		var e := table[k] as Dictionary
		grid.add_child(UiKit.label("%s: %s %s%s" % [k.replace("_", " ").capitalize(), str(e["name"]).get_slice(" ", 0), UiKit.signed(int(e["bonus"])),
			"" if bool(e["proficient"]) else " ~"], 13, "vellum" if bool(e["proficient"]) else "bone"))
	skills.add_child(grid)
	for g: String in cov["gaps"]:
		skills.add_child(UiKit.label("· " + g, 13, "gilt", 760))
	lower.add_child(skills)


func _column(ch: Character, i: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(350, 0)
	col.add_child(UiKit.portrait(CombatToken.art_for(ch), 100))
	col.add_child(UiKit.label(ch.name, 18, "gilt_light"))
	col.add_child(UiKit.label(ch.class_summary(), 14, "parchment", 340))
	var hp := "HP %d/%d" % [ch.hp, ch.max_hp()]
	if ch.dead:
		hp += " · Dead"
	elif ch.hp <= 0:
		hp += " · Unconscious, death saves %d ✓ %d ✗%s" % [ch.death_successes, ch.death_failures, " (Stable)" if ch.stable else ""]
	elif ch.is_bloodied():
		hp += " · Bloodied"
	col.add_child(UiKit.label(hp, 15, "vellum", 340))
	var hd := ch.hit_dice()
	for d: String in hd:
		col.add_child(UiKit.label("Hit Point Dice: %d of %dd%s" % [int((hd[d] as Dictionary)["total"]) - int((hd[d] as Dictionary)["spent"]), int((hd[d] as Dictionary)["total"]), d], 13, "parchment"))
	var slots := ch.spell_slots()
	var parts: Array[String] = []
	for l in slots.size():
		if slots[l] > 0:
			parts.append("L%d %d/%d" % [l + 1, ch.slots_left(l + 1), slots[l]])
	if not parts.is_empty():
		col.add_child(UiKit.label("Slots: " + " · ".join(parts), 13, "moonlight"))
	for res_id: String in ch.resources:
		var r := ch.resources[res_id] as Dictionary
		col.add_child(UiKit.label("%s: %d/%d" % [r["name"], int(r["max"]) - int(r["used"]), int(r["max"])], 13, "vellum"))
	var conds := ch.active_conditions()
	if not conds.is_empty():
		col.add_child(UiKit.label(", ".join(conds.map(func(c: StringName) -> String: return str(c).capitalize())), 13, "gilt", 340))
	if ch.exhaustion > 0:
		col.add_child(UiKit.label("Exhaustion %d" % ch.exhaustion, 13, "gilt"))
	if st.can_level_up(ch):
		col.add_child(UiKit.button("▲ Level up", func() -> void: root.call("open_screen", "level_up", i), 14))
	col.add_child(UiKit.button("Sheet", func() -> void: root.call("open_screen", "sheet", i), 13))
	return col


func _move(i: int, step: int) -> void:
	var j := clampi(i + step, 0, st.party.size() - 1)
	var a := st.party[i]
	st.party[i] = st.party[j]
	st.party[j] = a
	if root.has_method("rebuild"):
		root.call("rebuild")
	_draw()
