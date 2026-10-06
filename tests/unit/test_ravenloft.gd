extends TestCase
## Ravenloft: The Horrors Within options (data/ and combat/ravenloft_features.gd): the species, the origin feats and
## Ravenloft Dark Gifts (a background's feat can be swapped for one), and the subclasses' fights.


func _add(e: Encounter, ch: Character, cell: Vector2i) -> Combatant:
	return e.add(ch, &"party", cell)


func _act(e: Encounter, c: Combatant, id: String, t: Combatant = null, point: Vector2 = Vector2.INF) -> CombatResult:
	return e.feature_actions.perform(c, "rh:" + id, t, point)


func _listed(e: Encounter, c: Combatant, id: String) -> Dictionary:
	for a in e.feature_actions.list(c):
		if str(a["id"]) == "feat:rh:" + id:
			return a
	return {}


func _melee(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			return str(o["id"])
	return "weapon:unarmed_strike"


func _logged(e: Encounter, text: String) -> bool:
	return e.log.entries.any(func(x: Dictionary) -> bool:
		return str(x.get("text", "")).contains(text) or (x.get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).contains(text)))


## A character whose background feat is swapped for a Ravenloft Dark Gift (or another pick).
func _with_feat_choice(ch: Character, feat_id: String) -> Character:
	if not ch.build.has("choices"):
		ch.build["choices"] = {}
	(ch.build["choices"] as Dictionary)["background.feat_choice"] = [feat_id]
	ch.refresh()
	return ch


func _feat_ids(ch: Character) -> Array[String]:
	var out: Array[String] = []
	for f in ch.feats_taken:
		out.append(str(f["id"]))
	return out


# --- Data and character creation ---------------------------------------------------------------------------

func test_every_new_species_builds_a_character() -> void:
	for sp: String in ["dhampir", "hexblood", "lupin", "reborn"]:
		var ch := TestChars.custom("fighter", sp, 3)
		assert_eq(str(ch.build["species"]), sp)
	assert_eq(TestChars.custom("wizard", "hexblood", 1).creature_type, &"fey", "a Hexblood is a Fey")
	assert_eq(TestChars.custom("fighter", "dhampir", 1).speed().total(), 35, "a Dhampir walks 35 ft")
	assert_true(TestChars.custom("fighter", "dhampir", 1).resistance_source(&"necrotic") != "", "Trace of Undeath")
	assert_true(TestChars.custom("fighter", "reborn", 1).has_flag("trance"), "magic can't put a Reborn to sleep")


func test_every_new_subclass_builds_to_the_level_cap() -> void:
	var subs := {"bard": "college_of_spirits", "cleric": "grave_domain", "ranger": "hollow_warden", "rogue": "phantom",
		"sorcerer": "shadow_sorcery", "warlock": "undead_patron"}
	for cls: String in subs:
		var ch := TestChars.custom(cls, "human", 11, {"%s_subclass" % cls: [subs[cls]]})
		assert_eq(str(ch.subclasses.get(cls, "")), str(subs[cls]), "%s took %s" % [cls, subs[cls]])
		assert_eq(ch.character_level(), 11)


func test_a_background_feat_can_become_a_ravenloft_dark_gift() -> void:
	var ch := TestChars.custom("fighter", "human", 1)
	assert_true("savage_attacker" in _feat_ids(ch), "the Soldier's own origin feat by default")
	var c := ch.choice("background.feat_choice")
	assert_true(c != null and c.is_complete(), "the default counts as chosen, so older builds need nothing new")
	ChoiceOptions.populate(c, ch)
	assert_true(c.option("touch_of_death") != null, "Dark Gifts are offered")
	assert_true(c.option("savage_attacker") != null, "the background's own feat stays on offer")
	assert_true(c.option("alert") == null, "other origin feats aren't")
	_with_feat_choice(ch, "touch_of_death")
	assert_true("touch_of_death" in _feat_ids(ch))
	assert_false("savage_attacker" in _feat_ids(ch))
	assert_true(ch.d20_sources(["death_save"])["disadvantage"].size() > 0, "Touch of Death's drawback: Disadvantage on Death Saves")


func test_origin_feat_choices_offer_dark_gifts() -> void:
	var ch := TestChars.custom("fighter", "human", 1)
	var versatile: Choice = null
	for c in ch.choice_defs:
		if c.key.ends_with("versatile"):
			versatile = c
	assert_true(versatile != null)
	ChoiceOptions.populate(versatile, ch)
	assert_true(versatile.option("watchers") != null, "Human Versatile can take a Dark Gift")
	assert_true(versatile.option("sharp_eye") != null and versatile.option("survivor") != null, "and the new origin feats")


# --- Species in a fight -----------------------------------------------------------------------------------------

func test_vampiric_bite_drains_when_hurt() -> void:
	var e := TestCombat.open_field(3)
	var d := _add(e, TestChars.custom("fighter", "dhampir", 3), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, d)
	var bite := e.option_by_id(d, "bite:vampiric")
	assert_false(bite.is_empty(), "the bite is an attack option")
	assert_eq(str((bite["profile"] as WeaponProfile).damage_type), "piercing")
	d.creature.hp = 1
	var uses := (d.creature as Character).resource_left("vampiric_bite")
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(d, t, "bite:vampiric").hit)
	assert_eq((d.creature as Character).resource_left("vampiric_bite"), uses - 1)
	assert_true(d.creature.hp > 1, "Drain heals the dhampir")


func test_lupin_howl_and_feral_pounce() -> void:
	var e := TestCombat.open_field(3)
	var l := _add(e, TestChars.custom("monk", "lupin", 3), Vector2i(2, 3))
	var near := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	var far := TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, l)
	assert_eq(str(WeaponProfile.unarmed(l.creature).damage_type), "slashing", "claws: Slashing Unarmed Strikes")
	assert_false(_listed(e, l, "howl").is_empty())
	assert_true(_act(e, l, "howl").ok)
	assert_true(near.creature.effects.any(func(fx: Effect) -> bool: return fx.name == "Howl"), "the weak-willed foe quails")
	assert_false(far.creature.effects.any(func(fx: Effect) -> bool: return fx.name == "Howl"), "out of the 15-ft range")
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(l, near, "weapon:unarmed_strike").hit)
	assert_true(near.creature.has_condition(&"prone"), "Feral Pounce shoves as well")


func test_reborn_past_life_turns_a_near_miss_check() -> void:
	var e := TestCombat.open_field(3)
	var r := _add(e, TestChars.custom("fighter", "reborn", 3), Vector2i(2, 3))
	TestCombat.start_with(e, r)
	var uses := (r.creature as Character).resource_left("knowledge_from_a_past_life")
	var bonus := r.creature.skill_bonus(&"athletics").total()
	TestCombat.next_d20(e, 5)
	var t := r.creature.roll_check(e.dice, &"athletics", 5 + bonus + 1)
	assert_eq((r.creature as Character).resource_left("knowledge_from_a_past_life"), uses - 1, "used on the failure")
	assert_true(t.extra > 0, "a d6 added")


# --- Feats and Dark Gifts -------------------------------------------------------------------------------------------

func test_survivor_rerolls_a_low_initiative() -> void:
	var e := TestCombat.open_field(3)
	var ch := _with_feat_choice(TestChars.custom("fighter", "human", 1), "survivor")
	var s := _add(e, ch, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.next_d20(e, 3)
	e.start()
	assert_true(s.initiative_test.reroll_note.contains("Survivor"), "a 3 is rolled again")


func test_sharp_eye_and_watchers_on_a_search() -> void:
	var e := TestCombat.open_field(3)
	var ch := _with_feat_choice(TestChars.custom("rogue", "human", 1), "sharp_eye")
	var c := _add(e, ch, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var uses := ch.resource_left("sharp_eye")
	assert_true(e.search(c).ok)
	assert_eq(ch.resource_left("sharp_eye"), uses - 1)
	var w := _with_feat_choice(TestChars.custom("rogue", "human", 1), "watchers")
	var keys: Array[String] = ["check:perception", "search"]
	assert_true(w.modifiers_for(&"bonus_die").any(func(m: Modifier) -> bool: return m.matches_any(keys)), "Watchers: +1d4 on a Search")


func test_a_natural_one_wakes_a_dark_gift() -> void:
	var e := TestCombat.open_field(3)
	var ch := _with_feat_choice(TestChars.custom("fighter", "human", 3), "aberrant_anatomy")
	var c := _add(e, ch, Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 1)
	e.attack(c, t, _melee(e, c))
	if e.pending != null:
		e.answer_reaction(false)
	assert_true(_logged(e, "dark gift (Aberrant Anatomy)"), "the natural 1 calls for the drawback's save")


func test_mist_walker_needs_ten_miles_for_a_short_rest() -> void:
	var ch := _with_feat_choice(TestChars.custom("fighter", "human", 1), "mist_walker")
	assert_false(ch.mists_deny_short_rest(DiceRoller.new(1), 12.0), "after 10 miles the Mists let you rest")
	var denied := false
	for s in 20:
		denied = denied or ch.mists_deny_short_rest(DiceRoller.new(s), 0.0)
	assert_true(denied, "without the miles a failed save denies the rest")
	var other := TestChars.custom("fighter", "human", 1)
	assert_false(other.mists_deny_short_rest(DiceRoller.new(1), 0.0))


# --- Subclasses ------------------------------------------------------------------------------------------------------

func test_spirits_from_beyond_spends_inspiration() -> void:
	var e := TestCombat.open_field(3)
	var b := _add(e, TestChars.custom("bard", "human", 3, {"bard_subclass": ["college_of_spirits"]}), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(4, 3), 300)
	TestCombat.start_with(e, b)
	var bi := (b.creature as Character).resource_left("bardic_inspiration")
	assert_false(_listed(e, b, "spirits_from_beyond").is_empty())
	assert_true(_act(e, b, "spirits_from_beyond", t).ok)
	assert_eq((b.creature as Character).resource_left("bardic_inspiration"), bi - 1)
	assert_false(b.bonus_available)
	assert_true(_logged(e, "channels a spirit"))


func test_path_to_the_grave_curses_then_bursts() -> void:
	var e := TestCombat.open_field(3)
	var c := _add(e, TestChars.custom("cleric", "human", 3, {"cleric_subclass": ["grave_domain"]}), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(_act(e, c, "path_to_the_grave", t).ok)
	assert_true(t.creature.d20_sources(["attack"])["disadvantage"].size() > 0, "cursed: Disadvantage on attacks")
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(c, t, _melee(e, c)).hit)
	assert_true(_logged(e, "Path to the Grave 1d8+3"), "the hit ends the curse for 1d8 + Cleric level")
	assert_false(t.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "path_to_the_grave"))


func test_sentinel_at_deaths_door_halves_a_hit() -> void:
	var e := TestCombat.open_field(3)
	var c := _add(e, TestChars.custom("cleric", "human", 6, {"cleric_subclass": ["grave_domain"]}), Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	c.reaction_rules["sentinel_at_deaths_door"] = "auto"
	TestCombat.start_with(e, z)
	TestCombat.next_d20(e, 19)
	e.attack(z, c, e.attack_options(z)[0]["id"])
	assert_false(c.reaction_available, "the cleric spent its Reaction")
	assert_true(_logged(e, "Sentinel at Death's Door"))


func test_wrath_of_the_wild_armors_and_unnerves() -> void:
	var e := TestCombat.open_field(3)
	var r := _add(e, TestChars.custom("ranger", "human", 3, {"ranger_subclass": ["hollow_warden"]}), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, r)
	var ch := r.creature as Character
	var free := ch.resource_left("spell:hunters_mark")
	var ac := r.creature.ac_value()
	assert_true(_act(e, r, "wrath_of_the_wild").ok)
	assert_eq(ch.resource_left("spell:hunters_mark"), free - 1, "a Favored Enemy use")
	assert_true(r.creature.ac_value() > ac, "Ancient Armor")
	e.end_turn()
	assert_true(t.creature.has_condition(&"frightened"), "the foe starting its turn beside the warden is unnerved")


func test_wails_from_the_grave_hits_a_second_foe() -> void:
	var e := TestCombat.open_field(3)
	var ro := _add(e, TestChars.custom("rogue", "human", 3, {"rogue_subclass": ["phantom"]}), Vector2i(2, 3))
	_add(e, TestChars.custom("fighter", "human", 1), Vector2i(4, 4))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	var second := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, ro)
	var before := second.creature.hp
	var uses := (ro.creature as Character).resource_left("wails_from_the_grave")
	TestCombat.next_d20(e, 19)
	for o in e.attack_options(ro):
		if (o["profile"] as WeaponProfile).properties.has("finesse") and bool(o["melee"]):
			e.attack(ro, t, str(o["id"]))
			break
	assert_eq((ro.creature as Character).resource_left("wails_from_the_grave"), uses - 1)
	assert_true(second.creature.hp < before, "the wail hurts the second creature")


func test_form_of_dread_and_unholy_resuscitation() -> void:
	var e := TestCombat.open_field(3)
	var w := _add(e, TestChars.custom("warlock", "human", 10, {"warlock_subclass": ["undead_patron"]}), Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, w)
	assert_true(_act(e, w, "form_of_dread").ok)
	assert_true(w.creature.temp_hp > 0, "Facsimile of Life")
	assert_true(w.creature.is_condition_immune(&"frightened"))
	assert_true(w.creature.immunity_source(&"necrotic") != "", "Necrotic Husk: immune in the form")
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(w, t, e.attack_options(w)[0]["id"]).hit)
	assert_true(t.creature.has_condition(&"frightened"), "Frightful Avatar")
	w.creature.temp_hp = 0
	e.deal_damage(t, w, [{"amount": w.creature.hp + 5, "type": "slashing"}], false, "test")
	assert_true(w.creature.hp >= 10, "Unholy Resuscitation brings the warlock back")
	assert_eq(w.creature.exhaustion, 1)


func test_shadow_sorcery_senses_and_ill_omen() -> void:
	var e := TestCombat.open_field(3)
	var s := _add(e, TestChars.custom("sorcerer", "human", 6, {"sorcerer_subclass": ["shadow_sorcery"]}), Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, s)
	assert_eq(s.creature.darkvision(), 120)
	assert_eq(s.creature.sense_range("blindsight"), 10)
	assert_true(e.spells.cast(s, "summon_undead", 3, [], Vector2(3.5, 4.5), Vector2.ZERO, {"free": true}).ok)
	assert_true(s.creature.concentration == null, "Spirits of Ill Omen: no Concentration")
