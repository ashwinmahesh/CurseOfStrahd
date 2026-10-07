extends TestCase
## Difficulty modes (F1, combat/difficulty.gd and combat/ai/ai_tactics.gd): enemy Hit Points inside the Hit Dice,
## Baldur's Gate 3's +2s, how the AI picks targets at each mode, potions, a broken side fleeing, Honour's strikes on
## the fallen, Story's no-death rule, and what a save keeps.


func _foe_with(e: Encounter, id: String, cell: Vector2i, hp: int = -1) -> Combatant:
	var m := TestCombat.monster(id)
	if hp > 0:
		m.hp_max_base = hp   # a fight's tuned number (docs/contracts/locations.md)
		m.hp = hp
	return e.add(m, &"enemy", cell)


func _part(b: Breakdown, label: String) -> int:
	for p in b.parts:
		if str(p["label"]) == label:
			return int(p["value"])
	return 0


func _prepared(mode: String, id: String, hp: int = -1) -> Monster:
	var e := TestCombat.open_field()
	var c := _foe_with(e, id, Vector2i(9, 3), hp)
	Difficulty.named(mode).prepare(e)
	return c.creature as Monster


# --- Hit Points ---------------------------------------------------------------------------------------------------

func test_enemy_hit_points_by_mode() -> void:
	var want := {"story": [8, 108], "balanced": [11, 144], "tactician": [13, 173], "honour": [13, 173]}
	for mode: String in want:
		var wolf := _prepared(mode, "wolf")
		var strahd := _prepared(mode, "strahd_von_zarovich")
		assert_eq(wolf.max_hp(), int((want[mode] as Array)[0]), "%s wolf" % mode)
		assert_eq(strahd.max_hp(), int((want[mode] as Array)[1]), "%s Strahd" % mode)
		assert_eq(strahd.hp, strahd.max_hp(), "%s Strahd starts unhurt" % mode)
	assert_eq(_prepared("balanced", "wolf").effects.size(), 0, "Balanced changes nothing")


func test_hit_points_stay_inside_the_hit_dice_and_show_in_the_breakdown() -> void:
	# Vampire spawn tuned at 110 for the Kestrel table: +20% would be 132, its 12d8+36's highest roll.
	var spawn := _prepared("tactician", "vampire_spawn", 110)
	assert_eq(spawn.max_hp(), 132)
	var b := spawn.max_hp_breakdown()
	assert_eq(_part(b, "Tactician"), 22, "the mode's share shows under its name")
	# A twig blight (2d6, average 7) can't drop below what 2d6 rolls on Story.
	assert_eq(Difficulty.hit_dice_range(TestCombat.monster("twig_blight")), Vector2i(2, 12))
	assert_eq(_prepared("story", "twig_blight").max_hp(), 5)


func test_honour_puts_a_lighter_boss_back_to_full_strength() -> void:
	# Baba Lysaga's lightest version, for a lower-level party, is 85; her stat block has 120.
	assert_eq(_prepared("tactician", "baba_lysaga", 85).max_hp(), 102, "Tactician: the fight's 85, +20%")
	assert_eq(_prepared("honour", "baba_lysaga", 85).max_hp(), 144, "Honour: her full 120, +20%")
	# A bandit captain (CR 2) isn't a boss: Honour keeps the fight's own number.
	assert_eq(_prepared("honour", "bandit_captain", 40).max_hp(), 48)


# --- Baldur's Gate 3's +2s ---------------------------------------------------------------------------------------

func test_tactician_enemies_hit_harder_to_dodge() -> void:
	var balanced := _prepared("balanced", "wolf")
	var tactician := _prepared("tactician", "wolf")
	assert_eq(tactician.attack_profile("bite").attack.total(), balanced.attack_profile("bite").attack.total() + 2)
	var e := TestCombat.open_field()
	var witch := _foe_with(e, "barovian_witch", Vector2i(9, 3))
	assert_eq(e.monster_actions.dc_bonus(witch), 0)
	Difficulty.named("honour").prepare(e)
	assert_eq(e.monster_actions.dc_bonus(witch), 2, "+2 to the DCs of its spells and actions")


func test_story_gives_the_party_two_and_a_switch_takes_it_back() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var before := h.creature.save_bonus(&"dex").total()
	Difficulty.named("story").arm(e)
	assert_eq(h.creature.save_bonus(&"dex").total(), before + 2)
	Difficulty.named("story").arm(e)
	assert_eq(h.creature.save_bonus(&"dex").total(), before + 2, "arming twice doesn't stack")
	Difficulty.named("tactician").arm(e)
	assert_eq(h.creature.save_bonus(&"dex").total(), before, "another mode takes Story's +2 off")


# --- How enemies pick targets -------------------------------------------------------------------------------------

## Two fighters the same distance from a wolf, the first already struck this round: [wolf, struck, other].
func _two_fighters(mode: String) -> Array[Combatant]:
	var e := TestCombat.open_field(4)
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var b := TestCombat.hero(e, "ilse_varga", Vector2i(9, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(6, 3))
	_encounters.append(e)
	Difficulty.named(mode).arm(e)
	TestCombat.start_with(e, w)
	e.ai.tactics.note_strike(a)
	return [w, a, b]


func test_story_spreads_blows_and_tactician_piles_on() -> void:
	var kind := _two_fighters("story")
	var p1 := _encounter_of(kind[0]).ai.plan_turn(kind[0])
	assert_eq((p1["target"] as Combatant).id, kind[2].id, "Story: the one nobody has struck yet")
	var sharp := _two_fighters("tactician")
	var p2 := _encounter_of(sharp[0]).ai.plan_turn(sharp[0])
	assert_eq((p2["target"] as Combatant).id, sharp[1].id, "Tactician: the one its side is already on")


## The tests' encounters, kept alive (an Encounter holds itself only weakly through its helpers).
var _encounters: Array[Encounter] = []


func _encounter_of(c: Combatant) -> Encounter:
	for e in _encounters:
		if c in e.combatants:
			return e
	return null


func test_tactician_goes_for_the_hurt_hero() -> void:
	for mode: String in ["balanced", "tactician"]:
		var e := TestCombat.open_field(4)
		var hurt := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
		var near := TestCombat.hero(e, "ilse_varga", Vector2i(8, 3))
		var w := TestCombat.foe(e, "wolf", Vector2i(6, 3))
		hurt.creature.hp = hurt.creature.max_hp() / 2 + 1
		Difficulty.named(mode).arm(e)
		TestCombat.start_with(e, w)
		var plan := e.ai.plan_turn(w)
		var want := hurt if mode == "tactician" else near
		assert_eq((plan["target"] as Combatant).id, want.id, "%s picks %s" % [mode, want.id])


func test_honour_cruel_foes_strike_the_fallen() -> void:
	for mode: String in ["tactician", "honour"]:
		var e := TestCombat.open_field(4)
		var fallen := TestCombat.hero(e, "silvain_aster", Vector2i(5, 3))
		var up := TestCombat.hero(e, "ilse_varga", Vector2i(9, 3))
		var spawn := TestCombat.foe(e, "vampire_spawn", Vector2i(4, 3))
		Difficulty.named(mode).arm(e)
		TestCombat.start_with(e, spawn)
		fallen.creature.hp = 0
		fallen.creature.add_condition(&"unconscious", "0 Hit Points")
		var plan := e.ai.plan_turn(spawn)
		if mode == "honour":
			assert_eq((plan["target"] as Combatant).id, fallen.id, "the spawn bites the fallen wizard")
			assert_true(bool(plan.get("finish", false)))
		else:
			assert_eq((plan["target"] as Combatant).id, up.id, "Tactician leaves the fallen alone")
	assert_true(AiTactics.cruel(TestCombat.foe(TestCombat.open_field(), "vampire_spawn", Vector2i.ZERO)))
	assert_false(AiTactics.cruel(TestCombat.foe(TestCombat.open_field(), "zombie", Vector2i.ZERO)), "Intelligence 3")
	assert_false(AiTactics.cruel(TestCombat.foe(TestCombat.open_field(), "wolf", Vector2i.ZERO)), "unaligned")


func test_a_strike_on_the_fallen_lands_as_two_failures() -> void:
	var e := TestCombat.open_field(4)
	var fallen := TestCombat.hero(e, "silvain_aster", Vector2i(5, 3))
	TestCombat.hero(e, "ilse_varga", Vector2i(11, 7))
	var spawn := TestCombat.foe(e, "vampire_spawn", Vector2i(4, 3))
	Difficulty.named("honour").arm(e)
	TestCombat.start_with(e, spawn)
	fallen.creature.hp = 0
	fallen.creature.add_condition(&"unconscious", "0 Hit Points")
	e.run_ai_turn()
	assert_true(fallen.creature.dead or fallen.creature.death_failures >= 2, "a hit from beside it is a Critical Hit")


# --- Potions ------------------------------------------------------------------------------------------------------

func test_a_bloodied_captain_drinks_his_potion() -> void:
	var e := TestCombat.open_field(4)
	TestCombat.hero(e, "ilse_varga", Vector2i(0, 0))
	var cap := TestCombat.foe(e, "bandit_captain", Vector2i(11, 7))
	Difficulty.named("tactician").prepare(e)
	assert_eq(AiTactics.potions(cap), 1, "armed humanoids carry one")
	TestCombat.start_with(e, cap)
	cap.creature.hp = 30
	e.run_ai_turn()
	assert_eq(AiTactics.potions(cap), 0)
	assert_true(cap.creature.hp > 30, "healed by 2d4 + 2")
	assert_true(e.log.entries.any(func(en: Dictionary) -> bool: return "drinks a Potion of Healing" in str(en["text"])))


func test_badly_hurt_and_pressed_it_steps_back_to_drink() -> void:
	var e := TestCombat.open_field(4)
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	var cap := TestCombat.foe(e, "bandit_captain", Vector2i(6, 3))
	Difficulty.named("tactician").prepare(e)
	TestCombat.start_with(e, cap)
	cap.creature.hp = 15
	var r := e.run_ai_turn()
	assert_false(r.is_paused(), "Disengaged: no Opportunity Attack to ask about")
	assert_true(e.distance(cap, h) > 5, "out of Ilse's reach")
	assert_eq(AiTactics.potions(cap), 0)
	assert_true(cap.creature.hp > 15)


func test_balanced_foes_carry_nothing_and_leftovers_are_looted() -> void:
	var e := TestCombat.open_field()
	var cap := TestCombat.foe(e, "bandit_captain", Vector2i(6, 3))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(8, 3))
	Difficulty.named("balanced").prepare(e)
	assert_eq(AiTactics.potions(cap), 0)
	Difficulty.named("tactician").equip(cap)
	Difficulty.named("tactician").equip(wolf)
	assert_eq(AiTactics.potions(wolf), 0, "a wolf carries nothing")
	assert_true(AiTactics.leftovers(e).is_empty(), "nothing to loot while he stands")
	cap.creature.dead = true
	var left := AiTactics.leftovers(e)
	assert_eq(left.size(), 1)
	assert_eq(str(left[0]["id"]), "potion_of_healing")
	assert_eq(int(left[0]["qty"]), 1)


# --- A broken side ------------------------------------------------------------------------------------------------

func _pack(mode: String, monster: String) -> Array[Combatant]:
	var e := TestCombat.encounter(["........................", "........................", "........................"], 4)
	TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var out: Array[Combatant] = []
	for i in 4:
		out.append(TestCombat.foe(e, monster, Vector2i(4 + i, 1 if i != 0 else 0)))
	_encounters.append(e)
	Difficulty.named(mode).arm(e)
	TestCombat.start_with(e, out[0])
	out[2].creature.hp = 0
	out[2].creature.dead = true
	out[3].creature.hp = 0
	out[3].creature.dead = true
	return out


func test_a_broken_pack_flees_the_field() -> void:
	var pack := _pack("tactician", "wolf")
	var e := _encounter_of(pack[0])
	e.run_ai_turn()
	assert_eq(str(e.ai.last_plan.get("kind", "")), "flee", "half the pack is down")
	assert_true(e.legendary.departed.has(pack[0].id), "and it got clear of the fight")
	var calm := _pack("balanced", "wolf")
	_encounter_of(calm[0]).run_ai_turn()
	assert_ne(str(_encounter_of(calm[0]).ai.last_plan.get("kind", "")), "flee", "Balanced: no morale")
	var dead := _pack("tactician", "zombie")
	_encounter_of(dead[0]).run_ai_turn()
	assert_ne(str(_encounter_of(dead[0]).ai.last_plan.get("kind", "")), "flee", "zombies don't break")


# --- Story's no-death rule ----------------------------------------------------------------------------------------

func test_story_heroes_are_spared() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "silvain_aster", Vector2i(2, 3))
	Difficulty.named("story").arm(e)
	h.creature.take_damage(h.creature.max_hp() * 3, &"slashing")
	assert_false(h.creature.dead, "massive damage leaves a Story hero alive")
	assert_true(h.creature.stable and h.creature.hp == 0)
	assert_true(h.creature.has_condition(&"unconscious"))
	Difficulty.named("balanced").arm(e)
	h.creature.take_damage(h.creature.max_hp() * 3, &"slashing")
	assert_true(h.creature.dead, "Balanced: the rules")


# --- Saves and switching ------------------------------------------------------------------------------------------

func test_a_round_start_save_keeps_the_mode() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "silvain_aster", Vector2i(2, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(8, 3))
	Difficulty.named("story").prepare(e)
	TestCombat.start_with(e, h)
	var back := EncounterSnapshot.restore(EncounterSnapshot.capture(e), DiceRoller.new(2))
	assert_eq(back.difficulty.id, "story")
	assert_eq(back.get_c(w.id).creature.max_hp(), 8, "the wolf keeps Story's Hit Points")
	assert_true(back.get_c(h.id).creature.spared_from_death)
	assert_eq(Difficulty.of_options({}).id, "balanced", "a save from before the modes is Balanced")


func test_switching_rules() -> void:
	assert_true(Difficulty.can_switch("story", "tactician"))
	assert_true(Difficulty.can_switch("honour", "tactician"))
	assert_false(Difficulty.can_switch("balanced", "honour"), "Honour only at a new game")
	assert_ne(Difficulty.switch_warning("honour", "tactician"), "")
	assert_eq(Difficulty.switch_warning("story", "balanced"), "")
	for id in Difficulty.IDS:
		assert_false(Difficulty.named(id).describe().is_empty())


func test_a_foe_joining_mid_fight_gets_the_mode_too() -> void:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	Difficulty.named("tactician").prepare(e)
	TestCombat.start_with(e, h)
	var late := TestCombat.foe(e, "wolf", Vector2i(9, 3))
	assert_eq(late.creature.max_hp(), 13, "Children of the Night arrive at Tactician's Hit Points")
	var pup := e.add(TestCombat.monster("wolf"), &"party", Vector2i(9, 5))
	assert_eq(pup.creature.max_hp(), 11, "the party's own summons are left alone")


# --- Spells and scrolls (Tactician and Honour) --------------------------------------------------------------------

func _witch_fight(mode: String) -> Array[Combatant]:
	var e := TestCombat.open_field(4)
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var w := TestCombat.foe(e, "barovian_witch", Vector2i(9, 3))
	_encounters.append(e)
	Difficulty.named(mode).prepare(e)
	TestCombat.start_with(e, w)
	return [w, h]


func test_tactician_casters_cast_from_their_whole_list() -> void:
	var sharp := _witch_fight("tactician")
	var e := _encounter_of(sharp[0])
	e.run_ai_turn()
	while e.pending != null:
		e.answer_reaction(false)
	assert_eq(str(e.ai.last_plan.get("kind", "")), "cast", "a Barovian witch casts rather than stabbing with her dagger")
	assert_true(e.log.texts().any(func(t: String) -> bool: return "casts" in t))
	var calm := _witch_fight("balanced")
	var e2 := _encounter_of(calm[0])
	e2.run_ai_turn()
	while e2.pending != null:
		e2.answer_reaction(false)
	assert_ne(str(e2.ai.last_plan.get("kind", "")), "cast", "Balanced keeps the old caster AI")


func test_a_caster_reads_its_scroll_when_its_spells_are_spent() -> void:
	var f := _witch_fight("honour")
	var w := f[0]
	var e := _encounter_of(w)
	assert_eq(AiSpells.scroll_of(w), "ray_of_sickness", "its strongest daily spell that harms")
	for sid: String in ["ray_of_sickness", "sleep", "tashas_hideous_laughter"]:
		w.set_meta("cast_%s" % sid, 4)
	var p := e.ai.spells.plan(w, 0.0)
	assert_eq(str(p.get("spell", "")), "ray_of_sickness")
	assert_true(bool(p.get("scroll", false)), "read from the scroll")
	e.ai.spells.cast(w, p)
	assert_eq(AiSpells.scroll_of(w), "", "the scroll crumbles")
	assert_eq(int(w.get_meta("cast_ray_of_sickness")), 4, "and the daily uses stay spent")
	var w2 := _witch_fight("tactician")[0]
	w2.creature.dead = true
	var left := AiTactics.leftovers(_encounter_of(w2))
	assert_true(left.any(func(it: Dictionary) -> bool: return str(it["id"]) == "spell_scroll__ray_of_sickness"), "an unread scroll is loot")
