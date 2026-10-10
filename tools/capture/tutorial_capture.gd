extends Node
## make capture SCENE=res://tools/capture/tutorial_capture.tscn NAME=tutorial FRAMES=10

var session: TutorialSession


func capture_shots(tool: Node, out: String) -> void:
	if "--tutorial-large" in OS.get_cmdline_user_args():
		GameSettings.set_ui_scale(GameSettings.UI_SCALES.back())
		GameSettings.set_text_scale(GameSettings.TEXT_SCALES.back())
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child(menu)
	menu.call("_new_game")
	menu.call("_offer_tutorial")
	await _shot(tool, out + "_01_invitation.png")
	menu.queue_free()
	await tool.call("wait_frames", 3)
	session = TutorialSession.new()
	session.pending_campaign = true
	add_child(session)
	await _shot(tool, out + "_02_welcome.png")
	_click(session.coach.next_button)
	await tool.call("wait_frames", 3)
	if session.lesson_id() != "explore":
		push_error("Tutorial capture: Continue click did not advance")
		return
	await _shot(tool, out + "_03_explore.png")
	var start := session.location.leader().cell
	if not session.location.walk_to(TutorialSession.EXPLORE_TARGET):
		push_error("Tutorial capture: exploration path refused")
		return
	for i in 200:
		if session.lesson_complete:
			break
		await tool.call("wait_frames", 1)
	print("tutorial capture: exploration moved=", session.location.leader().cell != start, " complete=", session.lesson_complete)
	await _shot(tool, out + "_04_moved.png")
	await _lesson(tool, "sheet")
	session.open_screen("sheet")
	await _shot(tool, out + "_05a_sheet_health.png")
	_click(session.coach.action_button)
	await _shot(tool, out + "_05b_sheet_abilities.png")
	_click(session.coach.action_button)
	await _shot(tool, out + "_05c_sheet_return.png")
	_click(session.get("_guide_close") as Button)
	await tool.call("wait_frames", 4)
	await _lesson(tool, "check")
	session.roll_practice_check()
	print("tutorial capture: actual check=", session.last_check.total, " success=", session.last_check.success)
	await _shot(tool, out + "_06_check.png")
	await _lesson(tool, "conversation")
	session.start_practice_conversation()
	for i in 10:
		if not session.dialogue.options_shown.is_empty():
			break
		session.dialogue._advance()
		await tool.call("wait_frames", 1)
	await _shot(tool, out + "_06b_conversation_choices.png")
	session.dialogue._choose(0)
	await tool.call("wait_frames", 90)
	await _shot(tool, out + "_06c_conversation_roll.png")
	for i in 10:
		if session.dialogue == null:
			break
		session.dialogue._advance()
		await tool.call("wait_frames", 1)
	print("tutorial capture: conversation completed=", session.lesson_complete, " result=", session.practice.get_flag("tutorial_dialogue_result"))
	await _shot(tool, out + "_06d_conversation_result.png")
	await _lesson(tool, "inventory")
	session.interact_practice_object()
	for i in 300:
		if session.loot != null:
			break
		await tool.call("wait_frames", 1)
	if session.loot == null:
		push_error("Tutorial capture: chest never opened")
		return
	await _shot(tool, out + "_07_loot.png")
	session.loot._take_all()
	await tool.call("wait_frames", 3)
	session.open_screen("inventory")
	await _shot(tool, out + "_08_inventory.png")
	session.close_screen()
	await _lesson(tool, "rest")
	session.practice_rest()
	await _shot(tool, out + "_09_rest.png")
	session.close_screen()
	await _lesson(tool, "combat_attack")
	if not await _ready_combat(tool):
		return
	await _shot(tool, out + "_10_combat_attack.png")
	_click_point(session.combat.view.hud.coach_rects("action", "attack:weapon:greatsword")[0].get_center())
	await tool.call("wait_frames", 4)
	await _shot(tool, out + "_10b_attack_target.png")
	var enemy := session.combat.opponent
	var target := session.combat.rig.camera.unproject_position(session.combat.board.cell_center(enemy.cell) + Vector3(0, 0.6, 0))
	_click_point(target)
	await _completed(tool)
	await _shot(tool, out + "_11_attack_result.png")
	await _lesson(tool, "combat_reaction")
	if not await _ready_combat(tool):
		return
	session.combat.view._end_turn()
	if session.combat.view.hud.confirm_open():
		session.combat.view._end_turn()
	for i in 600:
		if session.combat.view.mode == CombatView.Mode.PROMPT:
			break
		await tool.call("wait_frames", 1)
	if session.combat.view.mode != CombatView.Mode.PROMPT:
		push_error("Tutorial capture: real reaction prompt never appeared")
		return
	await _shot(tool, out + "_12_reaction.png")
	session.combat.view._answer(false, "ask")
	await _completed(tool)
	await _shot(tool, out + "_13_reaction_result.png")
	await _lesson(tool, "combat_heal")
	if not await _ready_combat(tool):
		return
	var hp := session.combat.partner.creature.hp
	if not _target("spell:cure_wounds", session.combat.partner, 1):
		return
	await _completed(tool)
	print("tutorial capture: healing hp before=", hp, " after=", session.combat.partner.creature.hp)
	await _shot(tool, out + "_14_healing.png")
	await _lesson(tool, "combat_concentration")
	if not await _ready_combat(tool):
		return
	if not _target("spell:bless", session.combat.hero, 1):
		return
	await tool.call("wait_frames", 4)
	await _shot(tool, out + "_15a_confirm_bless.png")
	_click(session.coach.action_button)
	await _completed(tool)
	print("tutorial capture: concentration=", session.combat.hero.creature.concentration != null)
	await _shot(tool, out + "_15_concentration.png")
	session.start_lesson(session.lesson_count() - 1)
	await _shot(tool, out + "_16_complete.png")
	session.leave_tutorial()
	session.queue_free()
	session = null
	await tool.call("wait_frames", 4)


func _shot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 12)
	tool.call("_shot", path)


func _lesson(tool: Node, id: String) -> void:
	var index := TutorialSession.EXPLORATION_IDS.find(id)
	if index < 0:
		index = TutorialSession.EXPLORATION_IDS.size() + TutorialCombat.LESSON_IDS.find(id)
	session.start_lesson(index)
	await tool.call("wait_frames", 3)


func _ready_combat(tool: Node) -> bool:
	for i in 500:
		var fight := session.combat
		if fight.view != null:
			if fight.view.mode == CombatView.Mode.PROMPT and session.lesson_id() == "combat_reaction":
				return true
			if fight.view.mode == CombatView.Mode.IDLE:
				if fight.e.current() == fight.hero:
					return true
				if not fight.is_guided() and fight.hero in fight.e.shared_heroes():
					fight.view._switch(fight.hero)
					return true
				if fight.e.current().is_player_controlled():
					fight.view._end_turn()
					if fight.view.hud.confirm_open():
						fight.view._end_turn()
		await tool.call("wait_frames", 1)
	push_error("Tutorial capture: combat did not become ready for %s" % session.lesson_id())
	return false


func _target(id: String, target: Combatant, level: int = 0) -> bool:
	var cv := session.combat.view
	var action := cv.catalog.find(session.combat.hero, id)
	if action.is_empty():
		push_error("Tutorial capture: missing action %s" % id)
		return false
	cv._choose(action, level)
	cv.hover_cell = target.cell
	cv._confirm_target(session.combat.hero, cv.tokens[target.id] as CombatToken)
	return true


func _completed(tool: Node) -> void:
	for i in 500:
		if session.lesson_complete:
			print("tutorial capture: completed ", session.lesson_id())
			return
		await tool.call("wait_frames", 1)
	push_error("Tutorial capture: command did not complete %s" % session.lesson_id())


func _click(button: Button) -> void:
	var center := (button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)).get_center()
	_click_point(center)


func _click_point(center: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = center
	get_viewport().push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
