extends TestCase
## The Skirmish screen and its fight (N1) in the real scenes: heroes added from the pregens, a quick class and the
## Lab's levels (with one taken by hand on the game's level-up screen and one taken back), an item given, foes and a
## map chosen, the setup saved and loaded, then the fight played in the combat arena on that map, ending on the
## results with its tally.

const SCREEN := preload("res://scenes/skirmish.tscn")
const ARENA := preload("res://scenes/combat/arena.tscn")

var screen: SkirmishScreen
var arena: CombatArena


func before_each() -> void:
	# Achievements of this test's own: other tests in the same process may have earned them already.
	Achievements.path = "user://test_achievements_skirmish_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(Achievements.path)
	SkirmishLibrary.dir = "user://test_skirmish_screen_%d/" % OS.get_process_id()
	SkirmishScreen.current = null
	SkirmishScreen.kept_tab = "Party"


func after_each() -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	if arena != null:
		arena.queue_free()
		arena = null
	for f in SkirmishLibrary.list():
		SkirmishLibrary.delete(str(f["file"]))
	SkirmishLibrary.dir = "user://skirmish/"
	DirAccess.remove_absolute(Achievements.path)
	Achievements.path = ""
	SkirmishScreen.current = null
	CombatArena.skirmish = null
	get_tree().paused = false
	ModeController.force(ModeController.Mode.EXPLORATION)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open() -> void:
	screen = SCREEN.instantiate() as SkirmishScreen
	add_child(screen)
	await frames(3)


func test_a_party_is_built_in_the_lab() -> void:
	await _open()
	assert_eq(screen.hero_index, -1, "an empty party opens on Add a hero")
	SkirmishScreen.add_level = 12
	screen.call("_add_pregen", "liriel_dawnsong")
	assert_eq(screen.setup.party.size(), 1)
	assert_eq(screen.lab_hero.character_level(), 12)
	assert_eq(screen.hero_index, 0)
	screen.call("_add_quick", "rogue")
	assert_eq(screen.setup.hero(1).name, "Lab Rogue")
	assert_eq(screen.setup.hero(1).character_level(), 12)
	# The Lab's levels: up two, back one, and a pregen rebuilt lower than it came in.
	screen.call("_set_level", 14)
	assert_eq(screen.lab_hero.character_level(), 14)
	assert_eq(screen.setup.hero(1).character_level(), 14, "written back to the setup")
	screen.call("_set_level", 13)
	assert_eq(screen.lab_hero.character_level(), 13)
	screen.call("_select_hero", 0)
	screen.call("_set_level", 4)
	assert_eq(screen.lab_hero.character_level(), 4)
	assert_eq(screen.lab_hero.class_level_of("cleric"), 4)
	# An item from the Lab's list.
	screen.call("_give", "cloak_of_protection")
	assert_true("cloak_of_protection" in screen.setup.hero(0).attuned)
	await frames(2)
	assert_true(screen.get_node_or_null("SkirmishResults") == null)


func test_a_level_is_taken_by_hand_on_the_level_up_screen() -> void:
	await _open()
	SkirmishScreen.add_level = 11
	screen.call("_add_pregen", "godrick_pendlebrook")
	screen.call("_level_by_hand")
	await frames(2)
	var up := screen.screen as LevelUpScreen
	assert_true(up != null, "the game's level-up screen opened")
	assert_false(screen.layer.visible, "over the Skirmish frame")
	HeroLab.fill_choices(up.ctl.pending_choices, up.ctl.choose, up.ctl.preview)
	up.call("_confirm")
	await frames(2)
	assert_true(screen.screen == null, "it closed itself at the Lab's level")
	assert_eq(screen.setup.hero(0).character_level(), 12, "past the campaign's cap")
	# Escape on the next one leaves the hero as they were.
	screen.call("_level_by_hand")
	await frames(2)
	screen.close_screen()
	assert_eq(screen.setup.hero(0).character_level(), 12)
	assert_eq((screen.undo[0] as Array).size(), 1, "only the confirmed level can be taken back")
	# The sheet and inventory open for the Lab's hero too.
	screen.open_screen("sheet", 0)
	await frames(2)
	assert_true(screen.screen is CharacterSheetScreen)
	screen.open_screen("inventory", 0)
	await frames(2)
	assert_true(screen.screen is InventoryScreen)
	screen.close_screen()


func test_tabs_draw_and_setups_save_and_load() -> void:
	await _open()
	SkirmishScreen.add_level = 3
	screen.call("_add_pregen", "thistle")
	for t in SkirmishScreen.TABS:
		screen.tab = t
		screen.call("_redraw")
		await frames(2)
	screen.tab = "Foes"
	screen.call("_redraw")
	screen.call("_add_foe", "wolf")
	screen.call("_add_foe", "wolf")
	assert_eq(screen.setup.foe_count("wolf"), 2)
	screen.tab = "Field"
	screen.setup.map_id = "location:tser_pool"
	screen.call("_redraw")
	await frames(2)
	assert_true(screen.sketch != null and screen.sketch.grid != null, "the map's sketch")
	assert_eq(screen.sketch.marks.size(), 3)
	screen.setup.title = "Tser Pool wolves"
	screen.call("_save")
	SkirmishScreen.current = null
	screen.setup = SkirmishSetup.new()
	screen.call("_load", "tser_pool_wolves")
	assert_eq(screen.setup.map_id, "location:tser_pool")
	assert_eq(screen.setup.party.size(), 1)
	assert_eq(screen.setup.foes.size(), 2)
	assert_true(SkirmishScreen.current == screen.setup)
	var fight := screen.find_child("Fight", true, false) as Button
	assert_true(fight != null and not fight.disabled)
	# The achievements open from above Back to the title, and Esc closes them before it leaves the screen.
	(screen.find_child("Achievements", true, false) as Button).pressed.emit()
	await frames(2)
	assert_true(screen.achievements != null, "the achievements panel")
	screen.achievements.close()
	await frames(1)
	assert_true(screen.achievements == null)


func test_a_skirmish_is_fought_on_its_map_and_ends_on_the_results() -> void:
	var s := SkirmishSetup.new()
	s.title = "Inn brawl"
	s.map_id = "location:vallaki_blue_water_inn"
	s.add_hero(HeroLab.pregen("wren_featherfoot", 8), "wren_featherfoot")
	s.add_hero(HeroLab.quick_hero("wizard", 8), "")
	s.add_foe("ghoul")
	s.add_foe("ghoul")
	CombatArena.skirmish = s
	arena = ARENA.instantiate() as CombatArena
	add_child(arena)
	await frames(5)
	assert_true(CombatArena.skirmish == null, "the arena took the setup")
	assert_true(arena.played == s)
	assert_eq(arena.e.combatants.size(), 4)
	assert_eq(arena.tokens.size(), 4)
	assert_true(arena.atmosphere != null, "the inn's own light and mood")
	assert_eq(arena.board.place, "vallaki_blue_water_inn")
	assert_false(arena.view.restart_allowed, "the results offer the next step instead")
	# The foes fall; the view ends the fight, and the player goes on from the banner.
	for c in arena.e.combatants:
		if c.side == &"enemy":
			arena.e.deal_damage(arena.e.combatants[0], c, [{"amount": 500, "type": "slashing"}], false, "test")
	arena.e.call("_check_over")
	await frames(10)
	assert_eq(arena.e.outcome, "victory")
	arena.view.finished.emit(arena.e.outcome)
	await frames(2)
	assert_true(arena.results != null, "the results")
	var row := FightTally.side_rows(arena.e, arena.results.tally, "party")[0]
	assert_eq(int(row["kills"]), 2, "both ghouls are Wren's")
	assert_true(arena.results.find_child("FightAgain", true, false) != null)
	var earned := arena.results.find_child("Earned", true, false) as Label
	assert_true(earned != null and earned.text.contains("Proving Grounds") and earned.text.contains("Overwhelming Force"),
		"achievements the fight earned: %s" % (earned.text if earned != null else "none"))
	assert_true(Achievements.has("skirmish_win"), "kept")


func test_the_encounter_editor_works_on_the_sketch() -> void:
	await _open()
	SkirmishScreen.add_level = 4
	screen.call("_add_pregen", "kip_smudgewick")
	screen.tab = "Field"
	screen.field_list = "Stat blocks"
	screen.call("_redraw")
	await frames(2)
	assert_true(screen.sketch.editable)
	screen.brush = {"kind": "new", "monster": "ghoul"}
	screen.call("_show_sketch")
	assert_true(screen.sketch.shade.has(Vector2i(10, 6)), "open ground is shaded for the brush")
	assert_false(screen.sketch.shade.has(Vector2i(0, 0)), "walls aren't")
	screen.call("_sketch_clicked", Vector2i(10, 6), MOUSE_BUTTON_LEFT)
	screen.call("_sketch_clicked", Vector2i(12, 6), MOUSE_BUTTON_LEFT)
	screen.call("_sketch_clicked", Vector2i(0, 0), MOUSE_BUTTON_LEFT)
	assert_eq(screen.setup.foes.size(), 2, "two ghouls; the wall refused")
	assert_true(screen._note.text.contains("A wall"), screen._note.text)
	# Pick the second ghoul up and move it; right-click takes the first away.
	screen.brush = {}
	screen.call("_sketch_clicked", Vector2i(12, 6), MOUSE_BUTTON_LEFT)
	assert_eq(screen.brush, {"kind": "foe", "index": 1})
	screen.call("_sketch_clicked", Vector2i(14, 8), MOUSE_BUTTON_LEFT)
	assert_eq(SkirmishSetup._cell_of(screen.setup.foes[1]), Vector2i(14, 8))
	screen.call("_sketch_clicked", Vector2i(10, 6), MOUSE_BUTTON_RIGHT)
	assert_eq(screen.setup.foes.size(), 1)
	assert_eq(SkirmishSetup._cell_of(screen.setup.foes[0]), Vector2i(14, 8))
	# The hero placed by hand, saved, and the fight taken for a new party.
	screen.brush = {"kind": "hero", "index": 0}
	screen.call("_sketch_clicked", Vector2i(3, 12), MOUSE_BUTTON_LEFT)
	assert_true(screen.setup.pinned("hero", 0))
	screen.setup.title = "Ghoul in the shrine"
	screen.call("_save")
	screen.setup.party.clear()
	screen.setup.foes.clear()
	screen.call("_add_quick", "fighter")
	screen.call("_load", "ghoul_in_the_shrine", true)
	assert_eq(screen.setup.party.size(), 1)
	assert_eq(screen.setup.hero(0).name, "Lab Fighter")
	assert_eq(screen.setup.foes.size(), 1)
	assert_eq((screen.setup.placements(screen.setup.grid())["party"] as Array[Vector2i])[0], Vector2i(3, 12))
