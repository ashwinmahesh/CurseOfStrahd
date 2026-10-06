class_name LiveSheet
extends RefCounted
## The live character sheet beside creation and level up (docs/ui/character_creation.md "Live sheet"), in the
## sheet's look: the six ability medallions, the Armor Class shield and plaques for Initiative, Speed and Proficiency
## Bonus, then Hit Points, passive Perception, saves, the best attack and, for casters, spell DC, attack and slots.
## Every number's tooltip is its Breakdown. With `before` (level up), changed values carry ▲/▼ badges (shape, not
## only colour).

const WIDTH := 340.0


static func build(ch: Character, before: Character = null) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var who := UiKit.title(ch.name if ch.name != "" else "New character")
	who.add_theme_font_size_override("font_size", 24)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(who)
	var cls := UiKit.label(ch.class_summary() if not ch.class_order.is_empty() else "No class yet", 14, "gilt", WIDTH)
	cls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cls)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	for ab: StringName in Abilities.ALL:
		var full := str(Creature.ABILITY_NAMES[ab])
		var delta := ch.ability_score(ab) - before.ability_score(ab) if before != null else 0
		grid.add_child(UiParts.medallion(full, ch.ability_mod(ab), ch.ability_score(ab), func() -> Control:
			return UiParts.breakdown_tip(ch.ability_breakdown(ab), full, "%d (%s)" % [ch.ability_score(ab), UiKit.signed(ch.ability_mod(ab))]),
			100.0, delta))
	var centre := CenterContainer.new()
	centre.add_child(grid)
	box.add_child(centre)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiParts.shield(ch.ac_value(), func() -> Control: return UiParts.breakdown_tip(ch.armor_class(), "Armor Class"),
		_delta(ch.ac_value(), before.ac_value() if before != null else ch.ac_value())))
	var init := ch.initiative_bonus()
	row.add_child(UiParts.plaque(init.signed(), "Initiative", func() -> Control: return UiParts.breakdown_tip(init, "Initiative", init.signed()),
		"", _delta(init.total(), before.initiative_bonus().total() if before != null else init.total())))
	var speed := ch.speed()
	row.add_child(UiParts.plaque(str(speed.total()), "Speed", func() -> Control: return UiParts.breakdown_tip(speed, "Speed", "%d ft" % speed.total()),
		"FEET", _delta(speed.total(), before.speed().total() if before != null else speed.total())))
	var pb := Breakdown.new("Proficiency Bonus")
	pb.add("By character level", ch.proficiency_bonus())
	row.add_child(UiParts.plaque(UiKit.signed(ch.proficiency_bonus()), "Proficiency", func() -> Control:
		return UiParts.breakdown_tip(pb, "Proficiency Bonus", UiKit.signed(ch.proficiency_bonus())), "",
		_delta(ch.proficiency_bonus(), before.proficiency_bonus() if before != null else ch.proficiency_bonus())))
	box.add_child(row)
	var card := UiParts.card("ui_oxblood", "gilt_dark", 0.45, 8)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 1)
	card.add_child(list)
	list.add_child(_row("Hit Points", ch.max_hp_breakdown(), before.max_hp_breakdown() if before != null else null))
	list.add_child(_row("Passive Perception", ch.passive_score(&"perception"), before.passive_score(&"perception") if before != null else null))
	var saves: Array[String] = []
	for ab: StringName in Abilities.ALL:
		if ch.save_proficiency(ab) != "":
			saves.append("%s %s" % [Creature.ABILITY_SHORT[ab], UiKit.signed(ch.save_bonus(ab).total())])
	list.add_child(_text_row("Saves", ", ".join(saves) if not saves.is_empty() else "none proficient"))
	var attacks := ch.attacks()
	if not attacks.is_empty():
		var best := attacks[0]
		for a in attacks:
			if a.average_damage() > best.average_damage():
				best = a
		var bonus := best.damage_bonus.total()
		var dmg := best.damage_dice + ("%+d" % bonus if bonus != 0 else "") if not best.damage_dice.is_valid_int() else str(int(best.damage_dice) + bonus)
		var arow := _text_row(best.name, "%s · %s" % [best.attack.signed(), dmg])
		list.add_child(UiParts.tipped(arow, func() -> Control:
			var tb := VBoxContainer.new()
			tb.add_child(UiParts.breakdown_tip(best.attack, best.name, "%s to hit" % best.attack.signed()))
			tb.add_child(UiParts.breakdown_tip(best.damage_bonus, "Damage", "%s %s" % [dmg, str(best.damage_type).capitalize()]))
			return tb))
	for e in ch.spellcasting:
		var cid := str(e["class_id"])
		list.add_child(_row("Spell save DC (%s)" % ch.class_name_of(cid), ch.spell_save_dc(cid), null))
		list.add_child(_row("Spell attack", ch.spell_attack_bonus(cid), null, true))
	box.add_child(card)
	var slots := ch.spell_slots()
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	for i in slots.size():
		if slots[i] > 0:
			var chip := HBoxContainer.new()
			chip.add_theme_constant_override("separation", 4)
			chip.add_child(UiParts.caption(ActionCatalog._ordinal(i + 1), 11))
			chip.add_child(UiParts.pips(slots[i], slots[i], "moonlight"))
			flow.add_child(chip)
	if flow.get_child_count() > 0:
		box.add_child(UiParts.caption("Spell slots", 11))
		box.add_child(flow)
	else:
		flow.free()
	return box


static func _delta(now: int, was: int) -> int:
	return now - was


## "Hit Points  14 ▲7": the value, a badge when it changed, and its Breakdown on hover.
static func _row(name: String, b: Breakdown, before: Breakdown, signed: bool = false) -> Control:
	var v := b.total()
	var text := UiKit.signed(v) if signed else str(v)
	var row := _text_row(name, text)
	if before != null and before.total() != v:
		var d := v - before.total()
		var mark := UiKit.label(("▲%d" if d > 0 else "▼%d") % absi(d), 13, "bile" if d > 0 else "rose")
		row.add_child(mark)
	return UiParts.tipped(row, func() -> Control: return UiParts.breakdown_tip(b, name, text))


static func _text_row(name: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var n := UiKit.label(name, 14, "parchment")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	row.add_child(UiKit.label(value, 15, "vellum"))
	return row
