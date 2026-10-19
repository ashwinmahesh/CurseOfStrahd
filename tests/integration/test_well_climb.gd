extends TestCase
## Getting down the old well-head on the shore of Lake Baratok into the Drowned Library (Ashwin, 2026-10-19: "How to climb
## down old head well to reach drowned library?"): examining the well-head offers the climb itself, the shaft square beside
## it still works, and both leave The Drowned Library at "asked" (walking straight down used to leave it at "rumored").

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const WELL := "van_richtens_tower/the_drowned_library:wellhead"

var root: Node


func before_each() -> void:
	GameSettings.set_turn_based(false)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "van_richtens_tower"
	Dice.reseed(4)


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _start() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


## Where the conversation sent the party: [location, spawn], or [] if it didn't.
func _went(beats: Array[Dictionary]) -> Array[String]:
	var mv: Variant = beats[-1].get("move", null)
	if not mv is Dictionary:
		return []
	return [str((mv as Dictionary)["location"]), str((mv as Dictionary)["spawn"])]


func _options(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			for o: Variant in b["options"] as Array:
				out.append(str((o as Dictionary)["text"]))
	return out


func test_examining_the_well_head_offers_the_climb_and_a_way_out() -> void:
	var st := SideQuestPlay.party(FOUR, 10, "van_richtens_tower", 14)
	var first := SideQuestPlay.play(st, WELL, ["Leave it be"])
	assert_eq(SideQuestPlay.missing(first), "")
	assert_true("Climb down the well-shaft." in _options(first), "the climb is on offer once the whisper has been heard")
	assert_true("Leave it be." in _options(first), "and so is leaving")
	assert_eq(st.quest_stage("the_drowned_library"), "asked")
	assert_eq(str(first[-1].get("kind", "")), "end")
	assert_false(first[-1].has("move"), "leaving stays on the shore")


func test_climbing_from_the_well_head_goes_down_takes_a_few_minutes_and_asks_the_quest() -> void:
	for before: String in ["", "rumored", "asked"]:
		var st := SideQuestPlay.party(FOUR, 10, "van_richtens_tower", 14)
		if before != "":
			st.set_quest_stage("the_drowned_library", before)
		var minutes := st.total_minutes()
		var beats := SideQuestPlay.play(st, WELL, ["Climb down the well-shaft"])
		assert_eq(SideQuestPlay.missing(beats), "", before)
		assert_eq(_went(beats), ["drowned_library", "from_shore"] as Array[String], "%s: the party goes down" % before)
		assert_eq(st.quest_stage("the_drowned_library"), "asked", "%s: asked" % before)
		assert_true(st.total_minutes() - minutes >= 5, "%s: a few minutes pass" % before)


func test_the_climb_is_there_after_the_index_is_gone_too() -> void:
	var st := SideQuestPlay.party(FOUR, 10, "van_richtens_tower", 14)
	st.set_flag("index_destroyed")
	st.set_quest_stage("the_drowned_library", "done")
	var beats := SideQuestPlay.play(st, WELL, ["Climb down the well-shaft"])
	assert_eq(_went(beats), ["drowned_library", "from_shore"] as Array[String])
	assert_eq(st.quest_stage("the_drowned_library"), "done", "and a finished quest stays finished")


func test_walking_onto_the_shaft_square_leaves_a_rumoured_quest_at_asked() -> void:
	GameState.story.set_quest_stage("the_drowned_library", "rumored")
	await _start()
	var v := root.get("view") as LocationView
	assert_eq(v.loc_id, "van_richtens_tower")
	v.leader().cell = Vector2i(21, 26)
	LocationWalk.step(v, Vector2i.RIGHT)
	LocationWalk.tick(v, 1.0)
	await _frames(4)
	assert_eq((root.get("view") as LocationView).loc_id, "drowned_library", "the shaft square still leads down")
	assert_eq(GameState.story.quest_stage("the_drowned_library"), "asked", "and the quest has moved on")


func test_the_shaft_stays_shut_until_the_quest_has_begun() -> void:
	await _start()
	var v := root.get("view") as LocationView
	v.leader().cell = Vector2i(21, 26)
	LocationWalk.step(v, Vector2i.RIGHT)
	LocationWalk.tick(v, 1.0)
	await _frames(4)
	assert_eq((root.get("view") as LocationView).loc_id, "van_richtens_tower", "no quest, no way down")
	assert_eq(GameState.story.quest_stage("the_drowned_library"), "")
