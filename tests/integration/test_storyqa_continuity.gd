extends "res://tests/integration/test_phase3_exit.gd"
## A playthrough with no set-up flags (Storyline QA, 2026-10-08): the phase 3 run from character creation to Ireena,
## then on through Father Donavich's rites, the burial (Strahd at the lych-gate, the churchyard dead), Ireena's escort,
## the road west, Madam Eva's reading and Vallaki's gate, saving and loading mid-quest on the way. The phase 4 to 6 runs
## start each region from a built party and set flags; this is the stretch between them, played as a player would.
## Slow (about a minute): make test FILES=test_storyqa_continuity.gd.


## The phase 3 run is the first half of the test below, so it isn't run again on its own here.
func test_create_a_party_survive_death_house_and_meet_ismark_and_ireena() -> void:
	pass


func test_from_ireena_to_vallaki_with_no_cheats() -> void:
	await super.test_create_a_party_survive_death_house_and_meet_ismark_and_ireena()
	if not _ok(bool(_st().get_flag("ireena_met")), "phase 3 reached Ireena"):
		return
	bot.prefer.assign(["We'll help you bury your father.", "Will you bury the burgomaster?",
		"We're ready to carry him to the church.", "Wait for him to find his voice.",
		"Ireena is under our protection. Leave.", "Yes. We'll take you to Vallaki.",
		"Someone should stay and keep the house standing.", "Set out west.", "Pay ten gold.",
		"One of us will tell you something true.", "Lean close and tell her", "How is he destroyed?", "This is Ireena Kolyana"])
	bot.avoid.assign(["Attack", "Draw steel", "Kill", "Intimidation", "Fill in the grave", "No. We can't take you",
		"Not yet", "Krezk", "without the priest", "stand watch", "We'll hold the house", "Unbar", "Lift the bar",
		"end his suffering", "Deception", "Turn the cards"])

	# 1. Father Donavich agrees to say the rites.
	if not _ok(await bot.go_to("village_church"), "reached the church"):
		return
	if not _ok(await bot.talk("donavich"), "talked to Donavich"):
		return
	if not _ok(bool(_st().get_flag("donavich_will_officiate")), "Donavich will say the words (%s)" % _burial()):
		return

	# 2. The procession: Ireena at the mansion. She leaves for the grave as the talk ends, so talk() may not find its
	# own conversation afterwards; the flag says whether it happened.
	if not _ok(await bot.go_to("burgomaster_mansion"), "back at the mansion"):
		return
	await bot.talk("ireena")
	if not _ok(bool(_st().get_flag("burial_procession")), "the procession set out (%s)" % _burial()):
		return
	await _reload_checking_quests("in the procession")

	# 3. The burial at the open grave.
	if not _ok(await bot.go_to("village_of_barovia"), "in the village"):
		return
	_view().refresh_npcs()
	await bot.talk("ireena")
	await bot.settle()
	if not _ok(bool(_st().get_flag("burgomaster_buried")), "the burgomaster is buried (%s)" % _burial()):
		return
	await _reload_checking_quests("after the burial")

	# 4. The escort: Ireena's answer, then the road west.
	_view().refresh_npcs()
	await bot.talk("ireena")
	var escort := _st().quest_stage("escort_ireena")
	if not _ok(escort == "accepted", "escort accepted (%s)" % escort):
		return
	if not _ok(await bot.use(Vector2i(1, 12)), "used the road west"):
		return
	await bot.settle()
	if not _ok(bool(_st().get_flag("village_departed")), "left the village by the west road"):
		return
	if not _ok("ireena" in _st().guest_ids, "Ireena walks with the party"):
		return

	# 5. Madam Eva at Tser Pool, by the map (StoryBot sets out only by a road out that's open: the crossroads' castle road
	# stays shut until the invitation).
	if not _ok(await bot.go_to("svalich_crossroads"), "reached the crossroads"):
		return
	if not _ok(await bot.go_to("tser_pool"), "reached Tser Pool"):
		return
	if not _ok(await bot.go_to("tser_pool_eva_tent"), "reached Madam Eva's tent"):
		return
	if not _ok(await bot.talk("madam_eva"), "talked to Madam Eva"):
		return
	if not _ok(_st().tarokka.size() == 5, "the reading: %s" % [_st().tarokka]):
		return
	await _reload_checking_quests("after the reading")

	# 6. Vallaki's gate, with Ireena: the escort is done, and Sanctuary begins.
	if not _ok(await bot.go_to("tser_pool"), "back out of the tent"):
		return
	if not _ok(await bot.go_to("vallaki"), "reached Vallaki"):
		return
	await bot.settle()
	for i in 3:
		if bool(_st().get_flag("vallaki_arrived")):
			break
		_view().refresh_npcs()
		await bot.talk("vallaki_guard")
		await bot.settle()
	if not _ok(bool(_st().get_flag("vallaki_arrived")), "through Vallaki's gate"):
		return
	assert_eq(_st().quest_stage("escort_ireena"), "arrived", "the escort is over")
	assert_eq(_st().quest_stage("sanctuary_for_ireena"), "arrived", "Sanctuary for Ireena begins at the gate")
	print("  continuity run: %d fights, %d conversations, day %d %02d:%02d, %d gp" % [bot.fights.size(),
		bot.conversations.size(), _st().day, _st().minute_of_day / 60, _st().minute_of_day % 60, int(_st().gold)])
	for f in bot.fights:
		print("    %s: %s, %s in %d rounds, %d down" % [f["where"], ", ".join(f["foes"] as Array), f["outcome"],
			int(f["rounds"]), int(f["downs"])])


func _st() -> StoryState:
	return GameState.story


func _view() -> LocationView:
	return root.get("view") as LocationView


func _burial() -> String:
	return "burial quest at %s" % _st().quest_stage("bury_the_burgomaster")


## A save and load mid-quest: quests, story flags, the journal (in its order) and guests come back the same.
func _reload_checking_quests(label: String) -> void:
	var before := _story_now()
	await _save_and_reload(label)
	var after := _story_now()
	for k: String in before:
		assert_eq(str(after[k]), str(before[k]), "%s: the %s survive the save" % [label, k])


func _story_now() -> Dictionary:
	var st := GameState.story
	var flags := {}
	for k: String in st.flags:
		if not k.begins_with("_"):
			flags[k] = st.flags[k]
	# Through JSON, as a save writes them, so an int that comes back a float (a quest's `at`, a counter) isn't a change.
	return {"quests": JSON.stringify(JSON.parse_string(JSON.stringify(st.quests))),
		"flags": JSON.stringify(JSON.parse_string(JSON.stringify(flags))),
		"journal": str(QuestLog.journal(st)), "guests": str(st.guest_ids)}
