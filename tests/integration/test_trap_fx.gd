extends TestCase
## A trap going off outside a fight (owner todo 2026-10-17): the party panel's Hit Points follow the damage at once (they
## stayed at the old value until something else refreshed the panel), the damage floats over the head of whoever took it as
## it does in a fight, and the trap plays its own effect on them (world/exploration/trap_fx.gd, art/vfx/effects.json), a
## pit's fall and a failed climb or swim that hurts too. The beat waits for the big d20 and for a paused game, on timers
## that run while the game is paused (location_hurt.gd).

const HALL := {
	"id": "test_trap_fx_hall", "name": "Trap Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"##############"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"props": [{"id": "slick_ledge", "cell": [2, 1], "kind": "decor", "label": "A slick ledge", "checks": [
		{"id": "ledge_climb", "skill": "athletics", "dc": 40, "label": "Climb the ledge", "alone": true,
			"success": {"text": "Up."}, "failure": {"text": "You slip.", "damage": "2d6", "damage_type": "bludgeoning"}}]}],
	"traps": [
		{"id": "t_lamp", "label": "a lamp", "cells": [[4, 2]], "detect_dc": 40, "disarm_dc": 40, "save": {"ability": "dex", "dc": 40},
			"damage": "3d6", "damage_type": "fire", "text": "Oil."},
		{"id": "t_glyph", "label": "a glyph", "cells": [[6, 2]], "detect_dc": 40, "disarm_dc": 40, "save": {"ability": "dex", "dc": 40},
			"damage": "3d6", "damage_type": "lightning", "text": "Zap."},
		{"id": "t_dart", "label": "a dart wall", "cells": [[8, 2]], "detect_dc": 40, "disarm_dc": 40, "save": {"ability": "dex", "dc": 40},
			"damage": "3d6", "damage_type": "piercing", "text": "Pft."},
		{"id": "t_beam", "label": "a beam", "cells": [[10, 2]], "detect_dc": 40, "disarm_dc": 40, "save": {"ability": "dex", "dc": -50},
			"damage": "3d6", "damage_type": "bludgeoning", "text": "Crack."},
		{"id": "t_pit", "label": "a covered pit", "cells": [[12, 2]], "pit_ft": 10, "detect_dc": 40, "disarm_dc": 40,
			"save": {"ability": "dex", "dc": 40}, "damage": "1d4", "damage_type": "piercing", "text": "Down."}]}

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Compendium.shared().tables["locations"]["test_trap_fx_hall"] = HALL.duplicate(true)
	GameState.story.location = "test_trap_fx_hall"
	GameState.story.visited["test_trap_fx_hall"] = true
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(4)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	get_tree().paused = false
	await _frames(1)
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_trap_fx_hall")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


## Springs trap `id` on the leader, standing in its square (a found trap set off on purpose, from where it is).
func _spring(id: String) -> Combatant:
	var view := _view()
	var trap := _trap(id)
	var victim := view.leader()
	victim.cell = LocationView._cell((trap["cells"] as Array)[0])
	LocationTraps.activate(view, trap)
	return victim


func _trap(id: String) -> Dictionary:
	for t: Variant in HALL["traps"]:
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


## The "hp / max" line of every party card on the exploring HUD, in the party's order.
func _panel() -> Array[String]:
	var out: Array[String] = []
	for l in (root.get("hud") as ExploreHud).find_children("*", "Label", true, false):
		var text := (l as Label).text
		if text.contains(" / ") and text.split(" / ")[0].is_valid_int():
			out.append(text)
	return out


func _expected_panel() -> Array[String]:
	var out: Array[String] = []
	for ch in GameState.story.party:
		out.append("%d / %d" % [ch.hp, ch.max_hp()])
	return out


## The marks floating over heads right now (Label3D under the view).
func _marks() -> Array[String]:
	var out: Array[String] = []
	for n in _view().get_children():
		if n is Label3D:
			out.append((n as Label3D).text)
	return out


func test_the_party_panel_follows_a_trap_damage() -> void:
	assert_eq(_panel(), _expected_panel(), "full to start with")
	var victim := _spring("t_lamp")
	var lost := victim.creature.max_hp() - victim.creature.hp
	assert_true(lost > 0, "the lamp hurt them")
	await _frames(2)   # the old cards free at the end of the frame
	assert_eq(_panel(), _expected_panel(), "the panel shows what they have left, not the old value")


func test_the_damage_floats_over_their_head_as_in_a_fight() -> void:
	var victim := _spring("t_glyph")
	var lost := victim.creature.max_hp() - victim.creature.hp
	assert_true("-%d" % lost in _marks(), "-%d over them: %s" % [lost, _marks()])
	await get_tree().create_timer(FloatText.TIME + 0.3).timeout
	assert_true(_marks().is_empty(), "and it fades and frees")


func test_a_saved_trap_floats_the_half_it_did() -> void:
	var victim := _spring("t_beam")
	var lost := victim.creature.max_hp() - victim.creature.hp
	assert_true("-%d" % lost in _marks() or (lost == 0 and "Unhurt" in _marks()), "what got through: %s %s" % [lost, _marks()])


func test_the_trap_plays_its_own_effect_on_them() -> void:
	_spring("t_lamp")
	var fxs := _view().find_children("*", "SpellFx", false, false)
	assert_eq(fxs.size(), 1, "the effect is up")
	await _frames(3)
	assert_true((fxs[0] as Node).find_children("*", "GPUParticles3D", true, false).size() > 0, "a burst of fire")


func test_every_look_plays_without_a_script_error() -> void:
	var view := _view()
	var tok := view.tokens[view.leader().id] as CombatToken
	var played: Array[SpellFx] = []
	for family in TrapFx.FAMILIES:
		var cue := {"family": family, "flavour": "steel", "size": 1.0, "key": "traps:test", "type": "piercing"}
		if family in ["nova", "strike"]:
			cue["flavour"] = "lightning"
		cue["colours"] = SpellFx.colours(str(cue["flavour"]))
		var fx := SpellFx.new()
		view.add_child(fx)
		TrapFx.play(fx, cue, tok, view)
		await _frames(3)
		assert_true(fx.get_child_count() > 0, "%s shows something" % family)
		played.append(fx)
	# Their delayed parts (a strike's splash, a crash's dust) play out before the effects go, as they do in the game.
	await get_tree().create_timer(1.2).timeout
	for fx in played:
		fx.queue_free()


func test_a_pit_floats_the_fall_and_the_stakes_together() -> void:
	var victim := _spring("t_pit")
	var lost := victim.creature.max_hp() - victim.creature.hp
	assert_true(lost > 0)
	assert_true("-%d" % lost in _marks(), "the fall and the stakes as one number: -%d in %s" % [lost, _marks()])
	await _frames(2)
	assert_eq(_panel(), _expected_panel())


func test_a_failed_climb_that_hurts_shows_the_same() -> void:
	var view := _view()
	var who := WorldChecks.roller(GameState.story, "test_trap_fx_hall", (HALL["props"][0]["checks"] as Array)[0] as Dictionary)
	var hp := who.hp
	LocationChecks.act(view, view.thing_at(Vector2i(2, 1)), "check:ledge_climb")
	# A fighter's Tactical Mind or a human's Heroic Inspiration would be asked about first (CheckAidPrompt): let the miss stand.
	for i in 12:
		var ask := root.get("_prompting") as CheckAidPrompt
		if ask != null and ask.visible:
			ask.stand_button.pressed.emit()
			break
		await get_tree().process_frame
	var lost := hp - who.hp
	assert_true(lost > 0, "the slip hurt")
	assert_true("-%d" % lost in _marks(), "-%d over them: %s" % [lost, _marks()])
	await _frames(2)
	assert_eq(_panel(), _expected_panel(), "and the panel has it")
	assert_eq(_view().find_children("*", "SpellFx", false, false).size(), 1, "with a crash of dust")


func test_the_beat_waits_while_the_game_is_paused_and_plays_when_it_isnt() -> void:
	get_tree().paused = true
	var victim := _spring("t_dart")
	await _frames(3)
	assert_true(_marks().is_empty(), "nothing shows over a paused game")
	assert_true(victim.creature.hp < victim.creature.max_hp(), "though the damage is dealt")
	get_tree().paused = false
	await get_tree().create_timer(LocationHurt.STEP * 3.0).timeout
	assert_false(_marks().is_empty(), "it plays once the game goes on: %s" % [_marks()])
	await _frames(2)
	assert_eq(_panel(), _expected_panel())


func test_every_trap_in_the_game_has_a_look() -> void:
	var flavours := SpellFx.data()["flavours"] as Dictionary
	var seen := 0
	for loc_id: Variant in Compendium.shared().tables["locations"]:
		for t: Variant in (Compendium.shared().tables["locations"][loc_id] as Dictionary).get("traps", []):
			var trap := t as Dictionary
			var cue := TrapFx.cue("traps", str(trap["id"]), StringName(str(trap.get("damage_type", "bludgeoning"))), PitFall.is_pit(trap))
			assert_true(str(cue["family"]) in TrapFx.FAMILIES, "%s: %s" % [trap["id"], cue])
			assert_true(flavours.has(str(cue["flavour"])), "%s is drawn in a flavour effects.json has" % trap["id"])
			seen += 1
	assert_true(seen > 20, "the game's traps were all checked")


func test_effects_json_picks_name_real_traps_and_checks() -> void:
	var traps := {}
	var checks := {}
	for loc_id: Variant in Compendium.shared().tables["locations"]:
		var loc := Compendium.shared().tables["locations"][loc_id] as Dictionary
		for t: Variant in loc.get("traps", []):
			traps[str((t as Dictionary)["id"])] = true
		for entry in WorldChecks.all_in(loc):
			checks[str((entry["check"] as Dictionary)["id"])] = true
	for id: Variant in (SpellFx.data()["traps"] as Dictionary):
		assert_true(traps.has(str(id)), "effects.json picks a look for %s, which isn't a trap" % id)
	for id: Variant in (SpellFx.data()["checks"] as Dictionary):
		assert_true(checks.has(str(id)), "effects.json picks a look for %s, which isn't a check" % id)
	for type: Variant in (SpellFx.data()["trap_damage"] as Dictionary):
		var cue := TrapFx.cue("traps", "none", StringName(str(type)))
		assert_true(str(cue["family"]) in TrapFx.FAMILIES, "%s: %s" % [type, cue])


func test_a_save_that_held_plays_smaller() -> void:
	var full := TrapFx.cue("traps", "t_lamp", &"fire")
	var held := TrapFx.cue("traps", "t_lamp", &"fire", false, true)
	assert_eq(float(held["size"]), float(full.get("size", 1.0)) * TrapFx.SAVED_SIZE)
