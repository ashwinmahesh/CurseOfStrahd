extends TestCase
## The Phase 3 exit (plan §10): a party built in character creation walks in from the mists, survives Death House,
## meets Ismark and Ireena and makes its first choices, saving and loading along the way. StoryBot plays it through
## the real game scene; fights are played by the test-only autopilot. Slow (a few minutes): `make test ONLY=exit`.

var root: Node
var bot: StoryBot


func before_each() -> void:
	Engine.time_scale = 8.0
	SaveSystem.delete_slot("exit_test")
	# EXIT_SEED=n tries other dice (the build log's survival count); CI uses 3.
	Dice.reseed(int(OS.get_environment("EXIT_SEED")) if OS.get_environment("EXIT_SEED").is_valid_int() else 3)


func after_each() -> void:
	Engine.time_scale = 1.0
	if root != null:
		root.queue_free()
		root = null
	SaveSystem.delete_slot("exit_test")


## Four characters built from scratch in the creation screen, as the title screen's "Build all four" does.
func _create_party() -> Array[Character]:
	var cs := CreationScreen.new()
	add_child(cs)
	var empty: Array[Dictionary] = []
	cs.open_with(empty)
	var picks := [["fighter", "soldier", "human", "Brannoc Vell"], ["rogue", "criminal", "halfling", "Pip Marrow"],
		["cleric", "acolyte", "dwarf", "Odessa Flint"], ["wizard", "sage", "elf", "Ithren Vael"]]
	for i in 4:
		cs.slot = i
		var b := cs.b()
		var p := picks[i] as Array
		b.set_class(str(p[0]))
		b.set_background(str(p[1]))
		b.set_species(str(p[2]))
		var missing := TestChars.auto_pick(func() -> Array[Choice]: return b.pending_choices(),
			func(key: String, chosen: Array) -> void: b.choose(key, chosen))
		assert_true(missing.is_empty(), "%s: %s" % [p[0], missing])
		b.set_name(str(p[3]))
		assert_true(b.errors().is_empty(), "%s: %s" % [p[3], b.errors()])
		cs.confirmed[i] = true
	var party: Array[Character] = []
	cs.finished.connect(func(made: Array[Character]) -> void: party.assign(made))
	cs.call("_finish")
	cs.queue_free()
	return party


func _start_game() -> void:
	if root != null:
		root.queue_free()
		await get_tree().process_frame
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	if bot == null:
		bot = StoryBot.new(self, root)
	bot.root = root


## Asserts, and on failure prints the bot's trace so the run stops at the first broken step.
func _ok(cond: bool, msg: String) -> bool:
	assert_true(cond, msg)
	if not cond:
		print("  --- story bot trace ---")
		for line: String in bot.trace.slice(maxi(0, bot.trace.size() - 120)):
			print("    ", line)
	return cond


## Saves, throws the game away, loads and rebuilds the scene: the run continues from the loaded state.
func _save_and_reload(label: String) -> void:
	var st := GameState.story
	var before := {"location": st.location, "party": st.party.map(func(c: Character) -> String: return "%s %d/%d L%d" % [c.name, c.hp, c.max_hp(), c.character_level()]),
		"flags": st.flags.size(), "gold": st.gold, "milestones": st.milestones}
	assert_eq(SaveSystem.save("exit_test"), OK, "%s: saved" % label)
	GameState.reset()
	assert_eq(SaveSystem.load_slot("exit_test"), OK, "%s: loaded" % label)
	st = GameState.story
	var after := {"location": st.location, "party": st.party.map(func(c: Character) -> String: return "%s %d/%d L%d" % [c.name, c.hp, c.max_hp(), c.character_level()]),
		"flags": st.flags.size(), "gold": st.gold, "milestones": st.milestones}
	assert_eq(str(after), str(before), "%s: the save round-trips" % label)
	await _start_game()
	assert_eq(bot.view().loc_id, str(before["location"]), "%s: back where we saved" % label)


func test_create_a_party_survive_death_house_and_meet_ismark_and_ireena() -> void:
	# 1. Character creation.
	var party := _create_party()
	assert_eq(party.size(), 4)
	GameState.reset()
	for ch in party:
		GameState.story.party.append(ch)
	GameState.story.gold = 10.0
	await _start_game()
	assert_eq(bot.view().loc_id, "into_the_mists_road")
	bot.prefer.assign(["We'll find Walter", "We'll help you.", "Refuse. Nobody", "Run for the stairs", "Smash the glass",
		"Gather the bones"])
	bot.avoid.assign(["Draw steel", "Stand and fight", "Give them what they ask", "stand watch", "keep watch",
		"carry him to the church", "without the priest", "Intimidation DC 15", "Choose who lies"])

	# 2. Into the Mists: the wolves on the road, then the children at the village edge.
	if not _ok(await bot.talk("mists_wolves"), "talked to mists_wolves"):
		return
	if not _ok(GameState.story.get_flag("mists_wolves_resolved") == true or GameState.story.get_flag("mists_wolves_fought") == true, "the wolves were dealt with"):
		return
	if not _ok(await bot.talk("rose"), "talked to rose"):
		return
	if not _ok(bool(GameState.story.get_flag("death_house_promised_walter")), "the party promised to find Walter"):
		return
	await _save_and_reload("on the road")

	# 3. Death House, up to the attic. The attic stair is behind a secret door off the balcony (book area 11).
	if not _ok(await bot.go_to("death_house_ground"), "reached death_house_ground"):
		return
	if not _ok(await bot.go_to("death_house_third"), "reached death_house_third"):
		return
	if not _ok(await bot.walk_to(Vector2i(11, 4)), "walked to (11, 4)"):
		return
	if not _ok(GameState.story.get_flag("death_house_armor_destroyed") == true, "the armor on the balcony"):
		return
	for i in 12:
		if not bot.view().thing_at(Vector2i(11, 3)).is_empty():
			break
		bot.view().search()
		await bot.frames(2)
	if not _ok(not bot.view().thing_at(Vector2i(11, 3)).is_empty(), "found the panel to the attic stair"):
		return
	if not _ok(await bot.go_to("death_house_attic"), "reached death_house_attic"):
		return

	# 4. The hidden stair (searching the storage room's corner) and the first milestone.
	if not _ok(await bot.walk_to(Vector2i(16, 1)), "walked to (16, 1)"):
		return
	for i in 12:
		if not bot.view().thing_at(Vector2i(18, 1)).is_empty():
			break
		bot.view().search()
		await bot.frames(2)
	if not _ok(await bot.use(Vector2i(18, 1)), "used the thing at (18, 1)"):
		return
	if not _ok(bool(GameState.story.get_flag("death_house_secret_stair_found")), "flag death_house_secret_stair_found"):
		return
	await bot.level_up()
	for ch in GameState.story.party:
		assert_eq(ch.character_level(), 2, "%s reached level 2" % ch.name)
	await _save_and_reload("in the attic")

	# 5. Down to the altar, and the choice: refuse.
	if not _ok(await bot.go_to("death_house_dungeon_2"), "reached death_house_dungeon_2"):
		return
	if not _ok(await bot.talk("cult_shades"), "talked to cult_shades"):
		return
	if not _ok(bool(GameState.story.get_flag("death_house_refused")), "flag death_house_refused"):
		return
	assert_false(bool(GameState.story.get_flag("death_house_sacrificed")))

	# 6. The house turns: back up through it and out of the dining room window.
	if not _ok(await bot.go_to("death_house_ground"), "reached death_house_ground"):
		return
	for i in 3:
		if bool(GameState.story.get_flag("death_house_completed")):
			break
		if not _ok(await bot.use(Vector2i(27, 12)), "used the thing at (27, 12)"):
			return
	if not _ok(bool(GameState.story.get_flag("death_house_completed")), "out of Death House"):
		return
	await bot.level_up()
	for ch in GameState.story.party:
		assert_eq(ch.character_level(), 3, "%s reached level 3" % ch.name)
	assert_eq(GameState.story.quest_stage("death_house"), "escaped_refused")
	if not _ok(await bot.go_to("village_of_barovia"), "reached village_of_barovia"):
		return

	# 7. Ismark at the tavern, then Ireena at the mansion.
	if not _ok(await bot.go_to("blood_of_the_vine"), "reached blood_of_the_vine"):
		return
	if not _ok(await bot.talk("ismark"), "talked to ismark"):
		return
	if not _ok(bool(GameState.story.get_flag("ismark_met")), "flag ismark_met"):
		return
	if not _ok(bool(GameState.story.get_flag("burial_agreed")), "the party agreed to help Ismark"):
		return
	await _save_and_reload("after Ismark")
	if not _ok(await bot.go_to("burgomaster_mansion"), "reached burgomaster_mansion"):
		return
	if not _ok(await bot.talk("ireena"), "talked to ireena"):
		return
	if not _ok(bool(GameState.story.get_flag("ireena_met")), "flag ireena_met"):
		return

	# EXIT_KEEP=1 keeps the end state as the save "exit_showcase" (make capture LOAD=exit_showcase).
	if OS.get_environment("EXIT_KEEP") == "1":
		print("  kept exit_showcase: ", error_string(SaveSystem.save("exit_showcase")))
	# The run, for the build log.
	var alive := GameState.story.party.filter(func(c: Character) -> bool: return not c.dead).size()
	if not _ok(alive == 4, "everyone made it"):
		return
	print("  exit run: %d fights, %d conversations, day %d %02d:%02d, %d gp" % [bot.fights.size(), bot.conversations.size(),
		GameState.story.day, GameState.story.minute_of_day / 60, GameState.story.minute_of_day % 60, int(GameState.story.gold)])
	for f in bot.fights:
		print("    %s: %s, %s in %d rounds, %d down" % [f["where"], ", ".join(f["foes"] as Array), f["outcome"], int(f["rounds"]), int(f["downs"])])
