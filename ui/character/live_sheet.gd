class_name LiveSheet
extends RefCounted
## The live character sheet beside creation and level up (docs/ui/character_creation.md "Live sheet"): scores and
## modifiers, AC, Hit Points, Speed, Initiative, Proficiency Bonus, saves, main attack, passive Perception, and for
## casters spell DC, attack and slots. Every number's tooltip is its Breakdown. With `before`, changed values are
## marked ▲/▼ (shape, not only colour).


static func build(ch: Character, before: Character = null) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.add_child(UiKit.header(ch.name if ch.name != "" else "New character"))
	box.add_child(UiKit.label(ch.class_summary() if not ch.class_order.is_empty() else "No class yet", 14, "parchment", 330))
	var grid := GridContainer.new()
	grid.columns = 3
	for ab: StringName in Abilities.ALL:
		var score := ch.ability_score(ab)
		var mark := ""
		if before != null:
			mark = _mark(score, before.ability_score(ab))
		var l := UiKit.label("%s %d (%s)%s" % [Creature.ABILITY_SHORT[ab], score, UiKit.signed(ch.ability_mod(ab)), mark], 15,
			"gilt_light" if mark != "" else "vellum")
		l.tooltip_text = ch.ability_breakdown(ab).describe()
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.custom_minimum_size = Vector2(110, 0)
		grid.add_child(l)
	box.add_child(grid)
	box.add_child(_row("Armor Class", ch.armor_class(), before.armor_class() if before != null else null))
	box.add_child(_row("Hit Points", ch.max_hp_breakdown(), before.max_hp_breakdown() if before != null else null))
	box.add_child(_row("Speed", ch.speed(), before.speed() if before != null else null, " ft"))
	box.add_child(_row("Initiative", ch.initiative_bonus(), before.initiative_bonus() if before != null else null, "", true))
	var pb := Breakdown.new("Proficiency Bonus")
	pb.add("By character level", ch.proficiency_bonus())
	box.add_child(_row("Proficiency Bonus", pb, null, "", true))
	box.add_child(_row("Passive Perception", ch.passive_score(&"perception"), before.passive_score(&"perception") if before != null else null))
	var saves: Array[String] = []
	for ab: StringName in Abilities.ALL:
		if ch.save_proficiency(ab) != "":
			saves.append("%s %s" % [Creature.ABILITY_SHORT[ab], UiKit.signed(ch.save_bonus(ab).total())])
	box.add_child(UiKit.label("Saves: " + (", ".join(saves) if not saves.is_empty() else "none proficient"), 14, "parchment", 330))
	var attacks := ch.attacks()
	if not attacks.is_empty():
		var best := attacks[0]
		for a in attacks:
			if a.average_damage() > best.average_damage():
				best = a
		var al := UiKit.label("Attack: " + best.describe(), 14, "vellum", 330)
		al.tooltip_text = best.attack.describe() + "\n" + best.damage_bonus.describe()
		al.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(al)
	for e in ch.spellcasting:
		var cid := str(e["class_id"])
		box.add_child(_row("Spell save DC (%s)" % ch.class_name_of(cid), ch.spell_save_dc(cid), null))
		box.add_child(_row("Spell attack", ch.spell_attack_bonus(cid), null, "", true))
	var slots := ch.spell_slots()
	var parts: Array[String] = []
	for i in slots.size():
		if slots[i] > 0:
			parts.append("%d×L%d" % [slots[i], i + 1])
	if not parts.is_empty():
		box.add_child(UiKit.label("Spell slots: " + " ".join(parts), 14, "moonlight"))
	return box


static func _row(name: String, b: Breakdown, before: Breakdown, suffix: String = "", signed: bool = false) -> HBoxContainer:
	var v := b.total()
	var text := (UiKit.signed(v) if signed else str(v)) + suffix
	if before != null:
		text += _mark(v, before.total())
	return UiKit.stat(name, text, b)


static func _mark(now: int, was: int) -> String:
	if now > was:
		return " ▲%d" % (now - was)
	if now < was:
		return " ▼%d" % (was - now)
	return ""
