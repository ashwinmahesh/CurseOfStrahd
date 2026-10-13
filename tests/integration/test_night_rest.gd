extends TestCase
## Whatever comes at the party in the night comes before the Long Rest's benefits (the owner, 2026-10-13;
## story/long_rest.gd): the night's visitors at camp and a visit of Strahd's that may come to blows find the party as it
## lay down, with no Hit Points, slots or Short Rest features back. Once the fight is won (or his visit is over) the
## party lies down again by itself and finishes the rest: the hours still to sleep and an hour more for each fight
## (2024 PHB), the 16 hours since the last Long Rest notwithstanding. Foes still waiting in the place keep it awake, and
## a night broken with nothing to fight ends with a Short Rest's benefits. While the rest is broken no other rest
## starts. A visit with only words keeps the old order: the rest's benefits, then him.

const FIELD := "test_night_rest_field"
const PACK := {"id": "visits", "summary": "", "visits": [{"id": "night_pack", "summary": "", "trigger": {"on": ["rest"]},
	"once": true, "encounter": {"id": "strahd_test_night_pack", "monsters": [{"monster": "wolf"}, {"monster": "wolf"}],
		"after": "strahd/visits:test_after"}}]}

var root: Node = null


func before_each() -> void:
	StrahdPresence.use({"id": "visits", "summary": "", "visits": []})   # no visit of the real file's in the way


func after_each() -> void:
	StrahdPresence.use({})
	if root != null:
		root.queue_free()
		root = null
		await _frames(3)
	(Compendium.shared().tables["locations"] as Dictionary).erase(FIELD)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A seed whose first d6 shows 1: the night's interruption in a risky place.
static func _breaking_seed() -> int:
	var s := 1
	while DiceRoller.new(s).roll_one(6) != 1:
		s += 1
	return s


## A hero as a day's adventuring leaves them when they lie down: half their Hit Points, half of each level's spell
## slots spent, and a Short Rest feature used.
static func _tired(ch: Character) -> void:
	ch.hp = maxi(1, ch.max_hp() / 2)
	var slots := ch.spell_slots()
	for i in slots.size():
		for n in slots[i] / 2:
			ch.expend_slot(i + 1)
	for res_id: String in ch.resources:
		if str((ch.resources[res_id] as Dictionary)["recharge"]) == "short" and ch.resource_left(res_id) > 0:
			ch.spend_resource(res_id)
			return


## What a hero has left: Hit Points, slots spent, and the Short Rest features' uses spent.
static func _left(ch: Character) -> Dictionary:
	var short := {}
	for res_id: String in ch.resources:
		var r := ch.resources[res_id] as Dictionary
		if str(r["recharge"]) == "short":
			short[res_id] = int(r["used"])
	return {"hp": ch.hp, "slots": ch.slots_used.duplicate(), "short": short}


static func _story(level: int) -> StoryState:
	var st := StoryState.new()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := TestChars.pregen(id, level)
		ch.finish_long_rest()
		_tired(ch)
		st.party.append(ch)
	st.minute_of_day = 22 * 60
	return st


static func _rested(st: StoryState) -> bool:
	for ch in st.party:
		if ch.hp != ch.max_hp() or ch.slots_used.any(func(n: int) -> bool: return n > 0):
			return false
	return true


func test_a_night_broken_by_something_in_the_dark_gives_nothing_until_it_goes_on() -> void:
	var st := _story(3)
	var before: Array = st.party.map(func(ch: Character) -> Dictionary: return _left(ch))
	var start := st.total_minutes()
	var res := LongRest.take(st, "risky", DiceRoller.new(_breaking_seed()))
	assert_eq(str(res["how"]), LongRest.DARK, "something comes out of the dark")
	assert_true(bool(res["interrupted"]))
	for i in st.party.size():
		assert_eq(_left(st.party[i]), before[i], "%s fights with what they lay down with" % st.party[i].name)
	assert_true(LongRest.broken(st), "the rest is broken, not over")
	assert_eq(st.total_minutes(), start + 60, "an hour slept before it came")
	assert_true(RestRules.BROKEN_NIGHT in RestRules.long_rest_refusals(st), "no other Long Rest meanwhile")
	assert_true(RestRules.BROKEN_NIGHT in RestRules.short_rest_refusals(st), "nor a Short Rest")
	LongRest.fought(st)
	res = LongRest.resume(st, DiceRoller.new(3))
	assert_eq(str(res["how"]), LongRest.SLEPT, "won: the party sleeps on")
	assert_true(_rested(st), "everyone fully healed, every slot back")
	assert_false(LongRest.broken(st))
	assert_eq(st.total_minutes(), start + 9 * 60, "eight hours, and an hour more for the fight (2024 PHB)")
	assert_eq(int(res["minutes"]), 9 * 60)
	assert_eq(RestRules.minutes_until_long_rest(st), RestRules.WAIT_MINUTES, "the 16 hours count from this rest")
	assert_true(LongRest.morning_open(st), "its morning")


func test_a_broken_night_with_nothing_to_fight_ends_with_a_short_rest() -> void:
	var st := _story(3)
	var before: Array = st.party.map(func(ch: Character) -> Dictionary: return _left(ch))
	LongRest.take(st, "risky", DiceRoller.new(_breaking_seed()))
	var res := LongRest.restless(st)
	assert_eq(str(res["how"]), LongRest.RESTLESS)
	assert_true(str(res["text"]).contains("Short Rest"), res["text"])
	assert_false(LongRest.broken(st), "the night is over")
	for i in st.party.size():
		var now := _left(st.party[i])
		assert_eq(now["hp"], before[i]["hp"], "no Long Rest: Hit Points as they were")
		assert_eq(now["slots"], before[i]["slots"], "and the slots")
		for res_id: String in now["short"]:
			assert_eq(int(now["short"][res_id]), 0, "%s's %s back: a Short Rest's benefits" % [st.party[i].name, res_id])
	assert_eq(RestRules.minutes_until_long_rest(st), 0, "the party may try again")
	assert_false(RestRules.BROKEN_NIGHT in RestRules.long_rest_refusals(st))


func test_foes_still_waiting_here_keep_the_party_awake() -> void:
	var st := _story(3)
	var place := ""
	for id: String in (Compendium.shared().tables["locations"] as Dictionary):
		if not RestRules.waiting_fights(st, id).is_empty():
			place = id
			break
	assert_ne(place, "", "a place whose fights still wait")
	st.location = place
	LongRest.take(st, "risky", DiceRoller.new(_breaking_seed()))
	LongRest.fought(st)
	var res := LongRest.resume(st, DiceRoller.new(3))
	assert_eq(str(res["how"]), LongRest.RESTLESS, "nobody sleeps again with enemies about")
	assert_true(str(res["text"]).begins_with("Enemies still prowl"), res["text"])
	assert_false(_rested(st), "no Long Rest's benefits")
	assert_false(LongRest.broken(st))


func test_strahd_s_visit_that_may_come_to_blows_comes_before_the_benefits() -> void:
	StrahdPresence.use(PACK.duplicate(true))
	var st := _story(3)
	var start := st.total_minutes()
	var res := LongRest.take(st, "safe", DiceRoller.new(3))
	assert_eq(str(res["how"]), LongRest.STRAHD, "he comes in the night")
	assert_false(_rested(st), "before the rest's benefits")
	assert_true(LongRest.waits_on_strahd(st))
	assert_eq(st.total_minutes(), start + 8 * 60, "the night slept")
	assert_eq(StrahdPresence.times(st, "night_pack"), 0, "the game root plays the visit (and marks it)")
	LongRest.fought(st)
	res = LongRest.resume(st, DiceRoller.new(3))
	assert_eq(str(res["how"]), LongRest.SLEPT, "and the party sleeps on, not asking for him again")
	assert_true(_rested(st))
	assert_eq(st.total_minutes(), start + 9 * 60, "an hour more for his fight")
	# A visit of words only keeps the old order: the benefits, then him (game root strahd_after_rest).
	StrahdPresence.use({"id": "visits", "summary": "", "visits": [{"id": "words", "summary": "", "trigger": {"on": ["rest"]},
		"dialogue": "strahd/visits:night"}]})
	var st2 := _story(3)
	assert_eq(str(LongRest.take(st2, "safe", DiceRoller.new(3))["how"]), LongRest.SLEPT)
	assert_true(_rested(st2))
	# The magic items' safe rests too.
	StrahdPresence.use(PACK.duplicate(true))
	var st3 := _story(3)
	assert_eq(str(LongRest.take_safe(st3, DiceRoller.new(3))["how"]), LongRest.STRAHD, "even in Daern's Instant Fortress")
	assert_false(_rested(st3))


func test_which_visits_may_come_to_blows() -> void:
	assert_true(StrahdPresence.may_fight(PACK["visits"][0]), "a fight of its own")
	assert_true(StrahdPresence.may_fight({"dialogue": "x", "then": [{"when": "flag.a", "encounter": {}}]}), "a fight it may lead to")
	assert_false(StrahdPresence.may_fight({"dialogue": "x", "then": [{"go": "y"}]}), "words and a carriage")
	assert_false(StrahdPresence.may_fight({}), "no visit")
	for id: String in ["the_hunt", "ireena_at_the_inn", "ireena_in_krezk"]:
		StrahdPresence.use({})
		assert_true(StrahdPresence.may_fight(StrahdPresence.visit(id)), "%s may come to blows" % id)
	assert_false(StrahdPresence.may_fight(StrahdPresence.visit("night_visit")), "his night visit is words")


# --- In the game ----------------------------------------------------------------------------------

## The four at level 2, tired, at night in an open field whose rest is `rest`.
func _start(rest: String) -> void:
	var rows: Array = []
	for z in 16:
		rows.append("#".repeat(22) if z == 0 or z == 15 else "#" + ".".repeat(20) + "#")
	Compendium.shared().tables["locations"][FIELD] = {"id": FIELD, "name": "Test Field", "region": "svalich_road",
		"summary": "", "map": {"rows": rows, "outdoors": true, "theme": "wilderness"}, "spawns": {"default": [10, 8]}, "rest": rest}
	GameState.reset()
	var st := _story(2)
	for ch in st.party:
		GameState.story.party.append(ch)
	GameState.story.milestones = 1
	GameState.story.location = FIELD
	GameState.story.minute_of_day = 22 * 60
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func _view() -> LocationView:
	return root.get("view") as LocationView


## Every foe in the fight falls, and the fight ends won.
func _win() -> void:
	var cv := _view().combat_view
	for c in cv.e.combatants:
		if c.side == &"enemy":
			cv.e.deal_damage(null, c, [{"amount": 500, "type": "slashing"}], false, "test")
	cv.finished.emit("victory")
	await _frames(4)


## Clicks through the open conversation, taking the first option each time. Returns its first node's file:node.
func _talk_through() -> String:
	var d := root.get("dialogue") as DialogueUI
	if d == null:
		return ""
	var ref := "%s:%s" % [d.runner.file.key, d.runner.node]
	for i in 300:
		if root.get("dialogue") == null:
			break
		if bool(d.get("_waiting_continue")):
			d.call("_advance")
		elif not d.options_shown.is_empty():
			d.call("_choose", 0)
		await get_tree().process_frame
	await _frames(4)
	return ref


func test_the_camp_fights_its_night_visitors_as_it_lay_down_then_sleeps_on() -> void:
	await _start("risky")
	var st := GameState.story
	var view := _view()
	var camp := LocationCamp.pitch(view, root, "risky")
	assert_true(camp != null, "camp is made")
	if camp == null:
		return
	var before: Array = st.party.map(func(ch: Character) -> Dictionary: return _left(ch))
	var start := st.total_minutes()
	Dice.reseed(_breaking_seed())
	camp.sleep()
	for i in st.party.size():
		assert_eq(_left(st.party[i]), before[i], "%s fights as they lay down" % st.party[i].name)
	await _frames(2)
	assert_true(view.in_combat, "something comes out of the dark")
	assert_eq(camp.sleep_refusal(), RestRules.BROKEN_NIGHT, "no sleeping again in the middle of it")
	await _win()
	assert_false(view.in_combat)
	assert_true(camp.slept, "the party slept on by itself")
	assert_true(_rested(st), "and woke fully healed")
	assert_false(LongRest.broken(st))
	# Eight hours, an hour more for the fight, and the fight's own minute.
	assert_eq(st.total_minutes(), start + 9 * 60 + 1)


func test_strahd_s_fight_at_the_rest_screen_comes_first_then_the_rest() -> void:
	StrahdPresence.use(PACK.duplicate(true))
	await _start("safe")
	var st := GameState.story
	var start := st.total_minutes()
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	var take: Button = null
	for b in rest.find_children("*", "Button", true, false):
		if (b as Button).text == "Take a Long Rest (8 hours)":
			take = b as Button
	assert_true(take != null and not take.disabled, "a plain Long Rest in a safe place")
	if take == null:
		return
	take.pressed.emit()
	await _frames(2)
	assert_true(root.get("screen") is RestScreen, "he waits for the screen to close")
	assert_true(LongRest.waits_on_strahd(st), "the rest is broken for him")
	assert_false(_rested(st), "no benefits yet")
	root.call("close_screen")
	await _frames(3)
	assert_true(_view().in_combat, "his wolves fall on the party")
	assert_false(_rested(st), "a tired party fights them")
	await _win()
	assert_eq(await _talk_through(), "strahd/visits:test_after", "his parting words")
	assert_false(LongRest.broken(st), "then the party sleeps on")
	assert_true(_rested(st), "and wakes fully healed")
	assert_eq(st.total_minutes(), start + 9 * 60 + 1, "eight hours, an hour more for the fight, and its minute")


func test_a_save_from_a_broken_night_plays_what_broke_it_then_the_rest() -> void:
	StrahdPresence.use(PACK.duplicate(true))
	await _start("safe")
	var res := LongRest.take(GameState.story, "safe", DiceRoller.new(3))
	assert_eq(str(res["how"]), LongRest.STRAHD, "he broke the night")
	# Saved with the night broken and no fight under way (an autosave as the night's first fight ended), then loaded.
	var data := GameState.to_dict()
	root.queue_free()
	root = null
	await _frames(3)
	GameState.from_dict(JSON.parse_string(JSON.stringify(data)) as Dictionary)
	assert_true(LongRest.waits_on_strahd(GameState.story), "the save keeps the broken night")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(6)
	assert_true(_view().in_combat, "his wolves come as the game loads")
	assert_false(_rested(GameState.story), "before the rest's benefits")
	await _win()
	assert_eq(await _talk_through(), "strahd/visits:test_after")
	assert_false(LongRest.broken(GameState.story), "then the party sleeps on")
	assert_true(_rested(GameState.story), "and wakes fully healed")
