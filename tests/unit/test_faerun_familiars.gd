extends TestCase
## The Arcana Unleashed familiar feats switched on in batch 7 (Familiar Friend, Elemental, Otherworldly and Soothing
## Familiar) and the Familiar Trainer background, taken through the real level-up path and used in a fight.


func _hero(e: Encounter, class_id: String, cell: Vector2i, level: int = 3, feat_id: String = "", picks: Dictionary = {}) -> Combatant:
	var p := picks.duplicate()
	if feat_id != "":
		p[".4.ability_score_improvement"] = [feat_id]
	var ch := TestChars.custom(class_id, "human", level, p, "familiar_trainer")
	if feat_id != "":
		assert_true(ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == feat_id), "took %s" % feat_id)
	return e.add(ch, &"party", cell)


func _ch(c: Combatant) -> Character:
	return c.creature as Character


func _find(e: Encounter, c: Combatant, id: String) -> Dictionary:
	return ActionCatalog.new(e).find(c, id)


func _called(e: Encounter, c: Combatant) -> Combatant:
	assert_true(e.spells.precast(c, "find_familiar"), "Find Familiar before the fight")
	var fam := e.faerun.familiar_of(c)
	assert_true(fam != null, "a familiar on the field")
	return fam


func test_the_familiar_feats_and_background_are_offered() -> void:
	var comp := Compendium.shared()
	var bgs := comp.all_playable("backgrounds").map(func(b: Dictionary) -> String: return str(b["id"]))
	assert_true("familiar_trainer" in bgs, "Familiar Trainer offered")
	var origin := comp.feats_in("origin").map(func(f: Dictionary) -> String: return str(f["id"]))
	assert_true("familiar_friend" in origin, "Familiar Friend offered")
	var general := comp.feats_in("general").map(func(f: Dictionary) -> String: return str(f["id"]))
	for id: String in ["elemental_familiar", "otherworldly_familiar", "soothing_familiar"]:
		assert_true(id in general, "%s offered" % id)
	assert_false("warlike_familiar" in general, "Warlike Familiar waits for Battle Familiar")


func test_familiar_friend_casts_free_and_fortifies_the_familiar() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "fighter", Vector2i(2, 3), 3)
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var ch := _ch(c)
	assert_true(ch.knows_spell("find_familiar"), "always prepared, even for a fighter")
	assert_eq(ch.resource_left("spell:find_familiar"), 1, "one free casting")
	var fam := _called(e, c)
	assert_eq(ch.resource_left("spell:find_familiar"), 0, "the free casting spent")
	assert_eq(fam.creature.max_hp(), 1 + 2 * 3, "an owl's 1 Hit Point plus twice the character level")
	assert_eq(fam.creature.hp, fam.creature.max_hp())


func test_a_familiar_called_as_a_ritual_stays_until_lost() -> void:
	var ch := TestChars.custom("wizard", "human", 3, {}, "familiar_trainer")
	var st := StoryState.new()
	st.party.append(ch)
	var e := TestCombat.open_field(3)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	EncounterSetup.bring_familiars(e, [c])
	assert_true(e.faerun.familiar_of(c) == null, "no familiar until Find Familiar is cast")
	var slots := ch.slots_left(1)
	var before := st.total_minutes()
	assert_true(bool(FieldCasting.cast_utility(st, ch, "find_familiar", true)["ok"]), "cast as a Ritual while exploring")
	assert_eq(ch.familiar, "here")
	assert_eq(ch.slots_left(1), slots, "no slot")
	assert_eq(ch.resource_left("spell:find_familiar"), 1, "nor the free casting")
	assert_eq(st.total_minutes() - before, 70, "an hour and the Ritual's ten minutes")
	# The next fight: it comes along, and dropping to 0 Hit Points loses it.
	var e2 := TestCombat.open_field(3)
	var c2 := e2.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e2, Vector2i(9, 3))
	EncounterSetup.bring_familiars(e2, [c2])
	var fam := e2.faerun.familiar_of(c2)
	assert_true(fam != null, "the familiar joins the fight")
	e2.deal_damage(null, fam, [{"amount": 100, "type": "force"}], false, "test")
	assert_eq(ch.familiar, "", "gone until cast again")
	var e3 := TestCombat.open_field(3)
	var c3 := e3.add(ch, &"party", Vector2i(2, 3))
	EncounterSetup.bring_familiars(e3, [c3])
	assert_true(e3.faerun.familiar_of(c3) == null, "and missing from the next fight")


func test_a_familiar_in_its_pocket_dimension_stays_there_and_a_dismissed_one_is_gone() -> void:
	var ch := TestChars.custom("wizard", "human", 3, {}, "familiar_trainer")
	ch.familiar = "here"
	var e := TestCombat.open_field(3)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	EncounterSetup.bring_familiars(e, [c])
	TestCombat.start_with(e, c)
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:familiar_away")).ok)
	assert_eq(ch.familiar, "pocket")
	var e2 := TestCombat.open_field(3)
	var c2 := e2.add(ch, &"party", Vector2i(2, 3))
	EncounterSetup.bring_familiars(e2, [c2])
	var fam := e2.faerun.familiar_of(c2)
	assert_true(fam != null and fam.has_meta("pocket"), "still in its pocket dimension next fight")
	TestCombat.punching_bag(e2, Vector2i(9, 3))
	TestCombat.start_with(e2, c2)
	assert_true(ActionCatalog.new(e2).perform(c2, _find(e2, c2, "feat:fr:familiar_back")).ok, "called back")
	assert_eq(ch.familiar, "here")
	c2.action_available = true
	c2.magic_action_used = false
	assert_true(ActionCatalog.new(e2).perform(c2, _find(e2, c2, "feat:fr:familiar_dismiss")).ok)
	assert_eq(ch.familiar, "", "dismissed for good")


func test_helpful_friend_gives_advantage_beside_the_familiar() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "wizard", Vector2i(2, 3), 3)
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var fam := _called(e, c)
	fam.cell = c.cell + Vector2i(1, 0)
	var ch := _ch(c)
	var left := ch.resource_left("helpful_friend")
	assert_eq(left, ch.proficiency_bonus(), "Proficiency Bonus uses")
	var t := c.creature.roll_check(e.dice, &"arcana", 10)
	assert_true(t.advantage_sources.has("Helpful Friend"), "Advantage on Arcana, a proficient skill")
	assert_eq(ch.resource_left("helpful_friend"), left - 1, "a use spent")
	assert_false(c.creature.roll_check(e.dice, &"str", 10).advantage_sources.has("Helpful Friend"), "not a plain ability check")
	fam.cell = c.cell + Vector2i(3, 0)
	assert_false(c.creature.roll_check(e.dice, &"arcana", 10).advantage_sources.has("Helpful Friend"), "not with the familiar away")
	fam.cell = c.cell + Vector2i(1, 0)
	c.reaction_rules["helpful_friend"] = "never"
	assert_false(c.creature.roll_check(e.dice, &"arcana", 10).advantage_sources.has("Helpful Friend"), "Off saves the uses")
	assert_eq(ch.resource_left("helpful_friend"), left - 1)
	# Outside a fight: before a proficient check, never after a failed one.
	assert_eq(CheckAids.before_check(ch, &"arcana"), ["Helpful Friend"] as Array[String], "Advantage before the roll")
	assert_eq(ch.resource_left("helpful_friend"), left - 2, "spent")
	assert_true(CheckAids.before_check(ch, &"str").is_empty(), "not a plain ability check")
	var failed := D20Test.from_natural(D20Test.Kind.ABILITY_CHECK, 2, 0, 25)
	assert_false(CheckAids.options(ch, failed).any(func(a: Dictionary) -> bool: return str(a["id"]) == "helpful_friend"), "a failed check isn't reopened")


func test_elemental_familiar_resists_and_bursts() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "wizard", Vector2i(2, 3), 4, "elemental_familiar", {"elemental_familiar_resistance": ["cold"]})
	var foe := TestCombat.punching_bag(e, Vector2i(8, 3), 200)
	TestCombat.start_with(e, c)
	var fam := _called(e, c)
	assert_true(fam.creature.modifiers_for(&"resistance").any(func(m: Modifier) -> bool: return m.text("value") == "cold"), "Cold Resistance")
	fam.cell = foe.cell + Vector2i(-1, 0)
	foe.creature.add_effect(Effect.new("Dull").with_modifier("auto_fail", {"on": "save:dex"}))
	var a := _find(e, c, "feat:fr:elemental_familiar")
	assert_false(a.is_empty(), "a Bonus Action command")
	assert_eq(str(a.get("reason", "")), "", "ready")
	var hp := foe.creature.hp
	assert_true(ActionCatalog.new(e).perform(c, a).ok)
	assert_true(foe.creature.hp < hp, "2d4 Cold on a failed save")
	assert_true(foe.creature.has_condition(&"prone"), "and knocked Prone")
	assert_false(fam.reaction_available, "the familiar's Reaction")
	assert_false(c.bonus_available, "the wizard's Bonus Action")
	c.bonus_available = true
	assert_ne(str(_find(e, c, "feat:fr:elemental_familiar").get("reason", "")), "", "once per familiar Reaction")


func test_otherworldly_familiar_passes_through_walls() -> void:
	var rows: Array[String] = []
	for z in 8:
		rows.append("......#.....")
	var e := TestCombat.encounter(rows, 3)
	var c := _hero(e, "wizard", Vector2i(2, 3), 4, "otherworldly_familiar", {"otherworldly_familiar_resistance": ["psychic"]})
	TestCombat.punching_bag(e, Vector2i(10, 6))
	TestCombat.start_with(e, c)
	var fam := _called(e, c)
	assert_true(fam.creature.modifiers_for(&"resistance").any(func(m: Modifier) -> bool: return m.text("value") == "psychic"), "Psychic Resistance")
	fam.cell = Vector2i(5, 3)
	e.end_turn()
	assert_eq(e.current(), fam, "the familiar's turn")
	fam.movement_left = 60
	var through := e.move(fam, Vector2i(7, 3))
	assert_true(through.ok, "through the wall: %s" % through.reason)
	assert_eq(fam.cell, Vector2i(7, 3))
	assert_true(e.move(fam, Vector2i(6, 3)).ok, "into the wall")
	e.end_turn()
	assert_eq(fam.cell, Vector2i(7, 3), "back to the last open space it left")


func test_soothing_familiar_lifts_low_healing_dice() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "wizard", Vector2i(2, 3), 4, "soothing_familiar")
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var fam := _called(e, c)
	fam.cell = ally.cell + Vector2i(0, 1)
	assert_eq(e.heal_floor(ally), 3, "an ally beside the familiar")
	assert_eq(e.heal_floor(foe), 0, "not a foe")
	for i in 10:
		assert_true(int(e.heal_roll("8d4", ally, "test")["total"]) >= 24, "every die counts at least 3")
	fam.cell = ally.cell + Vector2i(0, 3)
	assert_eq(e.heal_floor(ally), 0, "away from the familiar")


func test_the_familiar_goes_to_its_pocket_dimension_and_comes_back() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "wizard", Vector2i(2, 3), 3)
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var fam := _called(e, c)
	var away := _find(e, c, "feat:fr:familiar_away")
	assert_eq(str(away.get("reason", "?")), "", "a Magic action")
	assert_true(ActionCatalog.new(e).perform(c, away).ok)
	assert_true(fam.has_meta("pocket") and fam.creature.has_condition(&"incapacitated"), "out of the fight")
	assert_false(c.action_available, "the action spent")
	assert_true(_find(e, c, "feat:fr:familiar_away").is_empty(), "only Call Back while it's away")
	c.action_available = true
	c.magic_action_used = false
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:familiar_back"), [], Vector2(4.5, 3.5)).ok)
	assert_false(fam.has_meta("pocket") or fam.creature.has_condition(&"incapacitated"), "back")
	assert_eq(fam.cell, Vector2i(4, 3), "where it was called")
	c.action_available = true
	c.magic_action_used = false
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:familiar_dismiss")).ok)
	assert_true(e.faerun.familiar_of(c) == null, "dismissed")

