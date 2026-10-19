extends TestCase
## Standing up from Prone (2024: half your Speed, and it ends the condition whoever gave it). A stat block's rider (an air
## elemental's Whirlwind, a boar's charge) gives Prone as an effect with no end of its own, so standing up has to end that
## too. Owner report 2026-10-18: Ismark, flung Prone by a Whirlwind at Mount Baratok, spent half his Speed to stand and was
## still Prone, crawling at double cost, for the rest of the fight and every fight after it.


## Flings `h` Prone as the air elemental `foe`'s Whirlwind does: its rider, without the push that goes with it.
static func _fling(e: Encounter, foe: Combatant, h: Combatant) -> void:
	var riders: Array = []
	for rd: Variant in (foe.creature as Monster).action("whirlwind")["on_fail"] as Array:
		if str((rd as Dictionary)["do"]) == "condition":
			riders.append(rd)
	e.monster_actions.apply_riders(foe, h, riders, {}, "Whirlwind")


static func _prone_effects(c: Combatant) -> int:
	return c.creature.effects.filter(func(fx: Effect) -> bool: return &"prone" in fx.conditions).size()


## A field with an air elemental out of the way and `h` (Speed 30) on its turn, flung Prone.
func _flung(h_cell: Vector2i = Vector2i(2, 2)) -> Array:
	var e := TestCombat.open_field()
	var ae := TestCombat.foe(e, "air_elemental", Vector2i(10, 6))
	var h := TestCombat.hero(e, "ilse_varga", h_cell)
	TestCombat.start_with(e, h)
	_fling(e, ae, h)
	return [e, h, ae]


func test_standing_up_ends_a_prone_a_stat_block_gave() -> void:
	var f := _flung()
	var e := f[0] as Encounter
	var h := f[1] as Combatant
	assert_true(h.creature.has_condition(&"prone"), "flung Prone")
	assert_eq(_prone_effects(h), 1, "as an effect, with no end of its own")
	var left := h.movement_left
	var r := e.stand_up(h)
	assert_true(r.ok, r.reason)
	assert_false(h.creature.has_condition(&"prone"), "on its feet")
	assert_eq(_prone_effects(h), 0, "the effect is gone")
	assert_eq(h.movement_left, left - 15, "half its Speed")
	assert_true(h.stood_up)


func test_a_walk_from_a_stat_block_prone_stands_first_and_doesnt_crawl() -> void:
	var f := _flung()
	var e := f[0] as Encounter
	var h := f[1] as Combatant
	assert_true(e.move(h, Vector2i(4, 2)).ok)
	assert_false(h.creature.has_condition(&"prone"), "stood up first")
	assert_eq(h.movement_left, 5, "15 ft to stand, 10 to walk: no double cost")


func test_standing_takes_every_plain_source_and_the_effect_together() -> void:
	var f := _flung()
	var e := f[0] as Encounter
	var h := f[1] as Combatant
	h.creature.add_condition(&"prone", "Shove")
	h.creature.add_condition(&"prone", "Knocked out")
	assert_true(e.stand_up(h).ok)
	assert_false(h.creature.has_condition(&"prone"), "no source keeps it down")


func test_a_prone_effect_that_does_more_keeps_the_rest() -> void:
	var f := _flung()
	var e := f[0] as Encounter
	var h := f[1] as Combatant
	e.stand_up(h)
	var pinned := Effect.new("Pinned", &"monster", "t:pin").with_condition(&"prone").with_modifier("flag", {"value": "pinned_test"})
	h.creature.add_effect(pinned)
	assert_true(h.creature.has_condition(&"prone"))
	h.movement_left = 30
	assert_true(e.stand_up(h).ok)
	assert_false(h.creature.has_condition(&"prone"))
	assert_true(h.creature.has_flag("pinned_test") and h.creature.effects.has(pinned), "what else it did stays")


func test_the_stand_up_action_is_listed_and_works_for_the_player() -> void:
	var f := _flung()
	var e := f[0] as Encounter
	var h := f[1] as Combatant
	var cat := ActionCatalog.new(e)
	var a := cat.find(h, "stand")
	assert_false(a.is_empty(), "Stand Up is on the list")
	assert_eq(str(a.get("tab", "")), ActionCatalog.COMMON, "in the Common tab")
	assert_true(bool(a.get("legal", false)), str(a.get("reason", "")))
	assert_eq(str(a.get("sub", "")), "15 ft")
	assert_true(cat.find(h, "drop_prone").is_empty(), "there's no dropping Prone while Prone")
	assert_true(cat.perform(h, a).ok)
	assert_false(h.creature.has_condition(&"prone"))
	assert_true(cat.find(h, "stand").is_empty(), "gone once it's up")
	assert_false(cat.find(h, "drop_prone").is_empty(), "and Drop Prone is back")


func test_stand_up_says_why_it_cant() -> void:
	var f := _flung()
	var e := f[0] as Encounter
	var h := f[1] as Combatant
	h.movement_left = 10
	var a := ActionCatalog.new(e).find(h, "stand")
	assert_false(bool(a.get("legal", true)), "10 ft isn't half of 30")
	assert_eq(str(a.get("reason", "")), "Needs 15 ft of movement")
	assert_false(e.stand_up(h).ok)
	assert_true(h.creature.has_condition(&"prone"), "nothing was spent")
	assert_eq(h.movement_left, 10)


func test_a_guest_the_player_runs_stands_up_the_same_way() -> void:
	# Ismark, as the owner's save had him: a Warrior Veteran guest flung Prone by the Whirlwind.
	var e := TestCombat.open_field()
	var ae := TestCombat.foe(e, "air_elemental", Vector2i(10, 6))
	var ismark := e.add(TestCombat.monster("warrior_veteran"), &"guest", Vector2i(3, 3))
	TestCombat.start_with(e, ismark)
	_fling(e, ae, ismark)
	assert_true(ismark.creature.has_condition(&"prone"))
	var a := ActionCatalog.new(e).find(ismark, "stand")
	assert_true(bool(a.get("legal", false)), str(a.get("reason", "")))
	assert_true(ActionCatalog.new(e).perform(ismark, a).ok)
	assert_false(ismark.creature.has_condition(&"prone"), "on his feet")


func test_the_move_preview_counts_standing_and_not_crawling() -> void:
	var f := _flung()
	var e := f[0] as Encounter
	var h := f[1] as Combatant
	var cat := ActionCatalog.new(e)
	var p := cat.move_preview(h, Vector2i(4, 2))
	assert_true(bool(p["ok"]))
	assert_eq(int(p["cost"]), 25, "15 to stand and 10 to walk")
	assert_true((p["warnings"] as Array).has("Stands up first (15 ft)"))


func test_a_foe_flung_prone_gets_up_to_fight() -> void:
	var e := TestCombat.open_field()
	var ae := TestCombat.foe(e, "air_elemental", Vector2i(10, 6))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	TestCombat.start_with(e, z)
	_fling(e, ae, z)
	assert_true(z.creature.has_condition(&"prone"))
	e.ai.play_turn(z)
	assert_false(z.creature.has_condition(&"prone"), "it stood to swing at the hero beside it")
	assert_eq(_prone_effects(z), 0)


func test_taking_back_a_move_that_stood_up_puts_the_effect_back() -> void:
	var f := _flung()
	var e := f[0] as Encounter
	var h := f[1] as Combatant
	assert_true(e.move(h, Vector2i(4, 2)).ok)
	assert_false(h.creature.has_condition(&"prone"))
	assert_true(e.can_undo_move(h), "standing up is part of the move")
	assert_true(e.undo_move(h).ok)
	assert_true(h.creature.has_condition(&"prone"), "Prone again")
	assert_eq(_prone_effects(h), 1, "by the same effect")
	assert_eq(h.movement_left, 30)
	assert_eq(h.cell, Vector2i(2, 2))


func test_the_athlete_stands_for_five_feet_and_the_list_says_so() -> void:
	var f := _flung()
	var e := f[0] as Encounter
	var h := f[1] as Combatant
	h.creature.add_effect(Effect.new("Athlete", &"feat", "athlete").with_modifier("flag", {"value": "hop_up"}))
	h.movement_left = 10
	assert_eq(e.movement.stand_cost(h), 5)
	var cat := ActionCatalog.new(e)
	var a := cat.find(h, "stand")
	assert_true(bool(a.get("legal", false)), "10 ft is enough when it costs 5: %s" % a.get("reason", ""))
	assert_eq(str(a.get("sub", "")), "5 ft")
	var p := cat.move_preview(h, Vector2i(3, 2))
	assert_true(bool(p["ok"]), str(p["reason"]))
	assert_eq(int(p["cost"]), 10, "5 to stand, 5 to walk")
	assert_true(e.move(h, Vector2i(3, 2)).ok)
	assert_false(h.creature.has_condition(&"prone"))
	assert_eq(h.movement_left, 0)


func test_a_fight_over_leaves_no_one_with_hit_points_prone() -> void:
	var up := TestChars.pregen("ilse_varga", 5)
	up.add_effect(Effect.new("Prone (Whirlwind)", &"monster", "ae:Whirlwind").with_condition(&"prone"))
	var down := TestChars.pregen("silvain_aster", 5)
	down.add_effect(Effect.new("Prone (Whirlwind)", &"monster", "ae:Whirlwind").with_condition(&"prone"))
	down.hp = 0
	EncounterSetup.clear_fight_effects(up)
	EncounterSetup.clear_fight_effects(down)
	assert_false(up.has_condition(&"prone"), "on its feet once the fight is over")
	assert_true(down.has_condition(&"prone"), "one at 0 Hit Points isn't")


func test_a_save_outside_a_fight_loads_nobody_stuck_prone() -> void:
	GameState.reset()
	var ch := TestChars.pregen("ilse_varga", 5)
	ch.add_effect(Effect.new("Prone (Whirlwind)", &"monster", "ae:Whirlwind").with_condition(&"prone"))
	GameState.story.party.append(ch)
	assert_true(GameState.story.add_guest("ismark"))
	GameState.story.guests[0].add_effect(Effect.new("Prone (Whirlwind)", &"monster", "ae:Whirlwind").with_condition(&"prone"))
	var saved := GameState.to_dict()
	GameState.from_dict(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_false(GameState.story.party[0].has_condition(&"prone"), "the hero is up after the load")
	assert_false(GameState.story.guests[0].has_condition(&"prone"), "so is the guest")
	saved["combat"] = {"location": "x", "encounter": "y", "data": {"round": 2}}
	GameState.from_dict(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	assert_true(GameState.story.guests[0].has_condition(&"prone"), "a mid-fight save keeps it for its fight")
	GameState.reset()
