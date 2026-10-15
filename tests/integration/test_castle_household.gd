extends TestCase
## Owner, 2026-10-15: "Is Castle Ravenloft supposed to be empty when you walk through it? Should there be servants?" and
## "When Strahd invites the party over for dinner, the combats throughout the castle shouldn't be present until that
## sequence is complete." and "Fill Castle Ravenloft with generic NPCs who act as the servants or Strahd's court ... make
## sure they have paths which they walk around." The castle's household walks its rooms (a ghost steward, the dead watch
## on its rounds, a broom at its sweeping, Helga the maid, pale courtiers, a ghostly servant, the dead kitchen hands) and
## keeps out of every fight; while the party is Strahd's invited guest and dinner isn't over, the castle's fights that
## start as the party walks in wait (StoryConditions.TRUCES), and come back after.

const MAIN := "castle_ravenloft_main_floor"
const CASTLE := "castle_ravenloft"
## The household: who, where each walks, and their conversation.
const HOUSEHOLD: Array = [
	["castle_steward", MAIN, "castle_ravenloft/gates_household:steward"],
	["castle_dead_sentry", MAIN, "castle_ravenloft/gates_household:sentry"],
	["castle_hall_broom", MAIN, "castle_ravenloft/gates_household:broom"],
	["castle_courtier_1", MAIN, "castle_ravenloft/household:courtier"],
	["castle_courtier_2", MAIN, "castle_ravenloft/household:courtier"],
	["castle_ghost_servant", MAIN, "castle_ravenloft/household:ghost_servant"],
	["castle_dead_guard_1", MAIN, "castle_ravenloft/household:dead_guard"],
	["castle_dead_watchman", "castle_ravenloft_court", "castle_ravenloft/court_household:watchman"],
	["castle_courtier_1", "castle_ravenloft_court", "castle_ravenloft/household:courtier"],
	["castle_courtier_2", "castle_ravenloft_court", "castle_ravenloft/household:courtier"],
	["castle_ghost_servant", "castle_ravenloft_court", "castle_ravenloft/household:ghost_servant"],
	["helga_ruvak", "castle_ravenloft_court_weeping", "castle_ravenloft/court_household:helga"],
	["castle_ghost_servant", "castle_ravenloft_court_weeping", "castle_ravenloft/household:ghost_servant"],
	["castle_dead_guard_1", "castle_ravenloft_gates", "castle_ravenloft/household:dead_guard"],
	["castle_dead_guard_2", "castle_ravenloft_gates", "castle_ravenloft/household:dead_guard"],
	["castle_dead_servant_1", "castle_ravenloft_larders", "castle_ravenloft/household:dead_servant"],
	["castle_dead_servant_2", "castle_ravenloft_larders", "castle_ravenloft/household:dead_servant"],
	["castle_dead_guard_1", "castle_ravenloft_larders_dungeon", "castle_ravenloft/household:dead_guard"],
	["castle_ghost_servant", "castle_ravenloft_spires", "castle_ravenloft/household:ghost_servant"],
]

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	root = null
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The four pregens at level 10, the castle's band.
static func _party() -> StoryState:
	var st := StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		st.party.append(Pregens.build(id, 10))
	return st


## Every castle fight, with its map: [{location, spec}].
static func _castle_fights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in Compendium.shared().table("locations"):
		var loc := Compendium.shared().get_entry("locations", id)
		if str(loc.get("region", "")) != CASTLE:
			continue
		for en: Variant in loc.get("encounters", []):
			out.append({"location": id, "spec": en})
	return out


## Whether the fight would start now on its map, as the game asks (with the map's region), and as it was asked before
## the truce (without it).
static func _live(spec: Dictionary, st: StoryState, region: String = CASTLE) -> bool:
	return StoryConditions.check(StoryConditions.encounter_when(spec, region), st)


func test_dinner_guests_walk_the_castle_unfought_until_dinner_is_over() -> void:
	var st := _party()
	var walk_ins := 0
	st.set_flag("strahd_invitation", "accepted")
	assert_true(StoryConditions.truce_holds(CASTLE, st), "the invitation is open")
	for f: Dictionary in _castle_fights():
		var spec := f["spec"] as Dictionary
		if str(spec["trigger"]).begins_with("enter_area:"):
			walk_ins += 1
			assert_false(_live(spec, st), "%s waits for dinner (%s)" % [spec["id"], f["location"]])
		else:
			assert_eq(_live(spec, st), _live(spec, st, ""), "%s, which the party starts, is as it was" % spec["id"])
	assert_true(walk_ins >= 20, "the castle's walk-in fights are all held (%d)" % walk_ins)
	for ending: String in ["dined", "affront"]:
		st.set_flag("castle_dinner", ending)
		assert_false(StoryConditions.truce_holds(CASTLE, st), "dinner %s: the truce is over" % ending)
		for f: Dictionary in _castle_fights():
			var spec := f["spec"] as Dictionary
			assert_eq(_live(spec, st), _live(spec, st, ""), "after dinner (%s) %s is back as it was" % [ending, spec["id"]])
	var uninvited := _party()
	assert_false(StoryConditions.truce_holds(CASTLE, uninvited), "no invitation, no truce")
	var declined := _party()
	declined.set_flag("strahd_invitation", "declined")
	assert_false(StoryConditions.truce_holds(CASTLE, declined), "nor for those who said no")
	for f: Dictionary in _castle_fights():
		var spec := f["spec"] as Dictionary
		assert_eq(_live(spec, uninvited), _live(spec, uninvited, ""), "uninvited, %s is as it was" % spec["id"])
	# The truce is the castle's own: an invited party elsewhere meets its fights as before.
	var spec_elsewhere := {"id": "x", "trigger": "enter_area:yard", "when": ""}
	assert_true(_live(spec_elsewhere, st, "village_of_barovia"), "another region keeps its fights")
	assert_eq(StoryConditions.encounter_when({"when": "flag.a", "trigger": "enter_area:hall"}), "flag.a",
		"without a region, a fight's condition is its own")


func test_strahd_still_waits_at_the_table_through_the_truce() -> void:
	var st := _party()
	st.set_flag("strahd_invitation", "accepted")
	assert_eq(SideQuestPlay.standing(st, MAIN, "strahd"), "castle_ravenloft/gates_dinner:start", "the host at the organ")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/gates_dinner:start", ["Excuse yourselves"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(StoryConditions.truce_holds(CASTLE, st), "a party that leaves the table is still his guest")
	SideQuestPlay.play(st, "castle_ravenloft/gates_dinner:start", ["Thank him"])
	assert_eq(str(st.get_flag("castle_dinner", "")), "dined")
	assert_false(StoryConditions.truce_holds(CASTLE, st), "dinner over: the house is itself again")


## The truce holds for resting too: no walk-in fight keeps the party awake, and its fights come back after dinner.
func test_a_waiting_castle_fight_counts_again_after_dinner() -> void:
	var st := _party()
	st.location = MAIN
	var before := RestRules.waiting_fights(st, MAIN).map(func(w: Dictionary) -> String: return str(w["id"]))
	assert_true("crg_turret_guard" in before, "uninvited, the turret guard waits (%s)" % [before])
	st.set_flag("strahd_invitation", "accepted")
	var during := RestRules.waiting_fights(st, MAIN).map(func(w: Dictionary) -> String: return str(w["id"]))
	assert_false("crg_turret_guard" in during, "not while the invitation is open (%s)" % [during])
	st.set_flag("castle_dinner", "dined")
	var after := RestRules.waiting_fights(st, MAIN).map(func(w: Dictionary) -> String: return str(w["id"]))
	assert_true("crg_turret_guard" in after, "back once dinner is over (%s)" % [after])


## Boots the main floor with the castle's band, the party at `at`, and the turret's doors open.
func _boot(location: String, at: Vector2i, flags: Dictionary = {}) -> LocationView:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f: String in flags:
		GameState.story.set_flag(f, flags[f])
	for d: String in ["crg_turret_east_door", "crg_turret_west_door"]:
		(GameState.story.loc_state(MAIN)["doors"] as Dictionary)[d] = LocationView.DOOR_OPEN
	GameState.story.location = location
	GameState.story.positions = [at, at + Vector2i(0, 1), at + Vector2i(-1, 0), at + Vector2i(-1, 1)]
	GameState.story.minute_of_day = 20 * 60
	Dice.reseed(1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()
	return root.get("view") as LocationView


func _walk(v: LocationView, to: Vector2i) -> void:
	assert_true(v.walk_to(to), "a way to %s" % to)
	for i in 3000:
		if v.in_combat or (not v.busy and v.leader().cell == to):
			break
		await get_tree().process_frame


func test_walking_into_the_turret_post_waits_for_dinner() -> void:
	var v: LocationView = await _boot(MAIN, Vector2i(28, 20), {"strahd_invitation": "accepted"})
	await _walk(v, Vector2i(32, 20))
	assert_eq(v.leader().cell, Vector2i(32, 20), "in the east turret post")
	assert_false(v.in_combat, "the armour stays on its stands while the invitation is open")
	assert_eq(str((v.st.loc_state(MAIN)["encounters"] as Dictionary).get("crg_turret_guard", "")), "", "not begun")
	await _walk(v, Vector2i(27, 20))
	v.st.set_flag("castle_dinner", "dined")
	await _walk(v, Vector2i(32, 20))
	assert_true(v.in_combat, "after dinner the turret's guard is back on duty")


func test_the_household_walks_the_main_floor_and_keeps_out_of_its_fights() -> void:
	var v: LocationView = await _boot(MAIN, Vector2i(28, 20))
	var cells := {}
	for row: Array in HOUSEHOLD.filter(func(r: Array) -> bool: return str(r[1]) == MAIN):
		var id := str(row[0])
		assert_true(v.npc_tokens.has(id), "%s is on the main floor" % id)
		var tok := v.npc_tokens[id] as CombatToken
		assert_true(tok.visible, "%s shows" % id)
		cells[id] = tok.combatant.cell
	assert_true(v.start_encounter("crg_turret_guard"), "the turret's guard fights")
	await _frames(2)
	var e := v.combat_view.e
	for id: String in cells:
		assert_false((v.npc_tokens[id] as CombatToken).visible, "%s keeps out of the fight" % id)
		assert_false(e.grid.has_flag(cells[id] as Vector2i, CombatGrid.LOW), "and doesn't stand in its way (%s)" % id)
	v.refresh_npcs()
	for id: String in cells:
		assert_true((v.npc_tokens[id] as CombatToken).visible, "%s is back after it" % id)


## Each of the household stands where its map puts it, with art to show and a conversation that can always be left,
## and talking to them changes nothing in the story.
func test_the_household_has_a_word_and_a_way_out() -> void:
	var maps := {}
	for row: Array in HOUSEHOLD:
		var id := str(row[0])
		var loc := str(row[1])
		var ref := str(row[2])
		maps[loc] = true
		var npc := Compendium.shared().get_entry("npcs", id)
		assert_false(npc.is_empty(), "%s has an NPC entry" % id)
		var st := _party()
		st.location = loc
		assert_eq(SideQuestPlay.standing(st, loc, id), ref, "%s stands in %s" % [id, loc])
		var spec := {}
		for n: Variant in Compendium.shared().get_entry("locations", loc)["npcs"]:
			if str((n as Dictionary)["npc"]) == id:
				spec = n as Dictionary
		assert_true(bool(spec.get("steps_aside", false)), "%s keeps out of fights in %s" % [id, loc])
		assert_false((spec.get("path", []) as Array).is_empty(), "%s walks a route in %s" % [id, loc])
		var flags := st.flags.duplicate(true)
		var quests := st.quests.duplicate(true)
		var beats := SideQuestPlay.play(st, ref)
		assert_eq(str(beats[-1].get("kind", "")), "end", "%s's conversation ends" % id)
		assert_eq(SideQuestPlay.combat_of(beats), "", "and starts no fight")
		assert_eq(st.flags, flags, "%s sets nothing" % id)
		assert_eq(st.quests, quests, "nor moves a quest")
	assert_true(maps.size() >= 7, "the household walks seven of the castle's maps (%d)" % maps.size())
	var invited := _party()
	invited.set_flag("strahd_invitation", "accepted")
	var text := SideQuestPlay.text(SideQuestPlay.play(invited, "castle_ravenloft/gates_household:steward", ["Where should we sit?"]))
	assert_true(text.contains("You are expected"), "the steward expects the master's guests: " + text)
	assert_true(text.contains("chair at his right hand"), text)
