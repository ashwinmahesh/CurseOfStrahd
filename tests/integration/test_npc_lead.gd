extends TestCase
## The lead step in the game (docs/story/leads_and_guests.md; owner todo 2026-10-17: "if the NPC is supposed to take the
## characters somewhere, the gameplay should represent that. Have the player sprites follow the NPC sprites to that
## location. If it's in a different map area, give a confirmation to follow now or come back later"): the person walks, the
## party's figures follow in marching order, a click skips it, another place asks first, and the conversation carries on
## afterwards with `check.last` telling it whether the party went.

const LOC_A := {
	"id": "test_lead_a", "name": "Test Lead A", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################"], "light": "dim"},
	"spawns": {"default": [1, 4]},
	"npcs": [{"npc": "ismark", "cell": [3, 1], "dialogue": "test/lead:start"}],
	"props": [{"id": "well", "cell": [15, 2], "kind": "examine", "label": "The well", "model": "satchel", "text": "A well."}],
	"exits": [{"id": "to_b", "cell": [18, 4], "to": "test_lead_b", "spawn": "default", "label": "Out"}],
}

const LOC_B := {
	"id": "test_lead_b", "name": "Test Lead B, the Far Hall", "region": "test", "summary": "Another fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [1, 2], "far": [7, 2]},
}

const TALK := """
~ start
Ismark: Follow me to the well.
lead ismark to well
if check.last
Ismark: Here we are.
else
Ismark: Hm.
endif
-> END

~ square
Ismark: This way.
lead ismark to 12,3
Ismark: Here.
-> END

~ elsewhere
Ismark: Come to the far hall.
lead ismark to test_lead_b:far
if check.last
Ismark: Welcome.
set went
else
Ismark: Later, then.
set stayed
endif
-> END
"""

var root: Node


func before_each() -> void:
	var c := Compendium.shared()
	c.tables["locations"]["test_lead_a"] = LOC_A.duplicate(true)
	c.tables["locations"]["test_lead_b"] = LOC_B.duplicate(true)
	DialogueFile.register(DialogueFile.parse(TALK, "test/lead"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_lead_a"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	Compendium.shared().tables["locations"].erase("test_lead_a")
	Compendium.shared().tables["locations"].erase("test_lead_b")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _dialogue() -> DialogueUI:
	return root.get("dialogue") as DialogueUI


func _cell_of(npc_id: String) -> Vector2i:
	for shown in _view()._npc_shown:
		if str((shown["spec"] as Dictionary)["npc"]) == npc_id:
			return shown["cell"] as Vector2i
	var tok: Variant = _view()._staged.get(npc_id)
	if tok is Node3D:
		return _view().grid.cell_at((tok as Node3D).position)
	return Vector2i(-1, -1)


func _walk() -> LocationLead:
	for c in _view().get_children():
		if c is LocationLead:
			return c as LocationLead
	return null


## Starts `ref` and goes on until the conversation stops at the lead (the box hides).
func _to_the_lead(ref: String) -> void:
	root.call("start_dialogue", ref, "ismark")
	await _frames(1)
	for i in 6:
		if not _dialogue().visible:
			break
		_dialogue().call("_advance")
	assert_false(_dialogue().visible, "the conversation steps back for the walk")


## Runs the walk for up to `seconds` of game time, a tick at a time.
func _run_walk(seconds: float) -> void:
	var lead := _walk()
	var t := 0.0
	while lead != null and is_instance_valid(lead) and not lead._done and t < seconds:
		lead._process(0.05)
		if is_instance_valid(lead) and not lead._done:
			_view()._process(0.05)
		t += 0.05
	await _frames(2)


func _said() -> String:
	var d := _dialogue()
	return str((d.get("_text") as RichTextLabel).text) if d != null else ""


func test_the_person_walks_and_the_party_follows() -> void:
	var v := _view()
	var start_leader := v.leader().cell
	await _to_the_lead("test/lead:start")
	var lead := _walk()
	assert_true(lead != null, "the walk is on")
	assert_true(v.busy, "nothing else moves the party meanwhile")
	var steps_seen := {}
	var t := 0.0
	while lead != null and is_instance_valid(lead) and not lead._done and t < 60.0:
		lead._process(0.05)
		v._process(0.05)
		steps_seen[_cell_of("ismark")] = true
		t += 0.05
	await _frames(2)
	assert_true(steps_seen.size() >= 8, "he walked square by square, not in one jump (%d squares)" % steps_seen.size())
	var at := _cell_of("ismark")
	assert_true(maxi(absi(at.x - 15), absi(at.y - 2)) <= 1, "he stands beside the well (at %s)" % at)
	var lead_at := v.leader().cell
	assert_ne(lead_at, start_leader, "the party moved")
	assert_true(maxi(absi(lead_at.x - at.x), absi(lead_at.y - at.y)) <= 3, "and stands just behind him (%s, he's at %s)" % [lead_at, at])
	for i in range(1, v.members.size()):
		assert_true(maxi(absi(v.members[i].cell.x - at.x), absi(v.members[i].cell.y - at.y)) <= 6, "the rest of the line followed")
	assert_false(v.busy, "the party is free again")
	assert_true(_dialogue().visible, "the conversation is back")
	assert_true(GameState.story.last_check, "the party went")
	assert_true(_said().contains("Here we are"), "and it goes on from there: %s" % _said())
	assert_true(_cell_of("ismark") == at and (v.thing_at(at).get("id", "") == "ismark"), "his square is where he stands now")


func test_a_click_skips_the_walk() -> void:
	var v := _view()
	await _to_the_lead("test/lead:start")
	var lead := _walk()
	assert_true(lead != null)
	lead._skip()
	await _frames(2)
	var at := _cell_of("ismark")
	assert_true(maxi(absi(at.x - 15), absi(at.y - 2)) <= 1, "he is at the well at once (at %s)" % at)
	assert_true(maxi(absi(v.leader().cell.x - at.x), absi(v.leader().cell.y - at.y)) <= 3, "with the party gathered behind him")
	assert_true(_dialogue().visible)
	assert_true(_said().contains("Here we are"))


func test_a_square_works_as_well_as_a_thing() -> void:
	await _to_the_lead("test/lead:square")
	_walk()._skip()
	await _frames(2)
	assert_eq(_cell_of("ismark"), Vector2i(12, 3), "the square he was told to go to")


func test_he_keeps_his_new_place_when_the_talk_ends() -> void:
	await _to_the_lead("test/lead:start")
	_walk()._skip()
	await _frames(2)
	var at := _cell_of("ismark")
	for i in 6:
		if _dialogue() == null:
			break
		_dialogue().call("_advance")
		await _frames(1)
	assert_true(_dialogue() == null, "the conversation ended")
	await _frames(2)
	assert_eq(_cell_of("ismark"), at, "he stays where he walked to (the rebuild after the talk leaves people where they stand)")


func test_another_place_asks_first_and_later_leaves_things_as_they_were() -> void:
	await _to_the_lead("test/lead:elsewhere")
	var prompt := root.get("_prompting") as LeadPrompt
	assert_true(prompt != null, "a prompt asks")
	assert_true(prompt.npc_name.begins_with("Ismark") and prompt.place.contains("Far Hall"), "naming who and where: %s to %s" % [prompt.npc_name, prompt.place])
	assert_true(_walk() == null, "no walk until it is answered")
	prompt.later_button.pressed.emit()
	await _frames(2)
	assert_eq(_view().loc_id, "test_lead_a", "still here")
	assert_false(GameState.story.last_check)
	assert_true(_dialogue().visible)
	assert_true(_said().contains("Later, then"), _said())
	assert_true(root.get("_prompting") == null)
	assert_false(_view().busy)


func test_following_walks_to_the_way_out_and_carries_the_talk_on_in_the_new_place() -> void:
	await _to_the_lead("test/lead:elsewhere")
	var prompt := root.get("_prompting") as LeadPrompt
	prompt.follow_button.pressed.emit()
	await _frames(1)
	var lead := _walk()
	assert_true(lead != null, "they walk after him to the way out")
	await _run_walk(60.0)
	await _frames(3)
	assert_eq(_view().loc_id, "test_lead_b", "and the place changes")
	assert_true(_view()._staged.has("ismark"), "he is beside them there")
	assert_eq(_view().leader().cell.y, 2, "at the spawn the lead named (far)")
	assert_true(_view().leader().cell.x >= 6, "the far end of the hall (at %s)" % _view().leader().cell)
	assert_true(_dialogue() != null and _dialogue().visible, "the conversation is back")
	assert_true(GameState.story.last_check)
	assert_true(_said().contains("Welcome"), _said())
	for i in 6:
		if _dialogue() == null:
			break
		_dialogue().call("_advance")
		await _frames(1)
	await _frames(2)
	assert_true(bool(GameState.story.get_flag("went", false)))
	assert_true(_view()._staged.is_empty(), "he steps out of the scene when the talk ends, like anyone `appear` brought")
	assert_eq(ModeController.mode, ModeController.Mode.EXPLORATION)


func test_a_fight_in_the_way_ends_the_walk_without_the_party_going() -> void:
	await _to_the_lead("test/lead:start")
	var lead := _walk()
	lead.view.in_combat = true
	lead._process(0.05)
	lead.view.in_combat = false
	assert_true(lead._done, "the walk gave up")
	assert_false(lead.view.busy)
