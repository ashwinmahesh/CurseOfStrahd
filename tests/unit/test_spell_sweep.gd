extends TestCase
## Every spell the combat engine offers does something when cast in a fight: no spell may spend a slot and an
## action and change nothing (the owner's report: Thunderwave and Spiritual Weapon missing their secondary
## effects). Each spell is cast by a caster that knows it (a level 7 wizard for level 4 spells), at feeble foes, with
## up to six seeds so a lucky save can't hide a no-op. Smite spells are armed and go off on a weapon hit.


## Everything about the fight a spell could change.
func _snapshot(e: Encounter) -> String:
	var parts: Array = []
	for c in e.combatants:
		var fx: Array = []
		for x: Effect in c.creature.effects:
			fx.append(x.name)
		parts.append([c.id, c.cell, c.creature.hp, c.creature.temp_hp, c.creature.dead, c.creature.stable, c.movement_left,
			c.creature.active_conditions(), fx, c.creature.size, c.get_meta_list()])
	parts.append(e.spells.zones.live().size())
	parts.append(e.spells.sustained.size())
	parts.append(e.combatants.size())
	parts.append(e.marks.size())
	for c in e.combatants:
		if c.creature is Character:
			parts.append((c.creature as Character).inventory.size())
			parts.append(str((c.creature as Character).inventory))
	return str(parts)


func _try(spell_id: String, seed_value: int) -> Dictionary:
	var e := TestCombat.open_field(seed_value)
	var data0 := Compendium.shared().spell_data(spell_id)
	var c := TestCombat.caster_with(e, [spell_id], Vector2i(2, 3))
	TestCombat.give_components(c.creature as Character, [spell_id])   # its costly material component, carried
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var kind := str((data0.get("targets", {}) as Dictionary).get("creature_type", "humanoid"))
	var f1 := TestCombat.punching_bag(e, Vector2i(3, 3), 80, kind)
	if spell_id == "heat_metal":
		f1.creature.dead = true
		f1 = TestCombat.foe(e, "bandit", Vector2i(3, 2))
	TestCombat.punching_bag(e, Vector2i(4, 2), 80, kind)
	c.creature.hp = maxi(1, c.creature.max_hp() / 2)
	ally.creature.hp = 5
	# Something for Dispel Magic to end.
	var bless := Effect.new("Bless", &"spell", "bless").with_modifier("bonus_die", {"dice": "1d4", "on": ["attack"]})
	bless.spell_level = 1
	ally.creature.add_effect(bless)
	f1.creature.add_effect(bless)
	# Something for Remove Curse to lift.
	for who: Combatant in [ally, f1]:
		var curse := Effect.new("Cursed", &"monster", "curse").with_modifier("flag", {"value": "curse:test"})
		who.creature.add_effect(curse)
	TestCombat.start_with(e, c)
	var data := Compendium.shared().spell_data(spell_id)
	var cat := ActionCatalog.new(e)
	# A smite: armed, then a weapon hit sets it off.
	if bool(data.get("on_hit_spell", false)):
		var ch := c.creature as Character
		var ranged := bool(data.get("on_hit_ranged_only", false))
		if ranged:
			ch.add_item("shortbow")
			ch.add_item("arrow", 20)
			ch.equip("shortbow", "main_hand")
		var before0 := _snapshot(e)
		var armed := e.features.toggle_rider(c, "smite:" + spell_id)
		if not armed.ok:
			return {"fail": armed.reason}
		var opt := ""
		for o in e.attack_options(c):
			if bool(o["melee"]) != ranged and str(o["kind"]) in ["weapon", "unarmed"]:
				opt = str(o["id"])
		TestCombat.next_d20(e, 19)
		var hr := e.attack(c, f1, opt)
		while e.pending != null:
			hr = e.answer_reaction(true)
		if not hr.ok:
			return {"fail": hr.reason}
		return {"changed": before0 != _snapshot(e) and not (spell_id in c.armed)}
	var action := cat.find(c, "spell:" + spell_id)
	if action.is_empty():
		action = cat.find(c, "spell:%s:grovel" % spell_id)
	if action.is_empty():
		return {"skip": "not on the hotbar"}
	# Spells above the caster's slots (levels 6-9: the pregens stop at level 11) are cast with a stat block's numbers,
	# the way a monster or a magic item casts them.
	var by_numbers := not bool(action["legal"]) and str(action["reason"]).begins_with("No spell slots")
	if not bool(action["legal"]) and not by_numbers:
		return {"skip": str(action["reason"])}
	match str(action["targeting"]):
		"dying":
			ally.creature.hp = 0
		"dead":
			ally.creature.dead = true
	ally.creature.add_condition(&"poisoned", "test")
	# Something for Greater Restoration to end, and a foe weak enough for Divine Word to matter.
	if spell_id == "greater_restoration":
		ally.creature.add_condition(&"charmed", "test")
	if spell_id == "divine_word":
		f1.creature.hp = 30
	# A recovery spell needs expended slots, and its benefit must be measured separately from casting costs.
	var recovery_before := 0
	if spell_id == "mordenkainens_lucubration":
		var ch := c.creature as Character
		ch.expend_slot(2)
		ch.expend_slot(2)
		recovery_before = ch.expended_slots(2)
	var before := _snapshot(e)
	var targets: Array = []
	var point := Vector2.INF
	var dir := Vector2.ZERO
	match str(action["targeting"]):
		"enemy", "creature", "multi":
			targets = [f1]
			if str(action["targeting"]) == "multi" and ("healing" in data.get("tags", []) or "buff" in data.get("tags", []) or "defense" in data.get("tags", [])):
				targets = [ally]
		"ally", "dying", "dead":
			targets = [ally]
		"point", "wall":
			# A wall cast without drawn squares is the straight wall through the point (SpellTargeting.wall_cells).
			point = Vector2(3.5, 3.5)
		"place":
			point = Vector2(5.5, 3.5) if spell_id in ["misty_step", "dimension_door", "flaming_sphere", "dancing_lights", "mage_hand", "mordenkainens_faithful_hound", "grasping_vine"] \
				or spell_id in SpellCaster.SUMMON_SPELLS else Vector2.INF
			if point == Vector2.INF:
				targets = [f1]
		"direction":
			dir = Vector2.RIGHT
	var r: CombatResult
	if by_numbers:
		var nums := {"dc": Breakdown.new("DC").add("DC", 17), "attack": Breakdown.new("Attack").add("Attack", 9), "mod": 5}
		var o2 := (action.get("opts", {}) as Dictionary).duplicate()
		o2["direction"] = dir
		r = e.spells.cast_with_numbers(c, spell_id, int(data.get("level", 0)), targets, point if point != Vector2.INF else (Vector2(5.5, 3.5) if str(action["targeting"]) in ["place"] else point), nums, o2)
	else:
		r = cat.perform(c, action, targets, point, dir)
	while e.pending != null:
		r = e.answer_reaction(true)
	if not r.ok:
		return {"fail": r.reason}
	# Later turns: lingering areas, sustained actions and timed effects get their chance.
	var after := _snapshot(e)
	if spell_id == "mordenkainens_lucubration":
		return {"changed": recovery_before - (c.creature as Character).expended_slots(2) == 2}
	return {"changed": before != after}


## Spells that rightly do nothing to the foes of a fight: Enthrall's targets succeed automatically if you're
## fighting them.
const NO_EFFECT_ON_FOES := ["enthrall"]


## The sweep in slices by spell level, so make test can run them side by side (as one test it took up to 9 minutes).
## Together they cover every level; each slice must check about three quarters of the spells it had on 2026-10-07
## (76, 52, 77, 58 and 48), where the one test asked for more than 80 in all.
const SLICES := [[0, 1], [2], [3, 4], [5, 6], [7, 8, 9]]


func test_the_slices_cover_every_spell_level() -> void:
	var levels := {}
	for slice: Array in SLICES:
		for lv: int in slice:
			assert_false(levels.has(lv), "level %d is in one slice only" % lv)
			levels[lv] = true
	for s: Dictionary in Compendium.shared().all("spells"):
		assert_true(levels.has(int(s.get("level", 0))), "%s's level %d is swept" % [s["id"], int(s.get("level", 0))])


func test_every_cantrip_and_level_1_combat_spell_changes_something() -> void:
	assert_true(_sweep(SLICES[0]) > 55, "checked the cantrips and level 1 spells")


func test_every_level_2_combat_spell_changes_something() -> void:
	assert_true(_sweep(SLICES[1]) > 35, "checked the level 2 spells")


func test_every_level_3_and_4_combat_spell_changes_something() -> void:
	assert_true(_sweep(SLICES[2]) > 55, "checked the level 3 and 4 spells")


func test_every_level_5_and_6_combat_spell_changes_something() -> void:
	assert_true(_sweep(SLICES[3]) > 40, "checked the level 5 and 6 spells")


func test_every_level_7_to_9_combat_spell_changes_something() -> void:
	assert_true(_sweep(SLICES[4]) > 30, "checked the level 7 to 9 spells")


## Casts every combat spell of `levels` (up to six seeds each) and fails on any that can't be cast or changes nothing.
## Returns how many it checked.
func _sweep(levels: Array) -> int:
	var none: Array[String] = []
	var failed: Array[String] = []
	var checked := 0
	for s: Dictionary in Compendium.shared().all("spells"):
		var id := str(s["id"])
		if not int(s.get("level", 0)) in levels:
			continue
		var probe := TestCombat.open_field(1)
		if not probe.spells.has_combat_rules(s):
			continue
		if id in NO_EFFECT_ON_FOES:
			continue
		# SWEEP_LEVELS=7,8,9 narrows the sweep while chasing a problem.
		var id_only := OS.get_environment("SWEEP_IDS")
		if id_only != "" and not id in id_only.split(","):
			continue
		var lv_only := OS.get_environment("SWEEP_LEVELS")
		if lv_only != "" and not str(int(s.get("level", 0))) in lv_only.split(","):
			continue
		var unit := str((s.get("casting_time", {}) as Dictionary).get("unit", "action"))
		if unit in ["reaction", "minute", "hour"]:
			continue

		checked += 1
		var changed := false
		var last := {}
		for seed_value: int in [1, 2, 3, 5, 8, 13]:
			last = _try(id, seed_value)
			if last.has("skip") or last.has("fail"):
				break
			if bool(last["changed"]):
				changed = true
				break
		if last.has("fail"):
			failed.append("%s: %s" % [id, last["fail"]])
		elif last.has("skip"):
			failed.append("%s: can't be cast (%s)" % [id, last["skip"]])
		elif not changed:
			none.append(id)
	assert_eq(failed, [] as Array[String], "spells that can't be cast in the sweep (levels %s)" % [levels])
	assert_eq(none, [] as Array[String], "spells that change nothing (levels %s)" % [levels])
	print("    swept %d combat spells of level %s" % [checked, levels])
	return checked
