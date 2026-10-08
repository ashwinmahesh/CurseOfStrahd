extends TestCase
## Effects on the people of the overworld (owner, 2026-10-07: "if we cast sleep in the overworld, or anything that gives
## any enemy or NPC an effect, that should show in the game UI"). A party member casts Sleep at someone from the
## right-click menu (FieldCasting.cast_at, the spell engine on a peaceful board): it shows on them (lying down, the
## chips, the hover hint, Look), they can't answer while asleep, it lasts through the rebuilds after a conversation,
## and it runs down as time passes. Someone who sees it cast reports it (in a town, the watch comes); a spell at a foe in
## plain view opens the fight instead, and what's on a foe shows on its hover hint too.

const LOC := {
	"id": "test_square", "name": "Test Square", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"############"], "light": "bright"},
	"spawns": {"default": [2, 2]},
	"npcs": [{"npc": "ismark", "cell": [6, 2], "dialogue": "test/square:start"}]
}

const DIALOGUE := """
~ start
Ismark: You look like trouble.
-> END
"""

const AT := Vector2i(6, 2)

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_square"] = LOC.duplicate(true)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/square"))
	GameState.reset()
	for id: String in ["silvain_aster", "ilse_varga"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_square"
	Dice.reseed(11)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	Compendium.shared().tables["locations"].erase("test_square")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _ismark() -> CombatToken:
	return _view().npc_tokens["ismark"] as CombatToken


func _labels(cell: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for a: Variant in _view().actions_at(cell)["actions"]:
		out.append(str((a as Dictionary)["label"]))
	return out


## Casts Sleep at Ismark until he is asleep (a save can go either way; the dice are seeded, so this is the same every
## run). A fresh Long Rest gives the slot back between tries.
func _sleep_him() -> bool:
	var v := _view()
	for i in 15:
		var said: Array[String] = []
		var hear := func(text: String) -> void: said.append(text)
		v.narration.connect(hear)
		v.act(AT, "cast_at:0:sleep")
		v.narration.disconnect(hear)
		assert_eq(said.size(), 1, "the casting is told (%s)" % [said])
		if LocationNpcs.is_asleep(v, "ismark"):
			return true
		(GameState.story.party[0] as Character).finish_long_rest()
	return false


func test_the_menu_offers_spells_at_people() -> void:
	var labels := _labels(AT)
	assert_true(labels.has("Cast Sleep (Silvain)"), "Sleep is offered at Ismark (got %s)" % [labels])
	assert_false(labels.any(func(l: String) -> bool: return l.begins_with("Cast Magic Missile")), "nothing that hurts")
	assert_false(labels.any(func(l: String) -> bool: return l.begins_with("Cast Shield")), "nor anything for the party")


func test_sleep_shows_on_him_and_he_cannot_answer() -> void:
	assert_true(await _sleep_him(), "one of the tries put him to sleep")
	var v := _view()
	var cr := _ismark().combatant.creature
	assert_true(cr.has_condition(&"unconscious") and cr.has_condition(&"prone"))
	assert_eq(LocationNpcs.state_words(v, "ismark"), "asleep, prone · Sleep")
	assert_eq(str(v.thing_at(AT)["label"]), "Ismark Kolyanovich (asleep, prone · Sleep)", "the hover hint")
	assert_eq((_ismark().get("_status") as Label3D).text, "Asleep · Prone", "the chips over him")
	assert_true((_ismark().get("_lying") as Sprite3D).visible or _ismark().sprite.pose == "down", "lying down")
	assert_eq(_labels(AT)[0], "Approach", "nobody offers to chat with a sleeper")
	var said: Array[String] = []
	v.narration.connect(func(text: String) -> void: said.append(text))
	v.interact(v.thing_at(AT))
	await _frames(2)
	assert_true(root.get("dialogue") == null, "no conversation starts")
	assert_true(said.size() == 1 and said[0].contains("can't answer"), "he can't answer (got %s)" % [said])


func test_the_sleep_lasts_through_a_rebuild_and_runs_down_with_time() -> void:
	assert_true(await _sleep_him())
	var v := _view()
	v.refresh_npcs()   # what the game does after every conversation
	await _frames(2)
	assert_true(LocationNpcs.is_asleep(v, "ismark"), "still asleep after the people are rebuilt")
	GameState.story.advance_minutes(2)   # Sleep lasts a minute
	await _frames(3)
	assert_false(LocationNpcs.is_asleep(v, "ismark"), "awake once the minute is up")
	assert_false(_ismark().combatant.creature.has_condition(&"unconscious"))
	assert_true(LocationNpcs.can_talk(v, v.thing_at(AT)["spec"] as Dictionary), "and he can talk again")


## Rebuilds the game in another fixture place (the party as it is).
func _go(loc: Dictionary) -> void:
	Compendium.shared().tables["locations"][str(loc["id"])] = loc.duplicate(true)
	root.queue_free()
	await _frames(1)
	GameState.story.location = str(loc["id"])
	GameState.story.positions.clear()
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()


func test_a_spell_someone_sees_is_a_crime_and_the_watch_comes() -> void:
	var market := LOC.duplicate(true)
	market["id"] = "test_market"
	market["region"] = "vallaki"   # a town that keeps a watch (Crime.WATCH)
	market["npcs"] = [{"npc": "ismark", "cell": [6, 2], "dialogue": "test/square:start"},
		{"npc": "ireena", "cell": [3, 3], "dialogue": "test/square:start"}]   # right beside the caster: she sees it
	await _go(market)
	var before := GameState.story.attitude("ismark")
	_view().act(AT, "cast_at:0:sleep")
	await _frames(2)
	assert_eq(int(GameState.story.get_flag("crime_vallaki", 0)), 1, "the offence counts in Vallaki")
	assert_ne(GameState.story.attitude("ismark"), before, "Ismark thinks less of the party")
	assert_true(root.get("dialogue") != null, "the watch comes over about it")
	Compendium.shared().tables["locations"].erase("test_market")


func test_effects_show_on_a_foe_and_a_spell_at_it_opens_the_fight() -> void:
	var field := {"id": "test_field", "name": "Test Field", "region": "test", "summary": "A fixture.",
		"map": {"rows": ["################", "#..............#", "#..............#", "#..............#", "################"], "light": "bright"},
		"spawns": {"default": [2, 2]},
		"areas": [{"id": "far", "name": "Far end", "cells": [[10, 1], [14, 3]]}],
		"encounters": [{"id": "field_wolf", "trigger": "enter_area:far", "waiting": true,
			"monsters": [{"monster": "wolf", "cell": [11, 2], "facing": "east"}]}]}
	await _go(field)
	var v := _view()
	LocationStealth.refresh_waiting(v)
	await _frames(2)
	var thing := v.thing_at(Vector2i(11, 2))
	assert_eq(str(thing.get("kind", "")), "foe", "the wolf waits in plain view")
	var wolf := v.waiting[0]["foe"] as Combatant
	wolf.creature.add_condition(&"prone", "test")
	assert_eq(str(v.thing_at(Vector2i(11, 2))["label"]), "%s (prone)" % ("Attack " + wolf.name()), "what's on it shows on hover")
	var ids: Array = (v.actions_at(Vector2i(11, 2))["actions"] as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true("strike_cast:0:sleep:field_wolf" in ids, "Sleep at the wolf is offered (got %s)" % [ids])
	v.act(Vector2i(11, 2), "strike_cast:0:sleep:field_wolf")
	await _frames(3)
	assert_true(v.in_combat, "a spell at a foe opens the fight")
	Compendium.shared().tables["locations"].erase("test_field")
