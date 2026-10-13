extends TestCase
## Spell Sniper (2024 PHB) in a fight: an enemy within 5 ft doesn't give its spell attacks Disadvantage, they ignore Half
## and Three-Quarters Cover, and attack-roll spells of 10 ft or more reach 60 ft farther; the roll, the target tooltip
## (ActionCatalog.spell_attack_preview) and the target check all agree (owner's report, 2026-10-13). With it, the other
## feats whose Firing in Melee lifts that Disadvantage: Sharpshooter for Ranged weapons, Crossbow Expert for crossbows.


func _wizard(sniper: bool) -> Character:
	var picks := {".4.ability_score_improvement": ["spell_sniper" if sniper else "ability_score_improvement"]}
	var ch := TestChars.custom("wizard", "human", 4, picks)
	assert_eq(ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "spell_sniper"), sniper, "Spell Sniper taken: %s" % sniper)
	var prepared := ch.spellcasting[0]["prepared"] as Array
	for sid: String in ["fire_bolt", "ray_of_sickness"]:
		if not sid in prepared:
			prepared.append(sid)
	return ch


func _attack_event(e: Encounter) -> Dictionary:
	var ev := {}
	for x: Dictionary in e.events:
		if str(x["type"]) == "attack":
			ev = x
	return ev


func _preview(e: Encounter, c: Combatant, spell_id: String, t: Combatant) -> Dictionary:
	var prev := (c.creature as Character).spell_preview(spell_id, 0)
	return ActionCatalog.new(e).spell_attack_preview(c, spell_id, t, prev["attack"] as Breakdown)


func _within_5(lines: Array) -> bool:
	return lines.any(func(s: Variant) -> bool: return str(s).contains("within 5 ft"))


func test_casting_in_melee_rolls_and_previews_without_disadvantage() -> void:
	for sniper: bool in [false, true]:
		var e := TestCombat.open_field()
		var c := e.add(_wizard(sniper), &"party", Vector2i(2, 3))
		TestCombat.punching_bag(e, Vector2i(3, 3))
		var far := TestCombat.punching_bag(e, Vector2i(8, 3))
		TestCombat.start_with(e, c)
		var pv := _preview(e, c, "fire_bolt", far)
		assert_eq(str(pv["edge"]), "" if sniper else "disadvantage", "the tooltip's edge, Spell Sniper %s" % sniper)
		assert_eq(_within_5(pv["lines"] as Array), not sniper, "the tooltip names the foe beside you only without it: %s" % str(pv["lines"]))
		e.events.clear()
		assert_true(e.spells.cast(c, "fire_bolt", 0, [far]).ok)
		var edge := (_attack_event(e).get("edge", {}) as Dictionary)
		assert_eq(str(edge.get("kind", "")), "" if sniper else "disadvantage", "the roll, Spell Sniper %s: %s" % [sniper, str(edge)])


func test_the_tooltip_shows_the_odds_the_roll_has() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_wizard(false), &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(3, 3))
	var far := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	var pv := _preview(e, c, "fire_bolt", far)
	var needs := int(pv["needs"])
	var single := (21 - needs) / 20.0
	assert_between(float(pv["chance"]), single * single - 0.0001, single * single + 0.0001, "Disadvantage squares the chance of a single d20")
	assert_true(str((pv["lines"] as Array)[0]).contains("hit %d%%" % roundi(single * single * 100.0)), str(pv["lines"]))


func test_bypass_cover_for_spell_attacks_in_the_roll_and_the_tooltip() -> void:
	for sniper: bool in [false, true]:
		var e := TestCombat.encounter(["......", "......", "..=...", "......"])
		var c := e.add(_wizard(sniper), &"party", Vector2i(0, 2))
		var t := TestCombat.punching_bag(e, Vector2i(5, 2))
		TestCombat.start_with(e, c)
		var sit := e.spells.attack_situation(c, Compendium.shared().spell_data("fire_bolt"), t)
		assert_eq(int(sit["cover_bonus"]), 0 if sniper else 2, "the low wall's Half Cover, Spell Sniper %s" % sniper)
		var pv := _preview(e, c, "fire_bolt", t)
		var ac := t.creature.ac_value() + (0 if sniper else 2)
		assert_true(str((pv["lines"] as Array)[0]).contains("vs AC %d" % ac), "the tooltip's AC: %s" % str(pv["lines"]))
		assert_eq((pv["lines"] as Array).any(func(s: Variant) -> bool: return str(s).contains("Half Cover")), not sniper, str(pv["lines"]))


func test_increased_range_reaches_targets_the_spell_alone_cannot() -> void:
	var rows: Array[String] = []
	for z in 3:
		rows.append(".".repeat(36))
	for sniper: bool in [false, true]:
		var e := TestCombat.encounter(rows)
		var c := e.add(_wizard(sniper), &"party", Vector2i(0, 1))
		var t := TestCombat.punching_bag(e, Vector2i(30, 1))
		TestCombat.start_with(e, c)
		var cat := ActionCatalog.new(e)
		var bolt := cat.find(c, "spell:fire_bolt")
		assert_false(bolt.is_empty(), "Fire Bolt is on the list")
		assert_eq(int(bolt["range"]), 180 if sniper else 120, "the range the target check uses, Spell Sniper %s" % sniper)
		var why := cat.target_why(c, bolt, t)
		assert_eq(why == "", sniper, "150 ft away, Spell Sniper %s: %s" % [sniper, why])
		assert_eq(e.spells.cast(c, "fire_bolt", 0, [t]).ok, sniper, "and the cast itself agrees")


func test_firing_in_melee_with_ranged_weapons_and_crossbows() -> void:
	# [class, feat, weapon, whether the foe beside you still gives Disadvantage]
	for row: Array in [["ranger", "ability_score_improvement", "longbow", true], ["ranger", "sharpshooter", "longbow", false],
			["ranger", "crossbow_expert", "light_crossbow", false], ["ranger", "crossbow_expert", "longbow", true]]:
		var ch := TestChars.custom(str(row[0]), "human", 4, {".4.ability_score_improvement": [str(row[1])]})
		ch.add_item(str(row[2]))
		ch.add_item("arrow" if str(row[2]) == "longbow" else "crossbow_bolt", 20)
		ch.equip(str(row[2]), "main_hand")
		var e := TestCombat.open_field()
		var c := e.add(ch, &"party", Vector2i(2, 3))
		TestCombat.punching_bag(e, Vector2i(3, 3))
		var far := TestCombat.punching_bag(e, Vector2i(8, 3))
		TestCombat.start_with(e, c)
		var option := {}
		for o in e.attack_options(c):
			if (o["profile"] as WeaponProfile).item_id == str(row[2]):
				option = o
		assert_false(option.is_empty(), "%s in hand" % row[2])
		var dis := e.attack_situation(c, far, option)["disadvantage"] as Array
		assert_eq(_within_5(dis), bool(row[3]), "%s with %s: %s" % [row[1], row[2], str(dis)])


func test_sharpshooter_leaves_a_thrown_psychic_blade_as_it_is() -> void:
	# A Psychic Blade is a Simple Melee weapon: thrown, it isn't a Ranged weapon for Sharpshooter's Firing in Melee.
	var ch := TestChars.custom("rogue", "human", 4, {"rogue_subclass": ["soulknife"], ".4.ability_score_improvement": ["sharpshooter"]})
	assert_true(ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "sharpshooter"), "took Sharpshooter")
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(3, 3))
	var far := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	var dis := e.attack_situation(c, far, e.option_by_id(c, "blade:thrown"))["disadvantage"] as Array
	assert_true(_within_5(dis), str(dis))
