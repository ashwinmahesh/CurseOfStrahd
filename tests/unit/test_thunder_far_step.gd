extends TestCase
## Thunder Step and Far Step (Xanathar's, 2014 rules, added by the owner 2026-10-15): on the Sorcerer, Warlock and
## Wizard lists; Thunder Step teleports its caster up to 90 ft to a square it sees, with one willing creature of its size
## or smaller from within 5 ft, and booms Thunder (Con save, 3d10, +1d10 a slot level above 3rd) over everyone else within
## 10 ft of the space it left; Far Step teleports its caster up to 60 ft as a Bonus Action and again on each later turn
## it keeps concentrating (SpellSpecials, SpellSustained's `teleport`, the combat view's TargetPicker companion step).


## A long hall, 24 squares by 5 (120 ft), so 90 ft is in reach; `walls` are solid squares.
func _hall(walls: Array[Vector2i] = []) -> Encounter:
	var rows: Array[String] = []
	for z in 5:
		var row := ""
		for x in 24:
			row += "#" if Vector2i(x, z) in walls else "."
		rows.append(row)
	return TestCombat.encounter(rows)


## A level 9 wizard (Medium; fifth level slots) that knows both spells, at `cell`, its turn begun.
func _caster(e: Encounter, cell: Vector2i) -> Combatant:
	var c := TestCombat.caster_with(e, ["thunder_step", "far_step"], cell)
	TestCombat.give_components(c.creature as Character, ["thunder_step", "far_step"])
	return c


## A creature that fails every save, with plenty of Hit Points.
func _soft(e: Encounter, cell: Vector2i, side: StringName = &"enemy") -> Combatant:
	return e.add(TestChars.dummy(300, false, {"type": "humanoid", "ac": 1,
		"abilities": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}}), side, cell)


func _logged(e: Encounter, text: String) -> bool:
	return e.log.texts().any(func(t: String) -> bool: return t.contains(text))


## Whether a log line's details (the dice it rolled) mention `text`.
func _rolled(e: Encounter, text: String) -> bool:
	return e.log.entries.any(func(x: Dictionary) -> bool: return (x.get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).contains(text)))


# --- The lists and the hotbar ----------------------------------------------------------------------------

func test_both_are_on_the_sorcerer_warlock_and_wizard_lists_and_in_play() -> void:
	var comp := Compendium.shared()
	for id: String in ["thunder_step", "far_step"]:
		var s := comp.spell_data(id)
		assert_false(s.is_empty(), id)
		assert_eq(s["classes"], ["sorcerer", "warlock", "wizard"], id)
		assert_true(Compendium.playable(s), "%s is playable: the combat engine runs it" % id)
		assert_true(Compendium.shared().spells_for("wizard", int(s["level"])).any(func(x: Dictionary) -> bool: return str(x["id"]) == id), "%s is a wizard's choice" % id)
		assert_false("cleric" in (s["classes"] as Array), id)
	assert_eq(int(comp.spell_data("thunder_step")["level"]), 3)
	assert_eq(int(comp.spell_data("far_step")["level"]), 5)
	assert_eq((comp.spell_data("far_step")["duration"] as Dictionary)["concentration"], true)
	assert_eq((comp.spell_data("far_step")["casting_time"] as Dictionary)["unit"], "bonus_action")


## Sorcerers, warlocks and wizards pick them like any spell of their level: a level-up offers Thunder Step on each list.
func test_a_level_up_offers_thunder_step_to_each_of_the_three_classes() -> void:
	for class_id: String in ["wizard", "sorcerer", "warlock"]:
		var ch := TestChars.custom(class_id, "human", 5)
		var up := LevelUpController.new(ch)
		assert_true(up.choose_class(class_id), class_id)
		var offered := false
		for choice in up.pending_choices():
			if choice.kind in ["spell", "spellbook"]:
				var option := choice.option("thunder_step")
				offered = offered or (option != null and option.legal)
		assert_true(offered, "%s's level 6 spell choices include Thunder Step" % class_id)
	# Far Step (a 5th level spell) sits on the same three lists in the same way.
	for class_id: String in ["wizard", "sorcerer", "warlock"]:
		assert_true(Compendium.shared().spells_for(class_id, 5).any(func(x: Dictionary) -> bool: return str(x["id"]) == "far_step"), "Far Step on the %s list" % class_id)


func test_the_hotbar_asks_for_a_square_for_both() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	_soft(e, Vector2i(10, 2))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var thunder := cat.find(c, "spell:thunder_step")
	var far := cat.find(c, "spell:far_step")
	assert_eq(str(thunder["targeting"]), "place")
	assert_eq(str(far["targeting"]), "place")
	assert_eq(int(thunder["range"]), 90)
	assert_eq(int(far["range"]), 60)
	assert_eq(str(thunder["cost"]), "action")
	assert_eq(str(far["cost"]), "bonus")
	assert_true(bool(thunder["legal"]), str(thunder["reason"]))
	assert_true(bool(far["legal"]), str(far["reason"]))
	assert_true(str(thunder["sub"]).contains("3d10"), str(thunder["sub"]))


# --- Thunder Step ----------------------------------------------------------------------------------------

func test_thunder_step_teleports_up_to_90_ft_and_booms_where_the_caster_stood() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var near := _soft(e, Vector2i(4, 2))
	var edge := _soft(e, Vector2i(2, 4))   # 10 ft away
	var far := _soft(e, Vector2i(2, 0))
	far.cell = Vector2i(8, 0)   # 30 ft away
	TestCombat.start_with(e, c)
	var mine := c.creature.hp
	var slots := (c.creature as Character).slots_left(3)
	var r := e.spells.cast(c, "thunder_step", 3, [], Vector2(20.5, 2.5))
	assert_true(r.ok, r.reason)
	while e.pending != null:
		e.answer_reaction(true)
	assert_eq(c.cell, Vector2i(20, 2), "90 ft away")
	assert_eq((c.creature as Character).slots_left(3), slots - 1)
	assert_false(c.action_available, "an action")
	assert_eq(c.creature.hp, mine, "the caster isn't in its own boom")
	assert_true(near.creature.hp < 300, "5 ft from the space left")
	assert_true(edge.creature.hp < 300, "10 ft from it")
	assert_eq(far.creature.hp, 300, "30 ft from it is out of the boom")
	assert_true(_logged(e, "Thunder booms where"), "\n".join(e.log.texts().slice(-6)))
	assert_true(e.events.any(func(ev: Variant) -> bool: return str((ev as Dictionary).get("type", "")) == "teleport" and (ev as Dictionary)["to"] == Vector2i(20, 2)), "a teleport event for the view")
	var spell_event: Dictionary = e.events.filter(func(ev: Variant) -> bool: return str((ev as Dictionary).get("type", "")) == "spell")[0]
	assert_false((spell_event["cells"] as Array).is_empty(), "the area round the space left, for the view's outline")
	assert_true(Vector2i(4, 2) in (spell_event["cells"] as Array) and not Vector2i(20, 2) in (spell_event["cells"] as Array))
	assert_false((spell_event["outline"] as Dictionary).is_empty(), "its edge")


func test_the_boom_is_thunder_3d10_with_a_con_save_for_half_and_hurts_friends() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var friend := _soft(e, Vector2i(3, 2), &"party")
	var stout := e.add(TestCombat.monster("ogre"), &"enemy", Vector2i(3, 3))
	stout.creature.hp = 400
	var data := Compendium.shared().spell_data("thunder_step")
	assert_eq(str(data["save"]), "con")
	assert_eq(str(data["save_success"]), "half")
	assert_eq(str((data["damage"] as Array)[0]["dice"]), "3d10")
	assert_eq(str((data["damage"] as Array)[0]["type"]), "thunder")
	assert_eq(str((data["upcast"] as Dictionary)["damage"]), "1d10")
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "thunder_step", 3, [], Vector2(8.5, 2.5)).ok)
	while e.pending != null:
		e.answer_reaction(true)
	var lost := 300 - friend.creature.hp
	assert_between(lost, 3.0, 30.0, "3d10 on a failed save (this friend fails every one)")
	assert_true(400 - stout.creature.hp > 0, "the ogre takes at least half")
	assert_between(float(400 - stout.creature.hp), 1.0, 30.0)
	assert_true(_rolled(e, "3d10"), "the dice are shown")


func test_a_creature_that_makes_the_save_takes_half() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var weak := _soft(e, Vector2i(3, 2))
	var sturdy := e.add(TestChars.dummy(300, false, {"type": "humanoid", "ac": 1, "con": 100}), &"enemy", Vector2i(2, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "thunder_step", 3, [], Vector2(8.5, 2.5)).ok)
	while e.pending != null:
		e.answer_reaction(true)
	var failed := 300 - weak.creature.hp
	var saved := 300 - sturdy.creature.hp
	assert_between(failed, 3.0, 30.0)
	assert_eq(saved, failed / 2, "the same roll, halved for the one that saved")


func test_a_higher_slot_adds_1d10_a_level() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	_soft(e, Vector2i(3, 2))
	TestCombat.start_with(e, c)
	var fifth := (c.creature as Character).slots_left(5)
	assert_true(e.spells.cast(c, "thunder_step", 5, [], Vector2(8.5, 2.5)).ok)
	while e.pending != null:
		e.answer_reaction(true)
	assert_true(_rolled(e, "5d10"), "level 5 slot: 3d10 + 2d10")
	assert_eq((c.creature as Character).slots_left(5), fifth - 1, "the level 5 slot paid")


func test_pact_magic_casts_it_at_the_pact_level_only() -> void:
	var e := _hall()
	var c := TestCombat.caster_with(e, ["thunder_step"], Vector2i(2, 2), 9, "kip_smudgewick")
	var ch := c.creature as Character
	assert_eq(int(ch.pact_magic()["level"]), 5, "a level 9 warlock's pact slots are level 5")
	_soft(e, Vector2i(3, 2))
	TestCombat.start_with(e, c)
	var left := int(ch.pact_magic()["left"])
	var cat := ActionCatalog.new(e)
	var a := cat.find(c, "spell:thunder_step")
	assert_eq(cat.level_choices(c, a), [5] as Array[int], "the pact level is the only one offered")
	assert_true(str(a["sub"]).begins_with("Pact level 5") and str(a["sub"]).contains("5d10"), str(a["sub"]))
	var r := e.spells.cast(c, "thunder_step", 3, [], Vector2(8.5, 2.5))
	assert_true(r.ok, r.reason)
	while e.pending != null:
		e.answer_reaction(true)
	assert_eq(int(ch.pact_magic()["left"]), left - 1, "a pact slot spent")
	assert_true(_logged(e, "Thunder Step (level 5 slot)"), "\n".join(e.log.texts().slice(-8)))
	assert_true(_rolled(e, "5d10"), "5d10 at the pact level")


func test_the_square_must_be_in_range_unoccupied_and_seen() -> void:
	var e := _hall([Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4)])
	var c := _caster(e, Vector2i(2, 2))
	var other := _soft(e, Vector2i(12, 2))
	TestCombat.start_with(e, c)
	var past := e.spells.cast(c, "thunder_step", 3, [], Vector2(8.5, 2.5))
	assert_false(past.ok)
	assert_true(past.reason.contains("see"), "behind a wall: " + past.reason)
	var occupied := e.spells.cast(c, "thunder_step", 3, [], Vector2(12.5, 2.5))
	assert_false(occupied.ok)
	assert_eq(occupied.reason, "That square is occupied")
	assert_true((c.creature as Character).slots_left(3) > 0)
	assert_true(c.action_available, "nothing spent on a refusal")
	assert_eq(other.creature.hp, 300)
	# The wall gone, 95 ft is too far and 90 ft is not.
	var e2 := _hall()
	var c2 := _caster(e2, Vector2i(0, 2))
	TestCombat.start_with(e2, c2)
	var too_far := e2.spells.cast(c2, "thunder_step", 3, [], Vector2(19.5, 2.5))
	assert_false(too_far.ok)
	assert_true(too_far.reason.contains("out of range"), too_far.reason)
	assert_true(e2.spells.cast(c2, "thunder_step", 3, [], Vector2(18.5, 2.5)).ok, "18 squares is 90 ft")
	assert_eq(c2.cell, Vector2i(18, 2))


func test_a_willing_creature_of_its_size_or_smaller_within_5_ft_goes_along_unhurt() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var buddy := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	var foe := _soft(e, Vector2i(2, 3))
	TestCombat.start_with(e, c)
	var buddy_hp := buddy.creature.hp
	var r := e.spells.cast(c, "thunder_step", 3, [], Vector2(14.5, 2.5), Vector2.ZERO, {"with": buddy.id})
	assert_true(r.ok, r.reason)
	while e.pending != null:
		e.answer_reaction(true)
	assert_eq(c.cell, Vector2i(14, 2))
	assert_true(e.distance(c, buddy) <= 5, "arrives beside the caster, got %d ft" % e.distance(c, buddy))
	assert_true(buddy.cell.x >= 13, "far from where it stood")
	assert_eq(buddy.creature.hp, buddy_hp, "it left before the boom")
	assert_true(foe.creature.hp < 300, "the foe left behind is caught")


func test_who_can_go_along_is_checked_before_anything_is_spent() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var far_friend := TestCombat.hero(e, "ilse_varga", Vector2i(5, 2))
	var foe := _soft(e, Vector2i(2, 3))
	var ogre_ally := e.add(TestCombat.monster("ogre"), &"party", Vector2i(2, 1))
	TestCombat.start_with(e, c)
	var slots := (c.creature as Character).slots_left(3)
	var s := Compendium.shared().spell_data("thunder_step")
	var too_far := e.spells.cast(c, "thunder_step", 3, [], Vector2(14.5, 2.5), Vector2.ZERO, {"with": far_friend.id})
	assert_false(too_far.ok)
	assert_true(too_far.reason.contains("more than 5 ft"), too_far.reason)
	var enemy := e.spells.cast(c, "thunder_step", 3, [], Vector2(14.5, 2.5), Vector2.ZERO, {"with": foe.id})
	assert_false(enemy.ok)
	assert_true(enemy.reason.contains("willing"), enemy.reason)
	var big := e.spells.cast(c, "thunder_step", 3, [], Vector2(14.5, 2.5), Vector2.ZERO, {"with": ogre_ally.id})
	assert_false(big.ok)
	assert_true(big.reason.contains("larger"), big.reason)
	assert_eq((c.creature as Character).slots_left(3), slots, "no slot spent on a refusal")
	assert_true(c.action_available)
	assert_eq(c.cell, Vector2i(2, 2))
	var near := e.spells.targeting.companions_for(c, s)
	assert_eq(near.size(), 0, "only the ogre and the foe are beside the caster: neither can go")
	var buddy := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	assert_eq(e.spells.targeting.companions_for(c, s), [buddy] as Array[Combatant])


func test_with_no_room_beside_the_landing_the_companion_is_left_behind_in_the_boom() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var buddy := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	# The landing square at (14, 2) with every square round it taken.
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx != 0 or dz != 0:
				_soft(e, Vector2i(14 + dx, 2 + dz))
	TestCombat.start_with(e, c)
	var buddy_hp := buddy.creature.hp
	var r := e.spells.cast(c, "thunder_step", 3, [], Vector2(14.5, 2.5), Vector2.ZERO, {"with": buddy.id})
	assert_true(r.ok, r.reason)
	while e.pending != null:
		e.answer_reaction(true)
	assert_eq(c.cell, Vector2i(14, 2))
	assert_eq(buddy.cell, Vector2i(3, 2), "left behind")
	assert_true(_logged(e, "is left behind"), "\n".join(e.log.texts().slice(-6)))
	assert_true(buddy.creature.hp < buddy_hp, "and caught in the boom")


func test_a_caster_held_by_dimensional_shackles_makes_no_boom() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var foe := _soft(e, Vector2i(3, 2))
	c.creature.add_effect(Effect.new("Dimensional Shackles", &"item", "shackles").with_modifier("flag", {"value": "no_teleport"}))
	TestCombat.start_with(e, c)
	var slots := (c.creature as Character).slots_left(3)
	assert_true(e.spells.cast(c, "thunder_step", 3, [], Vector2(8.5, 2.5)).ok)
	assert_eq(c.cell, Vector2i(2, 2), "it stays put")
	assert_eq(foe.creature.hp, 300, "no teleport, no boom")
	assert_eq((c.creature as Character).slots_left(3), slots - 1, "the spell is spent (deviations.md)")


func test_thunder_step_takes_a_caster_out_of_a_web() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var spider := e.add(TestCombat.monster("giant_spider"), &"enemy", Vector2i(10, 2))
	TestCombat.start_with(e, c)
	e.monster_actions._timed_condition(spider, c, "restrained", "permanent", "Web", [], {"object": "spider_web"})
	assert_true(c.creature.has_condition(&"restrained"), "caught")
	assert_true(e.spells.cast(c, "thunder_step", 3, [], Vector2(16.5, 2.5)).ok)
	assert_false(c.creature.has_condition(&"restrained"), "left the web behind, as with any teleport (deviations.md)")


# --- The combat view's pick ------------------------------------------------------------------------------

func test_the_picker_asks_who_comes_along_and_passes_the_pick_on() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var buddy := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	var foe := _soft(e, Vector2i(2, 3))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var a := cat.find(c, "spell:thunder_step")
	var picker := TargetPicker.new(e)
	picker.begin(c, a, 3)
	assert_false(picker.bring_along(c, a, Vector2(1000.5, 2.5), 3), "a square out of the grid goes on to the cast, which says why")
	assert_false(picker.active())
	assert_true(picker.bring_along(c, a, Vector2(14.5, 2.5), 3), "a willing ally beside the caster: ask")
	assert_true(picker.active())
	assert_eq(picker.step, "companion")
	assert_true(picker.candidate(buddy))
	assert_false(picker.candidate(foe), "a foe is not willing")
	assert_false(picker.candidate(c))
	var view := picker.show(Vector2i(3, 2), buddy)
	assert_true(str(view["title"]).contains("bring someone along"), str(view["title"]))
	assert_false((view["friendly"] as Array).is_empty(), "the ones who could come are lit")
	assert_true(view.has("outline") and not (view["outline"] as Dictionary).is_empty(), "the boom's edge stays on the floor")
	assert_eq(view["goal"], [Vector2i(14, 2)] as Array, "and the landing")
	# A creature that can't go is refused with why.
	var refused := picker.pick(Vector2i(2, 3), foe)
	assert_eq(str(refused["do"]), "refuse")
	assert_true(str(refused["why"]).contains("willing"))
	# A square that isn't the landing is told what to do.
	assert_eq(str(picker.pick(Vector2i(9, 3), null)["do"]), "refuse")
	# The ally: the cast, with it along.
	var go := picker.pick(Vector2i(3, 2), buddy)
	assert_eq(str(go["do"]), "perform")
	assert_eq(str(((go["action"] as Dictionary)["opts"] as Dictionary)["with"]), buddy.id)
	assert_eq(go["point"], Vector2(14.5, 2.5))
	# Enter goes alone; clicking the landing square again too; Backspace picks another square.
	var alone := picker.confirm()
	assert_eq(str(alone["do"]), "perform")
	assert_false(((alone["action"] as Dictionary).get("opts", {}) as Dictionary).has("with"))
	assert_eq(str(picker.pick(Vector2i(14, 2), null)["do"]), "perform", "the landing square again")
	assert_true(picker.undo())
	assert_false(picker.active())
	# The command the view runs casts it.
	picker.bring_along(c, a, Vector2(14.5, 2.5), 3)
	var cmd := picker.pick(Vector2i(3, 2), buddy)
	var r := cat.perform(c, cmd["action"] as Dictionary, cmd["targets"] as Array, cmd["point"] as Vector2, cmd["dir"] as Vector2, 3)
	assert_true(r.ok, r.reason)
	while e.pending != null:
		e.answer_reaction(true)
	assert_eq(c.cell, Vector2i(14, 2))
	assert_true(e.distance(c, buddy) <= 5)


func test_nobody_to_bring_and_no_ask() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	_soft(e, Vector2i(3, 2))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var picker := TargetPicker.new(e)
	assert_false(picker.bring_along(c, cat.find(c, "spell:thunder_step"), Vector2(14.5, 2.5), 3), "only a foe is near: nobody to bring")
	assert_false(picker.bring_along(c, cat.find(c, "spell:far_step"), Vector2(14.5, 2.5), 5), "Far Step takes no one")


func test_the_preview_shows_the_boom_round_the_space_left_not_the_landing() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var foe := _soft(e, Vector2i(4, 2))
	var friend := _soft(e, Vector2i(2, 3), &"party")
	_soft(e, Vector2i(14, 2))   # beside the landing: not in the boom
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var a := cat.find(c, "spell:thunder_step")
	var pv := cat.spell_preview(c, a, Vector2(14.5, 2.5), Vector2.ZERO, 3)
	var ids := (pv["creatures"] as Array).map(func(w: Dictionary) -> String: return str(w["id"]))
	assert_true(foe.id in ids and friend.id in ids, "who the boom would catch, friends too")
	assert_false(c.id in ids, "not the caster")
	assert_eq(ids.size(), 2)
	assert_false((pv["outline"] as Dictionary).is_empty())
	assert_eq(str(pv["save"]), "Con")
	assert_true((pv["warnings"] as Array).any(func(w: Variant) -> bool: return str(w).contains("Friendly fire")), "the friend in it is warned about")
	var row: Dictionary = (pv["creatures"] as Array)[0]
	assert_true(float(row["save_chance"]) >= 0.0 and int(row["damage"]) > 0, "numbers for the area panel: %s" % row)


# --- Far Step --------------------------------------------------------------------------------------------

func test_far_step_teleports_up_to_60_ft_as_a_bonus_action_and_concentrates() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	TestCombat.start_with(e, c)
	var slots := (c.creature as Character).slots_left(5)
	var r := e.spells.cast(c, "far_step", 5, [], Vector2(14.5, 2.5))
	assert_true(r.ok, r.reason)
	assert_eq(c.cell, Vector2i(14, 2), "60 ft")
	assert_eq((c.creature as Character).slots_left(5), slots - 1)
	assert_false(c.bonus_available, "a Bonus Action")
	assert_true(c.action_available, "and only that")
	assert_true(c.creature.concentration != null and c.creature.concentration.source_id == "far_step")
	assert_eq(e.spells.sustained_actions(c).size(), 1, "the repeat teleport is on offer")
	assert_eq(str(e.spells.sustained_actions(c)[0]["do"]), "teleport")


func test_far_step_range_square_and_sight_rules_are_misty_steps() -> void:
	var e := _hall([Vector2i(8, 0), Vector2i(8, 1), Vector2i(8, 2), Vector2i(8, 3), Vector2i(8, 4)])
	var c := _caster(e, Vector2i(2, 2))
	var other := _soft(e, Vector2i(5, 2))
	TestCombat.start_with(e, c)
	assert_eq(e.spells.cast(c, "far_step", 5, [], Vector2(5.5, 2.5)).reason, "That square is occupied")
	var past := e.spells.cast(c, "far_step", 5, [], Vector2(10.5, 2.5))
	assert_false(past.ok)
	assert_true(past.reason.contains("see"), past.reason)
	var e2 := _hall()
	var c2 := _caster(e2, Vector2i(0, 2))
	TestCombat.start_with(e2, c2)
	var far := e2.spells.cast(c2, "far_step", 5, [], Vector2(13.5, 2.5))
	assert_false(far.ok)
	assert_true(far.reason.contains("out of range (60 ft)"), far.reason)
	assert_true(c2.bonus_available and (c2.creature as Character).slots_left(5) > 0, "nothing spent on a refusal")
	assert_eq(other.creature.hp, 300)


func test_far_step_teleports_again_with_a_bonus_action_on_each_later_turn() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	var bag := _soft(e, Vector2i(20, 4))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "far_step", 5, [], Vector2(8.5, 2.5)).ok)
	var cat := ActionCatalog.new(e)
	var now := cat.actions_for(c).filter(func(a: Dictionary) -> bool: return str(a.get("kind", "")) == "sustain" and str(a.get("spell_id", "")) == "far_step")
	assert_eq(now.size(), 1, "on the hotbar the turn it is cast")
	assert_false(bool((now[0] as Dictionary)["legal"]), "but the Bonus Action is gone this turn")
	e.end_turn()
	assert_eq(e.current(), bag)
	e.end_turn()
	assert_eq(e.current(), c, "the caster's next turn")
	assert_true(c.bonus_available)
	var again := cat.actions_for(c).filter(func(a: Dictionary) -> bool: return str(a.get("kind", "")) == "sustain" and str(a.get("spell_id", "")) == "far_step")
	assert_eq(again.size(), 1)
	var entry := again[0] as Dictionary
	assert_true(bool(entry["legal"]), str(entry["reason"]))
	assert_eq(str(entry["targeting"]), "place", "the hotbar asks for a square")
	assert_eq(int(entry["range"]), 60)
	assert_eq(str(entry["cost"]), "bonus")
	var slots := (c.creature as Character).slots_left(5)
	var r := cat.perform(c, entry, [], Vector2(14.5, 4.5))
	assert_true(r.ok, r.reason)
	assert_eq(c.cell, Vector2i(14, 4), "6 squares on")
	assert_false(c.bonus_available)
	assert_eq((c.creature as Character).slots_left(5), slots, "no further slot")
	assert_true(c.creature.concentration != null, "still concentrating")
	# Once a turn: the Bonus Action is the limit, and it is spent.
	var second := cat.actions_for(c).filter(func(a: Dictionary) -> bool: return str(a.get("kind", "")) == "sustain" and str(a.get("spell_id", "")) == "far_step")
	assert_false(bool((second[0] as Dictionary)["legal"]))
	# And again on the turn after that.
	e.end_turn()
	e.end_turn()
	assert_eq(e.current(), c)
	var third := cat.actions_for(c).filter(func(a: Dictionary) -> bool: return str(a.get("kind", "")) == "sustain" and str(a.get("spell_id", "")) == "far_step")
	assert_true(bool((third[0] as Dictionary)["legal"]))
	assert_true(cat.perform(c, third[0] as Dictionary, [], Vector2(8.5, 4.5)).ok)
	assert_eq(c.cell, Vector2i(8, 4))


func test_the_repeat_teleport_keeps_the_squares_rules_and_spends_nothing_on_a_refusal() -> void:
	var e := _hall([Vector2i(10, 0), Vector2i(10, 1), Vector2i(10, 2), Vector2i(10, 3), Vector2i(10, 4)])
	var c := _caster(e, Vector2i(2, 2))
	var bag := _soft(e, Vector2i(5, 4))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "far_step", 5, [], Vector2(6.5, 2.5)).ok)
	e.end_turn()
	e.end_turn()
	var id := str(e.spells.sustained_actions(c)[0]["id"])
	var tight := e.spells.use_sustained(c, id, [], Vector2(5.5, 4.5))
	assert_false(tight.ok)
	assert_eq(tight.reason, "That square is occupied")
	var out := e.spells.use_sustained(c, id, [], Vector2(20.5, 2.5))
	assert_false(out.ok)
	assert_true(out.reason.contains("out of range (60 ft)") or out.reason.contains("see"), out.reason)
	var walled := e.spells.use_sustained(c, id, [], Vector2(12.5, 2.5))
	assert_false(walled.ok)
	assert_true(walled.reason.contains("see"), walled.reason)
	assert_true(c.bonus_available, "refusals spend nothing")
	assert_eq(c.cell, Vector2i(6, 2))
	assert_eq(bag.creature.hp, 300)
	# A creature to put it beside (the hotbar's click on a foe).
	var beside := e.spells.use_sustained(c, id, [bag], Vector2.INF)
	assert_true(beside.ok, beside.reason)
	assert_true(e.distance(c, bag) <= 5)


func test_the_repeat_teleport_ends_with_the_concentration() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "far_step", 5, [], Vector2(8.5, 2.5)).ok)
	assert_eq(e.spells.sustained_actions(c).size(), 1)
	c.creature.concentration.end("test")
	assert_eq(e.spells.sustained_actions(c).size(), 0, "no spell, no teleport")
	var cat := ActionCatalog.new(e)
	assert_eq(cat.actions_for(c).filter(func(a: Dictionary) -> bool: return str(a.get("kind", "")) == "sustain").size(), 0)


func test_casting_another_concentration_spell_ends_far_step() -> void:
	var e := _hall()
	var c := TestCombat.caster_with(e, ["far_step", "hold_person"], Vector2i(2, 2))
	var foe := _soft(e, Vector2i(10, 2))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "far_step", 5, [], Vector2(8.5, 2.5)).ok)
	e.end_turn()
	e.end_turn()
	assert_eq(e.current(), c)
	assert_true(e.spells.cast(c, "hold_person", 2, [foe]).ok)
	assert_eq(e.spells.sustained_actions(c).size(), 0, "concentration moved on")


func test_a_forcecage_or_shackles_hold_the_caster_but_the_spell_still_stands() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	c.creature.add_effect(Effect.new("Dimensional Shackles", &"item", "shackles").with_modifier("flag", {"value": "no_teleport"}))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "far_step", 5, [], Vector2(8.5, 2.5)).ok)
	assert_eq(c.cell, Vector2i(2, 2), "can't teleport in the shackles")
	assert_true(_logged(e, "can't teleport"))
	assert_true(c.creature.concentration != null, "the spell took effect")


func test_an_antimagic_field_stops_a_teleport_into_it_and_the_repeat_teleport_inside_it() -> void:
	var e := _hall()
	var c := _caster(e, Vector2i(2, 2))
	_soft(e, Vector2i(20, 4))
	TestCombat.start_with(e, c)
	var field := FieldObject.new()
	field.spell_id = "antimagic_field"
	field.cells = [Vector2i(14, 2)] as Array[Vector2i]
	e.spells.zones.objects.append(field)
	var into := e.spells.cast(c, "thunder_step", 3, [], Vector2(14.5, 2.5))
	assert_false(into.ok)
	assert_eq(into.reason, "Magic can't reach into the Antimagic Field")
	assert_true(e.spells.cast(c, "far_step", 5, [], Vector2(8.5, 2.5)).ok)
	e.end_turn()
	e.end_turn()
	field.cells = [c.cell] as Array[Vector2i]
	var id := str(e.spells.sustained_actions(c)[0]["id"])
	var r := e.spells.use_sustained(c, id, [], Vector2(12.5, 2.5))
	assert_false(r.ok)
	assert_true(r.reason.contains("Antimagic"), r.reason)
