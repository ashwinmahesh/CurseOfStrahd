extends TestCase
## Sight cones before a fight (owner, 2026-10-07, after Baldur's Gate 3; docs/rules/stealth.md): a foe waiting in plain
## view sees only 120° ahead of the way it faces, and hears the party all round within 10 ft. A sneaking party can
## come up behind it and strike with Surprise; a foe that turns (or walks a route) turns its cone; townsfolk witness a
## theft the same way. Fights keep the 2024 rules, with no facing.

const LOC := {
	"id": "test_cone_hall", "name": "Cone Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##################",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"##################"], "light": "bright"},
	"areas": [{"id": "middle", "name": "Middle", "cells": [[7, 1], [9, 5]]}],
	"spawns": {"default": [2, 3]},
	"containers": [{"id": "till", "cell": [5, 1], "label": "Till", "owner": "urwin_martikov", "items": [{"id": "dagger", "qty": 1}], "gold": 5}],
	"npcs": [{"npc": "urwin_martikov", "cell": [11, 1]}],
	"encounters": [{"id": "cone_wolf", "trigger": "enter_area:middle", "waiting": true,
		"monsters": [{"monster": "wolf", "cell": [8, 4], "facing": "east"}], "flag": "test_cone_wolf_dead"}]
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_cone_hall"] = LOC.duplicate(true)
	GameSettings.set_turn_based(false)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_cone_hall"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	# Tamsin stays at the west wall, out of everyone's way.
	_view().members[1].cell = Vector2i(1, 1)


func after_each() -> void:
	GameSettings.set_turn_based(false)
	Compendium.shared().tables["locations"].erase("test_cone_hall")
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _wolf() -> Combatant:
	return _view().waiting[0]["foe"] as Combatant


func _leader_at(cell: Vector2i) -> Combatant:
	var lead := _view().leader()
	lead.cell = cell
	return lead


func _notices(cell: Vector2i, sneaking: bool = false, total: int = 0) -> bool:
	var who := _leader_at(cell)
	var e := LocationStealth.watch(_view())
	return LocationStealth.notices(e, _wolf(), who, sneaking, total)


func test_a_foe_sees_ahead_and_hears_close_but_not_behind() -> void:
	assert_true(LocationStealth.is_shown(_view().waiting[0]), "the wolf waits in plain view")
	assert_true(_notices(Vector2i(12, 4)), "20 ft ahead, in its cone: seen")
	assert_true(_notices(Vector2i(11, 2)), "off to the side but inside 120°: seen")
	assert_false(_notices(Vector2i(4, 4)), "20 ft behind it: not seen, though nobody sneaks")
	assert_false(_notices(Vector2i(8, 1)), "15 ft to its side, outside the cone: not seen")
	assert_true(_notices(Vector2i(6, 4)), "10 ft behind: heard")
	assert_true(_notices(Vector2i(8, 2)), "10 ft to its side: heard")


func test_hearing_still_answers_to_stealth() -> void:
	var pp := LocationStealth.passive_score(_wolf())
	assert_true(_notices(Vector2i(7, 4), true, pp), "a sneak who only ties its passive Perception is heard")
	assert_false(_notices(Vector2i(7, 4), true, pp + 1), "one who beats it isn't, even right behind it")


func test_sneaking_up_behind_it_to_strike_with_surprise() -> void:
	var v := _view()
	var pp := LocationStealth.passive_score(_wolf())
	v.set_sneaking(true)
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = pp - 3
	# Clumsy enough that it would spot them in front, but 15 ft behind its back it doesn't.
	_leader_at(Vector2i(5, 4))
	assert_false(LocationStealth.after_step(v), "unnoticed behind it")
	assert_true(v.strike(), "the party opens the fight")
	await _frames(3)
	for c in v.combat_view.e.combatants:
		if c.side == &"enemy":
			assert_true(c.surprised, "it never saw them coming")


func test_stepping_in_front_of_it_starts_the_fight() -> void:
	var v := _view()
	var pp := LocationStealth.passive_score(_wolf())
	v.set_sneaking(true)
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = pp - 3
	_leader_at(Vector2i(11, 4))
	assert_true(LocationStealth.after_step(v), "15 ft in front: it sees the clumsy sneak")
	assert_true(v.in_combat)


func test_a_foe_that_turns_turns_its_cone() -> void:
	assert_false(_notices(Vector2i(4, 4)), "behind it")
	(_view().waiting[0]["token"] as CombatToken).face(Vector2(-1, 0), false)
	assert_true(_notices(Vector2i(4, 4)), "it turned round (as a foe walking a route does): now ahead of it")


func test_the_sight_area_is_a_cone_and_a_ring() -> void:
	var v := _view()
	v.toggle_plan()
	await _frames(2)
	var overlay := v.get_node("SightOverlay") as SightOverlay
	var reach := overlay.reach_of(LocationStealth.watch(v), _wolf())
	assert_true(Vector2i(12, 4) in reach, "ahead")
	assert_true(Vector2i(7, 4) in reach, "close behind: the ring it hears")
	assert_false(Vector2i(4, 4) in reach, "far behind")
	assert_false(Vector2i(8, 1) in reach, "far to the side")
	assert_true(overlay.reach_size() > 0, "drawn on the ground")


func test_a_theft_behind_someones_back_goes_unseen() -> void:
	var v := _view()
	var urwin := LocationCrime.token(v, "urwin_martikov")
	urwin.face(Vector2(1, 0), false)   # Urwin looks east, away from the till
	_leader_at(Vector2i(5, 2))
	var before := GameState.story.attitude("urwin_martikov")
	LocationCrime.after_loot(v, "till", 5.0)
	assert_eq(GameState.story.attitude("urwin_martikov"), before, "30 ft behind his back: nobody saw")
	urwin.face(Vector2(-1, 0), false)
	LocationCrime.after_loot(v, "till", 5.0)
	assert_ne(GameState.story.attitude("urwin_martikov"), before, "facing the till, he sees it")


func test_townsfolk_show_what_they_see_while_sneaking() -> void:
	var v := _view()
	var overlay := v.get_node("SightOverlay") as SightOverlay
	var urwin := LocationCrime.token(v, "urwin_martikov")
	urwin.face(Vector2(-1, 0), false)   # looking west, across the room
	v.toggle_plan()
	await _frames(2)
	assert_eq(overlay.mood_of(urwin.combatant.id), "", "turn-based alone: townsfolk show nothing")
	v.set_sneaking(true)
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = 1
	await _frames(2)
	assert_eq(overlay.mood_of(urwin.combatant.id), "notices", "sneaking: an eye over Urwin, red for a clumsy sneak")
	assert_true(LocationStealth.hover_warning(v, Vector2i(6, 1)).contains("Urwin"), "the hint names him (the wolf faces away)")
	v.set_sneaking(false)
	assert_eq(LocationStealth.hover_warning(v, Vector2i(6, 1)), "", "walking openly, the hint only warns about foes")
