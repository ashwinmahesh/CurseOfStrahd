extends TestCase
## Boss presentation (G3, ui/combat/boss_bar.gd, narrative/combat/bosses.json): every boss listed is a real monster,
## and every name listed is one a fight in the game gives it; who counts as a boss (listed, named, or with legendary
## actions; only foes), the greatest first and at most three; the bar's quarter steps, never exact Hit Points; the
## line under it; and a sting that has its sounds.


func _named(id: String, as_name: String, e: Encounter, cell: Vector2i) -> Combatant:
	var c := TestCombat.foe(e, id, cell)
	c.creature.name = as_name
	return c


func test_every_boss_listed_is_a_real_monster_named_in_a_fight() -> void:
	var fights := {}   # monster id -> the names fights give it
	for loc: Variant in (Compendium.shared().tables["locations"] as Dictionary).values():
		for spec: Variant in (loc as Dictionary).get("encounters", []) as Array:
			for m: Variant in (spec as Dictionary).get("monsters", []) as Array:
				var md := m as Dictionary
				if not fights.has(str(md["monster"])):
					fights[str(md["monster"])] = []
				(fights[str(md["monster"])] as Array).append(str(md.get("name", "")))
	var bosses := BossBar.data()["bosses"] as Dictionary
	for id: String in bosses:
		assert_false(Compendium.shared().monster_data(id).is_empty(), "%s is a monster" % id)
		assert_true(fights.has(id), "a fight in the game has %s" % id)
		var spec := bosses[id] as Dictionary
		assert_true(spec.has("title") != spec.has("names"), "%s has a title or names, not both" % id)
		for who: String in spec.get("names", {}) as Dictionary:
			assert_true(who in (fights.get(id, []) as Array), "a fight calls a %s \"%s\"" % [id, who])


func test_who_counts_as_a_boss() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(0, 0))
	var hag := TestCombat.foe(e, "night_hag", Vector2i(2, 2))
	var mother := _named("night_hag", "Morgantha", e, Vector2i(3, 2))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(4, 2))
	var izek := TestCombat.foe(e, "izek_strazni", Vector2i(5, 2))
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(6, 2))
	var vampire := TestCombat.foe(e, "vampire", Vector2i(7, 2))
	assert_eq(BossBar.entry(strahd).get("title"), "Lord of Barovia")
	assert_eq(BossBar.entry(mother).get("title"), "Mother of Old Bonegrinder", "a shared stat block counts by its name")
	assert_true(BossBar.entry(hag).is_empty(), "a night hag with no name isn't")
	assert_eq(BossBar.entry(vampire).get("title"), "", "a foe with legendary actions is a boss without being listed")
	assert_true(BossBar.entry(wolf).is_empty(), "a wolf isn't")
	assert_true(BossBar.entry(hero).is_empty(), "nor is anyone on the party's side")
	var top := BossBar.bosses_in(e)
	assert_eq(top.slice(0, 2), [strahd, vampire] as Array[Combatant], "legendary first")
	assert_eq(top.size(), 3, "at most three")
	assert_true(top[2] in [izek, mother], "then by Challenge Rating")
	strahd.creature.dead = true
	assert_false(strahd in BossBar.bosses_in(e), "only bosses still standing")


func test_the_bar_drops_a_quarter_at_a_time() -> void:
	var e := TestCombat.open_field()
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(2, 2))
	var cr := strahd.creature
	var most := cr.max_hp()
	var steps := []
	for hp: int in [most, int(most * 0.75) + 1, int(most * 0.75), int(most * 0.5) + 1, int(most * 0.5), 1, 0]:
		cr.hp = hp
		steps.append(BossBar.step_of(strahd))
	assert_eq(steps, [4, 4, 3, 3, 2, 1, 0], "whole quarters, never the exact Hit Points")


func test_the_line_under_the_bar() -> void:
	var e := TestCombat.open_field()
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(2, 2))
	var izek := TestCombat.foe(e, "izek_strazni", Vector2i(4, 2))
	var bar := BossBar.new()
	add_child(bar)
	bar.build(e, BossBar.bosses_in(e))
	assert_eq(bar._words(strahd), "Lord of Barovia  ·  Legendary Resistance ◆◆◆")
	strahd.set_meta("legendary_resistance_used", 1)
	assert_eq(bar._words(strahd), "Lord of Barovia  ·  Legendary Resistance ◆◆◇", "one used")
	assert_eq(bar._words(izek), "The Baron's Enforcer")
	e.legendary.departed[strahd.id] = "mist"
	assert_eq(bar._words(strahd), "Fled as mist")
	bar.refresh()
	assert_true(((bar._plates[strahd.id] as Dictionary)["plate"] as Control).modulate.a < 1.0, "a boss that left dims")
	izek.creature.dead = true
	izek.creature.hp = 0
	bar.refresh()
	assert_eq(bar._words(izek), "The Baron's Enforcer · Defeated")
	assert_true(((bar._plates[izek.id] as Dictionary)["plate"] as Control).modulate.a < 1.0, "a fallen boss's plate dims")
	bar.free()


func test_the_sting_has_its_sounds() -> void:
	for id in BossBar.STING:
		assert_false(Audio.files("sfx", id).is_empty(), "the sting's %s has a recording" % id)
	for spec: Variant in (BossBar.data()["bosses"] as Dictionary).values():
		for id: Variant in (spec as Dictionary).get("sting", []) as Array:
			assert_false(Audio.files("sfx", str(id)).is_empty(), "a boss's sting %s has a recording" % id)
