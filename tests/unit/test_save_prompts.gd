extends TestCase
## Saves that stop for the choices after their rolls (F6): Indomitable, Heroic Inspiration, an ally's Bend Luck and the
## rest are asked about where the fight can pause (a spell's save, a monster's save action or the rider on its hit, a
## repeated save at the end of a turn, a Death Saving Throw, an attack roll), and settle by their rules where it can't.


## A monster from `id`'s stat block with `edit` applied to a copy of the data (a set DC, a sure hit).
func _foe(e: Encounter, id: String, cell: Vector2i, edit: Callable = Callable()) -> Combatant:
	var data := Compendium.shared().monster_data(id).duplicate(true)
	if edit.is_valid():
		edit.call(data)
	return e.add(Monster.from_data(data), &"enemy", cell)


## The swarm of ravens' Cacophony (a Wisdom save or Deafened) at `dc`.
func _ravens(e: Encounter, cell: Vector2i, dc: int) -> Combatant:
	return _foe(e, "swarm_of_ravens", cell, func(d: Dictionary) -> void:
		for a: Variant in d["actions"]:
			if str((a as Dictionary)["id"]) == "cacophony":
				((a as Dictionary)["save"] as Dictionary)["dc"] = dc)


func _cacophony(e: Encounter, ravens: Combatant, t: Combatant) -> CombatResult:
	var r := CombatResult.new()
	e.monster_actions.save_action(ravens, (ravens.creature as Monster).action("cacophony"), t, r)
	return r


## A fighter (Indomitable from level 9) with no Heroic Inspiration unless a test gives it.
func _fighter(e: Encounter, level: int, cell: Vector2i) -> Combatant:
	var c := e.add(TestChars.custom("fighter", "human", level, {"fighter_subclass": ["champion"]}), &"party", cell)
	(c.creature as Character).heroic_inspiration = false
	return c


func _hero(e: Encounter, cell: Vector2i, inspired: bool) -> Combatant:
	var c := TestCombat.hero(e, "ilse_varga", cell)
	(c.creature as Character).heroic_inspiration = inspired
	return c


func _asked(e: Encounter) -> String:
	return e.pending.kind if e.pending != null else "nothing"


func _wis(c: Combatant) -> int:
	return c.creature.save_bonus(&"wis").total()


# --- The roll itself ---------------------------------------------------------------------------------

func test_heroic_inspirations_reroll_keeps_the_better_die_with_advantage() -> void:
	var t := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 4, 2, 15)
	t.rolls = [4, 9]
	t.kept = 9
	t.advantage = true
	t._resolve()
	t.reroll_one(6, "Heroic Inspiration")
	assert_eq(t.kept, 9, "the lower die was rolled again and the 9 still counts")
	t.reroll_one(17, "Heroic Inspiration")
	assert_eq(t.kept, 17)
	assert_true(t.success)
	var d := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 3, 0, 10)
	d.rolls = [3, 18]
	d.kept = 3
	d.disadvantage = true
	d._resolve()
	d.reroll_one(20, "Heroic Inspiration")
	assert_eq(d.kept, 18, "with Disadvantage the other die still caps it")


func test_a_whole_reroll_keeps_its_advantage_and_bonuses() -> void:
	var dice := DiceRoller.new(5)
	var t := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 2, 3, 30)
	t.extra = 2
	t.advantage_sources.assign(["Bless"])
	t.advantage = true
	t._resolve()
	t.reroll(dice, "Indomitable")
	assert_eq(t.rolls.size(), 2, "still with Advantage")
	assert_eq(t.kept, maxi(t.rolls[0], t.rolls[1]))
	assert_eq(t.total, t.kept + 3 + 2, "the modifier and the bonus dice stay")
	var c := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 2, 0, 30)
	c.disadvantage_sources.assign(["Frightened"])
	c.disadvantage = true
	c.reroll(dice, "Countercharm", true)
	assert_eq(c.rolls.size(), 1, "Countercharm's Advantage meets the Disadvantage: a straight roll")


# --- Where the fight can pause -----------------------------------------------------------------------

func test_a_failed_save_against_a_save_action_asks_about_heroic_inspiration() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), true)
	var ravens := _ravens(e, Vector2i(3, 2), _wis(hero) + 12)
	TestCombat.start_with(e, ravens)
	TestCombat.next_d20(e, 2)
	var r := _cacophony(e, ravens, hero)
	assert_eq(_asked(e), "heroic_inspiration")
	assert_true(r.is_paused(), "the action waits")
	assert_false(hero.creature.has_condition(&"deafened"), "nothing lands while the choice waits")
	assert_true(e.pending.text.contains("vs DC %d" % (_wis(hero) + 12)), "the prompt gives the roll: %s" % e.pending.text)
	assert_false(e.pending.spends_reaction, "it isn't a Reaction")
	var res := e.answer_reaction(true)
	assert_false((hero.creature as Character).heroic_inspiration, "spent")
	assert_false(res.is_paused())
	var resisted := e.log.texts().any(func(x: String) -> bool: return x.contains("resists Cacophony"))
	assert_ne(hero.creature.has_condition(&"deafened"), resisted, "the reroll decides it")
	assert_true(e.log.texts().any(func(x: String) -> bool: return x.contains("Heroic Inspiration on the save")))


func test_declining_keeps_heroic_inspiration_and_the_failure_stands() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), true)
	var ravens := _ravens(e, Vector2i(3, 2), _wis(hero) + 12)
	TestCombat.start_with(e, ravens)
	TestCombat.next_d20(e, 2)
	_cacophony(e, ravens, hero)
	assert_eq(_asked(e), "heroic_inspiration")
	e.answer_reaction(false)
	assert_true((hero.creature as Character).heroic_inspiration, "kept")
	assert_true(hero.creature.has_condition(&"deafened"))


func test_a_rule_answers_without_asking() -> void:
	for rule: String in ["auto", "never"]:
		var e := TestCombat.open_field(3)
		var hero := _hero(e, Vector2i(2, 2), true)
		hero.reaction_rules["heroic_inspiration"] = rule
		var ravens := _ravens(e, Vector2i(3, 2), _wis(hero) + 12)
		TestCombat.start_with(e, ravens)
		TestCombat.next_d20(e, 2)
		var r := _cacophony(e, ravens, hero)
		assert_false(r.is_paused() or e.pending != null, "%s: nothing to ask" % rule)
		assert_eq((hero.creature as Character).heroic_inspiration, rule == "never", "%s: spent only on Automatic" % rule)


func test_no_prompt_when_the_save_succeeds_or_nothing_could_save_it() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), true)
	var ravens := _ravens(e, Vector2i(3, 2), -10)
	TestCombat.start_with(e, ravens)
	assert_false(_cacophony(e, ravens, hero).is_paused(), "a success: %s" % _asked(e))
	assert_false(hero.creature.has_condition(&"deafened"))
	var e2 := TestCombat.open_field(3)
	var hero2 := _hero(e2, Vector2i(2, 2), true)
	var ravens2 := _ravens(e2, Vector2i(3, 2), 60)
	TestCombat.start_with(e2, ravens2)
	assert_false(_cacophony(e2, ravens2, hero2).is_paused(), "even a 20 can't reach DC 60: %s" % _asked(e2))
	assert_true((hero2.creature as Character).heroic_inspiration, "and nothing is spent on it")


func test_indomitable_is_asked_before_heroic_inspiration() -> void:
	var e := TestCombat.open_field(3)
	var hero := _fighter(e, 9, Vector2i(2, 2))
	var ch := hero.creature as Character
	ch.heroic_inspiration = true
	var ravens := _ravens(e, Vector2i(3, 2), _wis(hero) + 12)
	TestCombat.start_with(e, ravens)
	TestCombat.next_d20(e, 2)
	_cacophony(e, ravens, hero)
	assert_eq(_asked(e), "indomitable")
	assert_true(e.pending.cost.contains("Indomitable"), e.pending.cost)
	e.answer_reaction(false)
	assert_eq(_asked(e), "heroic_inspiration", "declined, still failing: the next choice")
	assert_eq(ch.resource_left("indomitable"), 1, "kept")
	e.answer_reaction(false)
	assert_true(hero.creature.has_condition(&"deafened"))
	var e2 := TestCombat.open_field(3)
	var hero2 := _fighter(e2, 9, Vector2i(2, 2))
	var ravens2 := _ravens(e2, Vector2i(3, 2), _wis(hero2) + 12)
	TestCombat.start_with(e2, ravens2)
	TestCombat.next_d20(e2, 2)
	_cacophony(e2, ravens2, hero2)
	e2.answer_reaction(true)
	assert_eq((hero2.creature as Character).resource_left("indomitable"), 0, "spent")
	assert_true(e2.log.texts().any(func(x: String) -> bool: return x.contains("Indomitable reroll")))


func test_an_allys_bend_luck_is_asked_and_a_hopeless_roll_isnt_offered() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), false)
	var sorc := e.add(TestChars.custom("sorcerer", "human", 6, {"sorcerer_subclass": ["wild_magic_sorcery"]}), &"party", Vector2i(2, 4))
	# A 2 misses this DC by 2: Bend Luck's d4 could still save it.
	var ravens := _ravens(e, Vector2i(3, 2), _wis(hero) + 4)
	TestCombat.start_with(e, ravens)
	TestCombat.next_d20(e, 2)
	_cacophony(e, ravens, hero)
	assert_eq(_asked(e), "bend_luck")
	assert_eq(e.pending.reactor_id, sorc.id)
	assert_true(e.pending.spends_reaction)
	var points := (sorc.creature as Character).resource_left("sorcery_points")
	e.answer_reaction(true)
	assert_eq((sorc.creature as Character).resource_left("sorcery_points"), points - 1)
	assert_false(sorc.reaction_available)
	var e2 := TestCombat.open_field(3)
	var hero2 := _hero(e2, Vector2i(2, 2), false)
	e2.add(TestChars.custom("sorcerer", "human", 6, {"sorcerer_subclass": ["wild_magic_sorcery"]}), &"party", Vector2i(2, 4))
	var ravens2 := _ravens(e2, Vector2i(3, 2), _wis(hero2) + 12)
	TestCombat.start_with(e2, ravens2)
	TestCombat.next_d20(e2, 2)
	assert_false(_cacophony(e2, ravens2, hero2).is_paused(), "missed by far more than a d4: %s" % _asked(e2))


func test_a_ghouls_paralysing_claw_waits_for_the_choice() -> void:
	var e := TestCombat.open_field(3)
	var hero := _fighter(e, 9, Vector2i(2, 2))
	var ch := hero.creature as Character
	var dc := hero.creature.save_bonus(&"con").total() + 20
	var ghoul := _foe(e, "ghoul", Vector2i(3, 2), func(d: Dictionary) -> void:
		for a: Variant in d["actions"]:
			var act := a as Dictionary
			if str(act["id"]) == "claw":
				(act["attack"] as Dictionary)["bonus"] = 40
				((act["on_hit"] as Array)[0]["save"] as Dictionary)["dc"] = dc)
	TestCombat.start_with(e, ghoul)
	var hp := hero.creature.hp
	TestCombat.next_d20(e, 10)
	var r := e.monster_attack(ghoul, hero, "claw")
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "indomitable")
	assert_true(hero.creature.hp < hp, "the claw's damage landed before its rider's save")
	assert_false(hero.creature.has_condition(&"paralyzed"), "the rider waits for the answer")
	var res := e.answer_reaction(false)
	assert_eq(ch.resource_left("indomitable"), 1)
	assert_false(res.is_paused())
	assert_true(hero.creature.has_condition(&"paralyzed"), "declined: the claw paralyses")
	assert_eq(e.pending, null)


func test_a_spell_cast_at_the_party_pauses_on_the_failed_save() -> void:
	var e := TestCombat.open_field(3)
	var hero := _fighter(e, 9, Vector2i(2, 2))
	var mage := TestCombat.caster_with(e, ["hold_person"], Vector2i(8, 2))
	mage.side = &"enemy"
	mage.controller = &"ai"
	TestCombat.start_with(e, mage)
	var nums := {"dc": Breakdown.new("Spell save DC").add("Stat block", _wis(hero) + 20), "attack": Breakdown.new("Spell attack").add("Stat block", 5)}
	var r := e.spells.cast_with_numbers(mage, "hold_person", 2, [hero], Vector2.INF, nums)
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "indomitable")
	assert_false(hero.creature.has_condition(&"paralyzed"), "Hold Person waits for the answer")
	e.answer_reaction(false)
	assert_true(hero.creature.has_condition(&"paralyzed"), "declined: held")
	assert_true(mage.creature.concentration != null, "the caster keeps Concentration on it")
	assert_eq(e.pending, null)


func test_a_death_save_asks_about_heroic_inspiration() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), false)
	TestCombat.punching_bag(e, Vector2i(9, 2))
	TestCombat.start_with(e, hero)
	hero.creature.hp = 0
	hero.creature.add_condition(&"unconscious", "0 Hit Points")
	(hero.creature as Character).heroic_inspiration = true
	TestCombat.next_d20(e, 4)
	var r := e.death_save(hero)
	assert_true(r.is_paused(), "a 4 fails: asked %s" % _asked(e))
	assert_eq(hero.creature.death_failures, 0, "it doesn't count until answered")
	e.answer_reaction(false)
	assert_eq(hero.creature.death_failures, 1, "declined: one failure")
	assert_true((hero.creature as Character).heroic_inspiration)


func test_ending_a_turn_waits_on_a_repeated_save() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), false)
	var bag := TestCombat.punching_bag(e, Vector2i(9, 2))
	TestCombat.start_with(e, hero)
	var held := Effect.new("Held (test)", &"spell", "hold_person").with_condition(&"paralyzed")
	held.repeat_save = {"ability": "wis", "dc": _wis(hero) + 20, "when": "end"}
	held.caster_id = bag.id
	hero.creature.add_effect(held)
	(hero.creature as Character).heroic_inspiration = true
	var r := e.end_turn()
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "heroic_inspiration")
	assert_eq(e.current(), hero, "the turn hasn't passed yet")
	e.answer_reaction(false)
	assert_eq(e.pending, null)
	assert_ne(e.current(), hero, "the turn passes once answered")
	assert_true(held in hero.creature.effects, "declined: still held")


func test_a_missed_attack_asks_about_a_bardic_inspiration_die() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), false)
	var option := e.attack_options(hero)[0]
	var bonus := (option["profile"] as WeaponProfile).attack.total()
	var bag := e.add(TestChars.dummy(80, false, {"ac": bonus + 6}), &"enemy", Vector2i(3, 2))
	TestCombat.start_with(e, hero)
	var die := Effect.new("Bardic Inspiration", &"feature", "bardic_inspiration").with_modifier("inspiration_die", {"dice": "1d6"})
	hero.creature.add_effect(die)
	TestCombat.next_d20(e, 3)
	var r := e.attack(hero, bag, str(option["id"]))
	assert_true(r.is_paused(), "a 3 misses AC %d: asked %s" % [bonus + 6, _asked(e)])
	assert_eq(_asked(e), "inspiration")
	e.answer_reaction(true)
	assert_false(die in hero.creature.effects, "the die is used")


# --- Where it can't pause ----------------------------------------------------------------------------

func test_a_roll_that_cant_pause_keeps_the_old_rules() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), true)
	TestCombat.punching_bag(e, Vector2i(9, 2))
	TestCombat.start_with(e, hero)
	TestCombat.next_d20(e, 2)
	hero.creature.roll_save(e.dice, &"wis", _wis(hero) + 12)
	assert_false((hero.creature as Character).heroic_inspiration, "used on its own, as before")
	assert_eq(e.pending, null)
	var e2 := TestCombat.open_field(3)
	var hero2 := _hero(e2, Vector2i(2, 2), true)
	var ravens := _ravens(e2, Vector2i(3, 2), _wis(hero2) + 12)
	TestCombat.start_with(e2, ravens)
	TestCombat.next_d20(e2, 2)
	var r := CombatResult.new()
	e2.monster_actions.save_action(ravens, (ravens.creature as Monster).action("cacophony"), hero2, r, false)
	assert_false(r.is_paused(), "a caller that can't wait settles it by rule")
	assert_false((hero2.creature as Character).heroic_inspiration)


func test_the_save_choices_show_in_the_class_tab() -> void:
	var e := TestCombat.open_field(3)
	var hero := _fighter(e, 9, Vector2i(2, 2))
	TestCombat.punching_bag(e, Vector2i(9, 2))
	TestCombat.start_with(e, hero)
	var hotbar := ActionCatalog.new(e).actions_for(hero).map(func(a: Dictionary) -> String: return str(a["id"]))
	for kind: String in ["indomitable", "heroic_inspiration"]:
		for mode: String in ["ask", "auto", "never"]:
			assert_true("feat:reaction_policy:%s:%s" % [kind, mode] in hotbar, "%s: %s" % [kind, mode])


# --- A turn's start and end, the lair, Initiative ----------------------------------------------------

func test_starting_a_turn_in_a_stinking_cloud_waits_for_the_choice() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), false)
	var mage := TestCombat.caster_with(e, ["stinking_cloud"], Vector2i(11, 7))
	mage.side = &"enemy"
	mage.controller = &"ai"
	TestCombat.start_with(e, mage)
	var dc := hero.creature.save_bonus(&"con").total() + 20
	var nums := {"dc": Breakdown.new("Spell save DC").add("Stat block", dc), "attack": Breakdown.new("Spell attack").add("Stat block", 5)}
	assert_true(e.spells.cast_with_numbers(mage, "stinking_cloud", 3, [], e.center_of(hero), nums).ok)
	(hero.creature as Character).heroic_inspiration = true
	var r := e.end_turn()
	assert_eq(e.current(), hero, "the hero's turn has begun")
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "heroic_inspiration")
	assert_false(hero.creature.has_condition(&"poisoned"), "the cloud waits for the answer")
	e.answer_reaction(false)
	assert_true(hero.creature.has_condition(&"poisoned"))
	assert_false(hero.action_available, "and the turn's action is gone")


func test_a_ghasts_stench_at_the_start_of_a_turn_waits_for_the_choice() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), false)
	var dc := hero.creature.save_bonus(&"con").total() + 20
	var ghast := _foe(e, "ghast", Vector2i(3, 2), func(d: Dictionary) -> void:
		for tr: Variant in d["traits"]:
			if (tr as Dictionary).has("aura"):
				(((tr as Dictionary)["aura"] as Dictionary)["save"] as Dictionary)["dc"] = dc)
	TestCombat.start_with(e, ghast)
	(hero.creature as Character).heroic_inspiration = true
	var r := e.end_turn()
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "heroic_inspiration")
	e.answer_reaction(false)
	assert_true(hero.creature.has_condition(&"poisoned"), "declined: the stench takes hold")
	assert_eq(e.current(), hero)


func test_a_lair_save_waits_for_the_choice() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(8, 3), false)
	var dc := _wis(hero) + 20
	var data := TestChars.dummy(200).data.duplicate(true)
	data["lair_actions"] = [{"id": "dread", "name": "Dread", "kind": "save", "save": {"ability": "wis", "dc": dc},
		"targets": {"range": 60}, "damage": [{"average": 7, "dice": "2d6", "type": "psychic"}], "summary": "x"}]
	var boss := e.add(Monster.from_data(data), &"enemy", Vector2i(3, 3))
	e.start()
	boss.initiative = 10
	hero.initiative = 5
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)
	e.lair = true
	e.legendary.lair_round = 0
	e.turn_index = 0
	(hero.creature as Character).heroic_inspiration = true
	var hp := hero.creature.hp
	var r := e._lair_then_begin()
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "heroic_inspiration")
	assert_eq(hero.creature.hp, hp, "the lair's damage waits for the answer")
	e.answer_reaction(false)
	assert_true(hero.creature.hp < hp, "declined: the dread lands")
	assert_eq(e.current(), boss, "then the first turn begins")


func test_a_trample_waits_for_the_choice() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(5, 3), true)
	var dc := hero.creature.save_bonus(&"dex").total() + 12
	var el := _foe(e, "elephant", Vector2i(2, 2), func(d: Dictionary) -> void:
		for a: Variant in d["bonus_actions"]:
			if str((a as Dictionary)["id"]) == "trample":
				((a as Dictionary)["save"] as Dictionary)["dc"] = dc)
	TestCombat.start_with(e, el)
	hero.creature.add_condition(&"prone", "test")
	var hp := hero.creature.hp
	TestCombat.next_d20(e, 2)
	var r := e.monster_actions.bonus_action(el, "trample")
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "heroic_inspiration")
	assert_eq(hero.creature.hp, hp, "the trample waits for the answer")
	assert_false(el.bonus_available, "the Bonus Action is used")
	e.answer_reaction(false)
	assert_true(hero.creature.hp < hp, "declined: the trample lands")


func test_branches_of_the_tree_is_asked_as_a_foe_starts_its_turn() -> void:
	var e := TestCombat.open_field(3)
	var barb := e.add(TestChars.custom("barbarian", "human", 6, {"barbarian_subclass": ["path_of_the_world_tree"]}), &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, barb)
	assert_true(e.feature_actions.perform(barb, "cf:rage", null, Vector2.INF).ok, "rage")
	var r := e.end_turn()
	assert_eq(e.current(), foe)
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "branches_of_the_tree")
	assert_eq(e.pending.reactor_id, barb.id)
	e.answer_reaction(true)
	assert_false(barb.reaction_available, "the Reaction is spent")
	assert_true(e.distance(barb, foe) <= 5, "the punching bag can't make that Strength save: pulled beside the barbarian")


func test_tandem_footwork_is_asked_once_initiative_is_rolled() -> void:
	var e := TestCombat.open_field(3)
	var bard := e.add(TestChars.custom("bard", "human", 6, {"bard_subclass": ["college_of_dance"]}), &"party", Vector2i(2, 3))
	bard.reaction_rules["initiative_swap"] = "never"   # a human's Alert (its Versatile feat) isn't this test's
	var ally := _hero(e, Vector2i(3, 3), false)
	TestCombat.punching_bag(e, Vector2i(10, 3))
	e.start()
	assert_eq(_asked(e), "tandem_footwork")
	var before := ally.initiative
	var dice := (bard.creature as Character).resource_left("bardic_inspiration")
	e.answer_reaction(true)
	assert_eq((bard.creature as Character).resource_left("bardic_inspiration"), dice - 1)
	assert_true(ally.initiative > before, "the ally within 30 ft dances too")
	assert_true(e.current() != null and e.pending == null, "then the first turn begins")
	assert_eq(e.order[0].initiative, e.order.map(func(c: Combatant) -> int: return c.initiative).max(), "in the new order")


## A rogue with Alert (the criminal background's feat), two allies and a foe, in a fight started with the rogue at 20,
## the foe at 10, Ilse at 5 and Silvain at 15; then Initiative's choices are offered again.
func _alert(e: Encounter) -> Array[Combatant]:
	var rogue := e.add(TestChars.custom("rogue", "human", 3, {}, "criminal"), &"party", Vector2i(2, 3))
	var ilse := _hero(e, Vector2i(3, 3), false)
	var silvain := TestCombat.hero(e, "silvain_aster", Vector2i(3, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, rogue)
	rogue.reaction_rules["initiative_swap"] = "ask"
	for pair: Array in [[rogue, 20], [foe, 10], [ilse, 5], [silvain, 15]]:
		(pair[0] as Combatant).initiative = int(pair[1])
	return [rogue, ilse, silvain, foe]


func _offer_initiative(e: Encounter) -> CombatResult:
	return e.reactions.offer(e.class_features.initiative_offers(), func() -> CombatResult: return CombatResult.new(), CombatResult.new())


func test_alert_trades_initiative_with_the_ally_picked() -> void:
	var e := TestCombat.open_field(3)
	var party := _alert(e)
	var rogue := party[0]
	var ilse := party[1]
	assert_true(_offer_initiative(e).is_paused())
	assert_eq(_asked(e), "initiative_swap")
	assert_eq(e.pending.reactor_id, rogue.id)
	assert_false(e.pending.spends_reaction)
	assert_eq(e.pending.target_choices.size(), 1, "only Ilse: no enemy acts between the rogue and Silvain")
	assert_true(str(e.pending.target_choices[0]["label"]).contains("Initiative 5"))
	e.pending.selected_ids.assign([ilse.id])
	e.answer_reaction(true)
	assert_eq(rogue.initiative, 5)
	assert_eq(ilse.initiative, 20)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("trades Initiative with %s" % ilse.name())))


func test_alert_without_a_pick_trades_with_the_ally_furthest_behind() -> void:
	var e := TestCombat.open_field(3)
	var party := _alert(e)
	party[0].reaction_rules["initiative_swap"] = "auto"
	_offer_initiative(e)
	assert_eq(e.pending, null, "settled by its rule")
	assert_eq(party[0].initiative, 5)
	assert_eq(party[1].initiative, 20)


func test_alert_isnt_asked_with_its_rule_off_or_nobody_to_trade_with() -> void:
	var e := TestCombat.open_field(3)
	var party := _alert(e)
	party[0].reaction_rules.erase("initiative_swap")
	assert_false(_offer_initiative(e).is_paused(), "Off until the class tab turns it on: it would come up nearly every fight")
	party[0].reaction_rules["initiative_swap"] = "ask"
	party[1].creature.add_condition(&"incapacitated", "test")
	assert_false(_offer_initiative(e).is_paused(), "Ilse is Incapacitated and Silvain acts before the foe too")


func test_inspiring_movement_is_asked_when_a_foe_ends_its_turn_beside_the_bard() -> void:
	var e := TestCombat.open_field(3)
	var bard := e.add(TestChars.custom("bard", "human", 6, {"bard_subclass": ["college_of_dance"]}), &"party", Vector2i(4, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3))
	bard.reaction_rules["tandem_footwork"] = "never"
	TestCombat.start_with(e, foe)
	var at := bard.cell
	var dice := (bard.creature as Character).resource_left("bardic_inspiration")
	var r := e.end_turn()
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "inspiring_movement")
	e.answer_reaction(true)
	assert_ne(bard.cell, at, "the bard danced away")
	assert_eq((bard.creature as Character).resource_left("bardic_inspiration"), dice - 1, "for a Bardic Inspiration")


# --- A hero's rules last ----------------------------------------------------------------------------

func test_a_heros_rules_carry_into_the_next_fight_and_the_save() -> void:
	var ch := TestChars.pregen("ilse_varga", 3)
	var e := TestCombat.open_field(3)
	var c := e.add(ch, &"party", Vector2i(2, 2))
	c.reaction_rules["opportunity_attack"] = "never"
	var e2 := TestCombat.open_field(4)
	var c2 := e2.add(ch, &"party", Vector2i(2, 2))
	assert_eq(str(c2.reaction_rules.get("opportunity_attack", "")), "never", "the next fight remembers")
	var back := Character.from_dict(JSON.parse_string(JSON.stringify(ch.to_dict())) as Dictionary)
	assert_eq(str(back.reaction_rules.get("opportunity_attack", "")), "never", "and so does a save")


# --- Spells with code of their own, Concentration -----------------------------------------------------

func _enemy_caster(e: Encounter, spells: Array, cell: Vector2i) -> Combatant:
	var mage := TestCombat.caster_with(e, spells, cell)
	mage.side = &"enemy"
	mage.controller = &"ai"
	return mage


func _numbers(dc: int) -> Dictionary:
	return {"dc": Breakdown.new("Spell save DC").add("Stat block", dc), "attack": Breakdown.new("Spell attack").add("Stat block", 5)}


func test_sleep_command_and_polymorph_wait_for_the_choice() -> void:
	for spell: String in ["sleep", "command", "polymorph"]:
		var e := TestCombat.open_field(3)
		var hero := _hero(e, Vector2i(2, 2), false)
		var mage := _enemy_caster(e, [spell], Vector2i(6, 2))
		TestCombat.start_with(e, mage)
		(hero.creature as Character).heroic_inspiration = true
		var dc := hero.creature.save_bonus(&"wis").total() + 20
		TestCombat.next_d20(e, 2)
		var r := e.spells.cast_with_numbers(mage, spell, 4, [hero], e.center_of(hero), _numbers(dc))
		assert_true(r.is_paused(), "%s: asked %s (%s)" % [spell, _asked(e), r.reason])
		assert_eq(_asked(e), "heroic_inspiration", spell)
		e.answer_reaction(false)
		assert_eq(e.pending, null, spell)
		match spell:
			"sleep":
				assert_true(hero.creature.has_condition(&"incapacitated"), "declined: drowsy")
			"command":
				assert_true(hero.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "command"), "declined: commanded")
			"polymorph":
				assert_true(hero.creature is Monster or hero.creature.has_flag("polymorphed"), "declined: a beast")


func test_a_failed_concentration_save_is_asked_once_the_hit_is_done() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), false)
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2))
	TestCombat.start_with(e, foe)
	var conc := hero.creature.begin_concentration("bless", "Bless")
	(hero.creature as Character).heroic_inspiration = true
	var damage := 2 * (hero.creature.save_bonus(&"con").total() + 12)
	TestCombat.next_d20(e, 2)
	e.deal_damage(foe, hero, [{"amount": damage, "type": "slashing"}], false, "test")
	assert_true(hero.creature.concentration == conc and not conc.ended, "held while the attack finishes")
	var r := e.run_reaction_queue(CombatResult.new())
	assert_true(r.is_paused(), "asked: %s" % _asked(e))
	assert_eq(_asked(e), "heroic_inspiration")
	e.answer_reaction(false)
	assert_true(conc.ended, "declined: Concentration is lost")
	assert_true(e.log.texts().any(func(x: String) -> bool: return x.contains("loses Concentration")))


func test_a_concentration_save_with_nothing_to_ask_settles_at_once() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2), false)
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2))
	TestCombat.start_with(e, foe)
	var conc := hero.creature.begin_concentration("bless", "Bless")
	(hero.creature as Character).heroic_inspiration = true
	hero.reaction_rules["heroic_inspiration"] = "never"
	var damage := 2 * (hero.creature.save_bonus(&"con").total() + 12)
	TestCombat.next_d20(e, 2)
	e.deal_damage(foe, hero, [{"amount": damage, "type": "slashing"}], false, "test")
	assert_true(conc.ended, "a rule of Off settles it at once: nothing to ask")
