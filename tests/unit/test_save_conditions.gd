extends TestCase
## A condition from a failed save really lands, is obeyed and is told to the player: Abjure Foes (Paladin 9), Hold Monster,
## the Gilded Knight's and the Revenant's glares, and the immunities that turn one away. Ashwin's reports of 2026-10-18
## came from the Keepers' yard at Ghaki's: revenants and a helmed horror are immune to Frightened and Paralyzed, and the
## party stood in a paladin's Aura of Courage, so Abjure Foes, Hold Monster and the Vengeful Glare all failed their saves
## and then did nothing, with no word in the log of why.


func _add(e: Encounter, ch: Character, cell: Vector2i) -> Combatant:
	return e.add(ch, &"party", cell)


func _abjure(e: Encounter, p: Combatant) -> CombatResult:
	return e.feature_actions.perform(p, "cf:abjure_foes", null, Vector2.INF)


## Every save it makes fails (a -100 to all of them).
func _fails_saves(c: Combatant) -> void:
	c.creature.add_effect(Effect.new("Fails every save", &"effect", "test").with_modifier("save", {"ability": "all", "value": -100}))


func _said(e: Encounter, part: String) -> bool:
	return e.log.texts().any(func(t: String) -> bool: return t.contains(part))


func _dazed(c: Combatant) -> void:
	c.creature.add_effect(Effect.new("Dazed", &"feature", "test").with_modifier("flag", {"value": "dazed"}))


func _melee_id(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]):
			return str(o["id"])
	return ""


# --- Abjure Foes ------------------------------------------------------------------------------------------

func test_abjure_foes_frightens_a_foe_and_says_so() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 9), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, p)
	assert_true(_abjure(e, p).ok)
	assert_true(t.creature.has_condition(&"frightened"))
	assert_true(t.creature.has_flag("dazed"), "it is held to one of move, action or Bonus Action")
	assert_true(_said(e, "Dummy is Frightened (Abjure Foes)"), "\n".join(e.log.texts().slice(-4)))


func test_a_revenant_that_fails_abjure_foes_is_told_it_is_immune() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 9), Vector2i(2, 3))
	var rev := TestCombat.foe(e, "revenant", Vector2i(6, 3))
	_fails_saves(rev)
	TestCombat.start_with(e, p)
	assert_true(_abjure(e, p).ok)
	assert_false(rev.creature.has_condition(&"frightened"))
	assert_true(_said(e, "Revenant is immune to Frightened: Abjure Foes has no effect"), "\n".join(e.log.texts().slice(-4)))


func test_abjure_foes_takes_the_foes_it_can_frighten_before_the_immune_ones() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 9), Vector2i(1, 3))
	var n := maxi(1, p.creature.ability_mod(&"cha"))
	var immune: Array[Combatant] = []
	var able: Array[Combatant] = []
	for i in n:
		immune.append(TestCombat.foe(e, "revenant", Vector2i(3, i)))
		able.append(TestCombat.punching_bag(e, Vector2i(9, i), 300))
	TestCombat.start_with(e, p)
	assert_true(_abjure(e, p).ok)
	for t in able:
		assert_true(t.creature.has_condition(&"frightened"), "%s, nearer foes or not" % t.name())
	for t in immune:
		assert_false(t.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "abjure_foes"))
	assert_false(_said(e, "immune to Frightened"), "its picks were all foes it could frighten")


func test_abjure_foes_is_not_offered_with_no_foe_in_sight() -> void:
	var e := TestCombat.encounter(["........................"], 4)
	var p := _add(e, TestChars.custom("paladin", "human", 9), Vector2i(1, 0))
	TestCombat.punching_bag(e, Vector2i(18, 0), 300)   # 85 ft away
	TestCombat.start_with(e, p)
	var entry := {}
	for a in e.feature_actions.list(p):
		if str(a["id"]) == "feat:cf:abjure_foes":
			entry = a
	assert_false(entry.is_empty())
	assert_true(str(entry.get("why", "")).contains("No foe in sight"), str(entry.get("why", "")))


func test_damage_ends_abjure_foes() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 9), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, p)
	_abjure(e, p)
	assert_true(t.creature.has_condition(&"frightened"))
	e.deal_damage(p, t, [{"amount": 3, "type": "force"}], false, "test")
	assert_false(t.creature.has_condition(&"frightened"), "any damage ends it")
	assert_true(_said(e, "Abjure Foes"))


func test_abjure_foes_lasts_a_minute_of_the_foes_turns() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 9), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, p)
	_abjure(e, p)
	for i in 9:
		t.creature.on_turn_start(t.id)
	assert_true(t.creature.has_condition(&"frightened"), "still there after nine of its turns")
	t.creature.on_turn_start(t.id)
	assert_false(t.creature.has_condition(&"frightened"), "gone after a minute (ten rounds)")


func test_a_frightened_foe_strikes_at_disadvantage_while_the_paladin_is_in_sight() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 9), Vector2i(2, 3))
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(6, 3))
	_fails_saves(w)
	TestCombat.start_with(e, p)
	_abjure(e, p)
	assert_true(w.creature.has_condition(&"frightened"))
	var dis := w.creature.d20_sources(["attack", "attack:melee"])["disadvantage"] as Array
	assert_true("Frightened" in dis, "it may still attack, at Disadvantage: %s" % str(dis))
	p.creature.hp = 0
	p.creature.dead = true
	var gone := w.creature.d20_sources(["attack", "attack:melee"])["disadvantage"] as Array
	assert_false("Frightened" in gone, "a source that has died frightens no more")
	assert_true(h.is_alive())


# --- Move, take an action, or take a Bonus Action ---------------------------------------------------------

func test_a_dazed_creature_cannot_act_after_moving() -> void:
	var e := TestCombat.open_field(3)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(4, 3), 300)
	TestCombat.start_with(e, h)
	_dazed(h)
	assert_true(e.move(h, Vector2i(3, 3)).ok)
	var r := e.attack(h, bag, _melee_id(e, h))
	assert_false(r.ok, "moved, so no action")
	assert_true(r.reason.contains("Dazed"), r.reason)
	assert_true(h.action_available)
	assert_true(e.move(h, Vector2i(3, 2)).ok, "more of the same walk is fine")


func test_a_dazed_creature_cannot_move_after_acting() -> void:
	var e := TestCombat.open_field(3)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, h)
	_dazed(h)
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(h, bag, _melee_id(e, h)).ok)
	while e.pending != null:
		e.answer_reaction(false)
	var mv := e.move(h, Vector2i(2, 4))
	assert_false(mv.ok, "acted, so no move")
	assert_true(mv.reason.contains("Dazed"), mv.reason)
	assert_true(h.cell == Vector2i(2, 3))


func test_a_dazed_creature_cannot_take_a_bonus_action_after_moving_or_acting() -> void:
	var e := TestCombat.open_field(3)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3), 300)
	TestCombat.start_with(e, h)
	_dazed(h)
	assert_eq(e._bonus_check(h), "", "nothing used yet")
	assert_true(e.move(h, Vector2i(3, 3)).ok)
	assert_true(e._bonus_check(h).contains("Dazed"), e._bonus_check(h))
	assert_true(e._action_check(h).contains("Dazed"), e._action_check(h))


func test_a_dazed_foe_next_to_its_target_strikes_without_moving() -> void:
	var e := TestCombat.open_field(4)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(3, 3))
	TestCombat.start_with(e, w)
	_dazed(w)
	e.run_ai_turn()
	assert_eq(w.cell, Vector2i(3, 3), "it stayed")
	assert_false(w.action_available, "and acted")
	assert_true(h.is_alive())


func test_a_dazed_foe_far_from_its_target_only_closes_in() -> void:
	var e := TestCombat.open_field(4)
	TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(10, 3))
	TestCombat.start_with(e, w)
	_dazed(w)
	e.run_ai_turn()
	assert_ne(w.cell, Vector2i(10, 3), "it moved")
	assert_true(w.action_available, "and did not also attack or Dash")
	assert_false(e.log.texts().any(func(t: String) -> bool: return t.contains("misses") or t.contains("hits")), "no blow")


# --- Hold Monster -----------------------------------------------------------------------------------------

func _hold_monster_setup(foe_id: String) -> Array:
	var e := TestCombat.open_field(3)
	var c := TestCombat.caster_with(e, ["hold_monster"], Vector2i(2, 3), 9)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 3))
	var w := TestCombat.foe(e, foe_id, Vector2i(6, 3))
	_fails_saves(w)
	TestCombat.start_with(e, c)
	return [e, c, h, w]


func test_hold_monster_paralyzes_a_foe_and_the_party_strikes_with_advantage() -> void:
	var s := _hold_monster_setup("wolf")
	var e := s[0] as Encounter
	var c := s[1] as Combatant
	var h := s[2] as Combatant
	var w := s[3] as Combatant
	assert_true(e.spells.cast(c, "hold_monster", 5, [w]).ok)
	assert_true(w.creature.has_condition(&"paralyzed"))
	assert_true(_said(e, "Wolf is Paralyzed (Hold Monster)"))
	var sit := e.attack_situation(h, w, e.attack_options(h)[0])
	assert_true("Paralyzed (target)" in (sit["advantage"] as Array), str(sit))
	assert_true(w.creature.has_flag("auto_crit_within_5ft"), "a hit from within 5 ft is a Critical Hit")
	var start := w.cell
	while e.current() != w:
		e.end_turn()
	e.run_ai_turn()
	assert_eq(w.cell, start, "it loses its turn")
	assert_true(w.action_available, "and does nothing with it")


func test_hold_monster_on_an_immune_creature_says_why() -> void:
	var s := _hold_monster_setup("revenant")
	var e := s[0] as Encounter
	var c := s[1] as Combatant
	var w := s[3] as Combatant
	assert_true(e.spells.cast(c, "hold_monster", 5, [w]).ok)
	assert_false(w.creature.has_condition(&"paralyzed"))
	assert_true(_said(e, "Revenant is immune to Paralyzed: Hold Monster has no effect"), "\n".join(e.log.texts().slice(-4)))


func test_the_target_tooltip_warns_of_an_immunity_before_the_slot_is_spent() -> void:
	var s := _hold_monster_setup("revenant")
	var e := s[0] as Encounter
	var rev := s[3] as Combatant
	var wolf := TestCombat.foe(e, "wolf", Vector2i(7, 3))
	var cat := ActionCatalog.new(e)
	assert_eq(cat.condition_immunity_note("hold_monster", rev), "Immune to Paralyzed: Hold Monster has no effect")
	assert_eq(cat.condition_immunity_note("hold_monster", wolf), "")
	assert_eq(cat.condition_immunity_note("fireball", rev), "", "no condition to turn away")


func test_hold_monster_ends_when_its_caster_loses_concentration() -> void:
	var s := _hold_monster_setup("wolf")
	var e := s[0] as Encounter
	var c := s[1] as Combatant
	var w := s[3] as Combatant
	assert_true(e.spells.cast(c, "hold_monster", 5, [w]).ok)
	assert_true(w.creature.has_condition(&"paralyzed"))
	_fails_saves(c)
	e.deal_damage(w, c, [{"amount": 20, "type": "slashing"}], false, "test")
	while e.pending != null:
		e.answer_reaction(false)
	assert_false(w.creature.has_condition(&"paralyzed"), "a hit that breaks Concentration frees the foe")
	assert_true(_said(e, "loses Concentration"))


# --- Glares and an Aura of Courage ------------------------------------------------------------------------

func test_the_gilded_knights_covetous_glare_paralyzes_a_hero() -> void:
	var e := TestCombat.open_field(3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 9)
	var k := TestCombat.foe(e, "gilded_knight", Vector2i(6, 3))
	_fails_saves(hero)
	TestCombat.start_with(e, k)
	var act := (k.creature as Monster).action("covetous_glare")
	var r := e.monster_actions.save_action(k, act, hero, CombatResult.new(), false)
	assert_true(r.ok)
	assert_true(hero.creature.has_condition(&"paralyzed"), "\n".join(e.log.texts().slice(-4)))


func test_a_vengeful_glare_is_turned_away_by_an_aura_of_courage_and_the_log_says_so() -> void:
	var e := TestCombat.open_field(3)
	var pal := _add(e, TestChars.custom("paladin", "human", 11), Vector2i(3, 3))
	var near := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 3), 9)
	var far := TestCombat.hero(e, "ilse_varga", Vector2i(3, 0), 9)
	var rev := TestCombat.foe(e, "revenant", Vector2i(9, 3))
	_fails_saves(near)
	_fails_saves(far)
	TestCombat.start_with(e, rev)
	e.class_features.refresh_auras()
	assert_true(near.creature.is_condition_immune(&"frightened"), "in Godrick's aura")
	assert_false(far.creature.is_condition_immune(&"frightened"), "out of it")
	var act := (rev.creature as Monster).action("vengeful_glare")
	e.monster_actions.save_action(rev, act, near, CombatResult.new(), false)
	e.monster_actions.save_action(rev, act, far, CombatResult.new(), false)
	assert_false(near.creature.has_condition(&"frightened"))
	assert_true(_said(e, "Hedda Ironvow is immune to Frightened (Aura of Courage): Vengeful Glare has no effect"), "\n".join(e.log.texts().slice(-6)))
	assert_true(far.creature.has_condition(&"frightened"), "outside the aura it takes hold")
	assert_true(pal.is_alive())


# --- Radiant Strikes (Paladin 11) -------------------------------------------------------------------------

func _hit_text(e: Encounter, from: int) -> String:
	var out := ""
	for i in range(from, e.log.entries.size()):
		out += "%s %s\n" % [e.log.entries[i]["text"], " ".join(e.log.entries[i]["details"])]
	return out


func _swing(e: Encounter, p: Combatant, t: Combatant, option_id: String, d20: int = 15) -> String:
	p.reset_turn()
	var from := e.log.entries.size()
	TestCombat.next_d20(e, d20)
	assert_true(e.attack(p, t, option_id).ok)
	while e.pending != null:
		e.answer_reaction(false)
	return _hit_text(e, from)


func test_radiant_strikes_adds_1d8_to_melee_weapon_and_unarmed_hits_but_not_ranged_ones() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 11), Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 900)
	TestCombat.start_with(e, p)
	assert_true(_swing(e, p, bag, _melee_id(e, p)).contains("Radiant Strikes 1d8"), "melee weapon")
	assert_true(_swing(e, p, bag, "weapon:unarmed_strike").contains("Radiant Strikes 1d8"), "Unarmed Strike")
	var ranged := ""
	for o in e.attack_options(p):
		if not bool(o["melee"]):
			ranged = str(o["id"])
	assert_ne(ranged, "", "the paladin has a shortbow")
	assert_false(_swing(e, p, bag, ranged).contains("Radiant Strikes"), "a ranged weapon is not a Melee weapon or an Unarmed Strike")


func test_radiant_strikes_is_on_every_hit_of_the_attack_action_and_doubles_on_a_critical_hit() -> void:
	var e := TestCombat.open_field(3)
	var p := _add(e, TestChars.custom("paladin", "human", 11), Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 900)
	TestCombat.start_with(e, p)
	var id := _melee_id(e, p)
	var from := e.log.entries.size()
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(p, bag, id).ok)
	while e.pending != null:
		e.answer_reaction(false)
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(p, bag, id).ok, "the second attack of Extra Attack")
	while e.pending != null:
		e.answer_reaction(false)
	var both := _hit_text(e, from)
	assert_eq(both.count("Radiant Strikes 1d8"), 2, both)
	var crit := _swing(e, p, bag, id, 20)
	assert_true(crit.contains("Radiant Strikes 1d8 ×2 (Critical Hit)"), "a Critical Hit doubles the dice: " + crit)
