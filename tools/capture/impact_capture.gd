extends Node
## G2 combat impact, frame by frame (lane 21):
## make capture SCENE=res://tools/capture/impact_capture.tscn LOCATION=<id> ENCOUNTER=<fight id> NAME=<name>
## [ARGS=--off]. Starts the fight and, on the party's first turn, stages each moment with made-up events on the
## fight's own creatures: a heavy hit, a critical hit, a killing blow, a Fireball into the foes, and the last foe's
## fall. Each is shot 20 times a second as <out>_<moment>_NN.jpg (with <out>_<moment>_sheet.jpg). --off plays the
## same moments with the impact turned off, for comparison. The events change only the shown fight, never a save.

const FPS := 20.0
const SIZE := Vector2i(640, 360)
## Each moment and how many real seconds it's shot for.
const MOMENTS := {"heavy": 1.6, "crit": 1.9, "kill": 2.2, "spell": 3.8, "last": 3.6}

var game: Node
var cv: CombatView
var _out := ""


func _ready() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)


func capture_shots(tool: Node, out: String) -> void:
	var encounter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--encounter="):
			encounter = a.get_slice("=", 1)
		elif a == "--off":
			CombatImpact.enabled = false
			out += "_off"
	_out = out
	var view := game.get("view") as LocationView
	view.input_locked = true
	if not view.start_encounter(encounter):
		push_warning("impact_capture: no encounter %s here" % encounter)
		return
	cv = view.combat_view
	cv.input_locked = true
	# The party's first turn, after the opening beat (enemies that act first play their turns on their own).
	for guard in 600:
		if cv.mode == CombatView.Mode.IDLE:
			break
		await tool.call("wait_frames", 5)
	var a := cv.e.current()
	for moment: String in MOMENTS:
		var t := _nearest_foe(a)
		if t == null:
			break
		var events := _stage(moment, a, t)
		await tool.call("wait_frames", 50)   # the camera settles on the attacker
		cv.e.events.append_array(events)
		cv.call("_play_events")
		await _film(moment, float(MOMENTS[moment]))
		await tool.call("wait_frames", 40)


## The made-up events for `moment`, with the creatures' Hit Points set to match (shown only).
func _stage(moment: String, a: Combatant, t: Combatant) -> Array:
	var at := a
	if moment == "spell":
		for c in cv.e.combatants:
			if c.side == &"party" and c.creature is Character and (c.creature as Character).class_level_of("wizard") > 0:
				at = c
	if moment != "spell":
		_beside(at, t)
	cv.rig.follow = cv.tokens[at.id] as Node3D
	var action := ""
	for act in cv.catalog.actions_for(a):
		if str(act["kind"]) == "attack" and (action == "" or bool(cv.e.option_by_id(a, str(act["option_id"]))["melee"])):
			action = str(act["option_id"])
	var swing := {"type": "attack", "attacker": a.id, "target": t.id, "hit": true, "critical": false, "action": action}
	var cr := t.creature
	cr.hp = cr.max_hp()
	match moment:
		"heavy":
			var amount := maxi(int(ceil(cr.max_hp() * 0.55)), 5)
			cr.hp -= amount
			return [swing, {"type": "damage", "id": t.id, "amount": amount}]
		"crit":
			swing["critical"] = true
			var amount := maxi(int(ceil(cr.max_hp() * 0.7)), 5)
			cr.hp -= amount
			return [swing, {"type": "damage", "id": t.id, "amount": amount, "critical": true}]
		"kill":
			cr.hp = 0
			cr.dead = true
			return [swing, {"type": "damage", "id": t.id, "amount": cr.max_hp()}, {"type": "death", "id": t.id}]
		"spell":
			# The fireball lands in the open, four to six squares from the caster where the ground around is
			# clearest of walls, with three foes gathered there (shown only), so no roof hides it.
			var mid := t.cell
			var clearest := -1
			for dx in range(-6, 7):
				for dy in range(-6, 7):
					var spot := at.cell + Vector2i(dx, dy)
					var far := Vector2(dx, dy).length()
					if far < 4.0 or far > 6.0 or not cv.e.grid.in_bounds(spot):
						continue
					var open := 0
					for ox in range(-4, 5):
						for oy in range(-4, 5):
							var near := spot + Vector2i(ox, oy)
							if cv.e.grid.in_bounds(near) and not cv.e.grid.is_solid(near):
								open += 1
					if open > clearest:
						clearest = open
						mid = spot
			var cells: Array = []
			for dx in range(-3, 4):
				for dy in range(-3, 4):
					var cell := mid + Vector2i(dx, dy)
					if Vector2(dx, dy).length() <= 3.2 and cv.e.grid.in_bounds(cell):
						cells.append(cell)
			var ev := {"type": "spell", "caster": at.id, "spell": "fireball", "cells": cells, "targets": []}
			var out := [ev]
			var spots: Array[Vector2i] = [mid, mid + Vector2i(1, 1), mid + Vector2i(-1, 1)]
			for c in cv.e.combatants:
				if c.side == &"enemy" and c.is_alive() and not spots.is_empty():
					(cv.tokens[c.id] as CombatToken).position = cv.board.cell_center(spots.pop_front() as Vector2i, c.size_cells)
					c.creature.hp = 1
					out.append({"type": "damage", "id": c.id, "amount": c.creature.max_hp() - 1})
			return out
		"last":
			# Every other foe is already down; the fight ends on this blow.
			var quiet := CombatImpact.enabled
			CombatImpact.enabled = false
			for c in cv.e.combatants:
				if c.side == &"enemy" and c != t and c.is_alive():
					c.creature.hp = 0
					c.creature.dead = true
					cv.e.events.append({"type": "death", "id": c.id})
			cv.call("_play_events")
			CombatImpact.enabled = quiet
			cv.e.state = Encounter.State.OVER
			cv.e.outcome = "victory"
			cr.hp = 0
			cr.dead = true
			return [swing, {"type": "damage", "id": t.id, "amount": cr.max_hp()}, {"type": "death", "id": t.id}]
	return []


## Puts `c`'s token (shown only) on a free square next to `t`.
func _beside(c: Combatant, t: Combatant) -> void:
	var best := c.cell
	var best_d := INF
	var want := 1.0
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			var cell := t.cell + Vector2i(dx, dy)
			if not cv.e.grid.in_bounds(cell) or cv.e.grid.is_solid(cell) or cv.e.occupant_at(cell) != null:
				continue
			var d := absf(Vector2(dx, dy).length() - want)
			if d < best_d:
				best_d = d
				best = cell
	var tok := cv.tokens[c.id] as CombatToken
	tok.position = cv.board.cell_center(best, c.size_cells)
	var to := cv.board.cell_center(t.cell, t.size_cells) - tok.position
	tok.face(Vector2(to.x, to.z), false)


func _nearest_foe(a: Combatant) -> Combatant:
	var best: Combatant = null
	for c in cv.e.combatants:
		if c.side == &"enemy" and c.is_alive() and cv.tokens.has(c.id):
			if best == null or cv.e.distance(a, c) < cv.e.distance(a, best):
				best = c
	return best


## Shoots `seconds` of real time FPS times a second (frames kept in memory, saved after so saving doesn't stall it).
func _film(moment: String, seconds: float) -> void:
	var shots: Array[Image] = []
	var start := Time.get_ticks_msec()
	var next := 0.0
	while next <= seconds:
		await get_tree().process_frame
		var now := (Time.get_ticks_msec() - start) / 1000.0
		if now < next:
			continue
		var img := get_viewport().get_texture().get_image()
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
		shots.append(img)
		next += 1.0 / FPS
	for i in shots.size():
		shots[i].save_jpg("%s_%s_%02d.jpg" % [_out, moment, i], 0.82)
	_sheet(shots, "%s_%s_sheet.jpg" % [_out, moment])
	print("capture: %s_%s (%d frames)" % [_out, moment, shots.size()])


func _sheet(shots: Array[Image], path: String) -> void:
	var cols := 8
	var thumb := SIZE / 2
	var rows := ceili(float(shots.size()) / cols)
	var sheet := Image.create(thumb.x * cols, thumb.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		var t := shots[i].duplicate() as Image
		t.convert(Image.FORMAT_RGB8)
		t.resize(thumb.x, thumb.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, thumb), Vector2i((i % cols) * thumb.x, (i / cols) * thumb.y))
	sheet.save_jpg(path, 0.85)
