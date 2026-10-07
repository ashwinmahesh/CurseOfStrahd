extends TestCase
## The Heroes of Faerûn and Arcana Unleashed magic items switched on in batch 9 (combat/faerun_items.gd and the data).

const WEAPONS_9A := ["barnacled_wave_swept_weapon", "aquatic_wave_swept_weapon", "ascendant_wave_swept_weapon", "grave_reaper",
	"mage_breaker", "namers_needle", "three_keyholes_dagger", "ten_keyholes_dagger", "many_keyholes_dagger",
	"dispelling_ammunition", "goading_ammunition", "tramontane_armor"]


func _armed(e: Encounter, item_id: String, cell: Vector2i = Vector2i(2, 2)) -> Combatant:
	var c := TestCombat.hero(e, "ilse_varga", cell, 5)
	var ch := c.creature as Character
	ch.add_item(item_id)
	if MagicItems.needs_attunement(Compendium.shared().item_data(item_id)):
		ch.attune(item_id)
	ch.equip(item_id, "armor" if item_id.begins_with("tramontane") else "main_hand")
	return c


func _talker(e: Encounter, cell: Vector2i) -> Combatant:
	var m := TestChars.dummy(300, false, {"type": "humanoid", "ac": 1, "languages": ["common"],
		"abilities": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}})
	return e.add(m, &"enemy", cell)


func _hit_state(e: Encounter, c: Combatant, item_id: String) -> Dictionary:
	var opt := e.option_by_id(c, "weapon:" + item_id)
	return {"t": D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 12, 5, 10), "option": opt, "critical": false}


func test_the_9a_items_are_switched_on() -> void:
	var ids := Compendium.shared().all_playable("magic_items").map(func(d: Dictionary) -> String: return str(d["id"]))
	for id: String in WEAPONS_9A:
		assert_true(id in ids, "%s playable" % id)


func test_wave_swept_weapons_swim_glow_and_salt() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "ascendant_wave_swept_weapon__longsword")
	TestCombat.punching_bag(e, Vector2i(9, 2))
	TestCombat.start_with(e, c)
	assert_eq(c.creature.speed("swim").total(), 30, "Swim 30")
	assert_eq(c.creature.speed("fly").total(), 30, "Fly 30")
	assert_true(c.creature.has_flag("water_breathing"))
	assert_false(e.items.find_power(c, "ascendant_wave_swept_weapon__longsword", "salt").is_empty(), "salts water")


func test_grave_reaper_lantern_holds_five() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "grave_reaper__sickle")
	TestCombat.punching_bag(e, Vector2i(9, 2))
	TestCombat.start_with(e, c)
	var r := e.items.use(c, "grave_reaper__sickle", "spirit_lantern", [c])
	assert_true(r.ok, r.reason)
	assert_true(c.creature.has_flag("spirit_lantern"), "the lantern hovers")
	assert_eq(int(c.get_meta("lantern_capacity", 0)), 5, "five fragments")


func test_mage_breaker_hinders_concentration() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "mage_breaker__dagger")
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2), 300)
	TestCombat.start_with(e, c)
	foe.creature.begin_concentration("bless", "Bless")
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, "weapon:mage_breaker__dagger").hit)
	assert_true(e.log.dump().contains("Mage Breaker"), "the Concentration save had Disadvantage")
	assert_false(foe.has_meta("mage_broken"), "only that save")


func test_namers_needle_learns_a_name_and_crits_with_it() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "namers_needle__dagger")
	var foe := _talker(e, Vector2i(3, 2))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, "weapon:namers_needle__dagger").hit)
	assert_true(c.id in (foe.get_meta("named_to", []) as Array), "it spoke its name")
	assert_true(e.items.use(c, "namers_needle__dagger", "speak_name").ok)
	c.attacks_left = 1
	TestCombat.next_d20(e, 12)
	var r := e.attack(c, foe, "weapon:namers_needle__dagger")
	assert_true(r.hit and r.critical, "the name makes it a Critical Hit")


func test_keyholes_dagger_takes_another_shape_and_tries_again() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "many_keyholes_dagger__dagger")
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2), 300)
	TestCombat.start_with(e, c)
	var r := e.items.use(c, "many_keyholes_dagger__dagger", "reshape", [], Vector2.INF, Vector2.ZERO, 0, {"choice": "longsword"})
	assert_true(r.ok, r.reason)
	var p := e.option_by_id(c, "weapon:many_keyholes_dagger__dagger")["profile"] as WeaponProfile
	assert_true(p.name.contains("Longsword"), "a longsword now")
	assert_true(p.damage_dice in ["1d8", "1d10"], "with a longsword's damage")
	var best := &"dex" if c.creature.ability_mod(&"dex") > c.creature.ability_mod(&"str") else &"str"
	assert_eq(p.ability, best, "the better of Strength and Dexterity")
	var st := _hit_state(e, c, "many_keyholes_dagger__dagger")
	st["c"] = c
	st["t"] = D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 2, 5, 30)
	st["ac"] = 30
	var offers := e.items.specials.fr.after_miss_offers(st)
	assert_eq(offers.size(), 1, "a second try")
	(offers[0]["use"] as Callable).call()
	assert_eq(e.items.specials.fr.after_miss_offers(st).size(), 0, "once a day")
	var _unused := foe


func test_dispelling_and_goading_ammunition() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var foe := _talker(e, Vector2i(6, 2))
	TestCombat.start_with(e, c)
	var low := Effect.new("Bless", &"spell", "bless")
	low.spell_level = 1
	var high := Effect.new("Greater Invisibility", &"spell", "greater_invisibility")
	high.spell_level = 4
	foe.creature.add_effect(low)
	foe.creature.add_effect(high)
	var dr := DamageResult.new()
	dr.final = 5
	var it := {"id": "dispelling_ammunition__arrow", "data": Compendium.shared().item_data("dispelling_ammunition__arrow")}
	e.items.specials.fr.after_hit(c, foe, {}, dr, {}, CombatResult.new(), it)
	assert_false(foe.creature.effects.has(low), "a level 1 spell ends")
	assert_true(foe.creature.effects.has(high), "a level 4 one stays")
	var it2 := {"id": "goading_ammunition__arrow", "data": Compendium.shared().item_data("goading_ammunition__arrow")}
	e.items.specials.fr.after_hit(c, foe, {}, dr, {}, CombatResult.new(), it2)
	assert_true(foe.creature.has_flag("no_reactions"), "goaded")


func test_tramontane_armor_grips_and_drags() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "tramontane_armor__leather_armor")
	var foe := _talker(e, Vector2i(6, 2))
	TestCombat.start_with(e, c)
	assert_true((e.move_mode(c) & CombatGrid.MOVE_TERRAIN) != 0, "difficult ground is no bother")
	assert_false(e.items.use(c, "tramontane_armor__leather_armor", "pull", [foe]).ok, "not before the grip wakes")
	assert_true(e.items.use(c, "tramontane_armor__leather_armor", "grip").ok)
	c.bonus_available = true
	var before := e.distance(c, foe)
	var r := e.items.use(c, "tramontane_armor__leather_armor", "pull", [foe])
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.has_condition(&"grappled"), "Grappled")
	assert_true(e.distance(c, foe) < before, "pulled closer")


const ITEMS_9B := ["martialists_quarterstaff", "diamond_staff", "dissuader", "ominous_staff_of_skulls", "chattering_staff_of_skulls",
	"pulverizing_staff_of_skulls", "budding_blossom_rod", "flowering_blossom_rod", "somniferous_blossom_rod", "wand_of_freshness",
	"wand_of_slumber", "wand_of_teeth", "black_potion_of_dragons_breath", "blue_potion_of_dragons_breath", "green_potion_of_dragons_breath",
	"red_potion_of_dragons_breath", "white_potion_of_dragons_breath", "orb_of_sorcery", "orb_of_divination_detection"]


func _holding(e: Encounter, item_id: String, cell: Vector2i = Vector2i(2, 2), pregen: String = "silvain_aster") -> Combatant:
	var c := TestCombat.hero(e, pregen, cell, 9)
	var ch := c.creature as Character
	ch.add_item(item_id)
	if MagicItems.needs_attunement(Compendium.shared().item_data(item_id)):
		ch.attune(item_id)
	if not Compendium.shared().item_data(item_id).get("category", "") in ["potion"]:
		ch.equip(item_id, "main_hand")
	return c


func test_the_9b_items_are_switched_on() -> void:
	var ids := Compendium.shared().all_playable("magic_items").map(func(d: Dictionary) -> String: return str(d["id"]))
	for id: String in ITEMS_9B:
		assert_true(id in ids, "%s playable" % id)
	assert_false("staff_of_the_lost" in ids, "Staff of the Lost waits for the Minotaur of Baphomet")


func test_martialists_quarterstaff_flies_and_topples() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "martialists_quarterstaff__quarterstaff")
	var foe := _talker(e, Vector2i(3, 2))
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	var start := ch.charges_left("martialists_quarterstaff__quarterstaff")
	assert_true(e.items.use(c, "martialists_quarterstaff__quarterstaff", "throw").ok)
	assert_false(e.option_by_id(c, "thrown:martialists_quarterstaff__quarterstaff").is_empty(), "it can be thrown")
	assert_eq(ch.charges_left("martialists_quarterstaff__quarterstaff"), start - 1)
	var st := {"c": c, "target": foe, "option": e.option_by_id(c, "weapon:martialists_quarterstaff__quarterstaff"),
		"sit": {"advantage": [] as Array[String], "disadvantage": [] as Array[String]}, "ac": 1}
	var offers: Array = []
	e.items.specials.fr.before_roll(st, offers)
	assert_eq(offers.size(), 1, "Advantage for a charge")
	(offers[0]["use"] as Callable).call()
	assert_true(((st["sit"] as Dictionary)["advantage"] as Array).has("Martialist's Quarterstaff"))
	var it := {"id": "martialists_quarterstaff__quarterstaff", "data": Compendium.shared().item_data("martialists_quarterstaff__quarterstaff")}
	e.items.specials.fr.after_hit_more(c, foe, st["option"] as Dictionary, st, CombatResult.new(), it)
	assert_true(foe.creature.has_condition(&"prone"), "a Strength save or Prone")


func test_diamond_staff_light_and_stunning_blow() -> void:
	var e := TestCombat.open_field()
	var c := _holding(e, "diamond_staff__quarterstaff")
	var foe := _talker(e, Vector2i(3, 2))
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	var start := ch.charges_left("diamond_staff__quarterstaff")
	assert_true(e.items.use(c, "diamond_staff__quarterstaff", "radiance").ok)
	assert_eq(str(e.light_at(Vector2i(9, 2))), "bright", "40 ft of light")
	assert_eq(ch.charges_left("diamond_staff__quarterstaff"), start - 1)
	assert_true(e.items.use(c, "diamond_staff__quarterstaff", "stun").ok)
	c.attacks_left = 1
	c.action_available = true
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, "weapon:diamond_staff__quarterstaff").hit)
	assert_true(foe.creature.has_condition(&"stunned"), "Stunned on a failed Con save")
	assert_eq(ch.charges_left("diamond_staff__quarterstaff"), start - 3, "two more charges")


func test_dissuader_aura_and_repel() -> void:
	var e := TestCombat.open_field()
	var c := _armed(e, "dissuader__quarterstaff")
	var foe := _talker(e, Vector2i(10, 2))
	TestCombat.start_with(e, c)
	var r := e.items.use(c, "dissuader__quarterstaff", "aura")
	assert_true(r.ok, r.reason)
	e.end_turn()
	assert_eq(e.current(), foe)
	assert_true(e.move(foe, Vector2i(6, 2)).ok)
	assert_true(foe.creature.has_condition(&"frightened"), "entering the aura frightens it")
	var e2 := TestCombat.open_field()
	var c2 := _armed(e2, "dissuader__quarterstaff")
	var foe2 := _talker(e2, Vector2i(6, 2))
	TestCombat.start_with(e2, c2)
	e2.end_turn()
	assert_eq(e2.current(), foe2)
	e2.move(foe2, Vector2i(3, 2))
	assert_false(c2.reaction_available, "the Reaction")
	assert_true(e2.distance(c2, foe2) > 5, "thrown back")


func test_staffs_of_skulls_shriek_and_pulverize() -> void:
	var e := TestCombat.open_field()
	var c := _holding(e, "pulverizing_staff_of_skulls")
	var foe := _talker(e, Vector2i(5, 2))
	TestCombat.start_with(e, c)
	var st := {"c": foe, "target": c, "option": e.attack_options(foe)[0] if not e.attack_options(foe).is_empty() else {},
		"sit": {"advantage": [] as Array[String], "disadvantage": [] as Array[String]}, "ac": 10}
	var offers: Array = []
	e.items.specials.fr.before_roll(st, offers)
	assert_eq(offers.size(), 1, "a Reaction against the attack")
	(offers[0]["use"] as Callable).call()
	assert_true(((st["sit"] as Dictionary)["disadvantage"] as Array).has("Staff of Skulls"))
	var hp := foe.creature.hp
	assert_true(e.items.use(c, "pulverizing_staff_of_skulls", "pulverize", [foe]).ok)
	assert_true(foe.creature.hp < hp and foe.creature.has_condition(&"prone"), "10d8 Necrotic and Prone")
	assert_false(e.items.use(c, "pulverizing_staff_of_skulls", "pulverize", [foe]).ok, "once a day")


func test_somniferous_rod_puts_enemies_to_sleep() -> void:
	var e := TestCombat.open_field()
	var c := _holding(e, "somniferous_blossom_rod")
	var foe := _talker(e, Vector2i(5, 2))
	var dead := TestCombat.punching_bag(e, Vector2i(6, 4), 50, "undead")
	TestCombat.start_with(e, c)
	assert_true(e.items.use(c, "somniferous_blossom_rod", "slumber").ok)
	assert_true(foe.creature.has_condition(&"unconscious"), "asleep")
	assert_false(dead.creature.has_condition(&"unconscious"), "the Undead don't sleep")
	e.deal_damage(null, foe, [{"amount": 1, "type": "fire"}], false, "test")
	assert_false(foe.creature.has_condition(&"unconscious"), "damage wakes it")


func test_wand_of_teeth_bites_in_a_cone() -> void:
	var e := TestCombat.open_field()
	var c := _holding(e, "wand_of_teeth")
	var foe := _talker(e, Vector2i(4, 2))
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	var start := ch.charges_left("wand_of_teeth")
	var hp := foe.creature.hp
	var r := e.items.use(c, "wand_of_teeth", "teeth", [], Vector2.INF, Vector2.RIGHT, 0, {"choice": "2"})
	assert_true(r.ok, r.reason)
	assert_eq(ch.charges_left("wand_of_teeth"), start - 2)
	assert_true(foe.creature.hp < hp, "bitten")
	assert_true(foe.creature.has_condition(&"poisoned"), "and Poisoned")


func test_potion_of_dragons_breath_breathes_its_colour() -> void:
	var e := TestCombat.open_field()
	var c := _holding(e, "red_potion_of_dragons_breath")
	var foe := _talker(e, Vector2i(3, 2))
	TestCombat.start_with(e, c)
	assert_true(e.items.use(c, "red_potion_of_dragons_breath", "drink").ok)
	var breath := e.items.powers(c).filter(func(p: Dictionary) -> bool: return str((p["power"] as Dictionary).get("id", "")) == "breath")
	assert_false(breath.is_empty(), "a breath for a minute")
	c.action_available = true
	var hp := foe.creature.hp
	var p0 := breath[0] as Dictionary
	var r := e.items.use(c, str(p0["item_id"]), "breath", [], Vector2(4.5, 2.5), Vector2.RIGHT)
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.hp < hp, "burned")


func test_orb_of_sorcery_restores_points() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var sorc := e.add(TestChars.custom("sorcerer", "human", 5), &"party", Vector2i(2, 4))
	var ch := sorc.creature as Character
	ch.add_item("orb_of_sorcery")
	ch.attune("orb_of_sorcery")
	ch.equip("orb_of_sorcery", "main_hand")
	TestCombat.punching_bag(e, Vector2i(9, 2))
	TestCombat.start_with(e, sorc)
	var full := ch.resource_left("sorcery_points")
	ch.spend_resource("sorcery_points", 3)
	assert_true(e.items.use(sorc, "orb_of_sorcery", "restore").ok)
	assert_eq(ch.resource_left("sorcery_points"), full - 1, "two back")
	var _unused := c
