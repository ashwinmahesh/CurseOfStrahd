class_name TutorialSession
extends Node3D
## A disposable practice session. Never enters LocationFights or the campaign's save/achievement paths.
## Existing screens use Dice.roller, so its reference is scoped to our private roller and restored on every exit.

signal finished(start_campaign: bool)

const EXPLORATION_IDS: Array[String] = ["welcome", "explore", "sheet", "check", "conversation", "inventory", "rest"]
const EXPLORE_TARGET := Vector2i(8, 12)
const CONVERSATION_REF := "tutorial/conversation:start"
const MENTOR_CELL := Vector2i(14, 12)
const PRACTICE_PLACE := "svalich_roadhouse"
const CHEST_CELL := Vector2i(12, 12)
const CHECK_CELL := Vector2i(13, 13)

var pending_campaign := false
var lesson_index := 0
var lesson_complete := false
var coach: TutorialCoach
var location: LocationView
## Existing exploration screen/controller helpers expect the same host names as GameRoot.
var view: LocationView:
	get:
		return location
var hud: ExploreHud
var glow: HoverGlow
var pad: PadExplore
var combat: TutorialCombat
var practice: StoryState
var roller := DiceRoller.new(20261009)
var screen: CanvasLayer
var loot: LootWindow
var dialogue: DialogueUI
var last_check: D20Test
var _guide_close: Button
var _guide_controls: Array[Control] = []
var _guide_action := ""
var _guide_step := ""
var _sheet_step := 0
var _stage: Node3D
var _saved_dice: DiceRoller
var _saved_mode := ModeController.Mode.EXPLORATION
var _saved_paused := false
var _saved_music := ""
var _restored := false
var _leaving := false
var _changing := false
var _clearing := false
var _screen_kind := ""
var _practice_loot_taken := false
var _opened_inventory := false


func _ready() -> void:
	name = "TutorialSession"
	InputActions.ensure()
	UiScale.playing(self)
	_saved_dice = Dice.roller
	_saved_mode = ModeController.mode
	_saved_paused = get_tree().paused
	_saved_music = Audio.mood
	Dice.roller = roller
	get_tree().paused = false
	coach = TutorialCoach.new()
	add_child(coach)
	coach.event_filter = _guide_input
	coach.next_requested.connect(next_lesson)
	coach.retry_requested.connect(retry_lesson)
	coach.skip_requested.connect(skip_lesson)
	coach.exit_requested.connect(leave_tutorial)
	start_lesson(0)


func lesson_id() -> String:
	if lesson_index < EXPLORATION_IDS.size():
		return EXPLORATION_IDS[lesson_index]
	var combat_index := lesson_index - EXPLORATION_IDS.size()
	if combat_index < TutorialCombat.LESSON_IDS.size():
		return TutorialCombat.LESSON_IDS[combat_index]
	return "complete"


func lesson_count() -> int:
	return EXPLORATION_IDS.size() + TutorialCombat.LESSON_IDS.size() + 1


func start_lesson(index: int) -> void:
	if _leaving or not is_inside_tree():
		return
	_changing = true
	_clear_stage()
	lesson_index = clampi(index, 0, lesson_count() - 1)
	lesson_complete = false
	_guide_action = ""
	_guide_step = ""
	_sheet_step = 0
	_guide_controls.clear()
	last_check = null
	_practice_loot_taken = false
	_opened_inventory = false
	_stage = Node3D.new()
	_stage.name = "PracticeStage"
	add_child(_stage)
	coach.set_chrome_visible(true)
	coach.clear_action()
	var id := lesson_id()
	if id == "complete":
		_build_exploration()
		coach.show_finished(pending_campaign)
		lesson_complete = true
	elif id in TutorialCombat.LESSON_IDS:
		ModeController.force(ModeController.Mode.COMBAT)
		Audio.play_music("combat")
		combat = TutorialCombat.new()
		combat.configure(id, roller)
		combat.objective_met.connect(_complete)
		combat.menu_requested.connect(_tutorial_menu)
		combat.sheet_requested.connect(_combat_sheet)
		_stage.add_child(combat)
		coach.present(combat.description(), lesson_index, lesson_count())
	else:
		_build_exploration()
		coach.present(_exploration_lesson(id), lesson_index, lesson_count())
		match id:
			"welcome":
				_complete("Take your time. Each exercise can be repeated or skipped from the Tutorial menu.")
			"explore":
				coach.set_action("Walk to the highlighted square", _guided_world_action)
			"sheet":
				coach.set_action("Open character sheet", open_screen.bind("sheet", 0))
			"check":
				coach.set_action("Examine the practice ledger", _examine_ledger)
			"conversation":
				coach.set_action("Talk to Ismark", _approach_mentor)
			"inventory":
				coach.set_action("Open the practice chest", interact_practice_object)
			"rest":
				for ch in practice.party:
					ch.hp = maxi(1, ch.max_hp() / 2)
				_refresh()
				coach.set_action("Open Rest", open_screen.bind("rest", 0))
	coach.exit_button.text = "Start campaign instead" if pending_campaign else "Return to title"
	_changing = false


func next_lesson() -> void:
	if _changing or _leaving or not lesson_complete:
		return
	if lesson_id() == "complete":
		leave_tutorial()
		return
	_changing = true
	start_lesson.call_deferred(lesson_index + 1)


func retry_lesson() -> void:
	if _changing or _leaving:
		return
	_changing = true
	start_lesson.call_deferred(lesson_index)


func skip_lesson() -> void:
	if _changing or _leaving:
		return
	if lesson_id() == "complete":
		leave_tutorial()
		return
	_changing = true
	start_lesson.call_deferred(lesson_index + 1)


func leave_tutorial() -> void:
	if _leaving:
		return
	_leaving = true
	_clear_stage()
	_restore_globals()
	finished.emit(pending_campaign)


func _exit_tree() -> void:
	_restore_globals()


func _restore_globals() -> void:
	if _restored or _saved_dice == null:
		return
	_restored = true
	Dice.roller = _saved_dice
	ModeController.force(_saved_mode)
	if is_inside_tree():
		get_tree().paused = _saved_paused
	Audio.play_music(_saved_music)
	if pad != null:
		pad.clear()


func _clear_stage() -> void:
	_clearing = true
	_dismiss_dialogue()
	close_screen()
	if loot != null and is_instance_valid(loot):
		loot.queue_free()
	loot = null
	if pad != null:
		pad.clear()
	if glow != null:
		glow.clear()
	pad = null
	if _stage != null and is_instance_valid(_stage):
		_stage.process_mode = Node.PROCESS_MODE_DISABLED
		remove_child(_stage)
		_stage.queue_free()
	_stage = null
	location = null
	hud = null
	glow = null
	combat = null
	_clearing = false


func _build_exploration() -> void:
	ModeController.force(ModeController.Mode.EXPLORATION)
	Audio.play_music("road")
	practice = StoryState.new()
	practice.party.append(Pregens.build("ilse_varga", 1))
	practice.party.append(Pregens.build("liriel_dawnsong", 1))
	practice.options["difficulty"] = "story" # a guaranteed safe rest in this practice yard
	practice.minute_of_day = 12 * 60
	location = LocationView.create(PRACTICE_PLACE, practice, null, roller, "default")
	location.loc["name"] = "Practice at the Grey Goose"
	location.loc["text"] = ""
	location.loc["narration"] = {}
	location.loc["spawns"] = {"default": [10, 12]}
	for key: String in ["encounters", "exits", "areas", "npcs", "traps", "doors"]:
		location.loc[key] = []
	for prop: Dictionary in location.loc.get("props", []):
		prop.erase("dialogue")
		prop.erase("flag")
		prop.erase("item")
	location.loc["containers"] = [{"id": "tutorial_supplies", "cell": [CHEST_CELL.x, CHEST_CELL.y],
		"label": "Practice supplies", "model": "chest", "items": [{"id": "potion_of_healing", "qty": 2}], "gold": 2}]
	(location.loc["props"] as Array).append({"id": "tutorial_ledger", "kind": "examine",
		"cell": [CHECK_CELL.x, CHECK_CELL.y], "model": "ledger", "label": "Practice ledger",
		"dialogue": "tutorial:check"})
	if lesson_id() == "conversation":
		location.loc["npcs"] = [{"npc": "ismark", "cell": [MENTOR_CELL.x, MENTOR_CELL.y], "dialogue": CONVERSATION_REF, "facing": "west"}]
	location.loot_opened.connect(_open_loot)
	location.dialogue_requested.connect(func(ref: String, _npc: String) -> void:
		if ref == "tutorial:check":
			roll_practice_check()
		elif ref == CONVERSATION_REF:
			start_practice_conversation())
	_stage.add_child(location)
	# A preference for turn-based exploration must not prevent learning ordinary walking in this safe yard.
	if location.planning:
		LocationPlan.stop(location)
	hud = ExploreHud.new()
	_stage.add_child(hud)
	hud.build(practice)
	hud.show_location(location)
	hud.command.connect(_command)
	hud.leader_picked.connect(func(index: int) -> void:
		location.set_leader(index)
		_refresh())
	hud.sheet_requested.connect(func(index: int) -> void: open_screen("sheet", index))
	location.toast.connect(hud.toast)
	location.check_rolled.connect(hud.roll)
	glow = HoverGlow.new()
	pad = PadExplore.new(self)
	_refresh()


func _exploration_lesson(id: String) -> Dictionary:
	match id:
		"welcome":
			return {"read_only": true, "title": "Your first adventure", "body": "You choose what the heroes try; the game rolls dice when the outcome is uncertain. A party is your team, and you control every member.",
				"objective": "Learn at your own pace in a safe practice session.",
				"details": "No D&D experience is needed. We will explore, read a character, try a check, collect supplies, rest, then practise combat. Your chosen campaign party and difficulty are waiting. Training items, wounds and dice never carry into a campaign."}
		"explore":
			return {"title": "Move through the world", "body": "Select the highlighted square to walk there. In the campaign you can click open ground, use {walk}, or move with the controller left stick. Your companions follow the leader.",
				"objective": "Walk to the highlighted square.",
				"details": "There are no turns or movement costs while freely exploring. In combat you will have a movement allowance. Turn the camera with {camera_rotate_left}/{camera_rotate_right}, or the right stick on a controller. The portraits show who is travelling; {cycle_leader} changes the leader."}
		"sheet":
			return {"title": "Meet your character", "body": "Hit Points (HP) show how much harm a hero can take. Armor Class (AC) is the number an attack must meet to hit. Open the sheet and inspect the numbers.",
				"objective": "Open Character, inspect the sheet, then close it to return.",
				"details": "The six abilities describe strengths: Strength, Dexterity, Constitution, Intelligence, Wisdom and Charisma. Their modifiers add to relevant rolls. Proficiency adds a training bonus to skills, weapons and saves you know. Hover or use Explain on a number to see how it is calculated. The sheet opens with {open_sheet}; Escape/Back returns."}
		"check":
			return {"title": "Try something uncertain", "body": "Can your hero make sense of a faded ledger? This is an Investigation check: roll a twenty-sided die (d20), add the skill bonus and compare the total with Difficulty Class (DC) 10.",
				"objective": "Examine the highlighted ledger and read your actual roll.",
				"details": "Meeting the DC succeeds. A lower result fails this attempt, not the tutorial. Ability checks solve uncertain tasks outside attacks. Advantage rolls two d20s and keeps the higher; disadvantage keeps the lower. If both apply, they cancel. Bonuses and circumstances matter as well as luck."}
		"conversation":
			return {"title": "Talk your way through a problem", "body": "Talk to Ismark and choose what your hero says or notices. Persuasion asks someone to agree; Insight tries to understand their intentions. Choices show the skill, DC and speaking hero's bonus.",
				"objective": "Choose Persuasion or Insight, read the real roll, then finish the conversation.",
				"details": "Ask an ordinary question without rolling. Use the speaker button (Tab on keyboard) to choose another hero before a check; a different hero may have a better bonus. Success and failure lead to different replies, and both finish this lesson. Failed social attempts normally cannot simply be repeated; Repeat lesson resets this practice only. On a controller, use the normal conversation controls; Start opens tutorial options."}
		"inventory":
			return {"title": "Collect and inspect supplies", "body": "Click the highlighted chest, take its supplies, then open Inventory. Potions heal; weapons and armor must be equipped. Hover an item or use Explain to learn its effects.",
				"objective": "Take supplies from the chest, then open and close Inventory.",
				"details": "Items belong to individual heroes; gold belongs to the party. The loot window lets you choose who receives an item. Inventory opens with {open_inventory}; equipment slots show what is worn or held. You can give items to companions and keep useful consumables ready for combat."}
		"rest":
			return {"title": "Recover between encounters", "body": "Your practice party starts this exercise wounded. Open Rest and take a Long Rest, then close the screen. Watch their HP return.",
				"objective": "Complete a Long Rest through the Rest screen.",
				"details": "A Short Rest takes an hour: spend Hit Point Dice to heal, and some features recover. A Long Rest takes eight hours and restores HP, spell slots and most resources. Prepared casters can change spells afterward. The campaign can restrict or interrupt rests; this practice rest is safe. You cannot take repeated Long Rests immediately."}
	return {}


func _complete(feedback: String) -> void:
	if lesson_complete or _leaving or _clearing:
		return
	lesson_complete = true
	coach.set_complete(feedback)


func _process(_delta: float) -> void:
	if _leaving or _changing or coach == null:
		return
	_update_guidance()
	var blocked := coach.menu_open or lesson_complete or screen != null or loot != null or dialogue != null
	var pause_world := coach.menu_open or screen != null or loot != null or dialogue != null or (lesson_complete and combat == null)
	if _stage != null:
		_stage.process_mode = Node.PROCESS_MODE_DISABLED if pause_world else Node.PROCESS_MODE_INHERIT
	if combat != null:
		combat.view.input_locked = blocked
		if blocked:
			combat.view.hud.hide_tooltip()
		return
	if location == null:
		return
	location.rig.pad_look = false
	if blocked:
		return
	if lesson_id() == "explore" and location.leader().cell == EXPLORE_TARGET:
		_complete("You moved the party to the highlighted square. In the campaign, click a person or object to approach and interact.")


func _exploration_anchor() -> Rect2:
	if lesson_id() == "conversation":
		var point := location.rig.camera.unproject_position(location.board.cell_center(MENTOR_CELL) + Vector3(0, 0.8, 0))
		return Rect2(point - Vector2(40, 54), Vector2(80, 108))
	if lesson_id() in ["check", "inventory"]:
		if lesson_id() == "inventory" and _practice_loot_taken:
			return _hud_anchor("inventory")
		var cell := CHECK_CELL if lesson_id() == "check" else CHEST_CELL
		var point := location.rig.camera.unproject_position(location.board.cell_center(cell) + Vector3(0, 0.5, 0))
		return Rect2(point - Vector2(40, 42), Vector2(80, 84))
	if lesson_id() == "sheet":
		return _hud_anchor("sheet")
	if lesson_id() == "rest":
		return _hud_anchor("rest")
	return Rect2()


func _hud_anchor(key: String) -> Rect2:
	var button := hud._bar_buttons.get(key) as Control
	return button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size) if button != null else Rect2()


func _input(event: InputEvent) -> void:
	if _leaving or _changing:
		return
	# Start always reaches tutorial options even while the combat view owns the other gamepad actions.
	if event.is_action_pressed(&"pause_menu"):
		_tutorial_menu()
		get_viewport().set_input_as_handled()
	elif coach.menu_open and event.is_action_pressed(&"ui_cancel"):
		coach.close_menu()
		_sync_modal_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and (lesson_complete or screen != null or loot != null or dialogue != null):
		_tutorial_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _changing or loot != null or dialogue != null:
		return
	if screen != null:
		if event.is_action_pressed(&"ui_cancel"):
			close_screen()
			get_viewport().set_input_as_handled()
		return
	if combat != null:
		return # CombatView owns cancel/targeting and emits menu_requested.
	if event.is_action_pressed(&"ui_cancel"):
		_tutorial_menu()
		get_viewport().set_input_as_handled()
		return
	if coach.menu_open or lesson_complete or combat != null or location == null:
		return
	if event.is_action_pressed(&"combat_confirm"):
		_guided_world_action()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if coach.allows_point(event.position):
			_guided_world_action()


func _tutorial_menu() -> void:
	if _leaving:
		return
	if combat != null and combat.view.hud.menu_open():
		combat.view.hud._menu.hide()
	if coach.menu_open:
		coach.close_menu()
	else:
		coach.show_menu()
	_sync_modal_menu()


func _command(command: String) -> void:
	if screen != null or loot != null or dialogue != null or _leaving:
		return
	var expected := {"sheet": "sheet", "inventory": "inventory", "rest": "rest"}
	if command != str(expected.get(lesson_id(), "")):
		return
	if lesson_id() == "inventory" and not _practice_loot_taken:
		return
	match command:
		"sheet", "inventory", "rest", "journal":
			open_screen(command, 0)
		"search":
			if lesson_id() == "check":
				_examine_ledger()
			else:
				location.search()
		"sneak":
			location.set_sneaking(not location.sneaking)
		"split":
			location.solo = not location.solo
		"plan":
			location.toggle_plan()
		"plan_round":
			location.next_round()
		_:
			_tutorial_menu()
	_refresh()


func open_travel(_forced: bool = false) -> void:
	hud.toast("The campaign map connects places. This practice session stays in the yard.")


func open_world_menu(cell: Vector2i, _at: Vector2) -> void:
	if location != null:
		location.click(cell)


func _examine_ledger() -> void:
	if location != null:
		location.click(CHECK_CELL)


func roll_practice_check() -> void:
	if lesson_id() != "check" or lesson_complete or location == null:
		return
	last_check = location.leader().creature.roll_check(roller, &"investigation", 10)
	var result := "Success: you piece together the delivery route." if last_check.success else "This attempt fails: the faded writing remains unclear. A failed roll is a normal part of an adventure."
	_complete("d20 %d %+d skill bonus = %d against DC %d. %s" % [last_check.kept, last_check.modifier, last_check.total, last_check.target, result])


func interact_practice_object() -> void:
	if location != null:
		location.click(CHEST_CELL)


func _open_loot(container_id: String, items: Array, gold: float) -> void:
	if loot != null or screen != null or dialogue != null or _leaving:
		return
	loot = LootWindow.new()
	add_child(loot)
	coach.set_chrome_visible(false)
	loot.closed.connect(func() -> void:
		if _clearing or _leaving:
			return
		_practice_loot_taken = loot.items.is_empty()
		loot = null
		coach.set_chrome_visible(true)
		if lesson_id() == "inventory" and _practice_loot_taken:
			coach.set_action("Open Inventory", open_screen.bind("inventory", 0))
		_refresh())
	loot.show_loot(practice, container_id, items, gold, location)


func open_screen(kind: String, index: int = 0) -> void:
	if kind == "menu":
		_tutorial_menu()
		return
	if _leaving or loot != null or dialogue != null:
		return
	close_screen()
	match kind:
		"sheet":
			screen = CharacterSheetScreen.new()
		"inventory":
			screen = InventoryScreen.new()
		"rest":
			if combat != null:
				return
			screen = RestScreen.new()
		"journal":
			screen = JournalScreen.new()
		_:
			return
	_screen_kind = kind
	add_child(screen)
	if screen is CharacterSheetScreen and combat != null:
		(screen as CharacterSheetScreen).in_fight = true
	screen.call("open", self, practice, index)
	if kind == "sheet" and lesson_id() == "sheet":
		screen.set_process_unhandled_input(false)
	_add_guided_close()
	if kind == "inventory":
		_opened_inventory = true
	coach.set_chrome_visible(false)


func _combat_sheet(who: Character) -> void:
	practice = StoryState.new()
	for actor in combat.e.combatants:
		if actor.side == &"party" and actor.creature is Character:
			practice.party.append(actor.creature as Character)
	if who in practice.party:
		open_screen("sheet", practice.party.find(who))


func close_screen() -> void:
	if screen == null:
		return
	var kind := _screen_kind
	_guide_close = null
	screen.queue_free()
	screen = null
	_screen_kind = ""
	if coach != null:
		coach.set_chrome_visible(true)
	if _clearing or _leaving:
		return
	if lesson_id() == "sheet" and kind == "sheet" and _sheet_step >= 2:
		coach.present(_exploration_lesson("sheet"), lesson_index, lesson_count())
		_complete("You found the sheet. HP and AC help you judge danger; the ability and skill bonuses explain what this hero is good at.")
	elif lesson_id() == "inventory" and _opened_inventory and _practice_loot_taken:
		_complete("The supplies are yours to inspect and equip. Training items stay here; your campaign inventory is separate.")
	elif lesson_id() == "rest" and practice.flags.has(RestRules.DONE_AT):
		_complete("Eight hours passed in practice and the party recovered. Before a dangerous journey, check HP, spell slots and prepared spells.")
	_refresh()


## A reusable capture/test action; the player's exercise uses the same RestScreen button.
func practice_rest() -> void:
	if lesson_id() != "rest" or lesson_complete:
		return
	if not screen is RestScreen:
		open_screen("rest", 0)
	(screen as RestScreen)._long_rest("safe")


func _refresh() -> void:
	if location != null and hud != null:
		location.refresh_party()
		hud.refresh("Practice at the Grey Goose", location.sneaking, location.solo, location.planning)


func _approach_mentor() -> void:
	if location != null and dialogue == null:
		location.click(MENTOR_CELL)


## Campaign dialogue controls, speaker selection, dice checks and branching, with private practice state.
func start_practice_conversation() -> void:
	if lesson_id() != "conversation" or lesson_complete or dialogue != null or screen != null or loot != null or _leaving:
		return
	ModeController.force(ModeController.Mode.DIALOGUE)
	glow.clear()
	hud.visible = false
	coach.set_chrome_visible(false)
	var runner := DialogueRunner.new(practice, roller)
	runner.npc_id = "ismark"
	dialogue = DialogueUI.new()
	add_child(dialogue)
	dialogue.ended.connect(_practice_conversation_ended)
	if not dialogue.play(runner, CONVERSATION_REF):
		_dismiss_dialogue()
		ModeController.force(ModeController.Mode.EXPLORATION)
		hud.visible = true
		coach.set_chrome_visible(true)
		hud.toast("The practice conversation could not open. Repeat or skip this lesson to continue.")


func _practice_conversation_ended(_combat: String) -> void:
	if dialogue == null:
		return
	last_check = dialogue.runner._last_check.get("test") as D20Test
	dialogue = null
	if _leaving or _clearing:
		return
	ModeController.force(ModeController.Mode.EXPLORATION)
	hud.visible = true
	coach.set_chrome_visible(true)
	if bool(practice.get_flag("tutorial_dialogue_checked", false)) and last_check != null:
		var skill := str(practice.get_flag("tutorial_dialogue_skill", "skill")).capitalize()
		var outcome := "succeeded" if last_check.success else "failed"
		_complete("Your %s check %s: d20 %d %+d = %d against DC %d. You saw the resulting reply. Both outcomes are part of play, and this practice is complete." % [skill, outcome, last_check.kept, last_check.modifier, last_check.total, last_check.target])
	else:
		coach.set_action("Talk to Ismark", _approach_mentor)
	_refresh()


func _dismiss_dialogue() -> void:
	if dialogue == null:
		return
	VoiceOver.stop()
	if is_instance_valid(dialogue):
		dialogue.process_mode = Node.PROCESS_MODE_DISABLED
		dialogue.queue_free()
	dialogue = null




static func _guide_button(owner: Node, caption: String) -> Button:
	if owner == null:
		return null
	for node in owner.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == caption and not button.disabled and _guide_rect(button).has_area():
			return button
	return null


static func _guide_rect(control: Control) -> Rect2:
	if not is_instance_valid(control) or control.is_queued_for_deletion() or not control.is_visible_in_tree():
		return Rect2()
	var rect := control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor.is_queued_for_deletion() or (ancestor is CanvasLayer and not (ancestor as CanvasLayer).visible):
			return Rect2()
		if ancestor is Control and (ancestor as Control).clip_contents:
			var parent := ancestor as Control
			rect = rect.intersection(parent.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, parent.size))
		ancestor = ancestor.get_parent()
	return rect.intersection(control.get_viewport().get_visible_rect())


func _guide_result(step: String, hint: String, controls: Array[Control], spots: Array[Rect2] = []) -> Dictionary:
	var rects: Array[Rect2] = spots.duplicate()
	var live: Array[Control] = []
	for control in controls:
		var rect := _guide_rect(control)
		if rect.has_area() and not (control is BaseButton and (control as BaseButton).disabled):
			live.append(control)
			rects.append(rect)
	return {"step": step, "hint": hint, "rects": rects, "controls": live}


func _practice_cell_rect(cell: Vector2i, height: float = 0.1) -> Rect2:
	if location == null:
		return Rect2()
	var point := location.rig.camera.unproject_position(location.board.cell_center(cell) + Vector3(0, height, 0))
	return Rect2(point - Vector2(38, 32), Vector2(76, 64))


func _add_guided_close() -> void:
	var panel := screen.get_meta(&"frame_panel", null) as PanelContainer
	if panel == null:
		return
	for child in panel.get_children():
		if child is VBoxContainer:
			var footer := HBoxContainer.new()
			footer.alignment = BoxContainer.ALIGNMENT_END
			_guide_close = UiKit.button("Back to practice", close_screen, 15)
			_guide_close.name = "TutorialBack"
			footer.add_child(_guide_close)
			child.add_child(footer)
			return


func exploration_guide_state() -> Dictionary:
	if coach.menu_open:
		return _guide_result("tutorial_menu", "Choose an option or return to the lesson.", [])
	if lesson_complete:
		return _guide_result("continue", "Select Continue when you are ready.", [coach.next_button])
	if dialogue != null:
		if bool(dialogue.get("_waiting_continue")):
			var state := _guide_result("dialogue_continue", "Read the line or check result, then select Continue.", [dialogue.find_child("Continue", true, false) as Button])
			state["read_rects"] = _dialogue_read_rects()
			return state
		var choices: Array[Control] = []
		for button in dialogue.get("_option_buttons") as Array[Button]:
			choices.append(button)
		var speaker := dialogue.find_child("Speaker", true, false) as Button
		if speaker != null:
			choices.append(speaker)
		var state := _guide_result("dialogue_choice", "Choose what to say or notice. Persuasion and Insight roll checks.", choices)
		state["read_rects"] = _dialogue_read_rects()
		return state
	if loot != null:
		return _guide_result("take_all", "Select Take all to collect the practice supplies.", [_guide_button(loot, "Take all (Space)")])
	if screen != null:
		if screen is CharacterSheetScreen and lesson_id() == "sheet":
			return _sheet_guide_state()
		if screen is RestScreen and not practice.flags.has(RestRules.DONE_AT):
			return _guide_result("long_rest", "Select Take a Long Rest. This practice rest is safe.", [_guide_button(screen, "Take a Long Rest (8 hours)")])
		return _guide_result("close_screen", "Read the screen, then select Back to practice.", [_guide_close])
	match lesson_id():
		"explore":
			return _guide_result("walk_target", "Click the highlighted square, or press {combat_confirm} to walk there.", [], [_practice_cell_rect(EXPLORE_TARGET)])
		"sheet":
			return _guide_result("open_sheet", "Select the highlighted Character button.", [hud._bar_buttons.get("sheet") as Control])
		"check":
			return _guide_result("examine_ledger", "Select the highlighted ledger.", [], [_exploration_anchor()])
		"conversation":
			return _guide_result("talk_mentor", "Select Ismark to begin the conversation.", [], [_exploration_anchor()])
		"inventory":
			if _practice_loot_taken:
				return _guide_result("open_inventory", "Select the highlighted Inventory button.", [hud._bar_buttons.get("inventory") as Control])
			return _guide_result("open_chest", "Select the highlighted practice chest.", [], [_exploration_anchor()])
		"rest":
			return _guide_result("open_rest", "Select the highlighted Rest button.", [hud._bar_buttons.get("rest") as Control])
	return _guide_result("waiting", "Watch the result.", [])


## Only disposable tutorial widgets get their focus restricted. Ordinary campaign screens are unchanged.
func _guide_focus_scope(owner: Node, allowed: Array[Control]) -> void:
	if owner == null:
		return
	for node in owner.find_children("*", "Control", true, false):
		var control := node as Control
		var useful := allowed.any(func(target: Control) -> bool: return target == control or control.is_ancestor_of(target))
		if useful:
			control.remove_meta(&"pad_skip")
		else:
			control.set_meta(&"pad_skip", true)
		control.focus_mode = Control.FOCUS_ALL if control in allowed else Control.FOCUS_NONE
	if allowed.is_empty():
		return
	for i in allowed.size():
		var previous := allowed[i].get_path_to(allowed[posmod(i - 1, allowed.size())])
		var following := allowed[i].get_path_to(allowed[(i + 1) % allowed.size()])
		allowed[i].focus_next = following
		allowed[i].focus_previous = previous
		allowed[i].focus_neighbor_top = previous
		allowed[i].focus_neighbor_bottom = following
		allowed[i].focus_neighbor_left = previous
		allowed[i].focus_neighbor_right = following
	var focused := get_viewport().gui_get_focus_owner()
	if focused not in allowed and (focused == null or not coach.is_ancestor_of(focused)):
		allowed[0].grab_focus()


func _update_guidance() -> void:
	_sync_modal_menu()
	if coach.menu_open or lesson_complete:
		if lesson_complete and lesson_id() == "combat_orientation" and combat != null:
			coach.set_highlight(combat.view.hud.coach_anchor("turn_order"))
		return
	if screen != null and (not is_instance_valid(_guide_close) or _guide_close.is_queued_for_deletion()):
		_add_guided_close()
	var state: Dictionary
	if combat != null and screen == null:
		state = combat.guide_state()
		if not combat.is_guided():
			coach.set_spotlights([])
			return
		var action := str(state.get("coach_action", ""))
		if action != _guide_action:
			_guide_action = action
			if action == "confirm_bless":
				coach.set_action("Cast Bless on Liriel", combat.confirm_guided_cast)
				coach.action_button.grab_focus()
			else:
				coach.clear_action()
		if action == "confirm_bless":
			(state["rects"] as Array[Rect2]).append(_guide_rect(coach.action_button))
		var step := str(state["step"])
		if step == "reaction":
			_guide_focus_scope(combat.view.hud._prompt, combat.view.hud.coach_controls("reaction_choices"))
		elif step == "end_confirm":
			_guide_focus_scope(combat.view.hud._confirm, combat.view.hud.coach_controls("end_confirm"))
		if step in ["action", "menu"]:
			combat.view.hud.coach_focus_action(combat._guided_action_id())
		if step != _guide_step and step in ["move", "target"]:
			combat.view.cursor_cell = Vector2i(4, 3) if step == "move" else combat._guided_target().cell
			if PadNav.active():
				combat.view.using_pad = true
				combat.view._pad_hover()
		_guide_step = step
	else:
		state = exploration_guide_state()
		if state.has("copy_title"):
			coach.set_step_copy(str(state["copy_title"]), str(state["copy_body"]))
		coach.set_card_corner(bool(state.get("card_top_right", false)))
		if state.has("chrome_visible"):
			coach.set_chrome_visible(bool(state["chrome_visible"]))
		if str(state["step"]) != _guide_step:
			_guide_step = str(state["step"])
			if str(state.get("coach_action", "")) == "sheet_continue":
				coach.set_action(str(state["action_label"]), advance_sheet_step)
				coach.action_button.grab_focus()
			elif screen is CharacterSheetScreen:
				coach.clear_action()
		_guide_controls = state["controls"] as Array[Control]
		var owner: Node = dialogue if dialogue != null else (screen if screen != null else (loot if loot != null else hud))
		_guide_focus_scope(owner, _guide_controls)
	coach.set_action_scope(str(state.get("coach_action", "")) in ["confirm_bless", "sheet_continue"])
	var readable: Array[Rect2] = []
	readable.assign(state.get("read_rects", []))
	coach.set_read_regions(readable)
	coach.set_step_hint(str(state["step"]), str(state["hint"]), str(state.get("hint_pad", "")))
	coach.set_spotlights(state["rects"] as Array[Rect2])


func _guide_input(event: InputEvent) -> bool:
	if _leaving:
		return false
	if event is InputEventMouseMotion or event is InputEventJoypadMotion:
		return true
	if event is InputEventKey and not (event as InputEventKey).pressed:
		return true
	if event is InputEventJoypadButton and not (event as InputEventJoypadButton).pressed:
		return true
	if coach.menu_open or lesson_complete:
		return true
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and coach.is_ancestor_of(focused):
		for action: StringName in [&"ui_accept", &"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_focus_next", &"ui_focus_prev"]:
			if event.is_action(action):
				return true
	if combat != null and screen == null:
		return combat.allows_command("input", {"event": event})
	if event.is_action_pressed(&"ui_accept") and focused != null:
		return focused in _guide_controls or coach.is_ancestor_of(focused)
	if dialogue != null:
		if event is InputEventKey and not dialogue.options_shown.is_empty():
			var code := (event as InputEventKey).physical_keycode
			if code == KEY_TAB or code >= KEY_1 and code <= KEY_4:
				return true
	if screen != null or loot != null or dialogue != null:
		for action: StringName in [&"ui_accept", &"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_focus_next", &"ui_focus_prev", &"combat_confirm"]:
			if event.is_action(action):
				return true
		return loot != null and event.is_action(&"combat_end_turn")
	# During guided exploration a deliberate confirm uses exactly the highlighted world object.
	if event.is_action(&"combat_confirm"):
		return true
	for action: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_focus_next", &"ui_focus_prev", &"ui_accept"]:
		if event.is_action(action):
			return true
	return false


func _guided_world_action() -> void:
	match lesson_id():
		"explore":
			location.walk_to(EXPLORE_TARGET)
		"check":
			_examine_ledger()
		"conversation":
			_approach_mentor()
		"inventory":
			if not _practice_loot_taken:
				interact_practice_object()


func _sync_modal_menu() -> void:
	var has_modal := false
	for modal: CanvasLayer in [dialogue, screen, loot]:
		if modal == null:
			continue
		has_modal = true
		modal.visible = not coach.menu_open
		modal.process_mode = Node.PROCESS_MODE_DISABLED if coach.menu_open else Node.PROCESS_MODE_INHERIT
	coach.visible = true
	coach.set_chrome_visible(coach.menu_open or not has_modal or (screen is CharacterSheetScreen and lesson_id() == "sheet" and _sheet_step < 2))


static func _guide_label(owner: Node, caption: String) -> Label:
	if owner == null:
		return null
	for node in owner.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.strip_edges().to_lower() == caption.to_lower() and _guide_rect(label).has_area():
			return label
	return null


static func _shared_guide_parent(first: Control, second: Control) -> Control:
	if first == null or second == null:
		return null
	var candidate: Node = first
	while candidate != null:
		if candidate is Control and (candidate == second or candidate.is_ancestor_of(second)):
			return candidate as Control
		candidate = candidate.get_parent()
	return null


func _sheet_read_rects(step: int) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	if not screen is CharacterSheetScreen:
		return regions
	if step == 0 or step >= 2:
		var heading := _guide_label(screen, "HIT POINTS")
		if heading != null:
			var block := heading.get_parent().get_parent() as Control
			var hp_rect := _guide_rect(block)
			if hp_rect.has_area():
				regions.append(hp_rect.grow(5.0))
		for node in screen.find_children("*", "Control", true, false):
			var control := node as Control
			if str(control.get_meta(&"plain_tip", "")).begins_with("Armor Class "):
				var armor_rect := _guide_rect(control)
				if armor_rect.has_area():
					regions.append(armor_rect.grow(5.0))
				break
	if step >= 1:
		var abilities := _guide_label(screen, "Abilities & Saves")
		var skills := _guide_label(screen, "Skills")
		var column := _shared_guide_parent(abilities, skills)
		var column_rect := _guide_rect(column)
		if column_rect.has_area():
			regions.append(column_rect.grow(5.0))
	return regions


func advance_sheet_step() -> void:
	if lesson_id() != "sheet" or not screen is CharacterSheetScreen or lesson_complete or _sheet_step >= 2:
		return
	_sheet_step += 1
	_guide_step = ""
	_update_guidance()


func _sheet_guide_state() -> Dictionary:
	if _sheet_step >= 2:
		var done := _guide_result("sheet_return", "Select Back to practice when you are ready.", [_guide_close])
		done["read_rects"] = _sheet_read_rects(2)
		done["chrome_visible"] = false
		return done
	var character := (screen as CharacterSheetScreen)._ch()
	var hint := "Look at the highlighted HP bar and Armor Class shield, then select Continue."
	var body := "%s has %d of %d hit points (HP). Damage reduces current HP. At 0 HP a hero usually falls unconscious and needs help. Armor Class (AC) %d is the number an attack roll must meet to hit this hero; higher AC makes hits less likely." % [character.name, character.hp, character.max_hp(), character.ac_value()]
	var title := "Hit points and Armor Class"
	var action_label := "Continue: abilities and skills"
	if _sheet_step == 1:
		title = "Abilities, saving throws and skills"
		body = "The six abilities describe a hero's strengths. Their signed modifiers affect rolls. Saving throws resist danger, such as dodging a blast. Skills apply abilities to specific tasks; trained skills also include proficiency. %s's Athletics bonus is %s: add that bonus to a d20 Athletics check. The game calculates these bonuses for you." % [character.name, character.skill_bonus(&"athletics").signed()]
		hint = "Look at the ability modifiers, saves and skill bonuses, then select Continue."
		action_label = "Continue: return to practice"
	var state := _guide_result("sheet_read_%d" % _sheet_step, hint, [coach.action_button])
	state["read_rects"] = _sheet_read_rects(_sheet_step)
	state["chrome_visible"] = true
	state["card_top_right"] = true
	state["copy_title"] = title
	state["copy_body"] = body
	state["coach_action"] = "sheet_continue"
	state["action_label"] = action_label
	return state


func _dialogue_read_rects() -> Array[Rect2]:
	var regions: Array[Rect2] = []
	if dialogue == null:
		return regions
	var readable: Array[Control] = [dialogue._name, dialogue._text, dialogue._portrait]
	if is_instance_valid(dialogue.d20):
		readable.append(dialogue.d20)
	for control in readable:
		var rect := _guide_rect(control)
		if rect.has_area():
			regions.append(rect.grow(4.0))
	return regions
