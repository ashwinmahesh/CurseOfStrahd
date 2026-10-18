extends TestCase
## The five people the story has lead the party (docs/story/leads_and_guests.md), played in their real places: Adrian
## takes the party to his father's camp, Lupu to the study window, Parriwimple up to the hollow, Zuleika into the den and
## Bluto to the Vistani camp. The first two walk on the same map; the others ask "follow now or come back later" first.
## Each keeps what the conversation does right, whether the party goes or not, and never leaves the box hidden.

var root: Node


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The game at `location`, with a party of four at `level` and the hour `hour`; `setup` puts the story where it must be.
func _boot(location: String, level: int, hour: int, setup: Callable) -> void:
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = location
	GameState.story.minute_of_day = hour * 60
	setup.call(GameState.story)
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()


func _view() -> LocationView:
	return root.get("view") as LocationView


func _dialogue() -> DialogueUI:
	return root.get("dialogue") as DialogueUI


func _walk() -> LocationLead:
	for c in _view().get_children():
		if c is LocationLead:
			return c as LocationLead
	return null


func _cell_of(npc_id: String) -> Vector2i:
	for shown in _view()._npc_shown:
		if str((shown["spec"] as Dictionary)["npc"]) == npc_id:
			return shown["cell"] as Vector2i
	var tok: Variant = _view()._staged.get(npc_id)
	if tok is Node3D:
		return _view().grid.cell_at((tok as Node3D).position)
	return Vector2i(-1, -1)


func _said() -> String:
	var d := _dialogue()
	return str((d.get("_text") as RichTextLabel).text) if d != null else ""


## Starts `ref` and plays it, taking the options whose words match `picks` in order, until the box steps back (a lead), or ends.
func _to_the_lead(ref: String, npc: String, picks: Array[String]) -> void:
	root.call("start_dialogue", ref, npc)
	await _frames(1)
	var left := picks.duplicate()
	for i in 80:
		var d := _dialogue()
		if d == null or not d.visible:
			return
		if not d.options_shown.is_empty():
			var want := str(left.pop_front()) if not left.is_empty() else ""
			var idx := -1
			for j in d.options_shown.size():
				var o := d.options_shown[j] as Dictionary
				if want != "" and str(o["text"]).contains(want) and bool(o["enabled"]):
					idx = j
					break
			if idx < 0:
				fail("no option '%s' among %s" % [want, d.options_shown.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]))])
				return
			d.call("_choose", idx)
		else:
			d.call("_advance")
		await _frames(1)


func _run_walk(seconds: float = 90.0) -> void:
	var lead := _walk()
	var t := 0.0
	while lead != null and is_instance_valid(lead) and not lead._done and t < seconds:
		lead._process(0.05)
		if is_instance_valid(lead) and not lead._done:
			_view()._process(0.05)
		t += 0.05
	await _frames(3)


## The rest of the conversation, through to its end.
func _finish() -> void:
	for i in 60:
		var d := _dialogue()
		if d == null:
			break
		if not d.options_shown.is_empty():
			d.call("_choose", d.options_shown.size() - 1)
		else:
			d.call("_advance")
		await _frames(1)
	await _frames(2)


func _near(a: Vector2i, b: Vector2i, within: int) -> bool:
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) <= within


func test_adrian_takes_the_party_to_his_fathers_camp() -> void:
	await _boot("wizard_of_wines", 3, 10, func(st: StoryState) -> void: st.set_flag("vallaki_arrived"))
	assert_eq(_cell_of("adrian_martikov"), Vector2i(23, 27), "he waits at the foot of the lane")
	await _to_the_lead("wizard_of_wines/adrian:first_meeting", "adrian_martikov", ["Take us to your father"])
	assert_true(_walk() != null, "the party follows him")
	await _run_walk()
	assert_eq(_cell_of("adrian_martikov"), Vector2i(10, 27), "to the camp, where his next place has him")
	assert_true(_near(_view().leader().cell, Vector2i(10, 27), 3))
	assert_true(_dialogue().visible)
	assert_true(_said().contains("walk slowly") or _said().contains("mile"), _said())
	await _finish()
	assert_eq(_cell_of("adrian_martikov"), Vector2i(10, 27), "and he is there once the talk is over")
	assert_true(bool(GameState.story.get_flag("adrian_met", false)))


func test_lupu_leads_round_to_the_study_window_by_night_and_by_day() -> void:
	for hour: int in [23, 12]:
		GameState.reset()
		if root != null and is_instance_valid(root):
			root.queue_free()
			await _frames(2)
		await _boot("village_of_barovia", 3, hour, func(st: StoryState) -> void:
			st.set_flag("lupu_friend")
			st.set_quest_stage("the_burgomasters_hound", "rumored"))
		assert_eq(_cell_of("lupu"), Vector2i(7, 7), "Lupu is by the mansion step (hour %d)" % hour)
		await _to_the_lead("village_of_barovia/the_burgomasters_hound:lupu", "lupu", ["Follow where he's looking"])
		assert_true(_walk() != null, "the party follows the hound (hour %d)" % hour)
		await _run_walk()
		assert_eq(_cell_of("lupu"), Vector2i(12, 3), "to the mansion's side wall under the study window (hour %d)" % hour)
		assert_true(_near(_view().leader().cell, Vector2i(12, 3), 3), "the party stands behind him (at %s)" % _view().leader().cell)
		assert_eq(GameState.story.quest_stage("the_burgomasters_hound"), "asked")
		assert_true(_said().contains("study window"), _said())
		await _finish()
		assert_eq(_view().loc_id, "village_of_barovia")


func test_parriwimple_takes_the_party_up_to_the_hollow_or_waits() -> void:
	for follow: bool in [false, true]:
		GameState.reset()
		if root != null and is_instance_valid(root):
			root.queue_free()
			await _frames(2)
		await _boot("village_of_barovia", 2, 23, func(st: StoryState) -> void:
			st.set_flag("parriwimple_befriended")
			st.set_quest_stage("the_oat_thief", "rumored"))
		assert_eq(_cell_of("parriwimple"), Vector2i(38, 4), "he is on the north path by night")
		await _to_the_lead("village_of_barovia/the_oat_thief:path", "parriwimple", ["It's all right"])
		var prompt := root.get("_prompting") as LeadPrompt
		assert_true(prompt != null, "up to the hollow is another place: it asks")
		assert_true(prompt.place.contains("Hollow"), prompt.place)
		if not follow:
			prompt.later_button.pressed.emit()
			await _frames(2)
			assert_eq(_view().loc_id, "village_of_barovia", "come back later: still in the village")
			assert_true(bool(GameState.story.get_flag("hollow_known", false)), "what he told them stays told")
			assert_eq(_cell_of("parriwimple"), Vector2i(38, 4), "and he waits on the path")
			await _finish()
			assert_true(_dialogue() == null)
			continue
		prompt.follow_button.pressed.emit()
		await _frames(1)
		assert_true(_walk() != null, "they follow him to the way out")
		await _run_walk()
		assert_eq(_view().loc_id, "woodcutters_hollow", "and up into the pines")
		assert_false(_view().in_combat)
		assert_true(GameState.story.last_check, "the party went")
		await _finish()   # nothing more to say once they are there: the talk ends, and he steps out of the scene
		assert_true(_dialogue() == null)
		assert_true(_view()._staged.is_empty())
		assert_eq(ModeController.mode, ModeController.Mode.EXPLORATION)


func test_zuleika_takes_the_party_into_the_den_or_not() -> void:
	for follow: bool in [false, true]:
		GameState.reset()
		if root != null and is_instance_valid(root):
			root.queue_free()
			await _frames(2)
		await _boot("werewolf_den", 8, 14, func(_st: StoryState) -> void: pass)
		await _to_the_lead("werewolf_den/zuleika:start", "zuleika_toranescu", ["What do you want from strangers", "We'll free Emil"])
		assert_true(bool(GameState.story.get_flag("zuleika_vouched", false)), "the pact is made before the walk")
		var prompt := root.get("_prompting") as LeadPrompt
		assert_true(prompt != null, "into the caves is another place: it asks")
		if not follow:
			prompt.later_button.pressed.emit()
			await _frames(2)
			assert_eq(_view().loc_id, "werewolf_den")
			assert_true(_said().contains("Emil is in the alcove"), "the key and the directions follow either way: %s" % _said())
			await _finish()
			assert_true(GameState.story.party_has_item("emil_key") or bool(GameState.story.get_flag("emil_key_found", false)))
			continue
		prompt.follow_button.pressed.emit()
		await _frames(1)
		assert_true(_walk() != null, "they follow her to the cave mouth")
		await _run_walk()
		assert_eq(_view().loc_id, "werewolf_den_caves")
		assert_false(_view().in_combat, "no fight at the door: she vouched for them first")
		assert_true(_near(_cell_of("zuleika_toranescu"), _view().leader().cell, 4), "she is beside them, at her shrine (at %s, they're at %s)" % [_cell_of("zuleika_toranescu"), _view().leader().cell])
		assert_true(_dialogue() != null and _dialogue().visible, "the box is back")
		assert_true(_said().contains("Emil is in the alcove"), _said())
		await _finish()
		assert_eq(ModeController.mode, ModeController.Mode.EXPLORATION)


func test_bluto_goes_to_the_vistani_camp_or_stays_for_the_menu() -> void:
	for follow: bool in [false, true]:
		GameState.reset()
		if root != null and is_instance_valid(root):
			root.queue_free()
			await _frames(2)
		await _boot("lake_zarovich", 4, 10, func(st: StoryState) -> void: st.set_flag("arabelle_lost"))
		assert_eq(_cell_of("bluto"), Vector2i(22, 13), "Bluto is at his nets")
		await _to_the_lead("lake_zarovich/landing:bluto_nets", "bluto", ["taking you to the Vistani camp"])
		var prompt := root.get("_prompting") as LeadPrompt
		assert_true(prompt != null, "the Vistani camp is another place: it asks")
		assert_true(prompt.place.contains("Vistani"), prompt.place)
		if not follow:
			prompt.later_button.pressed.emit()
			await _frames(2)
			assert_eq(_view().loc_id, "lake_zarovich")
			assert_false(GameState.story.get_flag("bluto_fate", false) is String and str(GameState.story.get_flag("bluto_fate", "")) != "",
				"nothing is settled until they go")
			assert_true(_dialogue().visible)
			assert_false(_dialogue().options_shown.is_empty(), "back at his menu, with its other ways: %s" % _said())
			continue
		prompt.follow_button.pressed.emit()
		await _frames(3)
		assert_eq(_view().loc_id, "vallaki_vistani_camp", "no road from the shore: they are simply there")
		assert_true(_view()._staged.has("bluto"))
		assert_true(_said().contains("Luvash"), _said())
		await _finish()
		assert_eq(str(GameState.story.get_flag("bluto_fate", "")), "vistani")
		assert_true(bool(GameState.story.get_flag("lake_boat_ready", false)))
