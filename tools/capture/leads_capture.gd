extends Node
## NPCs that lead the party, and guests you can talk to (docs/story/leads_and_guests.md), for captures:
##   1-4  Adrian takes the party to his father's camp in the Wizard of Wines: the talk before the walk, the party strung
##        out behind him mid-walk, nearly there, and the box back at the camp
##   5    Parriwimple offers to take the party up to the hollow: the Follow now / Come back later prompt
##   6-9  Pidlwick II with the party in the high tower: his card on the HUD, its menu, the Give picker with the key,
##        and the Party screen's Talk / Give... / Send home. (`--before` hides the new buttons: how the cards looked.)
## make capture SCENE=res://tools/capture/leads_capture.tscn NAME=leads FRAMES=30 [ARGS="--before"]

var root: Node
var _before := false


func _boot(location: String, hour: int, setup: Callable) -> void:
	if root != null:
		root.queue_free()
		await get_tree().process_frame
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = location
	GameState.story.minute_of_day = hour * 60
	for c in Cutscenes.all():   # no arrival picture in the way
		Cutscenes.mark_played(str(c["id"]), GameState.story)
	setup.call(GameState.story)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _ready() -> void:
	_before = "--before" in OS.get_cmdline_user_args()
	_boot("wizard_of_wines", 10, func(_st: StoryState) -> void: pass)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func _dialogue() -> DialogueUI:
	return root.get("dialogue") as DialogueUI


func _walk() -> LocationLead:
	for c in (root.get("view") as LocationView).get_children():
		if c is LocationLead:
			return c as LocationLead
	return null


## Plays `ref` to its first menu, takes the option whose words match `pick`, and goes on until `stop` holds.
func _talk(tool: Node, ref: String, npc: String, pick: String) -> void:
	root.call("start_dialogue", ref, npc)
	for i in 30:
		await tool.call("wait_frames", 2)
		var d := _dialogue()
		if d == null or not d.visible:
			return
		if not d.options_shown.is_empty():
			for j in d.options_shown.size():
				if str((d.options_shown[j] as Dictionary)["text"]).contains(pick):
					d.call("_choose", j)
					return
			return
		d.call("_advance")


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 20)
	UiMotion.reduced = true
	(root.get("hud") as ExploreHud).close_narration()
	# 1-4: Adrian
	await _talk(tool, "wizard_of_wines/adrian:first_meeting", "adrian_martikov", "Take us to your father")
	await _shoot(tool, out + "_1_before_the_walk.png", 12)
	_dialogue().call("_advance")   # "This way, round by the trees": the walk begins
	var lead: LocationLead = null
	for i in 40:
		await tool.call("wait_frames", 2)
		lead = _walk()
		if lead != null:
			break
	var view := root.get("view") as LocationView
	for i in 600:
		await tool.call("wait_frames", 1)
		if _walk() == null or _walk()._done:
			break
		var npc_x := 99
		for shown in view._npc_shown:
			if str((shown["spec"] as Dictionary)["npc"]) == "adrian_martikov":
				npc_x = (shown["cell"] as Vector2i).x
		if npc_x <= 19 and not FileAccess.file_exists(out + "_2_mid_walk.png"):
			await _shoot(tool, out + "_2_mid_walk.png", 4)
		if npc_x <= 13 and not FileAccess.file_exists(out + "_3_nearly_there.png"):
			await _shoot(tool, out + "_3_nearly_there.png", 4)
	await tool.call("wait_frames", 40)
	await _shoot(tool, out + "_4_at_the_camp.png", 30)
	# 5: Parriwimple's offer
	await _boot("village_of_barovia", 23, func(st: StoryState) -> void:
		st.set_flag("parriwimple_befriended")
		st.set_quest_stage("the_oat_thief", "rumored"))
	await tool.call("wait_frames", 40)
	(root.get("hud") as ExploreHud).close_narration()
	await _talk(tool, "village_of_barovia/the_oat_thief:path", "parriwimple", "It's all right")
	for i in 20:
		if root.get("_prompting") != null:
			break
		_dialogue().call("_advance")
		await tool.call("wait_frames", 3)
	await _shoot(tool, out + "_5_follow_prompt.png", 20)
	var prompt := root.get("_prompting") as LeadPrompt
	if prompt != null:
		prompt.later_button.pressed.emit()
	# 6-9: Pidlwick
	await _boot("castle_ravenloft_spires", 22, func(st: StoryState) -> void:
		st.add_guest("pidlwick_ii")
		st.set_flag("pidlwick_met")
		st.set_flag("pidlwick_key_found")
		st.set_quest_stage("the_jesters_key", "found")
		st.gain_item("pidlwicks_key", 1, st.party[0]))
	await tool.call("wait_frames", 40)
	(root.get("hud") as ExploreHud).close_narration()
	await _shoot(tool, out + "_6_hud_guest_card.png", 20)
	root.call("guest_menu", "pidlwick_ii", Vector2(260, 140))
	await _shoot(tool, out + "_7_guest_menu.png", 12)
	(root.get("menu") as ContextMenu).hide()
	root.call("give_to_guest", "pidlwick_ii")
	await _shoot(tool, out + "_8_give_picker.png", 20)
	var picker := root.get("_prompting") as GiftPicker
	if picker != null:
		picker.back_button.pressed.emit()
	await tool.call("wait_frames", 10)
	root.call("open_screen", "party", 0)
	await tool.call("wait_frames", 12)
	if _before:
		for n in ["Talk_pidlwick_ii", "Give_pidlwick_ii"]:
			var b := (root.get("screen") as Node).find_child(n, true, false) as Button
			if b != null:
				b.visible = false
	await _shoot(tool, out + "_9_party_screen.png", 12)
