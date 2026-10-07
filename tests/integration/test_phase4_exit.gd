extends TestCase
## The Phase 4 exit (plan §10): two playthrough seeds draw two different Tarokka readings at Madam Eva's table, and
## Vallaki plays out differently depending on which faction the party backs (the Baron, Lady Wachter, or the town).
## StoryBot plays each through the real game scene; fights are played by the test-only autopilot.
## Slow (a minute or two): `make test ONLY=phase4_exit`.

var root: Node
var bot: StoryBot


func before_each() -> void:
	Engine.time_scale = 8.0


func after_each() -> void:
	Engine.time_scale = 1.0
	if root != null:
		root.queue_free()
		root = null


func _start(location: String, level: int, seed_value: int) -> void:
	if root != null:
		root.queue_free()
		root = null
		await get_tree().process_frame
	GameState.reset()
	var st := GameState.story
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		st.party.append(ch)
	st.gold = 400.0
	st.playthrough_seed = seed_value
	st.minute_of_day = 9 * 60
	st.location = location
	for loc: String in ["into_the_mists_road", "village_of_barovia", "death_house_ground"]:
		st.visited[loc] = true
	for f: String in ["death_house_completed", "ismark_met", "burgomaster_buried"]:
		st.set_flag(f, true)
	Dice.reseed(seed_value)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	bot = StoryBot.new(self, root)
	bot.avoid.assign(["Intimidation DC 18", "go through them", "It's ours now", "Keep it", "Rob", "steal", "Attack",
		"Draw", "Kill", "We didn't come for fortunes", "Read for one of us alone"])


func _ok(cond: bool, msg: String) -> bool:
	assert_true(cond, msg)
	if not cond:
		print("  --- story bot trace ---")
		for line: String in bot.trace.slice(maxi(0, bot.trace.size() - 80)):
			print("    ", line)
	return cond


func _reading_at_tser_pool(seed_value: int) -> Dictionary:
	await _start("tser_pool", 4, seed_value)
	bot.prefer.assign(["Pay ten gold.", "How is he destroyed?"])
	if not _ok(await bot.go_to("tser_pool_eva_tent"), "reached Madam Eva's tent"):
		return {}
	if not _ok(await bot.talk("madam_eva"), "talked to Madam Eva"):
		return {}
	return GameState.story.tarokka.duplicate()


func test_two_seeds_draw_two_readings_at_madam_evas_table() -> void:
	var a := await _reading_at_tser_pool(11)
	if not _ok(a.size() == 5, "seed 11: five cards %s" % [a]):
		return
	GoldenSaves.keep("tser_pool", "test_phase4_exit")
	var journal := QuestLog.journal(GameState.story)
	var text := ""
	for q in journal:
		text += " ".join(q["entries"] as Array) + " ".join(q["objectives"] as Array)
	assert_false(text.contains("{tarokka."), "journal hints are filled in from the reading")
	assert_true(GameState.story.quest_stage("find_the_tome") != "", "the treasure quests began")
	var b := await _reading_at_tser_pool(23)
	if not _ok(b.size() == 5, "seed 23: five cards %s" % [b]):
		return
	var same := 0
	for slot in Tarokka.SLOTS:
		if str(a[slot]) == str(b[slot]):
			same += 1
	assert_true(same < 5, "two seeds, two readings: %s vs %s" % [a, b])
	print("  readings: seed 11 %s / seed 23 %s" % [a, b])


## Plays Vallaki to the end of the Festival for one faction. Returns the flags at the end.
func _vallaki(pledge_place: String, pledge_npc: String, prefer: Array[String], aftermath_npc: String, seed_value: int) -> Dictionary:
	await _start("vallaki", 5, seed_value)
	GoldenSaves.keep("vallaki", "test_phase4_exit")
	var p: Array[String] = ["This is Ireena"]
	p.append_array(prefer)
	p.append_array(["We're ready. Let the festival begin."])
	bot.prefer.assign(p)
	if not _ok(await bot.go_to(pledge_place), "reached %s" % pledge_place):
		return {}
	if not _ok(await bot.talk(pledge_npc), "talked to %s" % pledge_npc):
		return {}
	if not _ok(str(GameState.story.get_flag("vallaki_pledge", "")) != "", "pledged: %s" % GameState.story.get_flag("vallaki_pledge", "")):
		return {}
	if not _ok(await bot.go_to("vallaki"), "back in the town"):
		return {}
	if not _ok(await bot.talk("vallaki_herald"), "asked the herald"):
		return {}
	if not _ok(bool(GameState.story.get_flag("festival_begun")), "the festival began"):
		return {}
	if not GameState.story.get_flag("festival_climax", false):
		await bot.talk("baron_vargas")
	await bot.settle()
	if not _ok(bool(GameState.story.get_flag("festival_climax")), "the festival turned"):
		return {}
	for i in 3:
		if GameState.story.get_flag("vallaki_backed", "") != "":
			break
		await bot.talk(aftermath_npc)
		await bot.settle()
	return GameState.story.flags.duplicate()


func test_vallaki_plays_out_differently_by_faction() -> void:
	var results := {}
	var baron := await _vallaki("vallaki_burgomaster_mansion", "baron_vargas", ["We'll stand with you, Baron."], "baron_vargas", 5)
	if baron.is_empty():
		return
	results["baron"] = baron
	var wachter := await _vallaki("vallaki_wachter_house", "lady_wachter", ["We're with you.", "About your offer.", "Exile him"], "lady_wachter", 6)
	if wachter.is_empty():
		return
	results["wachter"] = wachter
	var town := await _vallaki("vallaki_st_andrals", "father_lucian", ["Then we'll stand with the town", "We'll find the bones",
		"Read the crowd the letter"], "father_lucian", 7)
	if town.is_empty():
		return
	results["neither"] = town
	for k: String in results:
		assert_eq(str((results[k] as Dictionary).get("vallaki_backed", "")), k, "the %s path ends with vallaki_backed = %s" % [k, k])
	assert_eq(str(baron.get("wachter_fate", "")), "stocks", "backing the Baron puts Lady Wachter in the stocks")
	assert_true(str(wachter.get("baron_fate", "")) != "", "backing Lady Wachter decides the Baron's fate")
	assert_false(town.has("wachter_fate") and str(town["wachter_fate"]) == "stocks" and str(town.get("baron_fate", "")) != "", "the town path is its own")
	print("  vallaki: baron %s / wachter %s / town %s" % [baron.get("vallaki_backed"), wachter.get("vallaki_backed"), town.get("vallaki_backed")])
	for f in bot.fights:
		print("    %s: %s, %s in %d rounds, %d down" % [f["where"], ", ".join(f["foes"] as Array), f["outcome"], int(f["rounds"]), int(f["downs"])])
