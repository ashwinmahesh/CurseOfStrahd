extends TestCase
## What a hero can do with an Opportunity Attack (owner's playtest, 2026-10-08): War Caster's Reactive Spell, picked from
## the prompt in place of the attack, and Divine Smite asked about once the attack hits.


## A level 4 wizard with War Caster (and Chromatic Orb prepared) beside a zombie whose turn it is.
func _war_caster() -> Dictionary:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("wizard", "human", 4, {"ability_score_improvement": ["war_caster"]})
	ch.heroic_inspiration = false
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "chromatic_orb" in prepared:
		prepared.append("chromatic_orb")
	TestCombat.give_components(ch, ["chromatic_orb"])   # its 50 gp diamond, kept
	var w := e.add(ch, &"party", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	z.creature.hp = 200
	TestCombat.start_with(e, z)
	return {"e": e, "w": w, "z": z}


func _choices(e: Encounter) -> Array:
	return e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["id"]))


func test_war_caster_offers_its_spells_in_place_of_the_opportunity_attack() -> void:
	var f := _war_caster()
	var e := f["e"] as Encounter
	var w := f["w"] as Combatant
	var z := f["z"] as Combatant
	assert_true(e.features.has_feat(w, "war_caster"), "built with War Caster")
	z.movement_left = 30
	var r := e.move(z, Vector2i(8, 3))
	assert_true(r.is_paused(), "the zombie leaving reach provokes")
	assert_eq(e.pending.kind, "opportunity_attack")
	var ids := _choices(e)
	assert_true("attack" in ids, "the melee attack is still there")
	assert_true("spell:chromatic_orb" in ids, "a levelled spell aimed at one creature: %s" % str(ids))
	assert_false(ids.any(func(i: String) -> bool: return i == "spell:shield" or i == "spell:burning_hands"), "no Reactions or areas")
	var slots := (w.creature as Character).slots_left(1)
	e.pending.selected_ids.assign(["spell:chromatic_orb"])
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	assert_false(w.reaction_available, "the Reaction is spent")
	assert_eq((w.creature as Character).slots_left(1), slots - 1, "Chromatic Orb takes its slot")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("answers with Chromatic Orb (War Caster")))


func test_no_pick_makes_the_melee_attack() -> void:
	var f := _war_caster()
	var e := f["e"] as Encounter
	var w := f["w"] as Combatant
	var z := f["z"] as Combatant
	z.movement_left = 30
	e.move(z, Vector2i(8, 3))
	assert_eq(e.pending.kind, "opportunity_attack")
	var slots := (w.creature as Character).slots_left(1)
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	assert_false(w.reaction_available)
	assert_eq((w.creature as Character).slots_left(1), slots, "no spell")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("makes an Opportunity Attack")))


func test_a_paladin_is_asked_to_smite_on_an_opportunity_attack_hit() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("paladin", "human", 5)
	ch.heroic_inspiration = false
	var p := e.add(ch, &"party", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	z.creature.hp = 200
	TestCombat.start_with(e, z)
	z.movement_left = 30
	e.move(z, Vector2i(8, 3))
	assert_eq(e.pending.kind, "opportunity_attack")
	TestCombat.next_d20(e, 19)
	e.answer_reaction(true)
	assert_true(e.pending != null and e.pending.kind == "divine_smite", "asked once the attack hits: %s" % (e.pending.kind if e.pending != null else "nothing"))
	var free := ch.resource_left("spell:divine_smite")
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	assert_eq(ch.resource_left("spell:divine_smite"), free - 1, "smitten on the Opportunity Attack")


# --- Eldritch Blast as the Reactive Spell sends one beam (Ashwin's ruling, 2026-10-19) -----------------------------
# Cast as an action it keeps every beam. The 2024 text would let all of them fly at the one creature leaving reach.

## Kip Smudgewick (Agonizing Blast on Eldritch Blast) at `level` with War Caster in place of his level 4 Ability Score
## Improvement, beside a zombie whose turn it is: {e, kip, z}.
func _blaster(level: int) -> Dictionary:
	var e := TestCombat.open_field(3)
	var ch := TestChars.pregen("kip_smudgewick", level)
	var picks := ch.build["choices"] as Dictionary
	picks["warlock.4.ability_score_improvement"] = ["war_caster"]
	picks.erase("warlock.4.ability_score_improvement/ability_score_improvement.abilities")
	picks["warlock.4.ability_score_improvement/war_caster.abilities"] = ["cha"]
	ch.refresh()
	ch.heroic_inspiration = false
	var kip := e.add(ch, &"party", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	z.creature.hp = 500
	TestCombat.start_with(e, z)
	return {"e": e, "kip": kip, "z": z}


## The attack rolls Eldritch Blast has made since event `from`.
func _beams_since(e: Encounter, from: int) -> int:
	var n := 0
	for i in range(from, e.events.size()):
		var ev := e.events[i] as Dictionary
		if str(ev.get("type", "")) == "attack" and str(ev.get("action", "")) == "spell:eldritch_blast":
			n += 1
	return n


## The zombie walks out of Kip's reach, Kip picks Eldritch Blast from the prompt: {pending, beams}.
func _blast_the_leaver(f: Dictionary) -> Dictionary:
	var e := f["e"] as Encounter
	var z := f["z"] as Combatant
	z.movement_left = 30
	var mark := e.events.size()
	e.move(z, Vector2i(8, 3))
	var asked := e.pending
	assert_true(asked != null and asked.kind == "opportunity_attack", "the zombie leaving reach provokes")
	if asked == null:
		return {"pending": null, "beams": 0}
	e.pending.selected_ids.assign(["spell:eldritch_blast"])
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	return {"pending": asked, "beams": _beams_since(e, mark)}


func test_a_reaction_eldritch_blast_sends_one_beam_whatever_the_level() -> void:
	for level: int in [5, 11]:
		var f := _blaster(level)
		var e := f["e"] as Encounter
		var kip := f["kip"] as Combatant
		assert_true(e.features.has_feat(kip, "war_caster"), "level %d: built with War Caster" % level)
		var beams := e.spells.specials.beams(kip)
		assert_eq(beams, 2 if level == 5 else 3, "level %d: the action cast has %d beams" % [level, beams])
		var out := _blast_the_leaver(f)
		assert_eq(out["beams"], 1, "level %d: one beam as a Reaction" % level)
		assert_false(kip.reaction_available, "level %d: the Reaction is spent" % level)


func test_the_prompt_and_the_log_say_it_is_one_beam_and_why() -> void:
	var f := _blaster(11)
	var e := f["e"] as Encounter
	var z := f["z"] as Combatant
	z.movement_left = 30
	e.move(z, Vector2i(8, 3))
	assert_eq(e.pending.kind, "opportunity_attack")
	var labels: Array = e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["label"]))
	assert_true("Eldritch Blast (cantrip, one beam)" in labels, "the pick says one beam: %s" % str(labels))
	assert_true(e.pending.text.contains("Eldritch Blast: one beam instead of 3, since a Reaction casting sends a single beam"), e.pending.text)
	e.pending.selected_ids.assign(["spell:eldritch_blast"])
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	assert_true(e.log.texts().any(func(t: String) -> bool:
		return t.contains("answers with Eldritch Blast (War Caster, one beam instead of 3, since a Reaction casting sends a single beam)")),
		"the log names what was given up and why")


func test_below_level_5_it_is_one_beam_anyway_and_says_so_plainly() -> void:
	var f := _blaster(4)
	var e := f["e"] as Encounter
	var z := f["z"] as Combatant
	z.movement_left = 30
	e.move(z, Vector2i(8, 3))
	assert_false(e.pending.text.contains("instead of"), "nothing was given up: %s" % e.pending.text)
	e.pending.selected_ids.assign(["spell:eldritch_blast"])
	e.answer_reaction(true)
	while e.pending != null:
		e.answer_reaction(false)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("answers with Eldritch Blast (War Caster, one beam)")))


func test_the_one_beam_keeps_agonizing_blast() -> void:
	var f := _blaster(11)
	var e := f["e"] as Encounter
	TestCombat.next_d20(e, 19)
	assert_eq(_blast_the_leaver(f)["beams"], 1)
	var z := f["z"] as Combatant
	assert_true(z.creature.hp < 500, "it hit")
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool:
		return (x.get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).contains("Agonizing Blast"))), "Agonizing Blast adds to that beam")


func test_the_action_cast_and_a_readied_one_keep_every_beam() -> void:
	var f := _blaster(11)
	var e := f["e"] as Encounter
	var kip := f["kip"] as Combatant
	var z := f["z"] as Combatant
	var mark := e.events.size()
	assert_true(e.spells.release_readied(kip, {"spell": "eldritch_blast", "slot": 0, "conc": null}, z) != null)
	assert_eq(_beams_since(e, mark), 3, "a readied cast released with the Reaction is the action's cast: all three beams")
	while e.pending != null:
		e.answer_reaction(false)
	f = _blaster(11)
	e = f["e"] as Encounter
	kip = f["kip"] as Combatant
	z = f["z"] as Combatant
	TestCombat.start_with(e, kip)
	mark = e.events.size()
	assert_true(e.spells.cast(kip, "eldritch_blast", 0, [z]).ok)
	assert_eq(_beams_since(e, mark), 3, "cast as an action it sends all three")
	while e.pending != null:
		e.answer_reaction(false)


func test_other_reactive_spells_are_not_touched() -> void:
	var f := _war_caster()
	var e := f["e"] as Encounter
	var z := f["z"] as Combatant
	z.movement_left = 30
	e.move(z, Vector2i(8, 3))
	var labels: Array = e.pending.target_choices.map(func(x: Dictionary) -> String: return str(x["label"]))
	assert_true("Chromatic Orb (level 1 slot)" in labels, str(labels))
	assert_false(e.pending.text.contains("beam"), "no beam note: %s" % e.pending.text)
	while e.pending != null:
		e.answer_reaction(false)


func test_a_foe_warlock_with_war_caster_answers_with_one_beam_too() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.pregen("kip_smudgewick", 11)
	var picks := ch.build["choices"] as Dictionary
	picks["warlock.4.ability_score_improvement"] = ["war_caster"]
	picks.erase("warlock.4.ability_score_improvement/ability_score_improvement.abilities")
	picks["warlock.4.ability_score_improvement/war_caster.abilities"] = ["cha"]
	ch.refresh()
	var foe := e.add(ch, &"enemy", Vector2i(4, 3))
	foe.reaction_rules["reactive_spell"] = "auto"
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3), 3)
	hero.creature.hp = 500
	TestCombat.start_with(e, hero)
	hero.movement_left = 30
	var mark := e.events.size()
	e.move(hero, Vector2i(0, 3))
	while e.pending != null:
		e.answer_reaction(false)
	assert_false(foe.reaction_available, "the foe used its Reaction")
	assert_eq(_beams_since(e, mark), 1, "one beam from a foe too")
