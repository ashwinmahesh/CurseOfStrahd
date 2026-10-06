extends TestCase
## The Phase 2 arena scene boots from data, the player can move, act and end turns through the scene, enemy turns
## play on their own, and reaction prompts wait for the player.

const SCENE := preload("res://scenes/combat/arena.tscn")

var arena: Node3D


func before_each() -> void:
	Dice.reseed(3)
	arena = SCENE.instantiate() as Node3D
	add_child(arena)
	await _frames(5)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _enc() -> Encounter:
	return arena.get("e") as Encounter


func _v() -> CombatView:
	return arena.get("view") as CombatView


## Waits (answering prompts with `use`) until a party member can act, or the fight ends.
func _until_player_turn(use: bool = false) -> void:
	for i in 20000:
		var e := _enc()
		var hud := _v().get("hud") as CombatHud
		if e.state != Encounter.State.ACTIVE:
			return
		if hud.prompt_open():
			hud.answer_prompt(use)
		elif int(_v().get("mode")) == 1 and e.current().is_player_controlled():
			return
		await get_tree().process_frame


func test_arena_builds_the_fight_from_data() -> void:
	var e := _enc()
	assert_eq(e.combatants.size(), 13)
	assert_eq((arena.get("tokens") as Dictionary).size(), 13)
	assert_true(_v().get("hud") != null)
	assert_true(arena.get("post") != null, "palette pass")
	assert_eq(e.state, Encounter.State.ACTIVE)
	await _until_player_turn()
	assert_true(e.current().is_player_controlled())


func test_player_moves_acts_and_ends_turn() -> void:
	await _until_player_turn()
	var e := _enc()
	var c := e.current()
	var reach := _v().get("_reach") as Dictionary
	var dest := c.cell
	for cell: Vector2i in reach:
		var info := reach[cell] as Dictionary
		if not bool(info["occupied"]) and int(info["cost"]) == 10:
			dest = cell
			break
	_v().set("hover_cell", dest)
	_v().set("hover_token", null)
	_v().call("_confirm_at")
	await _frames(40)
	await _until_player_turn()
	if e.current() == c:
		assert_eq(c.cell, dest, "walked to the clicked square")
		var catalog := _v().get("catalog") as ActionCatalog
		_v().call("_choose", catalog.find(c, "dodge"))
		await _frames(10)
		assert_false(c.action_available, "Dodge used the action")
		assert_true(c.movement_left > 0)
		_v().call("_end_turn")
		assert_false((_v().get("hud") as CombatHud).confirm_open(), "leftover movement never asks")
		await _frames(5)
		assert_ne(e.current().id, c.id, "the turn passed")


func test_enemy_turns_play_and_prompts_wait() -> void:
	var e := _enc()
	await _until_player_turn()
	var start_round := e.round_no
	# End party turns until a few rounds have gone by; enemies act on their own.
	for i in 30:
		if e.state != Encounter.State.ACTIVE or e.round_no >= start_round + 2:
			break
		var c := e.current()
		if c.is_player_controlled() and int(_v().get("mode")) == 1:
			_v().set("_confirmed_end", true)
			_v().call("_end_turn")
		await _until_player_turn()
	assert_true(e.round_no >= start_round + 1 or e.state == Encounter.State.OVER)
	var attacked := e.log.texts().any(func(t: String) -> bool: return t.contains(" hits ") or t.contains(" misses "))
	assert_true(attacked, "enemies attacked")


func test_end_turn_asks_only_with_the_action_unused() -> void:
	await _until_player_turn()
	var e := _enc()
	var c := e.current()
	var hud := _v().get("hud") as CombatHud
	_v().call("_end_turn")
	assert_true(hud.confirm_open(), "Action still available")
	_v().call("_end_turn")
	await _frames(5)
	assert_ne(e.current().id, c.id, "the second press ends the turn")


func test_combat_log_minimizes_and_restores() -> void:
	var hud := _v().get("hud") as CombatHud
	var was := CombatHud.log_minimized
	hud.toggle_log()
	assert_eq(CombatHud.log_minimized, not was)
	assert_eq(hud._log.visible, was)
	hud.toggle_log()
	assert_eq(hud._log.visible, true if not was else false)
	CombatHud.log_minimized = false


func test_right_click_menu_info_and_casting_level() -> void:
	var e := _enc()
	var hud := _v().get("hud") as CombatHud
	var catalog := _v().get("catalog") as ActionCatalog
	# Play until it's Silvain's turn (enemies act on their own; party turns are ended).
	for i in 40:
		await _until_player_turn()
		if e.state != Encounter.State.ACTIVE:
			return
		var c := e.current()
		if not c.is_player_controlled():
			continue
		if (c.creature as Character).class_level_of("wizard") > 0:
			break
		_v().set("_confirmed_end", true)
		_v().call("_end_turn")
	var s := e.current()
	hud.shown = s
	var mm := catalog.find(s, "spell:magic_missile")
	hud.open_slot_menu(mm, Vector2(400, 400))
	assert_true(hud.menu_open())
	hud._on_menu(0)
	assert_true(hud._details.visible, "Info opens the details panel")
	hud.hide_details()
	hud._menu.hide()
	hud._on_menu(102)
	await _frames(2)
	assert_eq(int(_v().get("slot_level")), 2, "cast at level 2 from the menu")
	assert_eq(str((_v().get("selected") as Dictionary).get("spell_id", "")), "magic_missile")

