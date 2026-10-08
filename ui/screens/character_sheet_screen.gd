class_name CharacterSheetScreen
extends CanvasLayer
## The character sheet (docs/ui/party_management.md pm_02), laid out like Baldur's Gate 3's so it reads at a glance:
## - left, the hero: portrait, name, class and origin, the Hit Points bar, the Armor Class shield and plaques for
##   Initiative, Speed and Proficiency Bonus, then Hit Point Dice, passive scores, senses and load;
## - middle, the six abilities as medallions with their saving throws, and the 18 skills with proficiency marks;
## - right, tabs: Actions (attacks, spellcasting, slots, resources), Features, Spells (and casting outside a fight),
##   Equipment, Effects and Notes.
## Every number's tooltip lays its Breakdown out line by line, and long rules text lives in tooltips, not on the page.
## Left/right arrows (or the portrait chips) switch character, Q/E switch tab; Level up opens from here when a
## milestone allows it.
##
## In a fight (owner, 2026-10-08) the sheet opens view only, from a party frame's portrait or C: the fight waits under
## it, nothing on it can be changed or spent (no Level up, casting, inventory or notes), and Back to the fight, Esc or C
## close it with the turn as it was.

const TABS: Array[String] = ["Actions", "Features", "Spells", "Equipment", "Effects", "Notes"]
const TAB_ICONS := {"Actions": "attack", "Features": "character", "Spells": "spells", "Equipment": "inventory",
	"Effects": "rest", "Notes": "journal"}
## Names other screens used for the old tabs.
const TAB_ALIASES := {"Overview": "Actions", "Abilities & Skills": "Actions", "Features & Traits": "Features",
	"Inventory": "Equipment", "Active Effects": "Effects"}
const RECHARGE := {"short": ["Short Rest", "moonlight"], "long": ["Long Rest", "gilt"],
	"short_one": ["Long Rest · 1 back on a Short", "gilt"], "turn": ["Each turn", "bile"]}
const SCHOOL_COLOURS := {"abjuration": "moonlight", "conjuration": "candle", "divination": "silver",
	"enchantment": "lilac", "evocation": "rose", "illusion": "orchid", "necromancy": "sickly", "transmutation": "bile"}
const NICE_NAMES := {"martial_finesse_or_light": "Martial (Finesse or Light)", "thieves_cant": "Thieves' Cant",
	"shields": "Shields", "light": "Light", "medium": "Medium", "heavy": "Heavy"}
const HERO_W := 320.0
const MID_W := 424.0
## Text width inside the tab pane (the pane minus its margins and scroll bar).
const PANE_W := 570.0

var root: Node
var st: StoryState
var index := 0
var tab := "Actions"
var _frame: VBoxContainer
var _scroll: ScrollContainer
var _drawn := ""
var _cast_note := ""           ## what the last cast did, shown above the spell list
## Opened in a fight: view only (see the top).
var in_fight := false


func _init() -> void:
	name = "CharacterSheetScreen"
	layer = 30


func open(root_: Node, state: StoryState, index_: int) -> void:
	root = root_
	st = state
	index = clampi(index_, 0, st.party.size() - 1)
	_frame = UiKit.screen_frame(self, "Character Sheet", Vector2(1500, 850))
	_draw()


## Switches to a tab by its title ("Spells", "Effects" ...; the old names still work).
func show_tab(title: String) -> void:
	var t := str(TAB_ALIASES.get(title, title))
	tab = t if t in TABS else TABS[0]
	_draw()


func _ch() -> Character:
	return st.party[index]


func _draw() -> void:
	# Keep the scroll position when redrawing the same page (after casting a spell), not after switching.
	var key := "%d:%s" % [index, tab]
	var keep := _scroll.scroll_vertical if _scroll != null and is_instance_valid(_scroll) and key == _drawn else 0
	_drawn = key
	_scroll = null
	while _frame.get_child_count() > 0:
		var c := _frame.get_child(0)
		_frame.remove_child(c)
		c.queue_free()
	var ch := _ch()
	_frame.add_child(_party_strip(ch))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(body)
	body.add_child(_hero(ch))
	body.add_child(_column_rule())
	body.add_child(_abilities(ch))
	body.add_child(_column_rule())
	body.add_child(_tab_pane(ch))
	if _scroll != null and keep > 0:
		_restore_scroll(keep)


func _restore_scroll(v: int) -> void:
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = v


func _column_rule() -> Control:
	return UiParts.drawn(Vector2(2, 0), func(c: Control) -> void:
		var gilt := Color(Look.color("gilt_dark"), 0.8)
		c.draw_line(Vector2(1, 8), Vector2(1, c.size.y - 8), gilt, 1.0)
		UiParts.diamond(c, Vector2(1, 4), 3.0, Look.color("gilt"), true)
		UiParts.diamond(c, Vector2(1, c.size.y - 4), 3.0, Look.color("gilt"), true))


# --- The party ------------------------------------------------------------------------------------

func _party_strip(ch: Character) -> HBoxContainer:
	var strip := UiParts.party_chips(st.party, index, func(i: int) -> void:
		index = i
		_draw())
	if not in_fight and st.can_level_up(ch):
		var up := UiKit.button("Level up", func() -> void: root.call("open_screen", "level_up", index), 16)
		up.custom_minimum_size = Vector2(0, 46)
		up.add_theme_color_override("font_color", Look.color("gilt_light"))
		strip.add_child(up)
	strip.add_child(UiParts.gap())
	var hint := UiKit.label("", 13, "bone")
	if in_fight:
		PadGlyphs.hint(hint, "View only in a fight   ·   ← →  character   ·   Q  E  tab   ·   Esc or C: back",
			"View only in a fight   ·   {lt} {rt}  character   ·   {lb} {rb}  tab   ·   {b}: back")
	else:
		PadGlyphs.hint(hint, "← →  character   ·   Q  E  tab   ·   hover a number to see where it comes from",
			"{lt} {rt}  character   ·   {lb} {rb}  tab   ·   {y} on a number: where it comes from")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(hint)
	if in_fight:
		# The way back, at the far right, clear of the title's crest.
		var back := UiKit.button("Back to the fight", _close, 16)
		back.custom_minimum_size = Vector2(0, 46)
		strip.add_child(back)
	return strip


# --- Left: the hero -------------------------------------------------------------------------------

func _hero(ch: Character) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(HERO_W, 0)
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 196.0, ch.hp <= 0, ch.dead))
	var who := UiKit.title(ch.name)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(who)
	var cls := UiKit.label(ch.class_summary(), 16, "gilt", HERO_W)
	cls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cls)
	var sp := Compendium.shared().display_name("species", str(ch.build.get("species", "")))
	var bg := Compendium.shared().display_name("backgrounds", str(ch.build.get("background", "")))
	var origin := UiKit.label("%s · %s" % [sp, bg], 14, "parchment")
	origin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(origin)
	col.add_child(_hit_points(ch))
	col.add_child(_core_numbers(ch))
	col.add_child(_details(ch))
	return col


func _hit_points(ch: Character) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	head.add_child(UiParts.label("HIT POINTS", 12, "parchment", UiParts.caps_font()))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	if ch.dead:
		head.add_child(UiParts.pill("Dead", "vampire_red"))
	elif ch.hp <= 0:
		head.add_child(UiParts.pill("Stable" if ch.stable else "Unconscious", "vampire_red"))
	elif ch.is_bloodied():
		head.add_child(UiParts.pill("Bloodied", "vampire_red"))
	if ch.temp_hp > 0:
		head.add_child(UiParts.pill("+%d temporary" % ch.temp_hp, "moonlight"))
	box.add_child(head)
	box.add_child(UiParts.hp_bar(ch, HERO_W))
	if ch.dead:
		box.add_child(UiKit.label("Only magic such as Revivify can bring %s back." % ch.name.get_slice(" ", 0), 13, "rose", HERO_W))
	elif ch.hp <= 0:
		var saves := HBoxContainer.new()
		saves.add_theme_constant_override("separation", 8)
		saves.add_child(UiKit.label("Death saves", 13, "parchment"))
		saves.add_child(UiParts.pips(3, ch.death_successes, "bile"))
		saves.add_child(UiParts.pips(3, ch.death_failures, "vampire_red"))
		box.add_child(saves)
	return box


## The Armor Class shield, then Initiative, Speed and Proficiency Bonus.
func _core_numbers(ch: Character) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiParts.shield(ch.ac_value(), func() -> Control:
		return UiParts.breakdown_tip(ch.armor_class(), "Armor Class")))
	var init := ch.initiative_bonus()
	row.add_child(UiParts.plaque(init.signed(), "Initiative", func() -> Control:
		return UiParts.breakdown_tip(init, "Initiative", init.signed())))
	var speed := ch.speed()
	row.add_child(UiParts.plaque(str(speed.total()), "Speed", func() -> Control:
		var other: Array[String] = []
		for kind: String in ["climb", "swim", "fly"]:
			if ch.speed(kind).total() > 0:
				other.append("%s %d ft" % [kind.capitalize(), ch.speed(kind).total()])
		return UiParts.breakdown_tip(speed, "Speed", "%d ft" % speed.total(), ", ".join(other)), "FEET"))
	var pb := Breakdown.new("Proficiency Bonus")
	pb.add("Character level %d" % ch.character_level(), ch.proficiency_bonus())
	row.add_child(UiParts.plaque(UiKit.signed(ch.proficiency_bonus()), "Proficiency", func() -> Control:
		return UiParts.breakdown_tip(pb, "Proficiency Bonus", UiKit.signed(ch.proficiency_bonus()),
			"Added to attacks, saves and skills you're proficient in, and to your spell save DC.")))
	return row


## Hit Point Dice, passive scores, senses, size and load as a compact two-column list.
func _details(ch: Character) -> PanelContainer:
	var card := UiParts.card("ui_oxblood", "gilt_dark", 0.45, 8)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 1)
	card.add_child(list)
	var hd := ch.hit_dice()
	var hd_text: Array[String] = []
	for d: String in hd:
		var e := hd[d] as Dictionary
		hd_text.append("%d / %d d%s" % [int(e["total"]) - int(e["spent"]), int(e["total"]), d])
	list.add_child(_detail("Hit Point Dice", ", ".join(hd_text), func() -> Control:
		return UiParts.rules_tip("Hit Point Dice", "Left / total", "On a Short Rest, spend any number: roll each and add your Constitution modifier to heal. A Long Rest restores them all.")))
	for skill: StringName in [&"perception", &"insight", &"investigation"]:
		var b := ch.passive_score(skill)
		list.add_child(_detail("Passive " + str(skill).capitalize(), str(b.total()), func() -> Control:
			return UiParts.breakdown_tip(b, "Passive " + str(skill).capitalize())))
	var senses: Array[String] = []
	if ch.darkvision() > 0:
		senses.append("Darkvision %d ft" % ch.darkvision())
	for kind: String in ["blindsight", "tremorsense", "truesight"]:
		if ch.sense_range(kind) > 0:
			senses.append("%s %d ft" % [kind.capitalize(), ch.sense_range(kind)])
	list.add_child(_detail("Senses", ", ".join(senses) if not senses.is_empty() else "—", Callable()))
	var cap := ch.carrying_capacity()
	var carried := ch.carried_weight()
	list.add_child(_detail("Carrying", "%.0f / %d lb" % [carried, cap.total()], func() -> Control:
		return UiParts.breakdown_tip(cap, "Carrying capacity", "%d lb" % cap.total(), "Carrying %.1f lb." % carried),
		"rose" if carried > cap.total() else "vellum"))
	list.add_child(_detail("Size", str(ch.size).capitalize(), Callable()))
	if ch.heroic_inspiration:
		list.add_child(_detail("Heroic Inspiration", "Ready", func() -> Control:
			return UiParts.rules_tip("Heroic Inspiration", "", "Reroll one die right after rolling it and use the new roll. The game offers it after a missed attack."), "gilt_light"))
	if ch.exhaustion > 0:
		list.add_child(_detail("Exhaustion", "Level %d" % ch.exhaustion, func() -> Control:
			return UiParts.rules_tip("Exhaustion %d" % ch.exhaustion, "",
				str(Compendium.shared().condition_data("exhaustion").get("summary", ""))), "rose"))
	return card


func _detail(name_text: String, value: String, tip: Callable, colour: String = "vellum") -> Control:
	var row := HBoxContainer.new()
	var n := UiKit.label(name_text, 14, "parchment")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	var v := UiKit.label(value, 15, colour)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	if not tip.is_valid():
		return row
	return UiParts.tipped(row, tip)


# --- Middle: abilities, saves and skills ---------------------------------------------------------

func _abilities(ch: Character) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(MID_W, 0)
	col.add_theme_constant_override("separation", 8)
	col.add_child(UiParts.section("Abilities & Saves"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	for ab: StringName in Abilities.ALL:
		grid.add_child(_ability_cell(ch, ab))
	var centre := CenterContainer.new()
	centre.add_child(grid)
	col.add_child(centre)
	col.add_child(UiParts.section("Skills"))
	var card := UiParts.card("ui_oxblood", "gilt_dark", 0.45, 8)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	card.add_child(cols)
	var skills: Array = Abilities.SKILLS.keys()
	skills.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	var half := ceili(skills.size() / 2.0)
	for part in 2:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 0)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in range(part * half, mini(skills.size(), (part + 1) * half)):
			list.add_child(_skill_row(ch, skills[i] as StringName))
		cols.add_child(list)
	col.add_child(card)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 6)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_child(UiParts.mark(1))
	legend.add_child(UiKit.label("Proficient", 12, "parchment"))
	legend.add_child(Control.new())
	legend.add_child(UiParts.mark(2))
	legend.add_child(UiKit.label("Expertise", 12, "parchment"))
	legend.add_child(Control.new())
	legend.add_child(UiParts.mark(0))
	legend.add_child(UiKit.label("Untrained", 12, "parchment"))
	col.add_child(legend)
	return col


func _ability_cell(ch: Character, ab: StringName) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	var full := str(Creature.ABILITY_NAMES[ab])
	cell.add_child(UiParts.medallion(full, ch.ability_mod(ab), ch.ability_score(ab), func() -> Control:
		return UiParts.breakdown_tip(ch.ability_breakdown(ab), full, "%d (%s)" % [ch.ability_score(ab), UiKit.signed(ch.ability_mod(ab))],
			"Modifier = (score − 10) ÷ 2, rounded down.")))
	var save := ch.save_bonus(ab)
	var prof := ch.save_proficiency(ab)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiParts.mark(1 if prof != "" else 0))
	row.add_child(UiKit.label("Save", 13, "gilt" if prof != "" else "parchment"))
	row.add_child(UiParts.label(save.signed(), 17, "ivory" if prof != "" else "vellum", UiParts.figure_font()))
	cell.add_child(UiParts.tipped(row, func() -> Control:
		return UiParts.breakdown_tip(save, "%s saving throw" % full, save.signed(), ("Proficient from %s." % prof) if prof != "" else "")))
	return cell


func _skill_row(ch: Character, skill: StringName) -> Control:
	var rank := ch.skill_rank(skill)
	var b := ch.skill_bonus(skill)
	var nice := str(skill).replace("_", " ").capitalize().replace(" Of ", " of ")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 25)
	row.add_child(UiParts.mark(rank))
	var n := UiKit.label(nice, 14, "gilt_light" if rank > 0 else "vellum")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	row.add_child(UiKit.label(str(Creature.ABILITY_SHORT[Abilities.SKILLS[skill]]), 11, "bone"))
	var v := UiParts.label(b.signed(), 16, "ivory" if rank > 0 else "vellum", UiParts.figure_font())
	v.custom_minimum_size = Vector2(30, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return UiParts.tipped(row, func() -> Control:
		var why := "Expertise: twice the Proficiency Bonus." if rank >= 2 else ("Proficient." if rank == 1 else "")
		return UiParts.breakdown_tip(b, nice, b.signed(), why))


# --- Right: the tabs ------------------------------------------------------------------------------

func _tab_pane(ch: Character) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.add_child(UiParts.tab_strip(TABS, tab, func(t: String) -> void:
		tab = t
		_draw(), TAB_ICONS))
	var pane := UiParts.pane()
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(pane)
	if tab == "Notes":
		pane.add_child(_notes(ch))
		return col
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.add_child(_scroll)
	var content: Control
	match tab:
		"Features":
			content = _features(ch)
		"Spells":
			content = _spells(ch)
		"Equipment":
			content = _equipment(ch)
		"Effects":
			content = _effects(ch)
		_:
			content = _actions(ch)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	return col


func _tab_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	return box


func _row(content: Control, tip: Callable = Callable()) -> Control:
	return UiParts.row(content, tip)


func _empty(text: String) -> Label:
	var l := UiKit.label(text, 15, "bone", PANE_W)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# --- Actions --------------------------------------------------------------------------------------

func _actions(ch: Character) -> VBoxContainer:
	var box := _tab_box()
	box.add_child(UiParts.section("Attacks"))
	for a in ch.attacks():
		box.add_child(_attack_row(a))
	if not ch.spellcasting.is_empty():
		box.add_child(UiParts.section("Spellcasting"))
		for e in ch.spellcasting:
			box.add_child(_caster_row(ch, str(e["class_id"])))
	var slots := _slots_strip(ch)
	if slots != null:
		box.add_child(slots)
	if not ch.resources.is_empty():
		box.add_child(UiParts.section("Resources"))
		for res_id: String in ch.resources:
			box.add_child(_resource_row(ch, res_id))
	return box


func _attack_row(a: WeaponProfile) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var n := UiKit.label(a.name, 16, "vellum")
	n.custom_minimum_size = Vector2(170, 0)
	n.clip_text = true
	row.add_child(n)
	var hit := UiParts.label(a.attack.signed(), 20, "gilt_light", UiParts.figure_font())
	hit.custom_minimum_size = Vector2(38, 0)
	hit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(hit)
	row.add_child(UiKit.label("to hit", 12, "parchment"))
	var dmg := UiParts.label(_damage_text(a), 18, "ivory", UiParts.figure_font())
	dmg.custom_minimum_size = Vector2(70, 0)
	dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(dmg)
	row.add_child(UiKit.label(str(a.damage_type).capitalize(), 13, "parchment"))
	row.add_child(UiParts.gap())
	row.add_child(UiKit.label(_reach_text(a), 12, "bone"))
	if a.mastery != "":
		row.add_child(UiParts.pill(a.mastery.capitalize(), "moonlight"))
	return _row(row, func() -> Control:
		var box := VBoxContainer.new()
		box.add_child(UiParts.breakdown_tip(a.attack, a.name, "%s to hit" % a.attack.signed()))
		box.add_child(UiParts.breakdown_tip(a.damage_bonus, "Damage", "%s %s" % [_damage_text(a), str(a.damage_type).capitalize()],
			"Dice: %s" % a.damage_dice))
		var extra: Array[String] = []
		if not a.properties.is_empty():
			extra.append("Properties: " + ", ".join(a.properties.map(func(p: Variant) -> String: return str(p).capitalize())))
		if a.mastery != "":
			extra.append("Mastery %s: %s" % [a.mastery.capitalize(), ActionCatalog.MASTERY_TEXT.get(a.mastery, "")])
		for t in a.notes:
			extra.append(t)
		if not a.proficient:
			extra.append("Not proficient: no Proficiency Bonus on the attack.")
		if not extra.is_empty():
			box.add_child(UiParts.wrapped("\n".join(extra), 13, "moonlight", UiParts.TIP_WIDTH))
		return box)


## "1d8+3", or a flat number when the dice are flat (an Unarmed Strike's 1 + Str).
func _damage_text(a: WeaponProfile) -> String:
	var bonus := a.damage_bonus.total()
	if a.damage_dice.is_valid_int():
		return str(int(a.damage_dice) + bonus)
	return a.damage_dice + ("%+d" % bonus if bonus != 0 else "")


func _reach_text(a: WeaponProfile) -> String:
	if a.melee and not a.thrown:
		return "Reach %d ft" % a.reach
	return "Range %d/%d ft" % [a.normal_range, a.long_range]


func _caster_row(ch: Character, class_id: String) -> Control:
	var e := ch.spellcasting_entry(class_id)
	var ab := StringName(str(e.get("ability", "int")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", -2)
	who.add_child(UiKit.label(ch.class_name_of(class_id), 16, "vellum"))
	who.add_child(UiKit.label("casts with %s" % Creature.ABILITY_NAMES[ab], 12, "parchment"))
	who.custom_minimum_size = Vector2(170, 0)
	row.add_child(who)
	row.add_child(UiParts.gap())
	var dc := ch.spell_save_dc(class_id)
	var atk := ch.spell_attack_bonus(class_id)
	row.add_child(_figure_pair("Save DC", str(dc.total()), func() -> Control: return UiParts.breakdown_tip(dc, "Spell save DC")))
	row.add_child(_figure_pair("Spell attack", atk.signed(), func() -> Control: return UiParts.breakdown_tip(atk, "Spell attack", atk.signed())))
	return _row(row)


func _figure_pair(caption: String, value: String, tip: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UiKit.label(caption, 13, "parchment"))
	row.add_child(UiParts.label(value, 20, "gilt_light", UiParts.figure_font()))
	var t := UiParts.tipped(row, tip)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## Spell slots by level as lozenges ("1st ◆◆◇"), Pact Magic slots included and noted.
func _slots_strip(ch: Character) -> Control:
	var slots := ch.spell_slots()
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 4)
	var pact := ch.pact_magic()
	for i in slots.size():
		if slots[i] <= 0:
			continue
		var lvl := i + 1
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 6)
		chip.add_child(UiParts.label(ActionCatalog._ordinal(lvl), 12, "parchment", UiParts.caps_font()))
		chip.add_child(UiParts.pips(slots[i], ch.slots_left(lvl), "moonlight"))
		flow.add_child(UiParts.tipped(chip, func() -> Control:
			var pact_here := int(pact["count"]) if int(pact["level"]) == lvl else 0
			var body := "A slot of this level casts a spell of this level or lower."
			var note := ""
			if pact_here >= slots[i]:
				body += " These are Pact Magic slots: they come back on a Short or Long Rest."
			else:
				body += " They come back on a Long Rest."
				if pact_here > 0:
					note = "Includes %d Pact Magic slot%s, which come back on a Short Rest too." % [pact_here, "" if pact_here == 1 else "s"]
			return UiParts.rules_tip("Level %d spell slots" % lvl, "%d of %d left" % [ch.slots_left(lvl), slots[i]], body, [], note)))
	if flow.get_child_count() == 0:
		flow.free()
		return null
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(UiKit.label("Spell slots", 13, "parchment"))
	box.add_child(flow)
	return _row(box)


func _resource_row(ch: Character, res_id: String) -> Control:
	var r := ch.resources[res_id] as Dictionary
	var left := ch.resource_left(res_id)
	var total := ch.resource_max(res_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var n := UiKit.label(str(r["name"]), 16, "vellum" if left > 0 else "bone")
	n.custom_minimum_size = Vector2(190, 0)
	row.add_child(n)
	row.add_child(UiParts.pips(total, left))
	row.add_child(UiParts.gap())
	if res_id.begins_with("spell:"):
		row.add_child(UiParts.pill("Free cast", "lilac"))
	var rc := RECHARGE.get(str(r["recharge"]), [str(r["recharge"]).capitalize(), "gilt"]) as Array
	row.add_child(UiParts.pill(str(rc[0]), str(rc[1])))
	return _row(row, func() -> Control:
		var body := ""
		if res_id.begins_with("spell:"):
			body = str(Compendium.shared().spell_data(res_id.get_slice(":", 1)).get("summary", ""))
		else:
			for f in ch.features:
				if str(f["name"]) == str(r["name"]) or str(f["id"]) == res_id:
					body = str(f["text"]) if str(f["text"]) != "" else str(f["summary"])
					break
		return UiParts.rules_tip(str(r["name"]), "From %s" % r["source"], body,
			[["Uses", "%d of %d left" % [left, total]], ["Comes back", str(rc[0])]]))


# --- Features -------------------------------------------------------------------------------------

func _features(ch: Character) -> VBoxContainer:
	var box := _tab_box()
	var groups := {}
	var order: Array[String] = []
	var titles := {}
	for cid in ch.class_order:
		var key := "class:" + cid
		order.append(key)
		titles[key] = "%s %d" % [ch.class_name_of(cid), ch.class_level_of(cid)]
		if ch.subclasses.has(cid):
			titles[key] += " · " + Compendium.shared().display_name("subclasses", str(ch.subclasses[cid]))
	for f in ch.features:
		var kind := str(f["source_kind"])
		var key := "other"
		if kind in ["class", "subclass"]:
			key = "class:" + str(f["class_id"])
			if kind == "class" and str(f["name"]).ends_with(" Subclass") and ch.subclasses.has(str(f["class_id"])):
				continue    # the placeholder that asked for the subclass; the group's title names it
		elif kind in ["species", "lineage"]:
			key = "species"
			titles[key] = "Species · " + Compendium.shared().display_name("species", str(ch.build.get("species", "")))
		elif kind == "background":
			key = "background"
			titles[key] = "Background · " + Compendium.shared().display_name("backgrounds", str(ch.build.get("background", "")))
		elif kind == "feat":
			key = "feat"
			titles[key] = "Feats"
		if not groups.has(key):
			groups[key] = []
			if not key in order:
				order.append(key)
		(groups[key] as Array).append(f)
	for key in order:
		if not groups.has(key):
			continue
		box.add_child(UiParts.section(str(titles.get(key, "Other"))))
		for f: Variant in groups[key]:
			box.add_child(_feature_row(f as Dictionary))
	box.add_child(UiParts.section("Training & Languages"))
	box.add_child(_training(ch))
	return box


func _feature_row(f: Dictionary) -> Control:
	return UiParts.feature_row(f, _feature_source(f), PANE_W)


## "Level 3", "Life Domain 3", or the feat's name ("Magic Initiate").
func _feature_source(f: Dictionary) -> String:
	var src := str(f["source"])
	match str(f["source_kind"]):
		"class":
			return "Level %d" % int(f["level"])
		"subclass":
			return src
		"feat":
			return src.get_slice(" (", 0)
	return ""


func _training(ch: Character) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	var rows := [["Armor", ch.proficiency_list("armor")], ["Weapons", ch.proficiency_list("weapons")],
		["Tools", ch.proficiency_list("tools")], ["Languages", ch.proficiency_list("languages")]]
	var masteries: Array[String] = []
	for w in ch.weapon_masteries:
		var item := Compendium.shared().item_data(w)
		var m := str((item.get("weapon", {}) as Dictionary).get("mastery", ""))
		masteries.append("%s (%s)" % [item.get("name", w), m.capitalize()] if m != "" else str(item.get("name", w)))
	rows.append(["Weapon Mastery", masteries])
	for r: Variant in rows:
		var pair := r as Array
		var names: Array[String] = []
		for id: Variant in pair[1]:
			names.append(_nice(str(id)))
		if names.is_empty() and str(pair[0]) == "Weapon Mastery":
			continue
		var cap := UiParts.label(str(pair[0]).to_upper(), 11, "parchment", UiParts.caps_font())
		cap.custom_minimum_size = Vector2(120, 0)
		grid.add_child(cap)
		grid.add_child(UiKit.label(", ".join(names) if not names.is_empty() else "—", 14, "vellum", PANE_W - 160.0))
	return _row(grid)


func _nice(id: String) -> String:
	if NICE_NAMES.has(id):
		return str(NICE_NAMES[id])
	if id.contains(" ") or id.contains("("):
		return id
	var item := Compendium.shared().item_data(id)
	if not item.is_empty():
		return str(item.get("name", id))
	return id.replace("_", " ").capitalize()


# --- Spells ---------------------------------------------------------------------------------------

func _spells(ch: Character) -> VBoxContainer:
	var box := _tab_box()
	if _cast_note != "":
		var note := UiKit.label(_cast_note, 15, "bile", PANE_W - 20.0)
		box.add_child(_row(note))
	for e in ch.spellcasting:
		box.add_child(_caster_row(ch, str(e["class_id"])))
	var known := ch.known_spells()
	if known.is_empty():
		box.add_child(_empty("%s doesn't cast spells." % ch.name.get_slice(" ", 0)))
		return box
	var casts := {}
	var utility := {}
	if not in_fight:   # spells are cast from the hotbar in a fight
		for o in FieldCasting.options(st.party, ch, Dice.roller):
			casts[str(o["id"])] = o
		for o in FieldCasting.utility_options(st.party, ch, Dice.roller):
			utility[str(o["id"])] = o
	var unique: Array = []
	var seen := {}
	for k in known:
		if not seen.has(str(k["id"])):
			seen[str(k["id"])] = true
			unique.append(k)
	var slots := ch.spell_slots()
	# By spell level under a heading each, alphabetical within (SpellGroups, the order every spell list uses).
	for g in SpellGroups.groups(unique, func(k: Dictionary) -> String: return str(k["id"])):
		var lvl := int(g["level"])
		var right: Control = null
		if lvl > 0 and lvl <= slots.size() and slots[lvl - 1] > 0:
			right = UiParts.pips(slots[lvl - 1], ch.slots_left(lvl), "moonlight")
		box.add_child(UiParts.section(str(g["heading"]), right))
		for kv: Variant in g["items"]:
			var k := kv as Dictionary
			var s := Compendium.shared().spell_data(str(k["id"]))
			box.add_child(_spell_row(ch, k, s, casts.get(str(k["id"]), {}) as Dictionary, utility.get(str(k["id"]), {}) as Dictionary))
	return box


func _spell_row(ch: Character, k: Dictionary, s: Dictionary, cast: Dictionary, util: Dictionary) -> Control:
	var id := str(k["id"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var school := str(s.get("school", ""))
	if UiParts.has_icons():
		UiParts.add_icon(row, "spell", id, 36.0)
	else:
		row.add_child(UiParts.drawn(Vector2(10, 22), func(c: Control) -> void:
			UiParts.diamond(c, Vector2(5, 12), 5.0, Look.color(str(SCHOOL_COLOURS.get(school, "parchment"))), true)))
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	head.add_child(UiKit.label(str(s.get("name", id)), 16, "vellum"))
	var how := str(k["kind"])
	if how == "always":
		head.add_child(UiParts.pill("Always prepared", "gilt"))
	elif how in ["granted", "bonus"]:
		head.add_child(UiParts.pill(str(k["source"]), "lilac"))
	var unit := str((s.get("casting_time", {}) as Dictionary).get("unit", "action"))
	if unit in ["bonus_action", "reaction"]:
		var tag := UiParts.ACTION_TAGS[unit] as Array
		head.add_child(UiParts.pill(str(tag[0]), str(tag[1])))
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		head.add_child(UiParts.pill("Conc.", "moonlight"))
	if bool(s.get("ritual", false)):
		head.add_child(UiParts.pill("Ritual", "bile"))
	if st.spell_active(id):
		head.add_child(UiParts.pill("Active", "bile"))
	left.add_child(head)
	left.add_child(UiKit.label(_spell_facts(ch, k, s), 13, "parchment"))
	row.add_child(left)
	if not cast.is_empty():
		_cast_controls(ch, cast, row)
	elif not util.is_empty():
		_utility_controls(ch, util, row)
	return _row(row, func() -> Control: return _spell_tip(ch, k, s))


## The line under a spell's name: how long it takes (unless a tag says so), its range, and what it does
## ("Action · 120 ft · 2d10 Fire").
func _spell_facts(ch: Character, k: Dictionary, s: Dictionary) -> String:
	var parts: Array[String] = []
	var ct := s.get("casting_time", {}) as Dictionary
	match str(ct.get("unit", "action")):
		"action":
			parts.append("Action")
		"minute":
			parts.append("%d min" % int(ct.get("amount", 1)))
		"hour":
			parts.append("%d hr" % int(ct.get("amount", 1)))
	var r := s.get("range", {}) as Dictionary
	parts.append("%d ft" % int(r["feet"]) if str(r.get("kind", "")) == "feet" else _range(s))
	var p := ch.spell_preview(str(k["id"]))
	if p.has("damage_dice"):
		var bonus := (p["damage_bonus"] as Breakdown).total()
		parts.append("%s%s %s" % [p["damage_dice"], "%+d" % bonus if bonus != 0 else "", str(p["damage_type"]).capitalize()])
	elif p.has("heal_dice"):
		var hb := (p["heal_bonus"] as Breakdown).total()
		parts.append("heals %s%s" % [p["heal_dice"], "%+d" % hb if hb != 0 else ""])
	else:
		var d := _duration(s).replace("Concentration, up to ", "")
		if d != "Instantaneous":
			parts.append(d)
	if p.has("save_dc"):
		parts.append("%s save" % Creature.ABILITY_SHORT.get(StringName(str(p["save"])), str(p["save"])))
	elif p.has("attack"):
		parts.append("spell attack")
	return "  ·  ".join(parts)


func _spell_tip(ch: Character, k: Dictionary, s: Dictionary) -> Control:
	var lvl := int(s.get("level", 0))
	var school := str(s.get("school", "")).capitalize()
	var facts: Array = [["Casting time", _casting_time(s)], ["Range", _range(s)], ["Components", _components(s)],
		["Duration", _duration(s)]]
	var p := ch.spell_preview(str(k["id"]))
	if p.has("attack"):
		facts.append(["Attack", (p["attack"] as Breakdown).signed()])
	if p.has("save_dc"):
		facts.append(["Save", "%s DC %d" % [Creature.ABILITY_NAMES.get(StringName(str(p["save"])), str(p["save"])), (p["save_dc"] as Breakdown).total()]])
	if p.has("damage_dice"):
		var bonus := (p["damage_bonus"] as Breakdown).total()
		facts.append(["Damage", "%s%s %s" % [p["damage_dice"], "%+d" % bonus if bonus != 0 else "", str(p["damage_type"]).capitalize()]])
	if p.has("heal_dice"):
		var hb := (p["heal_bonus"] as Breakdown).total()
		facts.append(["Healing", "%s%s" % [p["heal_dice"], "%+d" % hb if hb != 0 else ""]])
	var how := str(k["kind"])
	var foot := "From %s" % k["source"]
	if how == "always":
		foot += ": always prepared, and doesn't count against your prepared spells."
	elif how == "granted" and int(k.get("uses", 0)) > 0:
		foot += ": cast it %d time%s without a slot per %s." % [int(k["uses"]), "" if int(k["uses"]) == 1 else "s",
			"Short or Long Rest" if str(k["recharge"]) == "short" else "Long Rest"]
	var text := str(s.get("text", "")) if str(s.get("text", "")) != "" else str(s.get("summary", ""))
	return UiParts.rules_tip(str(s.get("name", k["id"])), ("%s cantrip" % school) if lvl == 0 else "Level %d %s" % [lvl, school],
		text, facts, foot)


func _casting_time(s: Dictionary) -> String:
	var ct := s.get("casting_time", {}) as Dictionary
	var amount := int(ct.get("amount", 1))
	var out := ""
	match str(ct.get("unit", "action")):
		"action":
			out = "Action"
		"bonus_action":
			out = "Bonus Action"
		"reaction":
			out = "Reaction"
		"minute":
			out = "%d minute%s" % [amount, "" if amount == 1 else "s"]
		"hour":
			out = "%d hour%s" % [amount, "" if amount == 1 else "s"]
		_:
			out = str(ct.get("unit", "")).capitalize()
	var trigger := str(ct.get("trigger", "")).trim_suffix(".")
	if trigger != "":
		out += ", " + trigger.left(1).to_lower() + trigger.substr(1)
	if bool(s.get("ritual", false)):
		out += " (or a Ritual: +10 minutes, no slot)"
	return out


func _range(s: Dictionary) -> String:
	var r := s.get("range", {}) as Dictionary
	var kind := str(r.get("kind", ""))
	if kind == "feet":
		return "%d feet" % int(r["feet"])
	if kind == "miles":
		return "%d mile%s" % [int(r["miles"]), "" if int(r["miles"]) == 1 else "s"]
	return kind.capitalize()


func _components(s: Dictionary) -> String:
	var c := s.get("components", {}) as Dictionary
	var parts: Array[String] = []
	if bool(c.get("v", false)):
		parts.append("V")
	if bool(c.get("s", false)):
		parts.append("S")
	if c.has("m"):
		parts.append("M (%s)" % c["m"] if c["m"] is String else "M")
	return ", ".join(parts) if not parts.is_empty() else "None"


func _duration(s: Dictionary) -> String:
	var d := s.get("duration", {}) as Dictionary
	var kind := str(d.get("kind", ""))
	var amount := int(d.get("amount", 1))
	var out := ""
	match kind:
		"instantaneous":
			out = "Instantaneous"
		"until_dispelled":
			out = "Until dispelled"
		"rounds", "minutes", "hours", "days":
			out = "%d %s" % [amount, kind.trim_suffix("s") if amount == 1 else kind]
		_:
			out = kind.replace("_", " ").capitalize()
	if bool(d.get("concentration", false)):
		out = "Concentration, up to " + out.to_lower()
	return out


## Healing and helpful spells outside a fight (FieldCasting): a slot picker when it can go at more than one level,
## and a Cast menu listing who it can go on.
func _cast_controls(ch: Character, o: Dictionary, row: HBoxContainer) -> void:
	var id := str(o["id"])
	if not bool(o["legal"]):
		var no := UiParts.small_button("Cast", func() -> void: pass, "spells")
		no.disabled = true
		no.tooltip_text = str(o["reason"])
		row.add_child(no)
		return
	var lvl := int(o["level"])
	var pick := OptionButton.new()
	if bool(o["free"]):
		pick.add_item("free", lvl)
	for sl: int in o["slots"] as Array:
		pick.add_item(ActionCatalog._ordinal(sl) + " slot", sl)
	UiParts.compact(pick)
	pick.visible = pick.item_count > 1
	row.add_child(pick)
	if bool(o["self_only"]):
		row.add_child(UiParts.small_button("Cast", func() -> void: _do_cast(ch, id, pick, [ch]), "spells"))
		return
	var menu := MenuButton.new()
	menu.text = "Cast on…"
	menu.flat = false
	UiKit.button_look(menu)
	UiParts.compact(menu)
	menu.icon = UiKit.icon("spells")
	var popup := menu.get_popup()
	for i in st.party.size():
		popup.add_item(st.party[i].name, i)
	var count := int(o["count"])
	if count > 1:
		popup.add_separator()
		popup.add_item("%d of us" % mini(count, st.party.size()), 100)
	popup.id_pressed.connect(func(pid: int) -> void:
		var tgt: Array[Character] = []
		if pid == 100:
			for t in st.party:
				if tgt.size() < count:
					tgt.append(t)
		else:
			tgt.append(st.party[pid])
		_do_cast(ch, id, pick, tgt))
	row.add_child(menu)


## Exploring spells (Light, Detect Magic, Find Traps ...): Cast, or as a Ritual.
func _utility_controls(ch: Character, o: Dictionary, row: HBoxContainer) -> void:
	var resource_controls: VBoxContainer
	if not (o.get("resource_casts", []) as Array).is_empty():
		resource_controls = VBoxContainer.new()
		row.add_child(resource_controls)
		var normal_controls := HBoxContainer.new()
		resource_controls.add_child(normal_controls)
		row = normal_controls
	var id := str(o["id"])
	var cast := UiParts.small_button("Cast", func() -> void: _do_utility(ch, id, false), "spells")
	cast.disabled = not bool(o["legal"])
	cast.tooltip_text = str(o["reason"])
	row.add_child(cast)
	for feature: Dictionary in o.get("resource_casts", []):
		var rule := feature["resource_cast"] as Dictionary
		var feat_id := str(feature["id"])
		var resource_button := UiParts.small_button(str(feature["name"]), func() -> void: _do_utility(ch, id, false, feat_id), "spells")
		resource_button.disabled = ch.resource_left(str(rule["resource"])) < int(rule["cost"]) or ch.hp <= 0 or ch.dead
		resource_button.tooltip_text = "Spend %d %s; no spell slot or Material components" % [int(rule["cost"]), str((ch.resources[str(rule["resource"])] as Dictionary).get("name", rule["resource"]))]
		resource_controls.add_child(resource_button)
	if bool(o["ritual"]):
		var rit := UiParts.small_button("Ritual", func() -> void: _do_utility(ch, id, true))
		rit.tooltip_text = "As a Ritual: 10 more minutes, no slot"
		row.add_child(rit)


func _do_utility(ch: Character, spell_id: String, ritual: bool, resource_feature: String = "") -> void:
	var res := FieldCasting.cast_utility(st, ch, spell_id, ritual, 0, resource_feature)
	_cast_note = str(res["text"])
	if bool(res["ok"]) and root != null and root.get("view") != null:
		(root.get("view") as LocationView).apply_spell_effect(spell_id)
	_draw()


func _do_cast(ch: Character, spell_id: String, pick: OptionButton, targets: Array) -> void:
	var tgt: Array[Character] = []
	for t: Variant in targets:
		tgt.append(t as Character)
	var slot := pick.get_item_id(pick.selected) if pick.item_count > 0 and pick.selected >= 0 else 0
	var res := FieldCasting.cast(st.party, ch, spell_id, slot, tgt, Dice.roller)
	_cast_note = str(res["text"]) if str(res["text"]) != "" else "Done."
	_draw()


# --- Equipment ------------------------------------------------------------------------------------

func _equipment(ch: Character) -> VBoxContainer:
	var box := _tab_box()
	box.add_child(UiParts.section("Worn and wielded"))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	for slot in Character.EQUIP_SLOTS:
		slots.add_child(_slot_card(ch, slot))
	box.add_child(slots)
	box.add_child(UiParts.section("Attunement", UiParts.pips(Character.MAX_ATTUNED, ch.attuned.size(), "lilac")))
	if ch.attuned.is_empty():
		box.add_child(UiKit.label("No attuned magic items (%d at most; attuning takes a Short Rest)." % Character.MAX_ATTUNED, 14, "bone", PANE_W))
	for item_id in ch.attuned:
		var data := Compendium.shared().item_data(item_id)
		box.add_child(_row(UiKit.label(str(data.get("name", item_id)), 15, "lilac"), _item_tip(data)))
	box.add_child(UiParts.section("Pack"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for e in ch.inventory:
		if str(e["slot"]) != "" or int(e["qty"]) <= 0:
			continue
		var data := Compendium.shared().item_data(str(e["id"]))
		var text := str(data.get("name", e["id"])) + (" ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else "")
		var chip := UiParts.card("ui_black", "gilt_dark", 0.8, 5)
		var chip_row := HBoxContainer.new()
		chip_row.add_theme_constant_override("separation", 6)
		UiParts.add_icon(chip_row, "item", str(e["id"]), 24.0)
		chip_row.add_child(UiKit.label(text, 14, "vellum"))
		chip.add_child(chip_row)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(UiParts.tipped(chip, _item_tip(data)))
	if flow.get_child_count() == 0:
		flow.add_child(UiKit.label("Nothing else carried.", 14, "bone"))
	box.add_child(flow)
	box.add_child(UiParts.section("Load"))
	var cap := ch.carrying_capacity()
	var carried := ch.carried_weight()
	var load := HBoxContainer.new()
	load.add_theme_constant_override("separation", 12)
	load.add_child(UiParts.bar(carried, cap.total(), 0.0, "%.0f / %d lb" % [carried, cap.total()],
		"vampire_red" if carried > cap.total() else "gilt_dark", func() -> Control:
			return UiParts.breakdown_tip(cap, "Carrying capacity", "%d lb" % cap.total(), "Carrying %.1f lb." % carried), 300.0))
	load.add_child(UiKit.label("Party purse: %d gp" % int(st.gold), 15, "gilt_light"))
	box.add_child(load)
	if in_fight:
		return box   # gear changes wait for the fight to end
	var open := UiKit.button("Open inventory", func() -> void: root.call("open_screen", "inventory", index), 15, "inventory")
	open.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(open)
	return box


func _slot_card(ch: Character, slot: String) -> Control:
	var item := ch.equipped(slot)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.add_child(UiParts.label(slot.replace("_", " ").to_upper(), 11, "parchment", UiParts.caps_font()))
	if item.is_empty():
		col.add_child(UiKit.label("Empty", 15, "bone"))
	else:
		col.add_child(UiKit.label(str(item.get("name", "")), 15, "vellum", 160.0))
		col.add_child(UiKit.label(_item_stat(ch, item), 14, "gilt_light"))
	var card := UiParts.card("ui_oxblood", "gilt_dark", 0.55, 8)
	card.custom_minimum_size = Vector2(0, 84)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(col)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.is_empty():
		return card
	var t := UiParts.tipped(card, _item_tip(item))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return t


## The one number that matters about a worn or wielded item: its AC, or its damage for this character.
func _item_stat(ch: Character, item: Dictionary) -> String:
	if Gear.is_shield(item):
		return "+%d AC" % int((item["armor"] as Dictionary).get("base_ac", 2))
	if Gear.is_armor(item):
		var arm := item["armor"] as Dictionary
		return "AC %d · %s" % [int(arm.get("base_ac", 10)), str(arm.get("kind", "")).capitalize()]
	if Gear.is_weapon(item):
		var p := WeaponProfile.build(ch, item)
		return "%s to hit · %s" % [p.attack.signed(), _damage_text(p)]
	return ""


func _item_tip(data: Dictionary) -> Callable:
	return func() -> Control:
		var sub := str(data.get("category", "")).capitalize()
		var magic := data.get("magic", {}) as Dictionary
		if not magic.is_empty():
			sub = "%s magic item" % str(magic.get("rarity", "")).replace("_", " ").capitalize()
		var body := str(data.get("text", "")) if str(data.get("text", "")) != "" else str(data.get("summary", ""))
		return UiParts.rules_tip(str(data.get("name", "")), sub, body,
			[["Weight", "%s lb" % str(data.get("weight_lb", 0))], ["Value", "%s gp" % str(data.get("cost_gp", 0))]])


# --- Effects --------------------------------------------------------------------------------------

func _effects(ch: Character) -> VBoxContainer:
	var box := _tab_box()
	var conds := ch.active_conditions()
	if conds.is_empty() and ch.effects.is_empty() and ch.exhaustion == 0 and ch.concentration == null:
		box.add_child(_empty("Nothing is affecting %s right now." % ch.name.get_slice(" ", 0)))
		return box
	if ch.concentration != null:
		box.add_child(_effect_row("Concentrating on %s" % ch.concentration.name, "A Constitution save when damaged keeps it going.",
			ch.name.get_slice(" ", 0), "", "gilt_light"))
	for c in conds:
		var data := Compendium.shared().condition_data(str(c))
		box.add_child(_effect_row(str(c).capitalize(), str(data.get("summary", "")), ", ".join(ch.condition_sources(c)), "",
			"rose", str(data.get("text", ""))))
	if ch.exhaustion > 0:
		var ex := Compendium.shared().condition_data("exhaustion")
		box.add_child(_effect_row("Exhaustion %d" % ch.exhaustion, str(ex.get("summary", "")), "", "until a Long Rest", "rose",
			str(ex.get("text", ""))))
	for e in ch.effects:
		var mods: Array[String] = []
		for m in e.modifiers:
			mods.append(_modifier_text(m))
		for c in e.conditions:
			mods.append(str(c).capitalize())
		var what := ", ".join(mods)
		var text := ""
		if e.source_kind == &"spell":
			var spell := Compendium.shared().spell_data(e.source_id)
			text = str(spell.get("text", spell.get("summary", "")))
			if str(spell.get("summary", "")) != "" and what == "":
				what = str(spell["summary"])
		var conc := " · Concentration" if e.concentration != null else ""
		box.add_child(_effect_row(e.name, what, _effect_source(e) + conc, e.describe_duration(), "moonlight", text))
	return box


## A modifier in a few words ("+2 AC", "Advantage on Dex saves", "+1d4 to attacks and saves").
func _modifier_text(m: Modifier) -> String:
	var v: Variant = m.data.get("value", 0)
	var amount := UiKit.signed(int(v)) if (v is int or v is float) else str(v).replace("_", " ")
	var on: Variant = m.data.get("on", "")
	var targets := ", ".join(PackedStringArray((on as Array).map(func(x: Variant) -> String: return str(x)))) if on is Array else str(on)
	targets = targets.replace("save:all", "saves").replace("save:", "").replace("attack:", "").replace(":", " ").replace("_", " ")
	var ab := str(m.data.get("ability", m.data.get("skill", "all"))).replace("_", " ")
	match str(m.stat):
		"ac":
			return "%s AC" % amount
		"ac_min":
			return "AC at least %s" % amount
		"ac_formula":
			return "Base AC %s" % str(m.data.get("base", ""))
		"save":
			return "%s to %s saves" % [amount, "all" if ab == "all" else ab.capitalize()]
		"check":
			return "%s to %s checks" % [amount, "all" if ab == "all" else ab.capitalize()]
		"initiative", "attack", "damage", "spell_dc", "spell_attack", "hp_max", "d20":
			var names := {"initiative": "Initiative", "attack": "attack rolls", "damage": "damage", "spell_dc": "spell save DC",
				"spell_attack": "spell attacks", "hp_max": "Hit Point maximum", "d20": "D20 Tests"}
			return "%s to %s" % [amount, names[str(m.stat)]]
		"speed":
			return "%s ft Speed" % amount
		"speed_set":
			return "Speed %s" % str(v)
		"speed_percent":
			return "Speed × %d%%" % int(v)
		"advantage", "disadvantage":
			return "%s on %s" % [str(m.stat).capitalize(), targets]
		"bonus_die", "penalty_die":
			return "%s%s to %s" % ["+" if m.stat == &"bonus_die" else "−", str(m.data.get("dice", "")), targets]
		"resistance", "vulnerability", "immunity":
			return "%s to %s" % [str(m.stat).capitalize(), str(v).capitalize()]
		"condition_immunity":
			return "Immune to %s" % str(v).capitalize()
		"extra_damage":
			return "+%s %s on hits" % [str(m.data.get("dice", "")), str(m.data.get("type", "")).capitalize()]
	return str(m.stat).replace("_", " ").capitalize()


func _effect_source(e: Effect) -> String:
	for m in st.party:
		if m.id == e.caster_id and e.caster_id != "":
			return m.name.get_slice(" ", 0)
	return str(e.source_kind).capitalize()


func _effect_row(title_text: String, summary: String, source: String, duration: String, colour: String, text: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UiKit.label(title_text, 16, colour))
	if summary != "":
		left.add_child(UiKit.label(summary, 14, "vellum", 360.0))
	row.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(160, 0)
	if source != "":
		right.add_child(UiKit.label(source, 13, "lilac"))
	if duration != "":
		right.add_child(UiKit.label(duration, 13, "gilt_light"))
	row.add_child(right)
	if text == "":
		return _row(row)
	return _row(row, func() -> Control: return UiParts.rules_tip(title_text, source, text))


# --- Notes ----------------------------------------------------------------------------------------

func _notes(ch: Character) -> Control:
	var t := TextEdit.new()
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.placeholder_text = "Notes about %s: names, promises, suspicions ..." % ch.name.get_slice(" ", 0)
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.add_theme_font_size_override("font_size", 16)
	t.text = str(ch.build.get("notes", ""))
	t.editable = not in_fight
	t.text_changed.connect(func() -> void: ch.build["notes"] = t.text)
	return t


func _close() -> void:
	root.call("close_screen")


func _unhandled_input(event: InputEvent) -> void:
	if in_fight and (event.is_action_pressed(&"combat_cancel") or event is InputEventKey \
			and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).physical_keycode == KEY_C):
		# In a fight the world's input waits (the tree is paused), so the sheet closes itself.
		get_viewport().set_input_as_handled()
		_close()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).physical_keycode:
			KEY_RIGHT:
				index = (index + 1) % st.party.size()
				_draw()
			KEY_LEFT:
				index = posmod(index - 1, st.party.size())
				_draw()
			KEY_E:
				tab = TABS[(TABS.find(tab) + 1) % TABS.size()]
				_draw()
			KEY_Q:
				tab = TABS[posmod(TABS.find(tab) - 1, TABS.size())]
				_draw()
