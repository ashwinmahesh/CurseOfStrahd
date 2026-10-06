extends TestCase
## Engine pieces for the Phase 4 classes, tested with stand-in data until their real data lands: marks the caster
## carries (Hunter's Mark, Hex), smite spells cast on a hit (Divine Smite), and dice given to an ally (Bardic
## Inspiration).


func after_each() -> void:
	for id: String in ["test_mark", "test_smite"]:
		(Compendium.shared().tables["spells"] as Dictionary).erase(id)


func _add_spell(d: Dictionary) -> void:
	(Compendium.shared().tables["spells"] as Dictionary)[str(d["id"])] = d


func _mark_spell() -> Dictionary:
	return {"id": "test_mark", "name": "Test Mark", "level": 1, "school": "divination", "classes": ["ranger"],
		"casting_time": {"unit": "bonus_action"}, "range": {"kind": "feet", "feet": 90}, "components": {"v": true},
		"duration": {"kind": "hours", "amount": 1, "concentration": true}, "targets": {"kind": "enemy", "count": 1},
		"effects": [{"effect": "modifiers", "params": {"target": "caster_vs", "modifiers": [{"stat": "extra_damage", "dice": "1d6", "type": "force", "on": "attack", "vs": "target"}]}}],
		"sustain": [{"do": "move_mark", "cost": "bonus_action", "range": 90, "label": "Move the mark"}],
		"summary": "test", "text": "test"}


func _smite_spell() -> Dictionary:
	return {"id": "test_smite", "name": "Test Smite", "level": 1, "school": "evocation", "classes": ["paladin"],
		"casting_time": {"unit": "bonus_action"}, "range": {"kind": "self"}, "components": {"v": true},
		"duration": {"kind": "instantaneous"}, "targets": {"kind": "enemy", "count": 1}, "on_hit_spell": true,
		"damage": [{"dice": "2d8", "type": "radiant"}], "upcast": {"damage": "1d8"}, "damage_bonus_vs": {"types": ["undead", "fiend"], "dice": "1d8"},
		"summary": "test", "text": "test"}


func test_a_mark_adds_damage_to_hits_on_its_target_and_moves() -> void:
	_add_spell(_mark_spell())
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["test_mark"], Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	var b := TestCombat.punching_bag(e, Vector2i(3, 4), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "test_mark", 1, [a]).ok)
	var mods := c.creature.modifiers_for(&"extra_damage")
	assert_eq(mods.size(), 1)
	assert_eq(str(mods[0].data["vs"]), a.id, "the mark points at its target")
	a.creature.hp = 0
	a.creature.dead = true
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	var mv := e.spells.sustained_for(c, "test_mark")
	assert_true(bool(mv["legal"]), str(mv["reason"]))
	assert_true(e.spells.use_sustained(c, str(mv["id"]), [b]).ok)
	assert_eq(str(c.creature.modifiers_for(&"extra_damage")[0].data["vs"]), b.id, "moved to the new target")


func test_a_smite_spell_goes_off_on_the_next_hit() -> void:
	_add_spell(_smite_spell())
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["test_smite"], Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	z.creature.hp = 200
	TestCombat.start_with(e, c)
	var slots := (c.creature as Character).slots_left(1)
	var opts := e.features.rider_options(c).map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_true("smite:test_smite" in opts, str(opts))
	assert_true(e.features.toggle_rider(c, "smite:test_smite").ok)
	var opt := ""
	for o in e.attack_options(c):
		if bool(o["melee"]):
			opt = str(o["id"])
	TestCombat.next_d20(e, 19)
	var r := e.attack(c, z, opt)
	assert_true(r.hit)
	assert_eq((c.creature as Character).slots_left(1), slots - 1, "a slot spent")
	assert_false(c.bonus_available, "a Bonus Action spent")
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool: return str(x["text"]).contains("Test Smite")))


func test_an_inspiration_die_helps_a_failed_roll_once() -> void:
	var e := TestCombat.open_field(1)
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.start_with(e, h)
	var fx := Effect.new("Bardic Inspiration", &"feature", "bardic_inspiration").with_modifier("inspiration_die", {"dice": "1d6"})
	h.creature.add_effect(fx)
	var t := h.creature.roll_save(e.dice, &"wis", 30)
	assert_true(t.extra_label.contains("Bardic Inspiration"), t.describe())
	assert_false(h.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "bardic_inspiration"), "used up")
