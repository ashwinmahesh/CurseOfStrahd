extends TestCase
## Spell and ability effects (docs/art/spell_effects.md, art/vfx/effects.json, world/combat/fx/spell_fx.gd): every
## pick names a real spell, a family and a flavour; flavours use palette colours only; the pilot spells look as picked;
## a smite spell tells the view when it rides a hit; and the view's effect plays its parts and clears them away.

const DATA := "res://art/vfx/effects.json"


func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA)) as Dictionary


func test_flavours_use_palette_colours_only() -> void:
	var palette := {}
	for f: String in ["res://art/palette/palette.json", "res://art/palette/ui_palette.json"]:
		palette.merge(JSON.parse_string(FileAccess.get_file_as_string(f)) as Dictionary)
	var flavours := _data()["flavours"] as Dictionary
	for name: String in flavours:
		for part: String in ["core", "glow", "edge", "smoke", "light"]:
			var colour := str((flavours[name] as Dictionary).get(part, ""))
			assert_true(palette.has(colour), "flavour %s: %s '%s' isn't a palette colour" % [name, part, colour])
	for ty: String in _data()["damage_flavours"] as Dictionary:
		assert_true(flavours.has(str((_data()["damage_flavours"] as Dictionary)[ty])), "damage type %s has no flavour" % ty)


func test_every_pick_names_a_spell_a_family_and_a_flavour() -> void:
	var d := _data()
	var families := d["families"] as Dictionary
	var flavours := d["flavours"] as Dictionary
	for id: String in d["spells"] as Dictionary:
		assert_false(Compendium.shared().spell_data(id).is_empty(), "art/vfx/effects.json picks a look for %s, which isn't a spell" % id)
		var pick: Variant = (d["spells"] as Dictionary)[id]
		var spec: Dictionary = pick if pick is Dictionary else {"family": str(pick).get_slice("@", 0), "flavour": str(pick).get_slice("@", 1) if str(pick).contains("@") else ""}
		assert_true(families.has(str(spec["family"])), "%s: no family %s" % [id, spec["family"]])
		assert_true(str(spec.get("flavour", "")) == "" or flavours.has(str(spec["flavour"])), "%s: no flavour %s" % [id, spec.get("flavour", "")])


func test_every_family_has_an_effect() -> void:
	for family: String in _data()["families"] as Dictionary:
		assert_true(SpellFx.has_family(family), "family %s is described in art/vfx/effects.json but has no effect in SpellFx" % family)


func test_pilot_spells_take_their_family_and_flavour() -> void:
	var want := {"fire_bolt": ["bolt", "fire"], "fireball": ["burst", "fire"], "cure_wounds": ["heal", "healing"],
		"eldritch_blast": ["beam", "force"], "divine_smite": ["smite", "radiant"]}
	for id: String in want:
		var cue := SpellFx.spell_cue(id)
		assert_eq(str(cue.get("family", "")), str((want[id] as Array)[0]), "%s's family" % id)
		assert_eq(str(cue.get("flavour", "")), str((want[id] as Array)[1]), "%s's flavour" % id)
		assert_eq((cue["colours"] as Dictionary)["glow"], Look.color(str(((_data()["flavours"] as Dictionary)[str((want[id] as Array)[1])] as Dictionary)["glow"])))


func test_a_spell_without_a_pick_gets_a_family_from_its_data() -> void:
	assert_eq(SpellFx.derive_family({"attack": "ranged", "damage": [{"type": "cold"}]}), "bolt")
	assert_eq(SpellFx.derive_family({"area": {"shape": "sphere", "size": 20}, "range": {"kind": "feet"}, "damage": [{"type": "fire"}]}), "burst")
	assert_eq(SpellFx.derive_family({"on_hit_spell": true}), "smite")
	assert_eq(SpellFx.derive_family({"tags": ["healing"], "heal": {"dice": "2d8"}}), "heal")


func test_a_smite_spell_riding_a_hit_tells_the_view() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["divine_smite"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	var melee := ""
	for o in e.attack_options(c):
		if bool(o["melee"]):
			melee = str(o["id"])
			break
	assert_true(e.features.toggle_rider(c, "smite:divine_smite").ok)
	e.drain_events()
	TestCombat.next_d20(e, 19)
	assert_true(e.attack(c, t, melee).hit)
	var events := e.drain_events()
	var kinds := events.map(func(ev: Dictionary) -> String: return str(ev["type"]))
	var at := kinds.find("smite")
	assert_true(at >= 0, "a smite event: %s" % [kinds])
	assert_true(at > kinds.find("attack") and at < kinds.find("damage"), "between the hit and its damage: %s" % [kinds])
	var ev := events[at] as Dictionary
	assert_eq(str(ev["spell"]), "divine_smite")
	assert_eq(str(ev["caster"]), c.id)
	assert_eq(str(ev["target"]), t.id)


func test_an_effect_plays_its_parts_and_clears_them_away() -> void:
	var fx := SpellFx.new()
	add_child(fx)
	var cue := SpellFx.spell_cue("fire_bolt")
	FxMissiles.impact(fx, cue, Vector3(1, 1, 1), 1.0)
	assert_true(fx.get_child_count() >= 4, "flash, flames, sparks and smoke")
	await get_tree().create_timer(2.5).timeout
	assert_eq(fx.get_child_count(), 0, "all freed once played out")
	fx.queue_free()


func _events_of(e: Encounter, kind: String) -> Array:
	return e.drain_events().filter(func(ev: Variant) -> bool: return str((ev as Dictionary)["type"]) == kind)


func test_attack_events_name_the_attack_used() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	z.creature.hp = 100
	TestCombat.start_with(e, ilse)
	e.drain_events()
	e.attack(ilse, z, "weapon:greatsword")
	var atk := _events_of(e, "attack")
	assert_eq(atk.size(), 1)
	assert_eq(str((atk[0] as Dictionary)["action"]), "weapon:greatsword", "a weapon attack")
	e.end_turn()
	for i in 4:
		if e.current() == z:
			break
		e.end_turn()
	e.drain_events()
	e.attack(z, ilse, "monster:slam")
	atk = _events_of(e, "attack")
	assert_eq(str((atk[0] as Dictionary)["action"]), "monster:slam", "a stat-block attack")


func test_spell_attack_events_name_the_spell() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["fire_bolt"], Vector2i(2, 3))
	var t := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, c)
	e.drain_events()
	e.spells.cast(c, "fire_bolt", 0, [t])
	var atk := _events_of(e, "attack")
	assert_eq(atk.size(), 1)
	assert_eq(str((atk[0] as Dictionary)["action"]), "spell:fire_bolt")


func test_a_class_feature_used_from_the_hotbar_comes_first_as_an_ability_event() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	ilse.creature.hp = 5
	var cat := ActionCatalog.new(e)
	e.drain_events()
	assert_true(cat.perform(ilse, cat.find(ilse, "second_wind")).ok)
	var events := e.drain_events()
	assert_true(events.size() >= 2, "the ability and its healing: %s" % [events])
	var ev := events[0] as Dictionary
	assert_eq(str(ev["type"]), "ability", "first, ahead of the healing")
	assert_eq(str(ev["source"]), "feature")
	assert_eq(str(ev["key"]), "second_wind")
	assert_eq(str(ev["by"]), ilse.id)
	assert_true(events.any(func(x: Variant) -> bool: return str((x as Dictionary)["type"]) == "heal"), "then the heal")
	# Common actions and failed ones say nothing.
	e.drain_events()
	cat.perform(ilse, cat.find(ilse, "dodge"))
	assert_eq(_events_of(e, "ability").size(), 0, "Dodge isn't an ability")


func test_a_monster_save_action_comes_as_an_ability_event() -> void:
	var e := TestCombat.open_field(4)
	var v := TestCombat.foe(e, "vampire_spawn", Vector2i(3, 3))
	var h := TestCombat.punching_bag(e, Vector2i(4, 3), 80)
	h.side = &"party"
	TestCombat.start_with(e, v)
	e.monster_actions.grapple(v, h, 13, 2, "Claw")
	e.drain_events()
	e.monster_actions.save_action(v, (v.creature as Monster).action("bite"), h, CombatResult.new())
	var ab := _events_of(e, "ability")
	assert_eq(ab.size(), 1)
	var ev := ab[0] as Dictionary
	assert_eq(str(ev["source"]), "monster")
	assert_eq(str(ev["key"]), "vampire_spawn.bite")
	assert_eq(str(ev["by"]), v.id)
	assert_eq(ev["targets"], [h.id])


func test_feature_and_monster_picks_name_a_family_and_a_real_action() -> void:
	var d := _data()
	for table: String in ["features", "monsters", "weapons"]:
		for key: String in d.get(table, {}) as Dictionary:
			var cue := SpellFx._spec((d[table] as Dictionary)[key])
			assert_true((d["families"] as Dictionary).has(str(cue["family"])), "%s %s: no family %s" % [table, key, cue["family"]])
			assert_true(str(cue.get("flavour", "")) == "" or (d["flavours"] as Dictionary).has(str(cue["flavour"])), "%s %s: no flavour" % [table, key])
	for key: String in d["monsters"] as Dictionary:
		var block := Compendium.shared().monster_data(key.get_slice(".", 0))
		assert_false(block.is_empty(), "art/vfx/effects.json: no monster %s" % key)
		var found := false
		for section: String in ["actions", "bonus_actions", "reactions", "lair_actions"]:
			var list: Variant = block.get(section, [])
			for a: Variant in (list as Array if list is Array else []):
				found = found or str((a as Dictionary).get("id", "")) == key.get_slice(".", 1)
		assert_true(found, "art/vfx/effects.json: %s has no action %s" % [key.get_slice(".", 0), key.get_slice(".", 1)])


func test_attacks_and_monster_actions_find_their_look() -> void:
	var e := TestCombat.open_field(4)
	var skull := TestCombat.foe(e, "flameskull", Vector2i(3, 3))
	var zombie := TestCombat.foe(e, "zombie", Vector2i(5, 3))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	assert_eq(str(SpellFx.attack_cue(skull, "monster:fire_ray")["family"]), "ray", "the Flameskull's green fire jet, picked")
	assert_eq(str(SpellFx.attack_cue(skull, "monster:fire_ray")["flavour"]), "necrotic")
	assert_eq(str(SpellFx.attack_cue(zombie, "monster:slam")["family"]), "slash", "a plain blow")
	assert_eq(str(SpellFx.attack_cue(ilse, "weapon:greatsword")["family"]), "slash")
	assert_eq(str(SpellFx.ability_cue("feature", "second_wind", ilse)["family"]), "heal")
	assert_eq(str(SpellFx.spell_cue("turn_undead")["family"]), "nova", "a feature shown as a spell event")
	assert_true(SpellFx.spell_cue("no_such_thing").is_empty())


func test_a_lair_action_names_whom_it_turns_on() -> void:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var data := {"id": "test_boss", "name": "Test Boss", "size": "medium", "type": "undead", "ac": 15,
		"hp": {"average": 100, "dice": "10d10+45"}, "speed": {"walk": 30},
		"abilities": {"str": 18, "dex": 14, "con": 16, "int": 12, "wis": 12, "cha": 16}, "cr": 10, "proficiency_bonus": 4,
		"actions": [], "ai_profile": "brute", "lair_actions": [{"id": "spirit", "name": "Spirit", "kind": "attack",
			"attack": {"bonus": 40, "range": 120}, "damage": [{"average": 7, "dice": "2d6", "type": "necrotic"}], "summary": "x"}]}
	var boss := e.add(Monster.from_data(data), &"enemy", Vector2i(3, 3))
	var a := TestCombat.hero(e, "hedda_ironvow", Vector2i(8, 3), 5)
	e.lair = false
	e.start()
	boss.initiative = 10
	a.initiative = 5
	e.order.sort_custom(func(x: Combatant, y: Combatant) -> bool: return x.initiative > y.initiative)
	e.lair = true
	e.legendary.lair_round = 0
	e.turn_index = 0
	e.drain_events()
	e._lair_then_begin()
	var lair := e.drain_events().filter(func(ev: Variant) -> bool: return str((ev as Dictionary)["type"]) == "lair")
	assert_eq(lair.size(), 1, "the lair acted")
	assert_eq(str((lair[0] as Dictionary)["action"]), "spirit")
	assert_eq((lair[0] as Dictionary)["targets"], [a.id], "the hero it struck")
