extends TestCase
## F13 in the real game: a fight won with foes who surrendered opens the captives' conversation, and the fight's
## spoils (and any journey) wait until it ends (world/exploration/location_fights.gd, story/captives.gd). Cutting a
## surrendered foe down costs the companions' regard.

const LOC := {
	"id": "test_yard", "name": "Test Yard", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"############"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "thugs", "trigger": "manual", "loot": {"gold": 7},
		"monsters": [{"monster": "bandit", "cell": [9, 1]}, {"monster": "bandit", "cell": [9, 3]}]}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_yard"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "ilse_varga"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_yard"
	Dice.reseed(5)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	Compendium.shared().tables["locations"].erase("test_yard")
	LocationFights._after_talk = {}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func test_captives_talk_first_and_the_spoils_wait() -> void:
	var v := _view()
	assert_true(v.start_encounter("thugs"))
	await _frames(3)
	var e := v.combat_view.e
	var foes := e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy")
	for f: Combatant in foes:
		AiTactics.surrender(e, f)
	assert_eq(e.outcome, "victory", "a side that all gave up has lost")
	v.combat_view.finished.emit("victory")
	await _frames(4)
	assert_true(root.get("dialogue") != null, "the captives' conversation is open")
	assert_true(root.get("loot") == null, "the spoils wait for it")
	assert_false(LocationFights._after_talk.is_empty())
	# The conversation ends: the spoils come.
	(root.get("dialogue") as Node).queue_free()
	root.set("dialogue", null)
	root.call("_dialogue_ended", "")
	await _frames(3)
	assert_true(root.get("loot") != null, "the fight's loot after the talk")
	assert_true(LocationFights._after_talk.is_empty())


func test_cutting_down_a_surrendered_foe_costs_godricks_regard() -> void:
	var v := _view()
	assert_true(v.start_encounter("thugs"))
	await _frames(3)
	var e := v.combat_view.e
	var foes := e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy")
	AiTactics.surrender(e, foes[0] as Combatant)
	(foes[0] as Combatant).creature.take_damage(200, &"slashing")
	(foes[1] as Combatant).creature.take_damage(200, &"slashing")
	e._check_over()
	assert_eq(e.outcome, "victory")
	v.combat_view.finished.emit("victory")
	await _frames(4)
	assert_true(Approval.score(GameState.story, "godrick_pendlebrook") < 0, "Godrick saw it")
	assert_true(root.get("dialogue") == null, "no captives left to talk to")
