extends TestCase
## Every monster save action and save spell that puts a condition on a creature that fails really does it (or says why
## it can't), so "it failed the save and nothing happened" can't hide in one of them. Found while looking into Ashwin's
## reports of 2026-10-18 (test_save_conditions.gd has the cases that were wrong).


func _told_immune(e: Encounter, cond: String) -> bool:
	return e.log.texts().any(func(t: String) -> bool: return t.contains("is immune to " + cond.capitalize()))


## Each stat-block save action with a condition rider, aimed at a hero that fails every save, standing square in front
## of the middle of the monster's facing edge (a cone from a Huge creature starts there, so a hero beside its corner is
## outside it).
func test_every_monster_save_action_lands_its_condition_or_says_why() -> void:
	var bad: Array[String] = []
	var checked := 0
	for id: String in Compendium.shared().table("monsters"):
		var data := Compendium.shared().monster_data(id)
		for a: Variant in data.get("actions", []):
			var act := a as Dictionary
			if str(act.get("kind", "")) != "save":
				continue
			# (A Web's restraint hangs on an object on the map, tested with the spider.)
			var riders := (act.get("on_fail", []) as Array).filter(func(r: Variant) -> bool:
				return str((r as Dictionary).get("do", "")) == "condition" and not (r as Dictionary).has("object"))
			if riders.is_empty():
				continue
			var e := TestCombat.open_field(5)
			var foe := TestCombat.foe(e, id, Vector2i(3, 3))
			var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3 + (foe.size_cells - 1) / 2), 9)
			hero.creature.add_effect(Effect.new("Fails every save", &"effect", "test").with_modifier("save", {"ability": "all", "value": -100}))
			TestCombat.start_with(e, foe)
			e.monster_actions.save_action(foe, act, hero, CombatResult.new(), false)
			checked += 1
			for rd: Variant in riders:
				var cond := str((rd as Dictionary)["condition"])
				if hero.creature.has_condition(StringName(cond)) or _told_immune(e, cond):
					continue
				bad.append("%s.%s: no %s and no word of why: %s" % [id, str(act["id"]), cond, " // ".join(e.log.texts().slice(-3))])
	assert_true(checked >= 25, "%d save actions with a condition checked" % checked)
	assert_eq(bad, [] as Array[String], "\n".join(bad))


## Each save spell whose failed save puts a condition on a creature, cast with a Difficulty Class no one can beat at a
## dummy 5 or 15 ft away (a Humanoid, else a Beast). Zones that act at a turn's start (Stinking Cloud), spells that
## ride a weapon hit (the smites) and Suggestion to a creature with no language are left to their own tests.
func test_every_condition_spell_lands_or_says_why() -> void:
	var bad: Array[String] = []
	var checked := 0
	for id: String in Compendium.shared().table("spells"):
		var s := Compendium.shared().spell_data(id)
		if not s.has("save") or bool(s.get("on_hit_spell", false)):
			continue
		var conds: Array[String] = []
		for fx: Variant in s.get("effects", []):
			var d := fx as Dictionary
			var params := d.get("params", {}) as Dictionary
			if str(d.get("effect", "")) == "condition" and str(params.get("on", "fail")) in ["fail", "always"]:
				conds.append(str(params.get("condition", "")))
		if conds.is_empty():
			continue
		var level := int(s.get("level", 1))
		var nums := {"dc": Breakdown.new("Spell save DC").add("test", 40), "attack": Breakdown.new("Spell attack").add("test", 10), "mod": 5, "ability": &"int"}
		var e: Encounter = null
		var target: Combatant = null
		var res: CombatResult = null
		for kind: String in ["humanoid", "beast"]:
			for x: int in [4, 2]:
				e = TestCombat.open_field(5)
				var caster := e.add(TestChars.dummy(300), &"party", Vector2i(1, 3))
				target = TestCombat.punching_bag(e, Vector2i(x, 3), 500, kind)
				TestCombat.start_with(e, caster)
				var point := e.center_of(target) if s.has("area") else Vector2.INF
				res = e.spells.cast_with_numbers(caster, id, level, [target], point, nums)
				if res.ok:
					break
			if res.ok:
				break
		if res == null or not res.ok:
			continue
		while e.pending != null:
			e.answer_reaction(false)
		checked += 1
		var landed := target.creature.effects.any(func(x: Effect) -> bool: return x.source_id == id)
		for c: String in conds:
			if c == "choice" or target.creature.has_condition(StringName(c)):
				landed = true
		var told := e.log.texts().any(func(t: String) -> bool: return t.contains("immune") or t.contains("fills") or t.contains("understand"))
		if not landed and not told:
			bad.append("%s: nothing on the target and no word of why: %s" % [id, " // ".join(e.log.texts().slice(-3))])
	assert_true(checked >= 30, "%d condition spells checked" % checked)
	assert_eq(bad, [] as Array[String], "\n".join(bad))
