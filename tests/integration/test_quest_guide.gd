extends TestCase
## Who to talk to for the tracked quest (owner ask 2026-10-12): QuestGuide finds the people whose conversation moves
## the quest on as things stand; the minimap marks them in green and turns with the camera; the journal shows their
## portrait for any open quest; the travel map rings their place.

const DIALOGUE := """
~ errand
Ismark: You came.
* [if quest.test_errand and not (quest.test_errand >= done)] Ask about the errand. -> give
* Leave. -> END

~ give
Ismark: Take it to the church.
quest test_errand done

~ locked
Ireena: Not now.
* [if flag.test_never_set] Tell her everything. -> tell
* Leave. -> END

~ tell
quest test_errand done
"""

var root: Node = null


func before_each() -> void:
	var c := Compendium.shared()
	c.tables["quests"]["test_errand"] = {"id": "test_errand", "name": "Test Errand", "summary": "", "stages": [
		{"id": "asked", "journal": "Ismark has an errand.", "objectives": ["Talk to Ismark"], "hint": "Talk to Ismark."},
		{"id": "done", "journal": "Done.", "objectives": [], "ends": "success"}]}
	c.tables["locations"]["test_guide_hall"] = {"id": "test_guide_hall", "name": "Guide Hall", "region": "test",
		"summary": "", "map": {"rows": ["##########", "#........#", "#........#", "#........#", "##########"], "theme": "manor"},
		"spawns": {"default": [2, 2]}, "exits": [],
		"npcs": [{"npc": "ismark", "cell": [6, 1], "dialogue": "test/guide:errand"},
			{"npc": "ireena", "cell": [6, 3], "dialogue": "test/guide:locked"}]}
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/guide"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_guide_hall"
	GameState.story.set_quest_stage("test_errand", "asked")
	QuestLog.track(GameState.story, "test_errand")


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	var c := Compendium.shared()
	c.tables["quests"].erase("test_errand")
	c.tables["locations"].erase("test_guide_hall")


func _ids(targets: Array[Dictionary]) -> Array:
	return targets.map(func(t: Dictionary) -> String: return str(t["npc"]))


func test_the_people_whose_talk_moves_the_tracked_quest_on() -> void:
	var st := GameState.story
	assert_eq(_ids(QuestGuide.targets(st)), ["ismark"], "Ismark's errand moves it on; Ireena's line needs a flag nobody set")
	assert_eq(str(QuestGuide.targets(st)[0]["location"]), "test_guide_hall", "and where he is")
	st.set_flag("test_never_set", true)
	assert_eq(_ids(QuestGuide.targets(st)), ["ismark", "ireena"], "with the flag set, Ireena's does too (in the place's order)")
	QuestLog.track(st, "")
	assert_true(QuestGuide.targets(st).is_empty(), "nothing tracked: nobody marked")
	assert_eq(_ids(QuestGuide.targets_for(st, "test_errand")), ["ismark", "ireena"], "the journal still names them")
	QuestLog.track(st, "test_errand")
	st.set_quest_stage("test_errand", "done")
	assert_true(QuestGuide.targets(st).is_empty(), "a finished quest needs nobody")


func test_the_minimap_marks_them_green_and_turns_with_the_camera() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 4:
		await get_tree().process_frame
	var view := root.get("view") as LocationView
	var map := (root.get("hud") as ExploreHud).minimap
	assert_true(map.talk_to.has("ismark") and not map.talk_to.has("ireena"), "Ismark is marked, Ireena isn't")
	var mid := map.size / 2.0
	var lead := Vector2(view.leader().cell) + Vector2(0.5, 0.5)
	for steps in 3:
		var fwd := view.rig.ground_basis()[0]
		var ahead := map.to_map(lead + Vector2(fwd.x, fwd.z) * 3.0) - map.to_map(lead)
		assert_true(ahead.y < -1.0 and absf(ahead.x) < 1.0, "the way the camera looks is up on the map")
		var far := Vector2i(view.leader().cell.x + 3, view.leader().cell.y)
		assert_eq(map.cell_at(map.to_map(Vector2(far) + Vector2(0.5, 0.5))), far, "a click still finds the right square")
		view.rig.rotate_step(1)
		for i in 90:
			await get_tree().process_frame
	assert_eq(map.cell_at(mid), view.leader().cell, "the leader stays in the middle")


func test_the_journal_shows_who_to_talk_to() -> void:
	var j := JournalScreen.new()
	add_child(j)
	j.open(self, GameState.story, 0)
	j.call("_draw")
	await get_tree().process_frame
	var talk := j.find_child("TalkTo", true, false)
	assert_true(talk != null, "the tracked quest names who to talk to")
	var words: Array = talk.find_children("*", "Label", true, false).map(func(l: Node) -> String: return (l as Label).text)
	assert_true(words.has(Compendium.shared().display_name("npcs", "ismark")), "Ismark, with his portrait")
	assert_true(words.has("Guide Hall"), "and where he is")
	assert_true(talk.find_children("*", "TextureRect", true, false).size() > 0, "a portrait")
	j.queue_free()


func test_the_travel_map_rings_their_place() -> void:
	var t := TravelScreen.new()
	add_child(t)
	var c := Compendium.shared()
	var saved := (c.tables["locations"]["test_guide_hall"] as Dictionary).duplicate(true)
	# Ismark stands in the village for this one.
	(c.tables["locations"]["test_guide_hall"] as Dictionary)["npcs"] = []
	var village := c.get_entry("locations", "village_of_barovia")
	(village["npcs"] as Array).push_front({"npc": "ismark", "cell": [20, 12], "dialogue": "test/guide:errand"})
	GameState.story.visited["village_of_barovia"] = true
	t.open_map(GameState.story, "village_of_barovia", false)
	(village["npcs"] as Array).pop_front()
	c.tables["locations"]["test_guide_hall"] = saved
	assert_true(t.talk_places.has("village_of_barovia"), "the village, where Ismark is, gets the green ring")
	t.queue_free()
