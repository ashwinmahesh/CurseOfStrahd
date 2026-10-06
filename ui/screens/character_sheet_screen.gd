class_name CharacterSheetScreen
extends CanvasLayer
## The character sheet (docs/ui/party_management.md pm_02): tabs for Overview, Abilities & Skills, Features &
## Traits, Spells, Active Effects and Notes; every number's tooltip is its Breakdown. Left/right arrows (or the
## portrait strip) switch character; Level up opens from here when a milestone allows it.

var root: Node
var st: StoryState
var index := 0
var _frame: VBoxContainer


func _init() -> void:
	name = "CharacterSheetScreen"
	layer = 30


func open(root_: Node, state: StoryState, index_: int) -> void:
	root = root_
	st = state
	index = clampi(index_, 0, st.party.size() - 1)
	_frame = UiKit.screen_frame(self, "Character", Vector2(1500, 850))
	_draw()


func _draw() -> void:
	while _frame.get_child_count() > 1:
		var c := _frame.get_child(1)
		_frame.remove_child(c)
		c.queue_free()
	var ch := st.party[index]
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	for i in st.party.size():
		var b := UiKit.button(("▸ " if i == index else "") + st.party[i].name, func() -> void:
			index = i
			_draw(), 14)
		strip.add_child(b)
	if st.can_level_up(ch):
		strip.add_child(UiKit.button("▲ Level up", func() -> void: root.call("open_screen", "level_up", index), 15))
	_frame.add_child(strip)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UiKit.portrait(CombatToken.art_for(ch), 120))
	var who := VBoxContainer.new()
	who.add_child(UiKit.title(ch.name))
	var sp := Compendium.shared().display_name("species", str(ch.build.get("species", "")))
	var bg := Compendium.shared().display_name("backgrounds", str(ch.build.get("background", "")))
	who.add_child(UiKit.label("%s · %s · %s" % [ch.class_summary(), sp, bg], 16, "parchment"))
	var identity := ch.build.get("identity", {}) as Dictionary
	if not (identity.get("tags", []) as Array).is_empty():
		who.add_child(UiKit.label("Tags: " + ", ".join(identity["tags"] as Array), 14, "parchment"))
	head.add_child(who)
	_frame.add_child(head)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(1460, 560)
	_frame.add_child(tabs)
	_tab(tabs, "Overview", _overview(ch))
	_tab(tabs, "Abilities & Skills", _abilities(ch))
	_tab(tabs, "Features & Traits", _features(ch))
	_tab(tabs, "Spells", _spells(ch))
	_tab(tabs, "Active Effects", _effects(ch))
	_tab(tabs, "Notes", _notes(ch))


func _tab(tabs: TabContainer, title: String, content: Control) -> void:
	var s := UiKit.scroll(content, Vector2(1440, 520))
	s.name = title
	tabs.add_child(s)


func _overview(ch: Character) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(UiKit.stat("Armor Class", str(ch.ac_value()), ch.armor_class()))
	box.add_child(UiKit.stat("Hit Points", "%d / %d%s" % [ch.hp, ch.max_hp(), " (+%d temporary)" % ch.temp_hp if ch.temp_hp > 0 else ""], ch.max_hp_breakdown()))
	if ch.hp <= 0 and not ch.dead:
		box.add_child(UiKit.label("Unconscious · Death saves %d ✓ %d ✗%s" % [ch.death_successes, ch.death_failures, " · Stable" if ch.stable else ""], 15, "vampire_red"))
	box.add_child(UiKit.stat("Speed", "%d ft" % ch.speed().total(), ch.speed()))
	box.add_child(UiKit.stat("Initiative", ch.initiative_bonus().signed(), ch.initiative_bonus()))
	var pb := Breakdown.new("Proficiency Bonus")
	pb.add("Character level %d" % ch.character_level(), ch.proficiency_bonus())
	box.add_child(UiKit.stat("Proficiency Bonus", UiKit.signed(ch.proficiency_bonus()), pb))
	box.add_child(UiKit.stat("Carrying", "%.0f / %d lb" % [ch.carried_weight(), ch.carrying_capacity().total()], ch.carrying_capacity()))
	var hd := ch.hit_dice()
	var hd_text: Array[String] = []
	for d: String in hd:
		hd_text.append("%d of %dd%s" % [int((hd[d] as Dictionary)["total"]) - int((hd[d] as Dictionary)["spent"]), int((hd[d] as Dictionary)["total"]), d])
	box.add_child(UiKit.stat("Hit Point Dice", ", ".join(hd_text)))
	for e in ch.spellcasting:
		var cid := str(e["class_id"])
		box.add_child(UiKit.stat("Spell save DC", str(ch.spell_save_dc(cid).total()), ch.spell_save_dc(cid)))
		box.add_child(UiKit.stat("Spell attack", ch.spell_attack_bonus(cid).signed(), ch.spell_attack_bonus(cid)))
	var slots := ch.spell_slots()
	var parts: Array[String] = []
	for i in slots.size():
		if slots[i] > 0:
			parts.append("L%d %d/%d" % [i + 1, ch.slots_left(i + 1), slots[i]])
	if not parts.is_empty():
		box.add_child(UiKit.stat("Spell slots", " · ".join(parts)))
	for res_id: String in ch.resources:
		var r := ch.resources[res_id] as Dictionary
		box.add_child(UiKit.stat(str(r["name"]), "%d / %d (%s rest)" % [int(r["max"]) - int(r["used"]), int(r["max"]), str(r["recharge"]).replace("_one", ", one use").replace("_", " ")]))
	if ch.heroic_inspiration:
		box.add_child(UiKit.label("Heroic Inspiration: reroll one die (offered after a missed attack)", 15, "bile"))
	box.add_child(UiKit.header("Attacks"))
	for a in ch.attacks():
		var l := UiKit.label(a.describe(), 15, "vellum", 1300)
		l.tooltip_text = a.attack.describe() + "\n" + a.damage_bonus.describe()
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(l)
	return box


func _abilities(ch: Character) -> VBoxContainer:
	var box := VBoxContainer.new()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 30)
	for ab: StringName in Abilities.ALL:
		var col := VBoxContainer.new()
		var l := UiKit.label("%s %d (%s)" % [Creature.ABILITY_NAMES[ab], ch.ability_score(ab), UiKit.signed(ch.ability_mod(ab))], 18, "flame")
		l.tooltip_text = ch.ability_breakdown(ab).describe()
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(l)
		col.add_child(UiKit.stat("Saving throw%s" % (" ●" if ch.save_proficiency(ab) != "" else ""), ch.save_bonus(ab).signed(), ch.save_bonus(ab)))
		for skill: StringName in Abilities.SKILLS:
			if Abilities.SKILLS[skill] == ab:
				var rank := ch.skill_rank(skill)
				var mark := " ●●" if rank >= 2 else (" ●" if rank == 1 else "")
				col.add_child(UiKit.stat(str(skill).replace("_", " ").capitalize() + mark, ch.skill_bonus(skill).signed(), ch.skill_bonus(skill)))
		grid.add_child(col)
	box.add_child(grid)
	box.add_child(UiKit.header("Passive scores"))
	for skill: StringName in [&"perception", &"insight", &"investigation"]:
		box.add_child(UiKit.stat("Passive " + str(skill).capitalize(), str(ch.passive_score(skill).total()), ch.passive_score(skill)))
	box.add_child(UiKit.label("● proficient · ●● Expertise", 13, "parchment"))
	return box


func _features(ch: Character) -> VBoxContainer:
	var box := VBoxContainer.new()
	for f in ch.features:
		var line := "%s · %s" % [f["name"], f["source"]]
		if str(f["implemented"]) == "text":
			line += " · rules text only for now"
		box.add_child(UiKit.label(line, 16, "flame"))
		var text := str(f["text"]) if str(f["text"]) != "" else str(f["summary"])
		if text != "":
			box.add_child(UiKit.label(text, 14, "vellum", 1380))
	return box


func _spells(ch: Character) -> VBoxContainer:
	var box := VBoxContainer.new()
	var known := ch.known_spells()
	if known.is_empty():
		box.add_child(UiKit.label("No spells.", 15, "parchment"))
	var by_level := {}
	for k in known:
		var s := Compendium.shared().spell_data(str(k["id"]))
		var lvl := int(s.get("level", 0))
		if not by_level.has(lvl):
			by_level[lvl] = []
		(by_level[lvl] as Array).append({"k": k, "s": s})
	var levels: Array = by_level.keys()
	levels.sort()
	for lvl: int in levels:
		box.add_child(UiKit.header("Cantrips" if lvl == 0 else "Level %d" % lvl))
		for entry: Variant in by_level[lvl]:
			var k := (entry as Dictionary)["k"] as Dictionary
			var s := (entry as Dictionary)["s"] as Dictionary
			var tags: Array[String] = []
			if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
				tags.append("Concentration")
			if bool(s.get("ritual", false)):
				tags.append("Ritual")
			var how := str(k["kind"])
			var l := UiKit.label("%s · %s%s%s" % [s.get("name", k["id"]), str(s.get("school", "")).capitalize(),
				(" · " + ", ".join(tags)) if not tags.is_empty() else "", " · ★ always prepared" if how == "always" else (" · from " + str(k["source"]) if how in ["granted", "bonus"] else "")], 15, "vellum", 1380)
			l.tooltip_text = str(s.get("text", s.get("summary", "")))
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			box.add_child(l)
	return box


func _effects(ch: Character) -> VBoxContainer:
	var box := VBoxContainer.new()
	var conds := ch.active_conditions()
	if conds.is_empty() and ch.effects.is_empty() and ch.exhaustion == 0:
		box.add_child(UiKit.label("Nothing affecting %s right now." % ch.name, 15, "parchment"))
	for c in conds:
		var data := Compendium.shared().condition_data(str(c))
		box.add_child(UiKit.label("%s · from %s" % [str(c).capitalize(), ", ".join(ch.condition_sources(c))], 16, "flame"))
		box.add_child(UiKit.label(str(data.get("summary", "")), 14, "vellum", 1380))
	if ch.exhaustion > 0:
		box.add_child(UiKit.label("Exhaustion %d" % ch.exhaustion, 16, "candle"))
	for e in ch.effects:
		var mods: Array[String] = []
		for m in e.modifiers:
			mods.append(m.describe())
		box.add_child(UiKit.label("%s · %s%s" % [e.name, e.describe_duration(), " · Concentration" if e.concentration != null else ""], 16, "lilac"))
		if not mods.is_empty():
			box.add_child(UiKit.label(", ".join(mods), 14, "vellum", 1380))
	if ch.concentration != null:
		box.add_child(UiKit.label("Concentrating on %s" % ch.concentration.name, 15, "wick"))
	return box


func _notes(ch: Character) -> VBoxContainer:
	var box := VBoxContainer.new()
	var t := TextEdit.new()
	t.custom_minimum_size = Vector2(1380, 420)
	t.text = str(ch.build.get("notes", ""))
	t.text_changed.connect(func() -> void: ch.build["notes"] = t.text)
	box.add_child(t)
	return box


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).physical_keycode:
			KEY_RIGHT:
				index = (index + 1) % st.party.size()
				_draw()
			KEY_LEFT:
				index = posmod(index - 1, st.party.size())
				_draw()
