extends TestCase
## Side quest failure plan, F1 (closures): a place run for real ends a quest its data says has run out. The clock in a
## location (LocationClock) closes one whose days are up, and walking into a place in another region closes one that
## ends as the party leaves (LocationView). A made-up quest, so the rules don't move when a real quest's data does.

const HERE := "village_of_barovia"
const THERE := "amber_temple_vault"
const QUEST := {"id": "test_walkaway", "name": "The Candle", "summary": "A candle in a window.", "stages": [
	{"id": "lit", "journal": "Lit.", "objectives": ["Come back."], "hint": "The village.", "ends": ""},
	{"id": "snuffed", "journal": "Snuffed.", "ends": "failure"},
	{"id": "burnt_down", "journal": "Burnt down.", "ends": "failure"}],
	"closes": [
		{"stage": "snuffed", "leave": "", "when": "flag.test_candle_left", "from": ["lit"]},
		{"stage": "burnt_down", "when": "quest_days.test_walkaway >= 2", "from": ["lit"], "warn": "It burns low."}]}


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var quest := QUEST.duplicate(true)
	((quest["closes"] as Array)[0] as Dictionary)["leave"] = _region(HERE)
	(Compendium.shared().tables["quests"] as Dictionary)["test_walkaway"] = quest


func after_each() -> void:
	(Compendium.shared().tables["quests"] as Dictionary).erase("test_walkaway")


func _region(loc_id: String) -> String:
	return str(Compendium.shared().get_entry("locations", loc_id).get("region", ""))


func test_the_two_places_are_in_different_regions() -> void:
	assert_true(_region(HERE) != "" and _region(THERE) != "" and _region(HERE) != _region(THERE))


func test_walking_out_of_a_region_closes_a_quest_that_ends_as_the_party_leaves() -> void:
	var st := GameState.story
	st.set_quest_stage("test_walkaway", "lit")
	st.set_flag("test_candle_left")
	st.location = HERE
	var told: Array[String] = []
	var v := LocationView.create(THERE, st, null, Dice.roller, "default")
	v.toast.connect(func(t: String) -> void: told.append(t))
	add_child(v)
	await get_tree().process_frame
	assert_eq(st.quest_stage("test_walkaway"), "snuffed", "leaving the village with the candle left ends it")
	assert_eq(told, ["Quest failed: The Candle"] as Array[String], "and says so")
	v.queue_free()
	await get_tree().process_frame


func test_moving_within_a_region_or_before_the_rule_holds_closes_nothing() -> void:
	var st := GameState.story
	st.set_quest_stage("test_walkaway", "lit")
	st.location = HERE
	var v := LocationView.create(THERE, st, null, Dice.roller, "default")
	add_child(v)
	await get_tree().process_frame
	assert_eq(st.quest_stage("test_walkaway"), "lit", "the party left the region, but the candle was not left")
	v.queue_free()
	await get_tree().process_frame
	st.set_flag("test_candle_left")
	var w := LocationView.create(THERE, st, null, Dice.roller, "default")
	add_child(w)
	await get_tree().process_frame
	assert_eq(st.quest_stage("test_walkaway"), "lit", "already in another region: nothing is left")
	w.queue_free()
	await get_tree().process_frame


func test_the_clock_in_a_location_closes_a_quest_whose_days_are_up() -> void:
	var st := GameState.story
	st.set_quest_stage("test_walkaway", "lit")
	var told: Array[String] = []
	var v := LocationView.create(THERE, st, null, Dice.roller, "default")
	v.toast.connect(func(t: String) -> void: told.append(t))
	add_child(v)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(st.quest_stage("test_walkaway"), "lit", "nothing has run out yet, and the journal warns")
	assert_eq(QuestClosures.warning(st, "test_walkaway"), "It burns low.")
	st.advance_minutes(2 * 24 * 60 + 30)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(st.quest_stage("test_walkaway"), "burnt_down", "two days on, the clock closes it")
	assert_true("Quest failed: The Candle" in told, str(told))
	v.queue_free()
	await get_tree().process_frame
