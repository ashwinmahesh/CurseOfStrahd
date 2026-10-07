extends TestCase
## Skirmish and the Character Lab (N1): heroes at any level from 1 to 20 with the picks filled in, items given and
## put on, setups that save and load, the 2024 encounter budgets, everyone placed on open ground on every map, the
## fight built with the place's light, and the per-fight tally read from the combat log.

## A folder of this run's own, so test runs side by side never touch each other's setups.
var test_dir := "user://test_skirmish_%d/" % OS.get_process_id()


func after_each() -> void:
	for f in SkirmishLibrary.list():
		SkirmishLibrary.delete(str(f["file"]))
	SkirmishLibrary.dir = "user://skirmish/"


func test_pregens_level_past_their_plans() -> void:
	var errors: Array[String] = []
	var ch := HeroLab.pregen("godrick_pendlebrook", 14, errors)
	assert_true(ch != null, str(errors))
	assert_true(errors.is_empty(), str(errors))
	assert_eq(ch.character_level(), 14)
	assert_eq(ch.class_level_of("paladin"), 14)
	assert_eq(ch.hp, ch.max_hp(), "rested")
	assert_true(ch.pending_choices().is_empty(), "every pick filled: %s" % str(ch.pending_choices().map(func(c: Choice) -> String: return c.key)))


func test_every_class_reaches_level_20() -> void:
	for c in Compendium.shared().all_playable("classes"):
		var ch := HeroLab.quick_hero(str(c["id"]), 20)
		assert_true(ch != null, "%s builds" % c["id"])
		if ch == null:
			continue
		assert_eq(ch.character_level(), 20, str(c["id"]))
		assert_true(ch.pending_choices().is_empty(), "%s: %s" % [c["id"], str(ch.pending_choices().map(func(x: Choice) -> String: return x.key))])
		assert_eq(ch.subclasses.size(), 1, "%s took a subclass" % c["id"])


func test_quick_heroes_prefer_the_core_books_and_raise_their_best_score() -> void:
	var ch := HeroLab.quick_hero("fighter", 3)
	var sub := str(ch.subclasses.get("fighter", ""))
	var book := str((Compendium.shared().subclass_data(sub).get("source", {}) as Dictionary).get("book", ""))
	assert_true(book in HeroLab.PREFERRED_BOOKS, "a core subclass, not %s (%s)" % [sub, book])
	var before := ch.ability_score(&"str")
	assert_true(before >= ch.ability_score(&"dex") and before >= ch.ability_score(&"con"), "Strength first for this Fighter")
	HeroLab.level_once(ch, "fighter")
	assert_eq(ch.ability_score(&"str"), mini(20, before + 2), "level 4's Ability Score Improvement went to Strength")


func test_items_are_given_and_put_on() -> void:
	var ch := HeroLab.quick_hero("fighter", 5)
	var note := HeroLab.give(ch, "plate_armor")
	assert_true(note.contains("worn"), note)
	assert_eq(str(ch.equipped("armor").get("id", "")), "plate_armor")
	note = HeroLab.give(ch, "flame_tongue")
	var held := ch.equipped("main_hand")
	assert_true(str(held.get("id", "")).begins_with("flame_tongue" + MagicItems.SEP), "the template went on a weapon: %s" % held.get("id", ""))
	assert_true(note.contains("attuned"), note)
	note = HeroLab.give(ch, "cloak_of_protection")
	assert_true(note.contains("worn") and note.contains("attuned"), note)
	assert_eq(ch.attuned.size(), 2)
	assert_true(HeroLab.all_items().size() > 600, "the mundane gear and the magic items")


func test_the_lab_level_cap_reaches_20() -> void:
	var st := SkirmishState.new()
	st.lab_target = 17
	var ch := HeroLab.pregen("thistle", 16)
	st.party.append(ch)
	assert_true(st.can_level_up(ch), "past the campaign's cap of %d" % StoryState.LEVEL_CAP)
	st.lab_target = 16
	assert_false(st.can_level_up(ch))


func test_setups_save_and_load() -> void:
	SkirmishLibrary.dir = test_dir
	var s := SkirmishSetup.new()
	s.title = "Wolves at Night"
	s.map_id = "location:svalich_crossroads"
	s.time = "night"
	var ch := HeroLab.pregen("wren_featherfoot", 6)
	HeroLab.give(ch, "cloak_of_protection")
	s.add_hero(ch, "wren_featherfoot")
	s.add_foe("wolf")
	s.add_foe("dire_wolf")
	s.foes[0]["cell"] = [3, 4]
	assert_eq(SkirmishLibrary.save(s), "wolves_at_night")
	var list := SkirmishLibrary.list()
	assert_eq(list.size(), 1)
	assert_eq(str(list[0]["title"]), "Wolves at Night")
	var back := SkirmishLibrary.load_setup("wolves_at_night")
	assert_eq(back.map_id, s.map_id)
	assert_eq(back.time, "night")
	assert_eq(back.pregen_of(0), "wren_featherfoot")
	assert_eq(back.foes.size(), 2)
	assert_eq(SkirmishSetup._cell_of(back.foes[0]), Vector2i(3, 4))
	var hero := back.hero(0)
	assert_eq(hero.character_level(), 6)
	assert_true("cloak_of_protection" in hero.attuned, "items and attunement come back")
	assert_eq(hero.ac_value(), ch.ac_value())
	SkirmishLibrary.delete("wolves_at_night")
	assert_true(SkirmishLibrary.list().is_empty())


func test_difficulty_follows_the_2024_budgets() -> void:
	var s := SkirmishSetup.new()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "wren_featherfoot", "ratatoille"]:
		s.add_hero(HeroLab.pregen(id, 3), id)
	var arena := Compendium.shared().get_entry("encounters", "arena_wolves_and_zombies")
	for m: Variant in arena["enemies"]:
		s.add_foe(str((m as Dictionary)["monster"]))
	assert_eq(s.budgets(), [600, 900, 1600] as Array[int])
	assert_eq(s.difficulty(), str(arena["difficulty"]), "the arena's own rating")
	s.foes.clear()
	s.add_foe("strahd_von_zarovich")
	assert_eq(s.difficulty(), "beyond high")


func test_everyone_finds_open_ground_on_every_map() -> void:
	var s := SkirmishSetup.new()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "wren_featherfoot", "ratatoille"]:
		s.add_hero(HeroLab.pregen(id, 1), id)
	for m: String in ["wolf", "wolf", "zombie", "dire_wolf", "ogre"]:
		s.add_foe(m)
	for entry in SkirmishSetup.maps():
		if str(entry["region"]) == "Test":
			continue   # a fixture place another test left in the shared Compendium, not one of the game's maps
		s.map_id = str(entry["id"])
		var g := s.grid()
		var errors: Array[String] = []
		var cells := s.placements(g, errors)
		assert_true(errors.is_empty(), "%s: %s" % [entry["id"], errors])
		var taken := s.furniture()
		var all: Array = []
		for c: Vector2i in cells["party"]:
			all.append([c, 1])
		for i in s.foes.size():
			all.append([(cells["foes"] as Array[Vector2i])[i], s._foe_size(i)])
		for pair: Array in all:
			var at := pair[0] as Vector2i
			assert_true(SkirmishSetup.fits(g, at, int(pair[1]), taken), "%s: %s at %s stands clear" % [entry["id"], pair, at])
			for c in CombatGrid.footprint(at, int(pair[1])):
				taken[c] = true


func test_placed_squares_are_kept_and_the_rest_filled_in() -> void:
	var s := SkirmishSetup.new()
	s.add_hero(HeroLab.pregen("thistle", 2), "thistle")
	s.add_hero(HeroLab.pregen("kip_smudgewick", 2), "kip_smudgewick")
	s.add_foe("wolf")
	s.add_foe("wolf")
	s.party[1]["cell"] = [4, 8]
	s.foes[0]["cell"] = [19, 3]
	s.foes[1]["cell"] = [0, 0]   # a wall: filled in instead
	var cells := s.placements(s.grid())
	assert_eq((cells["party"] as Array[Vector2i])[1], Vector2i(4, 8))
	assert_eq((cells["foes"] as Array[Vector2i])[0], Vector2i(19, 3))
	assert_ne((cells["foes"] as Array[Vector2i])[1], Vector2i(0, 0))
	assert_true((cells["foes"] as Array[Vector2i])[1].distance_to(Vector2i(19, 3)) < 5.0, "beside the placed wolf")
	s.pin(cells)
	assert_eq(SkirmishSetup._cell_of(s.party[0]), (cells["party"] as Array[Vector2i])[0])
	s.unpin()
	assert_false(s.party[1].has("cell"))


func test_the_fight_is_built_with_the_place_and_its_light() -> void:
	var s := SkirmishSetup.new()
	s.map_id = "location:vallaki_blue_water_inn"
	s.add_hero(HeroLab.pregen("ratatoille", 9), "ratatoille")
	s.add_hero(HeroLab.quick_hero("barbarian", 9), "")
	s.add_foe("wolf")
	s.add_foe("wolf")
	s.add_foe("ogre")
	s.surprise = "enemies"
	var errors: Array[String] = []
	var e := s.build(DiceRoller.new(4), errors)
	assert_true(e != null, str(errors))
	assert_eq(e.combatants.size(), 5)
	var names := e.combatants.map(func(c: Combatant) -> String: return c.name())
	assert_true("Wolf 1" in names and "Wolf 2" in names and "Ogre" in names, str(names))
	assert_eq(e.ambient_light, "dim", "the inn's own light")
	assert_false(e.outdoors)
	assert_eq(s.surprised_ids(e).size(), 3)
	s.map_id = "location:svalich_crossroads"
	s.unpin()
	s.time = "night"
	e = s.build(DiceRoller.new(4))
	assert_true(e.outdoors)
	assert_eq(e.ambient_light, "dark")
	assert_true(e.spells.zones.objects.any(func(o: FieldObject) -> bool: return o.caster_id == e.combatants[0].id), "the first hero carries the lantern")
	s.time = "day"
	e = s.build(DiceRoller.new(4))
	assert_eq(e.ambient_light, "bright")


func test_fights_play_to_the_end() -> void:
	var s := SkirmishSetup.new()
	s.map_id = "location:village_of_barovia"
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "wren_featherfoot", "ratatoille"]:
		s.add_hero(HeroLab.pregen(id, 5), id)
	for m: String in ["ghoul", "ghoul", "ghoul", "zombie", "zombie"]:
		s.add_foe(m)
	var e := s.build(DiceRoller.new(11))
	var res := PartyAutopilot.new(e).run(40)
	assert_ne(str(res["outcome"]), "timeout")


# --- The tally ------------------------------------------------------------------------------------

func test_roll_lines_are_read() -> void:
	var t := D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 20, 5, 15)
	t.label = "Wren Featherfoot → Wolf 2 (Spear)"
	var r := FightTally.read_roll(t.describe())
	assert_eq(str(r["roller"]), "Wren Featherfoot")
	assert_eq(int(r["natural"]), 20)
	assert_eq(str(r["outcome"]), "critical hit")
	r = FightTally.read_roll("Dexterity save vs Sacred Flame (Zombie 4): d20 1 - 2 = -1 vs DC 13, failure")
	assert_eq(str(r["roller"]), "Zombie 4")
	assert_eq(int(r["natural"]), 1)
	assert_eq(str(r["outcome"]), "failure")
	r = FightTally.read_roll("Wolf 1 → Wren Featherfoot (Wolf 1: Bite): d20 adv [Pack Tactics] (13, 1) + 4 = 17 vs AC 15, hit")
	assert_eq(str(r["roller"]), "Wolf 1")
	assert_eq(int(r["natural"]), 13, "Advantage keeps the higher")
	r = FightTally.read_roll("Liriel Dawnsong → Wolf 2 (Spiritual Weapon): d20 dis [Prone] (1, 9) + 5 = 6 vs AC 12, miss")
	assert_eq(int(r["natural"]), 1, "Disadvantage keeps the lower")
	assert_eq(str(r["outcome"]), "miss")
	assert_true(FightTally.read_roll("Spear 1d8: [8] = 8").is_empty())
	var taken := FightTally.read_taken(["Spear 1d8: [8] = 8", "Zombie 4 takes 11 Piercing damage, and dies"])
	assert_eq(str(taken["name"]), "Zombie 4")
	assert_eq(int(taken["amount"]), 11)


func test_a_whole_fight_is_tallied() -> void:
	for seed_value: int in [3, 5]:
		var e := EncounterSetup.load_id("arena_wolves_and_zombies", DiceRoller.new(seed_value))
		var res := PartyAutopilot.new(e).run(30)
		var t := FightTally.tally(e)
		var kills := 0
		var dealt := 0
		var taken_by_foes := 0
		for row in FightTally.side_rows(e, t, "party"):
			kills += int(row["kills"])
			dealt += int(row["damage_dealt"])
			assert_true(int(row["hits"]) + int(row["misses"]) > 0, "%s attacked" % row["name"])
		var dead := 0
		for row in FightTally.side_rows(e, t, "enemy"):
			dead += int(row["died"])
			taken_by_foes += int(row["damage_taken"])
		if str(res["outcome"]) == "victory":
			assert_eq(dead, e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy").size())
		assert_eq(kills, dead, "every dead foe is somebody's kill (seed %d)" % seed_value)
		assert_true(dealt > 0 and taken_by_foes > 0, "damage dealt and taken (%d, %d)" % [dealt, taken_by_foes])


# --- The encounter editor (N9) --------------------------------------------------------------------

func test_the_editor_places_moves_and_refuses() -> void:
	var s := SkirmishSetup.new()   # the arena: walls round the edge, '=' and '~' inside
	s.add_hero(HeroLab.pregen("thistle", 3), "thistle")
	var g := s.grid()
	var why: Array[String] = []
	assert_true(s.add_foe_at(g, "ogre", Vector2i(18, 10), why), str(why))
	assert_eq(s.foes.size(), 1)
	assert_true(s.pinned("foe", 0))
	var cells := s.placements(g)
	assert_eq(s.piece_at(cells, Vector2i(19, 11)), {"kind": "foe", "index": 0}, "the Large ogre covers four squares")
	assert_eq(s.place_problem(g, "foe", -1, Vector2i(0, 0), "wolf"), "A wall")
	assert_eq(s.place_problem(g, "foe", -1, Vector2i(5, 9), "wolf"), "Low cover: nobody stands on it")
	assert_eq(s.place_problem(g, "foe", -1, Vector2i(19, 11), "wolf"), "Someone stands there")
	assert_eq(s.place_problem(g, "foe", -1, Vector2i(21, 7), "ogre"), "A wall", "the ogre's far squares hit the stones")
	assert_false(s.add_foe_at(g, "wolf", Vector2i(18, 11), why))
	assert_eq(why.back(), "Someone stands there")
	# Moving: the ogre to open ground; the hero placed, then back to filled in.
	assert_true(s.place(g, "foe", 0, Vector2i(12, 5)))
	assert_eq(SkirmishSetup._cell_of(s.foes[0]), Vector2i(12, 5))
	assert_true(s.place(g, "hero", 0, Vector2i(2, 12)))
	assert_eq((s.placements(g)["party"] as Array[Vector2i])[0], Vector2i(2, 12))
	s.unplace("hero", 0)
	assert_false(s.pinned("hero", 0))
	# A filled-in hero standing where a foe is put moves aside.
	var auto := (s.placements(g)["party"] as Array[Vector2i])[0]
	assert_true(s.add_foe_at(g, "wolf", auto, why), str(why))
	var after := s.placements(g)
	assert_ne((after["party"] as Array[Vector2i])[0], auto)
	assert_eq((after["foes"] as Array[Vector2i])[1], auto)


func test_a_saved_fight_is_taken_for_another_party() -> void:
	var fight := SkirmishSetup.new()
	fight.map_id = "location:tser_pool"
	fight.time = "night"
	fight.surprise = "party"
	var g := fight.grid()
	fight.add_hero(HeroLab.pregen("thistle", 2), "thistle")
	var spot := (fight.placements(g)["party"] as Array[Vector2i])[0]
	fight.place(g, "hero", 0, spot)
	var foe_spot := (fight.placements(g)["party"] as Array[Vector2i])[0] + Vector2i(6, 0)
	for d: Vector2i in [Vector2i(6, 0), Vector2i(-6, 0), Vector2i(0, 6), Vector2i(0, -6), Vector2i(4, 4)]:
		if fight.place_problem(g, "foe", -1, spot + d, "werewolf") == "":
			foe_spot = spot + d
			break
	assert_true(fight.add_foe_at(g, "werewolf", foe_spot))
	var mine := SkirmishSetup.new()
	mine.add_hero(HeroLab.quick_hero("monk", 7), "")
	mine.add_hero(HeroLab.quick_hero("cleric", 7), "")
	mine.add_foe("rat")
	mine.take_fight(fight)
	assert_eq(mine.map_id, "location:tser_pool")
	assert_eq(mine.time, "night")
	assert_eq(mine.surprise, "party")
	assert_eq(mine.party.size(), 2, "the party stays")
	assert_eq(mine.hero(0).name, "Lab Monk")
	assert_eq(mine.foes.size(), 1)
	assert_eq(str(mine.foes[0]["monster"]), "werewolf")
	assert_eq(SkirmishSetup._cell_of(mine.foes[0]), foe_spot)
	assert_eq(SkirmishSetup._cell_of(mine.party[0]), spot, "the first hero starts where the saved one did")
	assert_false(mine.pinned("hero", 1))
