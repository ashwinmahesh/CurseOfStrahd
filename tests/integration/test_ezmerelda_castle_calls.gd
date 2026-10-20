extends TestCase
## Ezmerelda's plan at the castle gates (Story Allies Presence Plan, package M3): two props, the drawbridge's chains and the keep's
## carved crest, call her plan (narrative/allies/ezmerelda_castle.dialogue) once, when the leader comes near them with her along and
## the plan not yet told (a prop's `call`, `approach` 6, `call_when`). The chains are for those who walk up the road, the crest for
## those the black carriage set down in the front courtyard.

const GATES := "castle_ravenloft_gates"

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	root = null
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _boot(at: Vector2i, along: bool, flags: Dictionary = {}) -> LocationView:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	if along:
		assert_true(GameState.story.add_guest("ezmerelda"))
	for f: String in flags:
		GameState.story.set_flag(f, flags[f])
	GameState.story.location = GATES
	GameState.story.positions = [at, at + Vector2i(0, 1), at + Vector2i(-1, 0), at + Vector2i(-1, 1)]
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()
	return root.get("view") as LocationView


func _prop(id: String) -> Dictionary:
	for p: Variant in Compendium.shared().get_entry("locations", GATES)["props"]:
		if str((p as Dictionary)["id"]) == id:
			return p
	return {}


func test_the_two_props_carry_the_call() -> void:
	for id: String in ["crg_drawbridge_chains", "crg_keep_crest"]:
		var p := _prop(id)
		assert_false(p.is_empty(), id)
		assert_true(str(p.get("call", "")).begins_with("allies/ezmerelda_castle:"), id + ": the call")
		assert_true(int(p.get("approach", 0)) >= 5, id + ": the approach")
		assert_eq(str(p.get("call_when", "")), "guest:ezmerelda and not flag.ezmerelda_castle_plan", id)
	assert_eq(str(_prop("crg_drawbridge_chains")["call"]), "allies/ezmerelda_castle:plan")
	assert_eq(str(_prop("crg_keep_crest")["call"]), "allies/ezmerelda_castle:plan_keep")


func test_the_plan_plays_once_at_the_drawbridge_with_her_along() -> void:
	var v: LocationView = await _boot(Vector2i(19, 31), true)
	var calls: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: calls.append(ref))
	v.leader().cell = Vector2i(18, 29)
	assert_true(LocationNpcs._check_calls(v), "within a few squares of the chains, she stops")
	assert_eq(calls, ["allies/ezmerelda_castle:plan"] as Array[String])
	assert_false(LocationNpcs._check_calls(v), "once")


func test_nothing_stirs_without_her_or_after_the_plan() -> void:
	var alone: LocationView = await _boot(Vector2i(19, 31), false)
	alone.leader().cell = Vector2i(18, 29)
	assert_false(LocationNpcs._check_calls(alone), "she is not along")
	root.queue_free()
	await _frames(2)
	var told: LocationView = await _boot(Vector2i(19, 31), true, {"ezmerelda_castle_plan": true})
	told.leader().cell = Vector2i(18, 29)
	assert_false(LocationNpcs._check_calls(told), "the plan has been told")


func test_the_plan_plays_at_the_keep_for_those_the_carriage_set_down() -> void:
	var v: LocationView = await _boot(Vector2i(19, 12), true, {"strahd_invitation": "accepted"})
	var calls: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: calls.append(ref))
	v.leader().cell = Vector2i(21, 10)
	assert_true(LocationNpcs._check_calls(v), "under the keep's crest")
	assert_eq(calls, ["allies/ezmerelda_castle:plan_keep"] as Array[String])
