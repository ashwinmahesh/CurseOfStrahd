extends TestCase
## Line areas aimed at any angle (owner, 2026-10-12: "Allow aiming straight line spells (like lightning bolt) in any
## straight line (not just aligned with squares)"): Lightning Bolt and the other Line spells, their later beams and turns,
## a Dragonborn's Breath Weapon line and monsters' lines go straight from the caster's middle the way they're pointed,
## taking each square at least half inside (2024 DMG). Cones and cubes aim at any angle too (test_free_aim.gd).


func _field() -> Encounter:
	var rows: Array = []
	for z in 12:
		rows.append("................")
	return TestCombat.encounter(rows)


func _wizard(e: Encounter, cell: Vector2i) -> Combatant:
	var ch := TestChars.custom("wizard", "human", 9)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for id: String in ["lightning_bolt", "burning_hands", "thunderwave", "gust_of_wind"]:
		if not id in prepared:
			prepared.append(id)
	ch.finish_long_rest()
	return e.add(ch, &"party", cell)


## Aimed from (3, 6) toward (14.5, 2): three zombies on the slant and two along the row it used to snap to.
func _slant(e: Encounter) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for cell: Vector2i in [Vector2i(8, 4), Vector2i(10, 3), Vector2i(13, 2), Vector2i(9, 6), Vector2i(12, 6)]:
		out.append(TestCombat.foe(e, "zombie", cell))
	return out


func test_lightning_bolt_goes_the_way_it_is_pointed() -> void:
	var e := _field()
	var c := _wizard(e, Vector2i(3, 6))
	var z := _slant(e)
	TestCombat.start_with(e, c)
	var aim := Vector2(14.5, 2.0) - e.center_of(c)
	var cells := e.spells.area_for(c, Compendium.shared().spell_data("lightning_bolt"), Vector2.INF, aim)
	var caught := e.spells.creatures_in(cells)
	for i in 3:
		assert_true(z[i] in caught, "%s on the slant" % str(z[i].cell))
	assert_false(z[3] in caught or z[4] in caught, "not the ones along the row")
	assert_false(c.cell in cells, "not the caster's own square")
	var hp_before := z.map(func(o: Combatant) -> int: return o.creature.hp)
	var r := e.spells.cast(c, "lightning_bolt", 3, [], Vector2.INF, aim)
	assert_true(r.ok, r.reason)
	for i in 3:
		assert_true(z[i].creature.hp < int(hp_before[i]) or z[i].is_down(), "%s hurt" % str(z[i].cell))
	assert_eq(z[3].creature.hp, int(hp_before[3]), "the row's zombies untouched")
	assert_eq(z[4].creature.hp, int(hp_before[4]))


func test_its_outline_is_the_rectangle_at_that_angle() -> void:
	var e := _field()
	var c := _wizard(e, Vector2i(3, 6))
	TestCombat.start_with(e, c)
	var aim := Vector2(11, -4.5)
	var pts := e.spells.targeting.area_outline(c, Compendium.shared().spell_data("lightning_bolt"), Vector2.INF, aim)["points"] as PackedVector2Array
	assert_eq(pts.size(), 4)
	var d := aim.normalized()
	var start := CombatGrid.line_origin(c.cell, 1, aim)
	assert_true(((pts[0] + pts[3]) / 2.0).distance_to(start) < 0.001, "it starts where the aim leaves the caster's square")
	assert_true(((pts[1] + pts[2]) / 2.0).distance_to(start + d * 20.0) < 0.001, "and runs 100 ft that way")
	assert_true(absf(pts[0].distance_to(pts[3]) - 1.0) < 0.001, "5 ft wide")


func test_which_actions_aim_as_a_line() -> void:
	var e := _field()
	var c := _wizard(e, Vector2i(3, 6))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	assert_eq(cat.line_ft(c, cat.find(c, "spell:lightning_bolt")), 100)
	assert_eq(cat.line_ft(c, cat.find(c, "spell:gust_of_wind")), 60)
	assert_eq(cat.line_ft(c, cat.find(c, "spell:burning_hands")), 0, "a cone isn't a line")
	assert_eq(cat.line_ft(c, cat.find(c, "spell:thunderwave")), 0, "nor is a cube")
	assert_eq(cat.line_ft(c, {"id": "feat:breath_weapon:line"}), 30)
	assert_eq(cat.line_ft(c, {"id": "feat:breath_weapon:cone"}), 0)
	# Gust of Wind's Bonus Action turn aims the spell's own line.
	assert_true(e.spells.cast(c, "gust_of_wind", 2, [], Vector2.INF, Vector2.RIGHT).ok)
	var turn := {}
	for a in cat.actions_for(c):
		if str(a.get("kind", "")) == "sustain" and str(a.get("spell_id", "")) == "gust_of_wind":
			turn = a
	assert_false(turn.is_empty(), "Gust of Wind's turn on the hotbar")
	assert_eq(cat.line_ft(c, turn), 60)


func test_a_monsters_line_and_a_breath_weapon_go_straight_at_their_target() -> void:
	var e := _field()
	var c := _wizard(e, Vector2i(3, 6))
	var z := _slant(e)
	TestCombat.start_with(e, c)
	var act := {"area": {"shape": "line", "size": 60, "width": 5}, "targets": {}}
	var caught := e.monster_actions.save_victims(c, act, z[1])
	assert_true(z[0] in caught and z[1] in caught, "the zombies on the way to the one aimed at")
	assert_false(z[3] in caught or z[4] in caught)


func test_a_dragonborns_line_breath_goes_where_it_is_pointed() -> void:
	var e := _field()
	var d := e.add(TestChars.custom("fighter", "dragonborn", 5, {"draconic_ancestry": ["blue_dragon"]}), &"party", Vector2i(3, 6))
	var z := _slant(e)
	TestCombat.start_with(e, d)
	var hp_before := z.map(func(o: Combatant) -> int: return o.creature.hp)
	var r := e.feature_actions.perform(d, "breath_weapon:line", null, Vector2(14.5, 2.0))
	assert_true(r.ok, r.reason)
	assert_true(z[0].creature.hp < int(hp_before[0]) or z[0].is_down(), "the zombie 30 ft up the slant")
	assert_eq(z[3].creature.hp, int(hp_before[3]), "not the one along the row")
