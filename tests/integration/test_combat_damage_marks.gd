extends TestCase
## Damage numbers over heads in a fight (owner todo 2026-10-17: "show the damage done above the character's head, if we
## are not already doing that in combat, add it there too"): every Hit Point lost in a fight comes with a `damage` event
## and the view floats its number over whoever took it (FloatText, the same mark a trap's damage gets outside a fight),
## from a blow, a trap or anything else that goes through Encounter.deal_damage.

var e: Encounter
var view: CombatView
var _root: Node3D


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fight() -> Combatant:
	var rows: Array = []
	for z in 8:
		rows.append("............")
	e = TestCombat.encounter(rows)
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.foe(e, "zombie", Vector2i(10, 6))
	TestCombat.start_with(e, hero)
	_root = Node3D.new()
	add_child(_root)
	var board := ArenaBoard.build(e.grid)
	_root.add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		_root.add_child(token)
		tokens[c.id] = token
	var rig := CameraRig.new()
	_root.add_child(rig)
	view = CombatView.new()
	view.input_locked = true
	_root.add_child(view)
	view.begin(e, board, rig, tokens)
	await _frames(2)
	var waited := 0.0
	while view._opening and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await view._play_events()
	return hero


func _marks() -> Array[String]:
	var out: Array[String] = []
	for n in view.get_children():
		if n is Label3D:
			out.append((n as Label3D).text)
	return out


func test_a_trap_in_a_fight_floats_its_damage_over_the_one_it_hits() -> void:
	var hero := await _fight()
	e.traps.add({"id": "snare", "label": "a snare", "cells": [[4, 3]], "detect_dc": 15, "disarm_dc": 15,
		"save": {"ability": "dex", "dc": 40}, "damage": "3d6", "damage_type": "piercing"})
	var hp := hero.creature.hp
	assert_true(e.move(hero, Vector2i(4, 3)).ok)
	var lost := hp - hero.creature.hp
	assert_true(lost > 0, "the snare hurt")
	var damage := e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "damage")
	assert_eq(damage.size(), 1, "one damage event")
	assert_eq(int((damage[0] as Dictionary)["amount"]), lost, "carrying what was lost")
	await view._play_events()
	assert_true("-%d" % lost in _marks(), "-%d floats over them: %s" % [lost, _marks()])


func after_each() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	await _frames(1)
