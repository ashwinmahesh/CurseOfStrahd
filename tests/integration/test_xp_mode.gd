extends "res://tests/integration/test_phase3_exit.gd"
## XP levelling through the real game (story/xp.gd, docs/plans/xp_mode.md): the Phase 3 run, from character creation out of
## Death House, played in Experience mode. A fight won, a place found, a thing found, a conversation, a quest and the two
## Death House milestones all pay along the way; the party ends Death House at level 3 or more and never above 4 (the
## floor, and the ceiling of one level over the story's), the XP is what the saves keep, and milestone levelling still
## plays as before (test_phase3_exit). Slow (a few minutes): make test FILES=test_xp_mode.gd.

var _notices: Array[String] = []


## The milestone run is test_phase3_exit's own, so it isn't run again on its own here.
func test_create_a_party_survive_death_house_and_meet_ismark_and_ireena() -> void:
	pass


func _watch_notices() -> void:
	_notices.clear()
	GameState.story.xp_gained.connect(func(text: String) -> void: _notices.append(text))


func test_death_house_in_xp_mode_ends_at_level_3_or_more_and_never_above_4() -> void:
	var party := _create_party()
	GameState.reset()
	for ch in party:
		GameState.story.party.append(ch)
	GameState.story.gold = 10.0
	GameState.story.options[Xp.OPTION] = Xp.EXPERIENCE   # what the title screen's second question sets
	await _start_game()
	var st := GameState.story
	_watch_notices()
	assert_true(Xp.active(st), "the game is in Experience mode")
	assert_eq(bot.view().loc_id, "into_the_mists_road")
	assert_eq(st.target_level(), 1)
	assert_true(st.xp > 0, "the first place the party stands in is a new location: a little XP already")
	bot.prefer.assign(["We'll find Walter", "We'll help you.", "Refuse. Nobody", "Run for the stairs", "Smash the glass",
		"Gather the bones"])
	bot.avoid.assign(["Draw steel", "Stand and fight", "Give them what they ask", "stand watch", "keep watch",
		"carry him to the church", "without the priest", "Intimidation DC 15", "Choose who lies"])

	# The road: wolves, and the children at the village edge.
	var before_road := st.xp
	if not _ok(await bot.talk("mists_wolves"), "talked to mists_wolves"):
		return
	if not _ok(await bot.talk("rose"), "talked to rose"):
		return
	st = GameState.story
	assert_true(st.xp >= before_road, "XP never goes down")
	# A save keeps the pool, the reserve and the mode.
	var kept := st.xp
	await _save_and_reload("on the road")
	st = GameState.story
	_watch_notices()
	assert_eq(st.xp, kept, "the XP comes back with the save")
	assert_true(Xp.active(st), "and so does the mode")

	# Death House to the attic, the hidden stair and the first milestone.
	if not _ok(await bot.go_to("death_house_ground"), "reached death_house_ground"):
		return
	if not _ok(await bot.go_to("death_house_third"), "reached death_house_third"):
		return
	if not _ok(await bot.walk_to(Vector2i(11, 4)), "walked to (11, 4)"):
		return
	if not _ok(await bot.walk_to(Vector2i(11, 4)), "back at (11, 4)"):
		return
	if not _ok(await bot.search_for(Vector2i(11, 3)), "found the panel to the attic stair"):
		return
	st = GameState.story
	assert_true(st.flags.keys().any(func(k: Variant) -> bool: return str(k).begins_with("_xp/find/")), "a search that found something paid for it")
	if not _ok(await bot.go_to("death_house_attic"), "reached death_house_attic"):
		return
	if not _ok(await bot.walk_to(Vector2i(16, 1)), "walked to (16, 1)"):
		return
	if not _ok(await bot.search_for(Vector2i(18, 1)), "found the seam in the storage room"):
		return
	if not _ok(await bot.use(Vector2i(18, 1)), "used the thing at (18, 1)"):
		return
	st = GameState.story
	if not _ok(bool(st.get_flag("death_house_secret_stair_found")), "flag death_house_secret_stair_found"):
		return
	assert_eq(st.milestones, 1, "the hidden stair is the first milestone")
	assert_true(st.xp >= Xp.threshold(2), "the milestone brings the pool to level 2 at least (the floor)")
	await bot.level_up()
	for ch in st.party:
		assert_between(ch.character_level(), 2, 3, "%s after the hidden stair" % ch.name)
	await _save_and_reload("in the attic")
	st = GameState.story

	# The altar: refuse. Out of the house, the second milestone.
	if not _ok(await bot.go_to("death_house_dungeon_2"), "reached death_house_dungeon_2"):
		return
	if not _ok(await bot.use(Vector2i(23, 8)), "pulled the winch"):
		return
	if not _ok(await bot.talk("cult_shades"), "talked to cult_shades"):
		return
	if not _ok(await bot.go_to("death_house_ground"), "reached death_house_ground"):
		return
	for i in 3:
		if bool(GameState.story.get_flag("death_house_completed")):
			break
		if not _ok(await bot.use(Vector2i(27, 12)), "used the thing at (27, 12)"):
			return
	st = GameState.story
	if not _ok(bool(st.get_flag("death_house_completed")), "out of Death House"):
		return
	assert_eq(st.milestones, 2, "the second milestone")
	await bot.level_up()
	for ch in st.party:
		assert_between(ch.character_level(), 3, 4, "%s leaves Death House at level 3 or 4, never 5 (the floor and the ceiling)" % ch.name)
	assert_between(Xp.level_for(st.xp), 3, 4, "the pool agrees")
	assert_true(st.xp <= Xp.ceiling(st), "never past the ceiling")
	assert_eq(st.quest_stage("death_house"), "escaped_refused")
	# Death House's quest is paid by its milestone, not twice.
	assert_false(st.flags.has("_xp/main_quest/death_house"), "the milestone pays for Death House's ending")
	print("  xp run: %s, %d fights, level %d, %s" % [Xp.line(st), bot.fights.size(), st.target_level(), "; ".join(_notices.slice(0, 12))])
