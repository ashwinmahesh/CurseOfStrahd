extends TestCase
## Things on the ground in a fight (F5, combat/ground_items.gd): Disarming Attack on a character and on a monster,
## picking up with the free object interaction and then the Utilize action, thrown weapons coming down by their
## target (a returning one flying back, the Hammer of Thunderbolts staying), Heat Metal, the Unconscious condition and
## Command's "Drop" letting go, the party gathering its things (and half its arrows) after the fight while the foes'
## weapons become loot, what goes over the edge of a map's drop going down (and fetched afterwards), a saved fight
## keeping all of it, and the view drawing it.


## A swordsman that fails every save (its abilities as low as they go): a scimitar, and a light crossbow unless
## `with_bow` is false, in its stat block and its gear.
func _brigand(e: Encounter, cell: Vector2i, with_bow: bool = true) -> Combatant:
	var actions: Array = [{"id": "scimitar", "name": "Scimitar", "kind": "melee", "attack": {"bonus": 3, "reach": 5},
		"damage": [{"average": 4, "dice": "1d6+1", "type": "slashing"}], "weapon": true}]
	var gear: Array = ["scimitar"]
	if with_bow:
		actions.append({"id": "light_crossbow", "name": "Light Crossbow", "kind": "ranged", "attack": {"bonus": 3, "range": [80, 320]},
			"damage": [{"average": 5, "dice": "1d8+1", "type": "piercing"}], "weapon": true})
		gear.append("light_crossbow")
	var m := TestChars.dummy(200, false, {"ac": 1, "gear": gear, "actions": actions,
		"abilities": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}})
	m.name = "Brigand"
	return e.add(m, &"enemy", cell)


func _battle_master(e: Encounter, cell: Vector2i) -> Combatant:
	return e.add(TestChars.custom("fighter", "human", 3, {"fighter_subclass": ["battle_master"],
		"combat_superiority": ["disarming_attack", "parry", "precision_attack"]}), &"party", cell)


func _melee_option(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			return str(o["id"])
	return ""


func _pile_of(e: Encounter, item_id: String) -> Dictionary:
	for g in e.ground.items:
		if str(g["item_id"]) == item_id:
			return g
	return {}


func test_disarming_attack_knocks_a_monsters_weapon_down_until_it_picks_it_up() -> void:
	var e := TestCombat.open_field()
	e.default_player_reaction = "never"
	var f := _battle_master(e, Vector2i(2, 3))
	var b := _brigand(e, Vector2i(3, 3))
	TestCombat.foe(e, "wolf", Vector2i(10, 7))   # the fight goes on
	TestCombat.start_with(e, f)
	b.creature.add_condition(&"stunned", "test")   # it fails Strength saves outright
	assert_true(e.features.toggle_rider(f, "maneuver:disarming_attack").ok)
	TestCombat.next_d20(e, 19)
	var r := e.attack(f, b, _melee_option(e, f))
	assert_true(r.ok and r.hit, r.reason)
	var piles := e.ground.at(b.cell)
	assert_eq(piles.size(), 1, "the weapon lands in its space")
	assert_eq(str(piles[0]["item_id"]), "scimitar", "the weapon in its hand: the first melee weapon")
	assert_eq(str(piles[0]["owner_id"]), b.id)
	var m := b.creature as Monster
	assert_true(e.monster_actions.why_not(b, m.action("scimitar")).begins_with("Disarmed"), "no scimitar attacks")
	assert_true(e.attack_legal(b, f, e.option_by_id(b, "monster:scimitar")).begins_with("Disarmed"))
	assert_eq(e.monster_actions.why_not(b, m.action("light_crossbow")), "", "its crossbow is still slung on its back")
	assert_true(e.best_melee_option(b, f).is_empty(), "no Opportunity Attacks with the scimitar either")
	# Its turn: it takes the scimitar back with its free object interaction.
	b.creature.remove_condition(&"stunned", "test")
	for guard in 6:
		if e.current() == b:
			break
		e.end_turn()
	assert_true(e.current() == b)
	e.run_ai_turn()
	assert_true(e.ground.items.is_empty(), "picked up")
	assert_eq(e.monster_actions.why_not(b, m.action("scimitar")), "", "armed again")


func test_disarming_attack_takes_a_characters_weapon_out_of_its_hand() -> void:
	var e := TestCombat.open_field()
	var f := _battle_master(e, Vector2i(2, 3))
	var ilse := e.add(TestChars.pregen("ilse_varga", 3), &"enemy", Vector2i(3, 3))
	TestCombat.foe(e, "wolf", Vector2i(10, 7))
	TestCombat.start_with(e, f)
	ilse.creature.add_condition(&"stunned", "test")
	var ch := ilse.creature as Character
	var sword := str(ch.equipped("main_hand").get("id", ""))
	assert_ne(sword, "", "she holds a weapon")
	assert_true(e.features.toggle_rider(f, "maneuver:disarming_attack").ok)
	TestCombat.next_d20(e, 19)
	var r := e.attack(f, ilse, _melee_option(e, f))
	assert_true(r.ok and r.hit, r.reason)
	assert_eq(e.item_count(ilse, sword), 0, "out of her hands")
	assert_true(ch.equipped("main_hand").is_empty())
	assert_true(e.option_by_id(ilse, "weapon:" + sword).is_empty(), "no attacks with it")
	var piles := e.ground.at(ilse.cell)
	assert_eq(piles.size(), 1, "it lands in her space")
	assert_eq(str(piles[0]["slot"]), "main_hand", "it remembers the hand it left")


func test_picking_up_takes_the_free_object_interaction_then_the_utilize_action() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(3, 2))
	w.creature.hp = 200
	TestCombat.start_with(e, ilse)
	var ch := ilse.creature as Character
	var sword := str(e.ground.held(ilse)[0]["item_id"])
	assert_true(e.ground.disarm(ilse, w, "test"))
	assert_eq(e.item_count(ilse, sword), 0)
	var javelins := e.item_count(ilse, "javelin")
	e.ground.land(ilse, "javelin", {}, "", w)   # one she threw earlier, in the wolf's space beside her
	var cat := ActionCatalog.new(e)
	var picks := cat.actions_for(ilse).filter(func(a: Dictionary) -> bool: return str(a["kind"]) == "pickup")
	assert_eq(picks.size(), 2, "both lie within reach")
	var first := picks[0] as Dictionary
	assert_eq(str(first["label"]), "Pick up the %s" % sword)
	assert_eq(str(first["cost"]), "free", "the free object interaction")
	assert_true(cat.perform(ilse, first).ok)
	assert_false(ilse.free_interaction_available)
	assert_eq(str(ch.equipped("main_hand").get("id", "")), sword, "back in her hand")
	var second := cat.find(ilse, str((picks[1] as Dictionary)["id"]))
	assert_eq(str(second["cost"]), "action", "the next one costs the Utilize action")
	assert_true(cat.perform(ilse, second).ok)
	assert_false(ilse.action_available)
	assert_eq(e.item_count(ilse, "javelin"), javelins + 1)
	assert_true(e.ground.items.is_empty())
	e.ground.land(ilse, "javelin", {}, "", w)
	assert_eq(e.ground.pick_up_why(ilse, e.ground.items[0]), "No object interaction or action left")


func test_a_thrown_weapon_lands_by_its_target_and_is_picked_up_from_within_5_ft() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(1, 1))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(5, 1))
	w.creature.hp = 100
	TestCombat.start_with(e, t)
	assert_eq(e.item_count(t, "dagger"), 4)
	assert_true(e.attack(t, w, "thrown:dagger").ok)
	assert_eq(e.item_count(t, "dagger"), 3, "it left his hand")
	var piles := e.ground.at(Vector2i(5, 1))
	assert_eq(piles.size(), 1, "it came down in the wolf's space, on the square nearest him")
	e.weapons.throw_item(t, "dagger", w)
	assert_eq(int(piles[0]["qty"]), 2, "a second joins the first")
	assert_eq(e.ground.label(t, piles[0]), "Pick up the 2 daggers")
	assert_eq(e.ground.describe_at(Vector2i(5, 1)), ["On the ground: %s's 2 daggers" % t.name()] as Array[String])
	var cat := ActionCatalog.new(e)
	assert_false(cat.actions_for(t).any(func(a: Dictionary) -> bool: return str(a["kind"]) == "pickup"), "not on the hotbar from 15 ft")
	var line := cat.square_actions(t, Vector2i(5, 1)).filter(func(x: Dictionary) -> bool: return str(x["id"]).begins_with("act:pickup:"))
	assert_eq(line.size(), 1, "the square menu offers it")
	assert_false(bool((line[0] as Dictionary)["enabled"]))
	assert_true(str((line[0] as Dictionary)["why"]).contains("Out of reach"))
	assert_true(e.move(t, Vector2i(4, 1)).ok)
	assert_true(e.pick_up(t, str(piles[0]["gid"])).ok)
	assert_eq(e.item_count(t, "dagger"), 4, "both gathered with one interaction")


func test_a_returning_weapon_flies_back_and_the_hammer_of_thunderbolts_stays_where_it_fell() -> void:
	var e := TestCombat.open_field()
	var ch := TestChars.pregen("ilse_varga", 5)
	var thrower := "dwarven_thrower__warhammer"
	var hammer := "hammer_of_thunderbolts__maul"
	for id: String in [thrower, hammer]:
		ch.add_item(id)
		ch.attuned.append(id)
	# Only equipped weapons are thrown or hurled: the Thrower in hand, the Hammer in the other set (taken up to hurl it).
	ch.equip(thrower, "main_hand")
	ch.weapon_set_2 = {"main_hand": hammer}
	var c := e.add(ch, &"party", Vector2i(2, 2))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(5, 2))
	w.creature.hp = 300
	TestCombat.start_with(e, c)
	assert_true(e.attack(c, w, "thrown:" + thrower).ok)
	assert_eq(e.item_count(c, thrower), 1, "the Dwarven Thrower flies back to her hand")
	assert_true(e.ground.items.is_empty())
	var charges := ch.charges_left(hammer)
	TestCombat.next_d20(e, 19)
	var r := e.items.use(c, hammer, "hurl", [w])
	assert_true(r.ok, r.reason)
	assert_eq(e.item_count(c, hammer), 0, "hurled, it doesn't come back (2024 DMG)")
	var pile := _pile_of(e, hammer)
	assert_eq(pile.get("cell"), Vector2i(5, 2), "it lies by the wolf")
	assert_eq(int((pile["state"] as Dictionary)["charges"]), charges - 1, "the charge comes off the hammer as it flies")
	assert_true(e.move(c, Vector2i(4, 2)).ok)
	assert_true(e.pick_up(c, str(pile["gid"])).ok)
	assert_eq(ch.charges_left(hammer), charges - 1, "picked up again, charges and all")
	assert_true(hammer in ch.attuned, "still attuned")


func test_heat_metal_makes_a_monster_let_go_of_its_weapon() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["heat_metal"], Vector2i(2, 3))
	var b := _brigand(e, Vector2i(5, 3), false)
	TestCombat.foe(e, "wolf", Vector2i(10, 7))
	TestCombat.start_with(e, c)
	assert_eq(e.spells.specials.metal_of(b), "weapon")
	var r := e.spells.cast(c, "heat_metal", 2, [b])
	assert_true(r.ok, r.reason)
	assert_eq(e.ground.at(b.cell).size(), 1, "the searing scimitar falls in its space")
	assert_true(e.monster_actions.why_not(b, (b.creature as Monster).action("scimitar")).begins_with("Disarmed"))
	assert_eq(e.spells.specials.metal_of(b), "", "nothing metal in its hands now")


func test_unconscious_and_command_drop_let_go_of_what_is_held() -> void:
	var e := TestCombat.open_field()
	var g := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2))
	TestCombat.hero(e, "hedda_ironvow", Vector2i(0, 6))   # someone still standing: the fight goes on
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(3, 2))
	var b := _brigand(e, Vector2i(6, 6))
	var b2 := _brigand(e, Vector2i(8, 6))
	TestCombat.start_with(e, w)
	var ch := g.creature as Character
	var sword := str(ch.equipped("main_hand").get("id", ""))
	var shield := str(ch.equipped("off_hand").get("id", ""))
	assert_ne(sword, "")
	g.creature.hp = 3
	e.deal_damage(w, g, [{"amount": 5, "type": "piercing"}], false, "test")
	assert_true(g.creature.has_condition(&"unconscious"))
	assert_eq(e.item_count(g, sword), 0, "he drops his sword")
	assert_eq(e.ground.at(g.cell).size(), 1, "in his space")
	assert_eq(str(ch.equipped("off_hand").get("id", "")), shield, "a donned Shield stays on")
	b.creature.add_effect(Effect.new("Sleep", &"spell", "sleep").with_condition(&"unconscious"))
	assert_eq(e.ground.at(b.cell).size(), 1, "asleep, the brigand drops its scimitar")
	b2.creature.add_effect(Effect.new("Command", &"spell", "command").with_modifier("flag", {"value": "command_drop"}))
	e.ai.play_turn(b2)
	assert_eq(e.ground.at(b2.cell).size(), 1, "Command: Drop")


func test_what_goes_over_the_edge_goes_down_and_is_fetched_after_the_fight() -> void:
	var e := TestCombat.encounter(["......", "......", "      ", "      "], 5)
	e.grid.drop_ft = 200
	var g := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 1))
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(4, 0))
	var w := TestCombat.foe(e, "dire_wolf", Vector2i(2, 0))
	TestCombat.start_with(e, w)
	var ch := g.creature as Character
	var sword := str(ch.equipped("main_hand").get("id", ""))
	assert_ne(sword, "")
	# Going over the edge (EncounterMovement.fall_away puts him over the drop as he falls): his sword goes with him.
	g.cell = Vector2i(2, 2)
	assert_true(e.ground.goes_down(g))
	e.ground.drop_held(g, "Unconscious")
	assert_eq(str(ch.equipped("main_hand").get("id", "")), sword, "still in his hand")
	assert_true(e.ground.items.is_empty() and e.ground.fallen.is_empty(), "nothing left on a square over the drop")
	e.movement.leave_grid(g, "fell")
	e.ground.drop_held(g, "Unconscious")
	assert_true(e.ground.items.is_empty(), "out of the fight, nothing of his lands anywhere")
	# A thing that comes down over the drop falls out of reach, a saved fight keeps it, and it's fetched afterwards.
	var daggers := e.item_count(t, "dagger")
	assert_true(daggers > 0)
	e.weapons.throw_item(t, "dagger", null, Vector2i(4, 2))
	assert_eq(e.item_count(t, "dagger"), daggers - 1)
	assert_true(e.ground.items.is_empty(), "no pile over the drop")
	assert_eq(e.ground.fallen.size(), 1, "it fell over the edge")
	var back := JSON.parse_string(JSON.stringify(EncounterSnapshot.capture(e))) as Dictionary
	var e2 := EncounterSnapshot.restore(back, DiceRoller.new(1))
	assert_eq(e2.ground.fallen.size(), 1, "a saved fight keeps it")
	e.deal_damage(t, w, [{"amount": 500, "type": "slashing"}], false, "test")
	assert_true(e.is_over())
	assert_eq(e.item_count(t, "dagger"), daggers, "fetched from below with the rest")
	assert_eq(str(ch.equipped("main_hand").get("id", "")), sword, "he comes back up with his sword")


func test_after_the_fight_the_party_gathers_its_things_and_the_foes_weapons_are_loot() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 4))
	var b := _brigand(e, Vector2i(3, 2))
	TestCombat.start_with(e, ilse)
	var tch := t.creature as Character
	if e.item_count(t, "shortbow") == 0:
		tch.add_item("shortbow")
	tch.add_item("arrow", 10)
	var sword := str(e.ground.held(ilse)[0]["item_id"])
	assert_true(e.ground.disarm(ilse, b, "test"))
	assert_true(e.ground.disarm(b, ilse, "test"))
	e.weapons.throw_item(t, "dagger", b)
	var bow := e.option_by_id(t, "weapon:shortbow")
	var arrows := e.item_count(t, "arrow")
	for i in 3:
		e.weapons._spend_ammo(t, bow["profile"] as WeaponProfile)
	assert_eq(e.item_count(t, "arrow"), arrows - 3)
	e.deal_damage(ilse, b, [{"amount": 500, "type": "slashing"}], false, "test")
	assert_true(e.is_over())
	assert_eq(str((ilse.creature as Character).equipped("main_hand").get("id", "")), sword, "her weapon back in her hand")
	assert_eq(e.item_count(t, "dagger"), 4, "his dagger gathered")
	assert_eq(e.item_count(t, "arrow"), arrows - 2, "half the 3 arrows shot found again, rounded down")
	assert_eq(e.ground.spoils.size(), 1)
	assert_eq(str(e.ground.spoils[0]["id"]), "scimitar", "the brigand's scimitar is loot")
	assert_true(e.ground.items.is_empty())


func test_a_saved_fight_keeps_what_lies_on_the_ground() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2))
	var b := _brigand(e, Vector2i(3, 2))
	TestCombat.start_with(e, t)
	assert_true(e.ground.disarm(b, t, "test"))
	e.weapons.throw_item(t, "dagger", b)
	var back := JSON.parse_string(JSON.stringify(EncounterSnapshot.capture(e))) as Dictionary
	var e2 := EncounterSnapshot.restore(back, DiceRoller.new(1))
	assert_eq(e2.ground.items.size(), 2)
	var scimitar := _pile_of(e2, "scimitar")
	assert_eq(scimitar.get("cell"), b.cell)
	assert_eq(str(scimitar["owner_id"]), b.id)
	var b2 := e2.get_c(b.id)
	assert_true(e2.monster_actions.why_not(b2, (b2.creature as Monster).action("scimitar")).begins_with("Disarmed"), "still disarmed")
	var t2 := e2.get_c(t.id)
	assert_eq(e2.item_count(t2, "dagger"), 3)
	assert_true(e2.current() == t2, "the round begins again")
	assert_true(e2.pick_up(t2, str(_pile_of(e2, "dagger")["gid"])).ok)
	assert_eq(e2.item_count(t2, "dagger"), 4)


func test_a_monsters_weapon_attack_is_the_item_it_drops() -> void:
	for row: Array in [["bandit", "scimitar", "scimitar"], ["cultist", "ritual_sickle", "sickle"], ["deva", "holy_mace", "mace"],
			["wight", "necrotic_sword", "longsword"], ["rictavio", "sword_cane", ""]]:
		var m := TestCombat.monster(str(row[0]))
		assert_eq(GroundItems.weapon_item(m, m.action(str(row[1]))), str(row[2]), "%s's %s" % [row[0], row[1]])


func test_the_view_draws_each_pile_on_its_square() -> void:
	var e := TestCombat.open_field()
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 2))
	var b := _brigand(e, Vector2i(3, 2))
	TestCombat.start_with(e, t)
	assert_true(e.ground.disarm(b, t, "test"))
	e.weapons.throw_item(t, "dagger", b)
	var board := ArenaBoard.build(e.grid)
	add_child(board)
	var view := GroundView.create(board)
	add_child(view)
	view.sync(e.ground.items)
	var scimitar := view.node_for(str(_pile_of(e, "scimitar")["gid"]))
	var dagger := view.node_for(str(_pile_of(e, "dagger")["gid"]))
	assert_true(scimitar != null and dagger != null, "both drawn")
	assert_true(scimitar.position.distance_to(dagger.position) > 0.2, "side by side, not one on the other")
	assert_true(absf(scimitar.position.x - 3.5) < 0.5 and absf(scimitar.position.z - 2.5) < 0.5, "on the brigand's square")
	assert_eq(dagger.find_children("*", "Sprite3D", true, false).size(), 1, "the dagger's icon on the floor")
	assert_true(e.pick_up(t, str(_pile_of(e, "dagger")["gid"])).ok)
	view.sync(e.ground.items)
	await get_tree().process_frame
	assert_false(is_instance_valid(dagger), "gone once picked up")
	view.queue_free()
	board.queue_free()
