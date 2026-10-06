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


## Waits (answering prompts with `use`) until a party member can act, or the fight ends.
func _until_player_turn(use: bool = false) -> void:
	for i in 1200:
		var e := _enc()
		var hud := arena.get("hud") as CombatHud
		if e.state != Encounter.State.ACTIVE:
			return
		if hud.prompt_open():
			hud.answer_prompt(use)
		elif int(arena.get("mode")) == 1 and e.current().is_player_controlled():
			return
		await get_tree().process_frame


func test_arena_builds_the_fight_from_data() -> void:
	var e := _enc()
	assert_eq(e.combatants.size(), 13)
	assert_eq((arena.get("tokens") as Dictionary).size(), 13)
	assert_true(arena.get("hud") != null)
	assert_true(arena.get("post") != null, "palette pass")
	assert_eq(e.state, Encounter.State.ACTIVE)
	await _until_player_turn()
	assert_true(e.current().is_player_controlled())


func test_player_moves_acts_and_ends_turn() -> void:
	await _until_player_turn()
	var e := _enc()
	var c := e.current()
	var reach := arena.get("_reach") as Dictionary
	var dest := c.cell
	for cell: Vector2i in reach:
		var info := reach[cell] as Dictionary
		if not bool(info["occupied"]) and int(info["cost"]) == 10:
			dest = cell
			break
	arena.set("hover_cell", dest)
	arena.set("hover_token", null)
	arena.call("_confirm_at")
	await _frames(40)
	await _until_player_turn()
	if e.current() == c:
		assert_eq(c.cell, dest, "walked to the clicked square")
		var catalog := arena.get("catalog") as ActionCatalog
		arena.call("_choose", catalog.find(c, "dodge"))
		await _frames(10)
		assert_false(c.action_available, "Dodge used the action")
		arena.call("_end_turn")
		assert_true((arena.get("hud") as CombatHud).confirm_open(), "asks before ending with movement left")
		arena.call("_end_turn")
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
		if c.is_player_controlled() and int(arena.get("mode")) == 1:
			arena.set("_confirmed_end", true)
			arena.call("_end_turn")
		await _until_player_turn()
	assert_true(e.round_no >= start_round + 1 or e.state == Encounter.State.OVER)
	var attacked := e.log.texts().any(func(t: String) -> bool: return t.contains(" hits ") or t.contains(" misses "))
	assert_true(attacked, "enemies attacked")
