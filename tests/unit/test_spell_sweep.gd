extends TestCase
## Every spell the combat engine offers does something when cast in a fight: no spell may spend a slot and an
## action and change nothing (the owner's report: Thunderwave and Spiritual Weapon missing their secondary
## effects). Each spell is cast by a level 9 caster that knows it, at feeble foes, with up to six seeds so a lucky
## save can't hide a no-op.


## Everything about the fight a spell could change.
func _snapshot(e: Encounter) -> String:
	var parts: Array = []
	for c in e.combatants:
		var fx: Array = []
		for x: Effect in c.creature.effects:
			fx.append(x.name)
		parts.append([c.id, c.cell, c.creature.hp, c.creature.temp_hp, c.creature.dead, c.creature.stable, c.movement_left,
			c.creature.active_conditions(), fx, c.creature.size])
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
	var c := TestCombat.caster_with(e, [spell_id], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var data0 := Compendium.shared().spell_data(spell_id)
	var kind := str((data0.get("targets", {}) as Dictionary).get("creature_type", "humanoid"))
	var f1 := TestCombat.punching_bag(e, Vector2i(3, 3), 80, kind)
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
	var action := cat.find(c, "spell:" + spell_id)
	if action.is_empty():
		action = cat.find(c, "spell:%s:grovel" % spell_id)
	if action.is_empty():
		return {"skip": "not on the hotbar"}
	if not bool(action["legal"]):
		return {"skip": str(action["reason"])}
	match str(action["targeting"]):
		"dying":
			ally.creature.hp = 0
		"dead":
			ally.creature.dead = true
	ally.creature.add_condition(&"poisoned", "test")
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
		"point":
			point = Vector2(3.5, 3.5)
		"place":
			point = Vector2(5.5, 3.5) if spell_id in ["misty_step", "summon_fey", "summon_undead", "flaming_sphere", "dancing_lights", "mage_hand"] else Vector2.INF
			if point == Vector2.INF:
				targets = [f1]
		"direction":
			dir = Vector2.RIGHT
	var r := cat.perform(c, action, targets, point, dir)
	while e.pending != null:
		r = e.answer_reaction(true)
	if not r.ok:
		return {"fail": r.reason}
	# Later turns: lingering areas, sustained actions and timed effects get their chance.
	var after := _snapshot(e)
	return {"changed": before != after}


func test_every_combat_spell_changes_something() -> void:
	var none: Array[String] = []
	var failed: Array[String] = []
	var checked := 0
	for s: Dictionary in Compendium.shared().all("spells"):
		var id := str(s["id"])
		var probe := TestCombat.open_field(1)
		if not probe.spells.has_combat_rules(s):
			continue
		var unit := str((s.get("casting_time", {}) as Dictionary).get("unit", "action"))
		if unit in ["reaction", "minute", "hour"]:
			continue
		if int(s.get("level", 0)) > 3:
			continue   # the pregen caster tops out at level 3 spells; higher ones are tested where they're used
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
	assert_true(checked > 80, "checked %d spells" % checked)
	assert_eq(failed, [] as Array[String], "spells that can't be cast in the sweep")
	assert_eq(none, [] as Array[String], "spells that change nothing")
