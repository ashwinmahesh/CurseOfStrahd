extends TestCase
## Particular magic items doing their particular things (ADR 0012): weapons' riders, defensive items, containers,
## manuals, figurines, Spell Scrolls, and random treasure.


func _comp() -> Compendium:
	return Compendium.shared()


func _armed(e: Encounter, item_id: String, cell: Vector2i = Vector2i(2, 2), pregen: String = "ilse_varga") -> Combatant:
	var c := TestCombat.hero(e, pregen, cell, 5)
	var ch := c.creature as Character
	ch.add_item(item_id)
	if MagicItems.needs_attunement(_comp().item_data(item_id)):
		ch.attune(item_id)
	ch.equip(item_id, "main_hand")
	return c


func test_flame_tongue_burns_only_while_ablaze_and_lights_the_field() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "flame_tongue__longsword")
	var bag := TestCombat.punching_bag(e, Vector2i(3, 2))
	TestCombat.start_with(e, c)
	var opt := e.option_by_id(c, "weapon:flame_tongue__longsword")
	var st := {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": opt, "critical": false}
	assert_eq(e.items.hit_damage_dice(c, bag, opt, st).size(), 0, "not lit")
	var r := e.items.use(c, "flame_tongue__longsword", "ignite")
	assert_true(r.ok, r.reason)
	assert_false(c.bonus_available, "a Bonus Action")
	var dice := e.items.hit_damage_dice(c, bag, opt, st)
	assert_eq(dice.size(), 1)
	assert_eq(str(dice[0]["dice"]), "2d6")
	assert_eq(str(dice[0]["type"]), "fire")
	assert_eq(str(e.light_at(Vector2i(10, 2))), "bright", "40 ft of bright light")


func test_slayers_and_disruption_only_against_their_prey() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "giant_slayer__greataxe")
	var human := TestCombat.punching_bag(e, Vector2i(3, 2))
	var giant := TestCombat.punching_bag(e, Vector2i(3, 3), 80, "giant")
	TestCombat.start_with(e, c)
	var opt := e.option_by_id(c, "weapon:giant_slayer__greataxe")
	var st := {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": opt, "critical": false}
	assert_eq(e.items.hit_damage_dice(c, human, opt, st).size(), 0)
	assert_eq(e.items.hit_damage_dice(c, giant, opt, st).size(), 1, "2d6 more against a Giant")


func test_vorpal_sword_beheads_on_a_20_and_cuts_through_resistance() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "vorpal_sword__longsword")
	var bag := TestCombat.punching_bag(e, Vector2i(3, 2), 300)
	TestCombat.start_with(e, c)
	var parts: Array = [{"amount": 10, "type": "slashing", "item": "vorpal_sword__longsword"}]
	e.items.adjust_incoming(c, bag, parts, "test")
	assert_true(bool((parts[0] as Dictionary).get("ignore_resistance", false)))
	var opt := e.option_by_id(c, "weapon:vorpal_sword__longsword")
	var st := {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 20, 5, 10), "option": opt, "critical": true}
	var r := CombatResult.new()
	e.items.after_hit(c, bag, opt, DamageResult.new(), st, r)
	assert_true(bag.creature.dead, "off with its head")


func test_sword_of_wounding_bleeds_and_the_wound_can_only_rest_away() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "sword_of_wounding__longsword")
	var bag := TestCombat.punching_bag(e, Vector2i(3, 2), 100)
	TestCombat.start_with(e, c)
	var opt := e.option_by_id(c, "weapon:sword_of_wounding__longsword")
	var dr := DamageResult.new()
	dr.final = 10
	e.items.after_hit(c, bag, opt, dr, {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": opt, "critical": false}, CombatResult.new())
	assert_true(bag.creature.has_flag("wounded"))
	assert_eq(bag.creature.unhealable, 10)
	bag.creature.hp = 50
	bag.creature.heal(100, "Cure Wounds")
	assert_eq(bag.creature.hp, 90, "the wound's 10 can't be healed by magic")
	var before := bag.creature.hp
	e.items.turn_start(bag)
	assert_true(bag.creature.hp < before, "1d4 Necrotic at the start of its turn")


func test_adamantine_armor_turns_critical_hits_into_hits() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var ch := c.creature as Character
	ch.add_item("adamantine_armor__chain_mail")
	ch.equip("adamantine_armor__chain_mail", "armor")
	var foe := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	TestCombat.start_with(e, c)
	var details: Array[String] = []
	assert_false(e.items.crit_allowed(foe, c, true, details))
	assert_eq(details.size(), 1)


func test_ring_of_evasion_turns_a_failed_dex_save() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2), 5)
	var ch := c.creature as Character
	ch.add_item("ring_of_evasion")
	ch.attune("ring_of_evasion")
	ch.wear("ring_of_evasion")
	TestCombat.foe(e, "wolf", Vector2i(8, 2))
	TestCombat.start_with(e, c)
	var t := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 2, 0, 20)
	e.items.after_d20(c, t, ["save:all", "save:dex"])
	assert_true(t.success, "the ring turns it")
	assert_eq(ch.charges_left("ring_of_evasion"), 2)
	assert_false(c.reaction_available)


func test_cloak_of_displacement_until_the_wearer_is_hurt() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2), 5)
	var ch := c.creature as Character
	ch.add_item("cloak_of_displacement")
	ch.attune("cloak_of_displacement")
	ch.wear("cloak_of_displacement")
	var wolf := TestCombat.foe(e, "wolf", Vector2i(3, 2))
	TestCombat.start_with(e, c)
	var opt := e.option_by_id(wolf, "monster:bite")
	var st := {"c": wolf, "target": c, "option": opt, "sit": e.attack_situation(wolf, c, opt), "ac": c.creature.ac_value(), "opts": {}}
	e.items.before_roll(st)
	assert_true(((st["sit"] as Dictionary)["disadvantage"] as Array).any(func(x: Variant) -> bool: return str(x).begins_with("Cloak of Displacement")))
	e.items.on_damaged(wolf, c, 3, [])
	var st2 := {"c": wolf, "target": c, "option": opt, "sit": e.attack_situation(wolf, c, opt), "ac": c.creature.ac_value(), "opts": {}}
	e.items.before_roll(st2)
	assert_false(((st2["sit"] as Dictionary)["disadvantage"] as Array).any(func(x: Variant) -> bool: return str(x).begins_with("Cloak of Displacement")), "off after being hurt")


func test_bag_of_holding_weighs_five_pounds_and_two_spaces_tear() -> void:
	var ch := TestChars.pregen("ilse_varga", 3)
	ch.add_item("bag_of_holding")
	ch.add_item("plate_armor")
	var before := ch.carried_weight()
	assert_eq(ch.put_in("bag_of_holding", "plate_armor"), "")
	assert_between(ch.carried_weight(), before - 65.1, before - 64.9, "the armor weighs nothing in the bag")
	assert_true(ch.carries("plate_armor"), "still the party's")
	assert_true(ch.take_out("bag_of_holding", 0))
	ch.add_item("portable_hole")
	assert_eq(ch.put_in("bag_of_holding", "portable_hole"), "rift")
	assert_false(ch.carries("bag_of_holding"))
	assert_false(ch.carries("portable_hole"))


func test_a_manual_raises_a_score_and_its_maximum_for_good() -> void:
	var st := StoryState.new()
	var ch := TestChars.pregen("ilse_varga", 3)
	st.party.append(ch)
	var before := ch.ability_score(&"str")
	ch.add_item("manual_of_gainful_exercise")
	var res := FieldItems.use(st, ch, "manual_of_gainful_exercise", "study", ch, DiceRoller.new(4))
	assert_true(bool(res["ok"]), str(res.get("text", "")))
	assert_eq(ch.ability_score(&"str"), mini(before + 2, 22))
	assert_false(ch.carries("manual_of_gainful_exercise"), "its magic is spent")
	var copy := Character.from_dict(ch.to_dict())
	assert_eq(copy.ability_score(&"str"), ch.ability_score(&"str"), "kept in the build")


func test_figurine_becomes_its_creature_and_rests_for_days() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var ch := c.creature as Character
	ch.add_item("figurine_of_wondrous_power_onyx_dog")
	TestCombat.foe(e, "wolf", Vector2i(9, 6))
	TestCombat.start_with(e, c)
	var n := e.combatants.size()
	var r := e.items.use(c, "figurine_of_wondrous_power_onyx_dog", "animate", [], Vector2(4.5, 2.5))
	assert_true(r.ok, r.reason)
	assert_eq(e.combatants.size(), n + 1, "a Mastiff joins")
	var p := e.items.find_power(c, "figurine_of_wondrous_power_onyx_dog", "animate")
	assert_true(e.items.power_why(c, p).begins_with("Ready again in 7 days"))
	for i in 7:
		ch.on_dawn(DiceRoller.new(i))
	c.action_available = true
	c.magic_action_used = false
	assert_eq(e.items.power_why(c, p), "", "a week later it works again")


func test_spell_scrolls_name_their_spell_and_read_at_their_own_dc() -> void:
	var d := _comp().item_data("spell_scroll__fireball")
	assert_eq(str(d["name"]), "Spell Scroll (Fireball)")
	assert_eq(MagicItems.rarity(d), "uncommon")
	var ch := TestChars.pregen("silvain_aster", 5)
	ch.add_item("spell_scroll_level_1")
	var found := ""
	for e in ch.inventory:
		if str(e["id"]).begins_with("spell_scroll__"):
			found = str(e["id"])
	assert_true(found != "", "a generic scroll becomes a particular one")
	assert_true(str(_comp().item_data(found)["name"]).begins_with("Spell Scroll ("))
	assert_eq(int(_comp().spell_data(found.get_slice("__", 1)).get("level", -1)), 1)
	var items := Treasure.specify_scrolls([{"id": "spell_scroll_cantrip", "qty": 2}], StoryState.new(), "x")
	assert_eq(items.size(), 2)
	assert_true(str((items[0] as Dictionary)["id"]).begins_with("spell_scroll__"))


func test_treasure_is_the_same_for_a_seed_and_fits_the_level() -> void:
	var a := StoryState.new()
	a.playthrough_seed = 77
	var b := StoryState.new()
	b.playthrough_seed = 77
	var loc := ""
	for l in _comp().all("locations"):
		if (l.get("containers", []) as Array).size() >= 2:
			loc = str(l["id"])
			break
	assert_eq(JSON.stringify(Treasure.placed(a, loc)), JSON.stringify(Treasure.placed(b, loc)), "same seed, same treasure")
	var counts := {}
	var rng := DiceRoller.new(5)
	for i in 200:
		var it := Treasure.roll_item(rng, 2)
		var r := MagicItems.rarity(_comp().item_data(str(it.get("id", ""))))
		counts[r] = int(counts.get(r, 0)) + 1
	assert_false(counts.has("rare") or counts.has("very_rare") or counts.has("legendary"), "level 2: uncommon only, got %s" % counts)
	assert_false(counts.has("common"), "no commons (owner, 2026-10-08), got %s" % counts)
	assert_true(counts.has("uncommon"))


func test_charges_come_back_when_the_clock_passes_dawn() -> void:
	var st := StoryState.new()
	var ch := TestChars.pregen("silvain_aster", 5)
	st.party.append(ch)
	st.minute_of_day = 22 * 60
	ch.add_item("wand_of_magic_missiles")
	ch.spend_charges("wand_of_magic_missiles", 6)
	st.advance_minutes(8 * 60)
	assert_true(ch.charges_left("wand_of_magic_missiles") >= 3, "1d6 + 1 back at 6 o'clock")


func test_staff_of_power_guards_its_holder_and_casts_at_their_dc() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2), 5)
	var ch := c.creature as Character
	var ac := ch.ac_value()
	ch.add_item("staff_of_power__quarterstaff")
	ch.attune("staff_of_power__quarterstaff")
	assert_eq(ch.ac_value(), ac, "only while held")
	ch.equip("staff_of_power__quarterstaff", "main_hand")
	assert_eq(ch.ac_value(), ac + 2)
	var bag := TestCombat.punching_bag(e, Vector2i(6, 2))
	TestCombat.start_with(e, c)
	var hp := bag.creature.hp
	var r := e.items.use(c, "staff_of_power__quarterstaff", "magic_missile", [bag])
	assert_true(r.ok, r.reason)
	assert_true(bag.creature.hp < hp)
	assert_eq(ch.charges_left("staff_of_power__quarterstaff"), 19)


func test_identify_shows_what_a_disguised_item_really_is() -> void:
	var ch := TestChars.pregen("ilse_varga", 3)
	ch.add_item("potion_of_poison")
	var data := _comp().item_data("potion_of_poison")
	var e := ch.entry_of("potion_of_poison")
	assert_true(MagicItems.is_disguised(data, e))
	assert_eq(MagicItems.display_name(data, e), "Potion of Healing")
	assert_eq(str(MagicItems.shown_data(data, e)["id"]), "potion_of_healing", "its card shows the healing potion")
	assert_true(MagicItems.can_identify(data, e))
	assert_eq(ch.identify("potion_of_poison"), "Potion of Poison")
	assert_eq(MagicItems.display_name(data, ch.entry_of("potion_of_poison")), "Potion of Poison")
	assert_false(MagicItems.can_identify(data, ch.entry_of("potion_of_poison")))
	var copy := Character.from_dict(ch.to_dict())
	assert_eq(MagicItems.display_name(data, copy.entry_of("potion_of_poison")), "Potion of Poison", "kept in the save")
	# Every magic item can be identified, so the offer gives nothing away; attuning teaches an item too.
	ch.add_item("cloak_of_protection")
	assert_true(MagicItems.can_identify(_comp().item_data("cloak_of_protection"), ch.entry_of("cloak_of_protection")))
	var avid := "armor_of_vulnerability_slashing__plate_armor"
	ch.add_item(avid)
	var av := _comp().item_data(avid)
	assert_eq(MagicItems.display_name(av, ch.entry_of(avid)), "Plate Armor of Slashing Resistance")
	assert_false((MagicItems.shown_data(av, ch.entry_of(avid))["magic"] as Dictionary).has("curse"), "no curse showing")
	assert_true(MagicItems.is_cursed(av), "though it is cursed")
	assert_true(ch.attune(avid))
	assert_eq(MagicItems.display_name(av, ch.entry_of(avid)), "Plate Armor of Vulnerability (Slashing)", "attuning reveals it")


func test_any_party_member_can_cast_a_spell_into_a_ring_of_spell_storing() -> void:
	var st := StoryState.new()
	var holder := TestChars.pregen("ilse_varga", 5)
	var wizard := TestChars.pregen("silvain_aster", 5)
	wizard.finish_long_rest()
	st.party.append(holder)
	st.party.append(wizard)
	holder.add_item("ring_of_spell_storing")
	var entry := holder.entry_of("ring_of_spell_storing")
	entry["stored"] = []
	var opts := FieldItems.options(st.party, holder, "ring_of_spell_storing", DiceRoller.new(3))
	var store := {}
	for o in opts:
		if str(o["power_id"]) == "store":
			store = o
	assert_true(bool(store.get("legal", false)), "no attunement or wearing needed to cast into it: %s" % store.get("reason", ""))
	var picks := store["store"] as Array
	assert_false(picks.is_empty())
	assert_true(picks.all(func(p: Variant) -> bool: return str((p as Dictionary)["caster"]) == wizard.id), "only the wizard casts")
	var pick := picks[0] as Dictionary
	var slots_before := wizard.slots_left(int(pick["level"]))
	var res := FieldItems.use(st, holder, "ring_of_spell_storing", "store", null, DiceRoller.new(3),
		{"caster": str(pick["caster"]), "spell": str(pick["spell"]), "level": int(pick["level"])})
	assert_true(bool(res["ok"]), str(res["text"]))
	var stored := holder.entry_of("ring_of_spell_storing")["stored"] as Array
	assert_eq(stored.size(), 1)
	assert_eq(str((stored[0] as Dictionary)["spell"]), str(pick["spell"]))
	assert_eq(int((stored[0] as Dictionary)["dc"]), wizard.spell_save_dc(str(wizard.spellcasting[0]["class_id"])).total(), "the wizard's DC")
	assert_eq(wizard.slots_left(int(pick["level"])), slots_before - 1, "the wizard's slot is spent")
	entry = holder.entry_of("ring_of_spell_storing")
	entry["stored"] = [{"spell": "x", "level": 5}]
	var full := FieldItems.options(st.party, holder, "ring_of_spell_storing", DiceRoller.new(3))
	for o2 in full:
		if str(o2["power_id"]) == "store":
			assert_false(bool(o2["legal"]), "a full ring takes nothing more")


## Selling an attuned item ends the attunement, as giving it away does (QA FN-04: a sold item's attunement stayed,
## filling a slot for good with no item left to end it on).
func test_selling_an_attuned_item_frees_its_attunement() -> void:
	var npcs := _comp().tables["npcs"] as Dictionary
	npcs["test_fence"] = {"id": "test_fence", "name": "Test Fence", "summary": "", "shop": {"sells": [], "sell_rate": 0.5}}
	var st := StoryState.new()
	var ch := TestChars.pregen("ilse_varga", 5)
	st.party.append(ch)
	ch.add_item("cloak_of_protection")
	assert_true(ch.wear("cloak_of_protection"))
	assert_true(ch.attune("cloak_of_protection"))
	assert_eq(st.shop_sell("test_fence", "cloak_of_protection", ch), "")
	assert_true(ch.entry_of("cloak_of_protection").is_empty(), "sold")
	assert_false("cloak_of_protection" in ch.attuned, "and the attunement with it")
	npcs.erase("test_fence")


## A cursed item its holder is attuned to stays with them until the curse is lifted (QA FN-05: giving, stashing,
## dropping or selling it was the way out, and cursed armor came off with a click): nothing lets it go, and the armor
## stays on; once Remove Curse lifts it, it can go.
func test_a_cursed_item_stays_with_its_bearer_until_the_curse_is_lifted() -> void:
	var npcs := _comp().tables["npcs"] as Dictionary
	npcs["test_fence"] = {"id": "test_fence", "name": "Test Fence", "summary": "", "shop": {"sells": [], "sell_rate": 0.5}}
	var st := StoryState.new()
	var ch := TestChars.pregen("ilse_varga", 5)
	st.party.append(ch)
	var armor := "demon_armor__plate_armor"
	ch.add_item(armor)
	assert_true(ch.equip(armor, "armor"))
	assert_eq(ch.part_blocker(armor), "", "not attuned yet: the curse hasn't taken hold")
	assert_true(ch.attune(armor))
	assert_ne(ch.part_blocker(armor), "", "attuned: it won't leave")
	assert_ne(ch.take_off_blocker(armor), "", "and the armor won't come off")
	assert_ne(st.shop_sell("test_fence", armor, ch), "", "no merchant takes it")
	assert_false(st.stash_put(armor, ch), "nor the stash")
	assert_false(ch.entry_of(armor).is_empty(), "still carried")
	assert_eq(ch.part_blocker("cloak_of_protection"), "", "anything else goes as ever")
	ch.add_item("berserker_axe__greataxe")
	assert_true(ch.attune("berserker_axe__greataxe"))
	assert_ne(ch.part_blocker("berserker_axe__greataxe"), "", "a cursed weapon stays with its bearer")
	assert_eq(ch.take_off_blocker("berserker_axe__greataxe"), "", "though it can be put down, unlike the armor")
	ch.entry_of(armor)["curse_lifted"] = true
	assert_eq(ch.part_blocker(armor), "", "lifted: it can go")
	assert_eq(st.shop_sell("test_fence", armor, ch), "")
	npcs.erase("test_fence")


## An item power that changes its user's shape is still paid for (QA FN-08): a wizard who reads a Spell Scroll of
## Polymorph on herself is a beast by the time the scroll is used up, and the scroll stayed (with a SCRIPT ERROR); a
## Wand of Polymorph's charge comes off the same way.
func test_an_item_that_polymorphs_its_user_is_still_used_up() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.high_caster(e, [], Vector2i(2, 2))
	TestCombat.punching_bag(e, Vector2i(8, 2))
	var ch := c.creature as Character
	ch.add_item("spell_scroll__polymorph")
	TestCombat.start_with(e, c)
	var r := e.items.use(c, "spell_scroll__polymorph", "read", [c])
	assert_true(r.ok, r.reason)
	assert_true(e.shapes.is_shaped(c), "a beast now")
	assert_true(ch.entry_of("spell_scroll__polymorph").is_empty(), "the scroll is used up")
	var e2 := TestCombat.open_field()
	var c2 := TestCombat.high_caster(e2, [], Vector2i(2, 2))
	TestCombat.punching_bag(e2, Vector2i(8, 2))
	var ch2 := c2.creature as Character
	ch2.add_item("wand_of_polymorph")
	ch2.attune("wand_of_polymorph")
	ch2.equip("wand_of_polymorph", "main_hand")
	var charges := int(ch2.entry_of("wand_of_polymorph").get("charges", 0))
	TestCombat.start_with(e2, c2)
	var r2 := e2.items.use(c2, "wand_of_polymorph", "polymorph", [c2])
	assert_true(r2.ok, r2.reason)
	assert_eq(int(ch2.entry_of("wand_of_polymorph").get("charges", 0)), charges - 1, "a charge spent")


## Nolzur's Marvelous Pigments (The Count's Portraitist's reward): each of the case's 1d4 pots paints a real object worth
## up to 25 GP into the painter's hands, and the case is gone with its last pot.
func test_the_pigments_paint_real_objects_until_the_pots_run_out() -> void:
	var st := StoryState.new()
	var ch := TestChars.pregen("ilse_varga", 9)
	st.party.append(ch)
	ch.add_item("marvelous_pigments")
	var pots := ch.charges_left("marvelous_pigments")
	assert_true(pots >= 1 and pots <= 4, "1d4 pots: %d" % pots)
	var paint: Dictionary = {}
	for o in FieldItems.options(st.party, ch, "marvelous_pigments", DiceRoller.new(1)):
		if str(o["power_id"]) == "paint":
			paint = o
	assert_true(bool(paint.get("legal", false)), str(paint.get("reason", "")))
	assert_true("ladder" in (paint["choices"] as Array))
	var res := FieldItems.use(st, ch, "marvelous_pigments", "paint", ch, DiceRoller.new(2), {"choice": "ladder"})
	assert_true(bool(res["ok"]), str(res.get("text", "")))
	assert_true(ch.carries("ladder"), "the painted ladder is real")
	assert_false(bool(FieldItems.use(st, ch, "marvelous_pigments", "paint", ch, DiceRoller.new(2), {"choice": "plate_armor"})["ok"]),
		"nothing off the list (worth more than 25 GP)")
	for i in pots - 1:
		assert_true(bool(FieldItems.use(st, ch, "marvelous_pigments", "paint", ch, DiceRoller.new(3 + i), {"choice": "rope"})["ok"]))
	assert_false(ch.carries("marvelous_pigments"), "the last pot used, the case is gone")


## The Golden Idol of Good Fortunes (The Silver Hoard's reward): +1 AC while attuned, Augury once a day outside fights, a
## carried gemstone turned into its full worth in coin, and Globe of Invulnerability once a day in a fight.
func test_the_golden_idol_works_in_and_out_of_fights() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2), 9)
	var ch := c.creature as Character
	var ac := ch.ac_value()
	ch.add_item("golden_idol_of_good_fortunes")
	assert_true(ch.attune("golden_idol_of_good_fortunes"))
	assert_eq(ch.ac_value(), ac + 1, "+1 AC while attuned")
	var st := StoryState.new()
	st.party.append(ch)
	var opts := {}
	for o in FieldItems.options(st.party, ch, "golden_idol_of_good_fortunes", DiceRoller.new(1)):
		opts[str(o["power_id"])] = o
	assert_true(bool(opts["augury"]["legal"]), str(opts["augury"]["reason"]))
	assert_false(bool(opts["coin"]["legal"]), "nothing to change yet")
	assert_eq(str(opts["coin"]["reason"]), "No gemstones to change")
	ch.add_item("onyx")
	for o in FieldItems.options(st.party, ch, "golden_idol_of_good_fortunes", DiceRoller.new(1)):
		if str(o["power_id"]) == "coin":
			assert_eq(o["choices"], ["onyx"], "only what's carried")
	st.gold = 0.0
	var res := FieldItems.use(st, ch, "golden_idol_of_good_fortunes", "coin", ch, DiceRoller.new(2), {"choice": "onyx"})
	assert_true(bool(res["ok"]), str(res.get("text", "")))
	assert_eq(roundi(st.gold), 50, "an onyx's full worth")
	assert_false(ch.carries("onyx"))
	assert_true(bool(FieldItems.use(st, ch, "golden_idol_of_good_fortunes", "augury", ch, DiceRoller.new(2))["ok"]))
	TestCombat.start_with(e, c)
	var r := e.items.use(c, "golden_idol_of_good_fortunes", "globe", [c])
	assert_true(r.ok, r.reason)
	assert_false(e.items.use(c, "golden_idol_of_good_fortunes", "globe", [c]).ok, "once a day")


## The Wand of Slumber (The Waystone's reward): any hero can attune and put a foe to sleep with it in a fight, and its
## Catnap works outside one: the user and two companions sleep ten minutes and wake with a Short Rest's benefits.
func test_the_wand_of_slumber_sleeps_foes_and_rests_friends() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 6)
	var ch := c.creature as Character
	ch.add_item("wand_of_slumber")
	assert_true(ch.attune("wand_of_slumber"), "a fighter can attune it")
	var foe := TestCombat.foe(e, "bandit", Vector2i(5, 2))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(e.items.use(c, "wand_of_slumber", "sleep", [foe], Vector2(5, 2)).ok)
	assert_true(foe.creature.has_condition(&"incapacitated"), "a failed save: the first stage of Sleep")
	var st := StoryState.new()
	st.party.append(ch)
	for id: String in ["silvain_aster", "hedda_ironvow", "tamsin_tealeaf"]:
		st.party.append(TestChars.pregen(id, 6))
	ch.spend_resource("second_wind")
	var left := ch.resource_left("second_wind")
	var charges := ch.charges_left("wand_of_slumber")
	var minutes := st.total_minutes()
	var catnap: Dictionary = {}
	for o in FieldItems.options(st.party, ch, "wand_of_slumber", DiceRoller.new(1)):
		if str(o["power_id"]) == "catnap":
			catnap = o
	assert_true(bool(catnap.get("legal", false)), "Catnap is usable outside a fight: %s" % catnap.get("reason", "not offered"))
	var res := FieldItems.use(st, ch, "wand_of_slumber", "catnap", ch, DiceRoller.new(3))
	assert_true(bool(res["ok"]), str(res.get("text", "")))
	assert_eq(ch.charges_left("wand_of_slumber"), charges - 3, "three charges")
	assert_eq(st.total_minutes() - minutes, 10)
	assert_true(ch.resource_left("second_wind") > left, "the user woke with a Short Rest's benefits")
	assert_true(str(res["text"]).contains("Ilse, Silvain, Hedda") and not str(res["text"]).contains("Tamsin"),
		"the user and two companions: %s" % res["text"])


## Dimensional Shackles (The Baron's Island): a Utilize action binds an Incapacitated foe within 5 ft, who then can't
## teleport; one pair holds one creature at a time.
func test_dimensional_shackles_bind_one_foe_who_cannot_teleport() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2), 5)
	(c.creature as Character).add_item("dimensional_shackles")
	var foe := TestCombat.foe(e, "bandit", Vector2i(3, 2))
	var other := TestCombat.foe(e, "bandit", Vector2i(2, 3))
	TestCombat.start_with(e, c)
	assert_false(e.items.use(c, "dimensional_shackles", "shackle", [foe], Vector2(3, 2)).ok, "only an Incapacitated creature")
	foe.creature.add_condition(&"incapacitated", "test")
	other.creature.add_condition(&"incapacitated", "test")
	assert_true(e.items.use(c, "dimensional_shackles", "shackle", [foe], Vector2(3, 2)).ok)
	assert_true(foe.creature.has_condition(&"restrained"))
	TestCombat.start_with(e, c)
	var again := e.items.use(c, "dimensional_shackles", "shackle", [other], Vector2(2, 3))
	assert_false(again.ok, "one pair, one prisoner")
	assert_true("already on" in again.reason, again.reason)
	foe.creature.remove_condition(&"incapacitated", "test")
	var at := foe.cell
	e.spells._teleport(foe, Vector2i(6, 6), CombatResult.new())
	assert_eq(foe.cell, at, "the shackles stop a teleport")

