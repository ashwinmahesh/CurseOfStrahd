extends TestCase
## The Heroes of Faerûn and Arcana Unleashed general feats switched on in batch 3, taken at level 4 through the real
## level-up path and used in a fight (combat/faerun_features.gd, the data recipes).

const FEATS := ["abjuration_adept", "divination_adept", "enchantment_adept", "evocation_adept", "illusion_adept",
	"necromancy_adept", "magic_connoisseur", "spell_subterfuge", "cold_caster", "dragonscarred", "enclave_magic",
	"fairy_trickster", "genie_magic", "harper_teamwork", "lordly_resolve", "orders_resilience",
	"purple_dragon_commandant", "spellfire_adept", "street_justice", "zhentarim_tactics"]


func _with(class_id: String, feat_id: String, level: int = 4, background: String = "soldier", picks: Dictionary = {}) -> Character:
	var p := picks.duplicate()
	p[".4.ability_score_improvement"] = [feat_id]
	var ch := TestChars.custom(class_id, "human", level, p, background)
	assert_true(ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == feat_id), "%s took %s" % [class_id, feat_id])
	return ch


func _cast(e: Encounter, c: Combatant, id: String, slot: int, targets: Array = [], point: Vector2 = Vector2.INF) -> CombatResult:
	var ch := c.creature as Character
	if not ch.knows_spell(id):
		(ch.spellcasting[0]["prepared"] as Array).append(id)
	return e.spells.cast(c, id, slot, targets, point)


func _find(e: Encounter, c: Combatant, id: String) -> Dictionary:
	return ActionCatalog.new(e).find(c, id)


func _spent_hd(ch: Character) -> int:
	var n := 0
	for k: String in ch.hit_dice_spent:
		n += int(ch.hit_dice_spent[k])
	return n


func test_every_general_feat_is_offered() -> void:
	var offered := Compendium.shared().feats_in("general").map(func(f: Dictionary) -> String: return str(f["id"]))
	for id: String in FEATS:
		assert_true(id in offered, "%s offered" % id)
	assert_false("mythal_touched" in offered, "Mythal Touched waits for its table")


func test_abjuration_adept_wards_after_a_slotted_abjuration() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("wizard", "abjuration_adept"), &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "mage_armor", 1, [c]).ok)
	assert_eq(c.creature.temp_hp, 2, "twice the slot level")


func test_divination_adept_on_automatic_hinders_a_save_and_a_divination_restores_it() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("wizard", "divination_adept"), &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	assert_eq(str(_find(e, c, "feat:reaction_policy:divination_adept_benefit:never").get("sub", "")), "Off · selected", "off until chosen")
	c.reaction_rules["divination_adept_benefit"] = "auto"
	assert_true(_cast(e, c, "mind_spike", 2, [t]).ok)
	assert_true(str(e.log.entries).contains("Divination Adept"), "the save had Disadvantage")
	assert_false(c.reaction_available, "it took the Reaction")
	assert_eq(ch.resource_left("divination_adept"), 1, "Mind Spike is a Divination spell: the use comes back")


func test_enchantment_and_illusion_adepts_cast_without_a_voice() -> void:
	for pair: Array in [["enchantment_adept", "hold_person"], ["illusion_adept", "invisibility"]]:
		var e := TestCombat.open_field(2)
		var c := e.add(_with("wizard", str(pair[0])), &"party", Vector2i(2, 3))
		var foe := TestCombat.punching_bag(e, Vector2i(4, 3))
		TestCombat.start_with(e, c)
		c.creature.add_effect(Effect.new("Gagged").with_modifier("flag", {"value": "speechless"}))
		var target: Combatant = foe if str(pair[1]) == "hold_person" else c
		assert_true(_cast(e, c, str(pair[1]), 2, [target]).ok, "%s cast while unable to speak" % pair[1])
		c.action_available = true
		c.magic_action_used = false
		c.cast_slot_spell_this_turn = false
		assert_false(_cast(e, c, "magic_missile", 1, [foe]).ok, "other schools still need a voice")


func test_evocation_and_spellfire_adepts_feed_hit_dice_into_damage() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("wizard", "evocation_adept"), &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	assert_true(_cast(e, c, "magic_missile", 1, [t]).ok, "Magic Missile")
	assert_eq(_spent_hd(ch), 2, "two Hit Dice, once this turn")
	var e2 := TestCombat.open_field(2)
	var c2 := e2.add(_with("cleric", "spellfire_adept"), &"party", Vector2i(2, 3))
	var t2 := TestCombat.punching_bag(e2, Vector2i(5, 3), 300)
	t2.creature.add_effect(Effect.new("Radiant ward").with_modifier("resistance", {"value": "radiant"}))
	TestCombat.start_with(e2, c2)
	TestCombat.next_d20(e2, 1)
	assert_true(_cast(e2, c2, "sacred_flame", 0, [t2]).ok, "Sacred Flame")
	assert_eq(_spent_hd(c2.creature as Character), 2, "Radiant spell damage")
	assert_false(str(e2.log.entries).contains("Resistance to radiant"), "Radiant ignores Resistance")


func test_necromancy_adept_heals_with_hit_dice_while_hurt() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("wizard", "necromancy_adept"), &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, c)
	c.creature.hp = 5
	assert_true(_cast(e, c, "ray_of_enfeeblement", 2, [t]).ok)
	assert_true(c.creature.hp > 5, "Hit Dice + slot level back")
	assert_eq(_spent_hd(c.creature as Character), 2)


func test_magic_connoisseur_adds_two_spells_from_the_magic_initiate_list() -> void:
	var ch := _with("fighter", "magic_connoisseur", 4, "acolyte")
	var free := ch.known_spells().filter(func(k: Dictionary) -> bool: return str(k["kind"]) == "granted" and int(k.get("uses", 0)) > 0)
	var levels := {}
	for k: Dictionary in free:
		var s := Compendium.shared().spell_data(str(k["id"]))
		assert_true("cleric" in (s.get("classes", []) as Array), "%s is on the Acolyte's Cleric list" % k["id"])
		levels[int(s["level"])] = true
	assert_true(levels.has(1) and levels.has(2), "a level 1 and a level 2 spell: %s" % [free.map(func(k: Dictionary) -> String: return str(k["id"]))])
	var magic_initiate_ability := ch.picks_for("background.feat.two_cantrips.spellcasting_ability")
	for k: Dictionary in free:
		if int(Compendium.shared().spell_data(str(k["id"]))["level"]) == 2:
			assert_eq(str(k["ability"]), magic_initiate_ability[0], "the Magic Initiate's ability")
	var blocked := TestChars.custom("fighter", "human", 4, {}, "soldier")
	var opts := ChoiceOptions.prerequisite_problem(Compendium.shared().feat_data("magic_connoisseur"), blocked, 4)
	assert_ne(opts, "", "needs Magic Initiate")


func test_shrouding_spells_dash_and_hide_and_sneaky_casting_keeps_you_hidden() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("wizard", "spell_subterfuge"), &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(9, 3), 300)
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	assert_true(ch.resource_left("shrouding_spells") >= 1)
	assert_true(_cast(e, c, "magic_missile", 1, [t]).ok)
	var move := c.movement_left
	assert_false(_find(e, c, "feat:fr:shrouding_spells").is_empty(), "offered after the spell")
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:shrouding_spells")).ok)
	assert_eq(c.movement_left, move + c.speed(), "the Dash")
	assert_false(c.bonus_available)
	c.hidden = true
	c.creature.add_condition(&"invisible", "Hidden")
	c.action_available = true
	c.magic_action_used = false
	assert_true(_cast(e, c, "fire_bolt", 0, [t]).ok)
	assert_true(c.hidden, "a Verbal spell doesn't give you away yet")


func test_cold_caster_learns_a_cantrip_and_chills_on_a_cold_hit() -> void:
	var ch := _with("fighter", "cold_caster", 4, "soldier", {"cold_caster_cantrip": ["ray_of_frost"]})
	assert_true(ch.knows_spell("ray_of_frost"))
	var e := TestCombat.open_field(2)
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 19)
	assert_true(e.spells.cast(c, "ray_of_frost", 0, [t]).ok)
	assert_true(t.creature.modifiers_for(&"penalty_die").any(func(m: Modifier) -> bool: return m.source_name.contains("Cold Caster")), "−1d4 on its next save")


func test_dragonscarred_turns_dragons_terror_into_a_bonus_action_after_damage() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("fighter", "dragonscarred", 4, "dragon_cultist"), &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(_find(e, c, "feat:fr:dragons_terror_bonus").is_empty(), "not before dealing damage")
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(c, t, str(e.attack_options(c)[0]["id"])).ok)
	assert_false(_find(e, c, "feat:fr:dragons_terror_bonus").is_empty())
	TestCombat.next_d20(e, 1)
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:dragons_terror_bonus"), [t]).ok)
	assert_false(c.bonus_available, "a Bonus Action")


func test_enclave_magic_prepares_beast_sense_with_a_free_casting() -> void:
	var ch := _with("fighter", "enclave_magic", 4, "emerald_enclave_caretaker")
	assert_true(ch.known_spells().any(func(k: Dictionary) -> bool: return str(k["id"]) == "beast_sense" and int(k.get("uses", 0)) == 1))
	assert_eq(ch.resource_left("spell:beast_sense"), 1)


func test_fairy_trickster_trots_after_disengage_and_flusters_on_a_hit() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("rogue", "fairy_trickster"), &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:flustering_strike")).ok)
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(c, t, str(e.attack_options(c)[0]["id"])).ok)
	assert_true(t.creature.effects.any(func(fx: Effect) -> bool: return fx.name == "Flustered"), "Disadvantage on saves")
	assert_true(e.disengage(c, true).ok)
	assert_true(c.creature.has_flag("ignore_difficult_terrain"), "Faerie Trod Trotter")


func test_genie_magic_casts_its_spell_free_and_higher_from_level_eleven() -> void:
	var low := _with("fighter", "genie_magic", 4, "soldier", {"wish_magic": ["magic_missile"]})
	var k := low.known_spells().filter(func(x: Dictionary) -> bool: return str(x["id"]) == "magic_missile")
	assert_eq(k.size(), 1, "the chosen Sorcerer spell")
	assert_eq(int(k[0].get("free_slot", 0)), 0, "level 1 below character level 11")
	var high := _with("fighter", "genie_magic", 11, "soldier", {"wish_magic": ["magic_missile"]})
	var e := TestCombat.open_field(2)
	var c := e.add(high, &"party", Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(5, 3), 300)
	TestCombat.start_with(e, c)
	e.drain_events()
	assert_true(e.spells.cast(c, "magic_missile", 1, [t, t, t, t]).ok, "four darts: a level 2 casting")
	assert_eq(high.resource_left("spell:magic_missile"), 0, "once per Long Rest")


func test_harper_teamwork_hinders_the_distracted_foe_and_frees_an_ally() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("bard", "harper_teamwork", 4, "harper"), &"party", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, c)
	assert_true(e.help_attack(c, foe).ok)
	assert_false((foe.creature.d20_sources(foe.creature.save_keys(&"wis"))["disadvantage"] as Array).is_empty(), "Disadvantage on its next save")
	var fear := Effect.new("Fear", &"spell", "cause_fear").with_condition(&"frightened")
	fear.repeat_save = {"ability": "wis", "dc": 1, "when": "end"}
	c.creature.add_effect(fear)
	ally.creature.add_effect(Effect.new("Fear", &"spell", "cause_fear").with_condition(&"frightened"))
	e.spells._repeat_save(c, fear, [])
	assert_false(c.creature.has_condition(&"frightened"))
	assert_false(ally.creature.has_condition(&"frightened"), "the same ends on the ally")


func test_lordly_resolve_raises_and_steadies_three_allies() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("fighter", "lordly_resolve", 4, "lords_alliance_vassal"), &"party", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	ally.creature.add_condition(&"prone", "test")
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:lordly_resolve"), [ally]).ok)
	assert_false(ally.creature.has_condition(&"prone"), "stood up with its Reaction")
	assert_true(ally.creature.is_condition_immune(&"charmed") and ally.creature.is_condition_immune(&"frightened"))
	c.creature.add_condition(&"incapacitated", "test")
	e.end_turn()
	assert_false(ally.creature.is_condition_immune(&"charmed"), "ends when its giver is Incapacitated")


func test_orders_resilience_stands_cheaply_and_shares_strength_saves() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("fighter", "orders_resilience", 4, "knight_of_the_gauntlet"), &"party", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	c.creature.add_condition(&"prone", "test")
	var move := c.movement_left
	assert_true(e.stand_up(c).ok)
	assert_eq(c.movement_left, move - 5)
	var sv := ally.creature.roll_save(e.dice, &"str", 10)
	assert_true(sv.describe().contains("Order's Resilience"), "the ally beside it")


func test_purple_dragon_commandant_needs_rook_or_martial_training_and_rallies() -> void:
	var comp := Compendium.shared()
	var wizard := TestChars.custom("wizard", "human", 4)
	assert_ne(ChoiceOptions.prerequisite_problem(comp.feat_data("purple_dragon_commandant"), wizard, 4), "", "a wizard has neither")
	var rook := TestChars.custom("wizard", "human", 4, {}, "purple_dragon_squire")
	assert_eq(ChoiceOptions.prerequisite_problem(comp.feat_data("purple_dragon_commandant"), rook, 4), "", "the Rook feat is enough")
	var e := TestCombat.open_field(2)
	var c := e.add(_with("fighter", "purple_dragon_commandant"), &"party", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(ActionCatalog.new(e).perform(c, _find(e, c, "feat:fr:commandant_rally"), [ally]).ok)
	assert_true(ally.creature.temp_hp >= 2)
	c.creature.hp = 1
	assert_false((c.creature.d20_sources(["attack"])["advantage"] as Array).is_empty(), "Advantage while Bloodied")


func test_street_justice_headlock_gives_allies_advantage() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("fighter", "street_justice"), &"party", Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 300)
	TestCombat.start_with(e, c)
	e.grapples[foe.id] = c.id
	var sit := e.attack_situation(ally, foe, e.attack_options(ally)[0])
	assert_true((sit["advantage"] as Array).any(func(x: Variant) -> bool: return str(x).begins_with("Headlock")))


func test_zhentarim_tactics_answers_a_melee_hit_with_an_opportunity_attack() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(_with("fighter", "zhentarim_tactics", 4, "zhentarim_mercenary"), &"party", Vector2i(2, 3))
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, foe)
	c.reaction_rules["fr_zhentarim_tactics"] = "auto"
	TestCombat.next_d20(e, 19)
	var r := e.monster_attack(foe, c, "slam")
	assert_true(r.ok)
	assert_false(c.reaction_available, "it struck back")
	assert_true(e.log.texts().any(func(x: String) -> bool: return x.contains("Opportunity Attack")))
