extends TestCase
## Where a hero's saving throw comes in an action's events (owner, 2026-10-14: a Concentration check or a save after
## being attacked shows after the attack animation and the damage, not before). D20Responses.mark_save puts a "save"
## event in the stream where the roll was made; EncounterDamage moves the Concentration save's behind the damage event.


func _types(e: Encounter) -> Array[String]:
	var out: Array[String] = []
	for ev in e.events:
		out.append(str(ev["type"]) if str(ev["type"]) != "save" else "save:%s" % str(ev["id"]))
	return out


## A ghoul whose claw always hits and whose paralysing rider save is at `dc`.
func _ghoul(e: Encounter, cell: Vector2i, dc: int) -> Combatant:
	var data := Compendium.shared().monster_data("ghoul").duplicate(true)
	for a: Variant in data["actions"]:
		var act := a as Dictionary
		if str(act["id"]) == "claw":
			(act["attack"] as Dictionary)["bonus"] = 40
			((act["on_hit"] as Array)[0]["save"] as Dictionary)["dc"] = dc
	return e.add(Monster.from_data(data), &"enemy", cell)


func _hero(e: Encounter, cell: Vector2i) -> Combatant:
	var h := TestCombat.hero(e, "ilse_varga", cell)
	(h.creature as Character).heroic_inspiration = false
	return h


func test_a_concentration_save_comes_after_the_damage_event() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2))
	TestCombat.start_with(e, foe)
	hero.creature.begin_concentration("bless", "Bless")
	e.drain_events()
	e.deal_damage(foe, hero, [{"amount": 6, "type": "slashing"}], false, "test")
	assert_eq(_types(e), ["damage", "save:%s" % hero.id] as Array[String], "the damage first, then the roll for keeping the spell")
	var save := e.events[1]["test"] as D20Test
	assert_eq(save.kind, D20Test.Kind.SAVING_THROW, "the roll itself rides along")


func test_a_riders_save_comes_after_the_hit_and_its_damage() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2))
	var ghoul := _ghoul(e, Vector2i(3, 2), 5)
	TestCombat.start_with(e, ghoul)
	e.drain_events()
	TestCombat.next_d20(e, 10)
	e.monster_attack(ghoul, hero, "claw")
	var types := _types(e)
	var save_at := types.find("save:%s" % hero.id)
	assert_true(save_at > 0, "the hero's rider save is among the events: %s" % str(types))
	assert_true(types.find("attack") < types.find("damage") and types.find("damage") < save_at, "blow, damage, then the save: %s" % str(types))


func test_concentration_and_rider_saves_keep_their_order_after_the_damage() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2))
	var ghoul := _ghoul(e, Vector2i(3, 2), 5)
	TestCombat.start_with(e, ghoul)
	hero.creature.begin_concentration("bless", "Bless")
	e.drain_events()
	TestCombat.next_d20(e, 10)
	e.monster_attack(ghoul, hero, "claw")
	var saves := e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "save")
	assert_eq(saves.size(), 2, "the Concentration save and the rider's: %s" % str(_types(e)))
	var types := _types(e)
	assert_true(types.find("damage") < types.find("save:%s" % hero.id), "both after the damage: %s" % str(types))
	assert_true(saves[0]["test"] != saves[1]["test"], "two different rolls")


func test_only_a_heros_saves_are_marked_not_a_foes_or_a_check() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2))
	TestCombat.start_with(e, foe)
	e.drain_events()
	foe.creature.roll_save(e.dice, &"con", 10)
	hero.creature.roll_d20(e.dice, D20Test.Kind.ABILITY_CHECK, Breakdown.new("Athletics"), 10, [] as Array[String])
	assert_true(e.events.is_empty(), "no mark for a foe's save or a hero's check: %s" % str(e.events))
	hero.creature.roll_save(e.dice, &"wis", 10)
	assert_eq(_types(e), ["save:%s" % hero.id] as Array[String], "the hero's save is marked once")


func test_a_foes_concentration_save_has_no_mark() -> void:
	var e := TestCombat.open_field(3)
	var hero := _hero(e, Vector2i(2, 2))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2))
	TestCombat.start_with(e, hero)
	foe.creature.begin_concentration("bless", "Bless")
	e.drain_events()
	e.deal_damage(hero, foe, [{"amount": 6, "type": "slashing"}], false, "test")
	assert_eq(_types(e), ["damage"] as Array[String], "nothing to show: the log and sound tell it")
