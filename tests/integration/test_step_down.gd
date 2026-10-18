extends TestCase
## The Amber Sentinel steps down (Amber Temple Look Plan step 9, StepDown): whichever way its fight starts (the conversation
## that ended in a blow, `sentinel_wakes`, or the walk onto the ledge, `sentinel_stops_you`, at level 10 or lower) exactly one
## Sentinel figure is on the board, the person's, hidden, giving way to the foe's, which strides from the dais to its start
## square and ends there; a colossus is drawn faint over a friend behind it; and the stat block stays Large, two squares.

const FIGURE := "amber_sentinel"
const LEDGE := "amber_temple_entrance"


func before_each() -> void:
	GameState.reset()
	Look.set_style("modern", false)
	StepDown.headless_too = false


func after_each() -> void:
	StepDown.headless_too = false
	Look.set_style(Look.DEFAULT_STYLE, false)


func _party(level: int) -> void:
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


## The ledge with the party on the snow below the doors and the fight begun: through the conversation (`aside`: the people of it
## step aside, as a dialogue's `combat` does) or by walking onto it.
func _fight(level: int, encounter: String, aside: bool) -> LocationView:
	_party(level)
	GameState.story.set_flag("amber_temple_arrived")
	GameState.story.location = LEDGE
	GameState.story.visited[LEDGE] = true
	for c: Vector2i in [Vector2i(15, 13), Vector2i(16, 13), Vector2i(17, 13), Vector2i(14, 13)]:
		GameState.story.positions.append(c)
	var v := LocationView.create(LEDGE, GameState.story, Narrator.new(), Dice.roller, "")
	add_child(v)
	await get_tree().process_frame
	if aside:
		LocationNpcs.hide_npcs_of(v, "amber_temple/sentinel:attack")
	assert_true(LocationFights.start_encounter(v, encounter), "%s begins" % encounter)
	await get_tree().process_frame
	return v


## The Sentinel figures on the board that can be seen: tokens drawn with the colossus's sprite.
func _figures(v: LocationView) -> Array[CombatToken]:
	var out: Array[CombatToken] = []
	for n: Node in v.get_children():
		var t := n as CombatToken
		if t == null or not t.visible:
			continue
		var art := t.art_override if t.art_override != "" else CombatToken.art_id(t.combatant)
		if art == FIGURE:
			out.append(t)
	return out


func _foe(v: LocationView) -> CombatToken:
	for t in _figures(v):
		if t.combatant.side == &"enemy":
			return t
	return null


func test_each_start_leaves_one_sentinel_on_the_board() -> void:
	var starts := [
		{"level": 10, "encounter": "sentinel_wakes", "aside": true, "says": "the conversation, level 10"},
		{"level": 10, "encounter": "sentinel_stops_you", "aside": false, "says": "the walk onto the ledge"},
		{"level": 8, "encounter": "sentinel_wakes", "aside": true, "says": "the conversation, level 8"},
	]
	for s: Dictionary in starts:
		GameState.reset()
		var v := await _fight(int(s["level"]), str(s["encounter"]), bool(s["aside"]))
		var figures := _figures(v)
		assert_eq(figures.size(), 1, "one Sentinel is on the board after %s" % str(s["says"]))
		var foe := _foe(v)
		assert_true(foe != null, "and it is the foe (%s)" % str(s["says"]))
		if foe != null:
			var square := v.board.cell_center(foe.combatant.cell, foe.combatant.size_cells)
			assert_true(Vector2(foe.position.x - square.x, foe.position.z - square.z).length() < 0.05, "standing on its start square %s (%s)" % [str(foe.combatant.cell), str(s["says"])])
			assert_eq(foe.combatant.size_cells, 2, "a Large figure, two squares (%s)" % str(s["says"]))
		var person := v.npc_tokens.get("amber_sentinel") as Node3D
		assert_true(person != null and not person.visible, "the person on the dais is hidden (%s)" % str(s["says"]))
		v.queue_free()
		await get_tree().process_frame


func test_the_beat_strides_from_the_dais_and_ends_on_the_square() -> void:
	StepDown.headless_too = true
	var v := await _fight(10, "sentinel_stops_you", false)
	var foe := _foe(v)
	assert_true(foe != null and foe.has_meta(StepDown.META), "its figure has a stride to make")
	var dais := v.prop_nodes.get("sentinel_dais") as Node3D
	var seat := dais.get_meta("seat") as Vector3
	assert_true(foe.position.is_equal_approx(seat), "it starts on the dais (%s at %s)" % [str(foe.position), str(seat)])
	var opened := Time.get_ticks_msec()
	var waited := 0.0
	while foe.has_meta(StepDown.META) and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var took := (Time.get_ticks_msec() - opened) / 1000.0
	assert_true(not foe.has_meta(StepDown.META), "the stride plays out")
	assert_true(took <= StepDown.MOST + 0.4, "in about a second and a half (%.2f s)" % took)
	var square := v.board.cell_center(foe.combatant.cell, foe.combatant.size_cells)
	assert_true(Vector2(foe.position.x - square.x, foe.position.z - square.z).length() < 0.01, "and it ends exactly on its start square %s" % str(foe.combatant.cell))
	assert_eq(_figures(v).size(), 1, "with one Sentinel on the board throughout")
	assert_true(is_equal_approx(v.rig.shot_zoom, 1.0) and is_equal_approx(v.rig.shot_weight, 0.0), "the camera is back at the play view")
	v.queue_free()


func test_a_saved_fight_comes_back_with_one_sentinel_and_no_stride() -> void:
	StepDown.headless_too = true
	var v := await _fight(10, "sentinel_stops_you", false)
	var foe := _foe(v)
	var square := v.board.cell_center(foe.combatant.cell, foe.combatant.size_cells)
	while foe.has_meta(StepDown.META):
		await get_tree().process_frame
	var snapshot := {"location": LEDGE, "encounter": "sentinel_stops_you", "data": EncounterSnapshot.capture(v.combat_view.e)}
	v.queue_free()
	await get_tree().process_frame
	var back := LocationView.create(LEDGE, GameState.story, Narrator.new(), Dice.roller, "")
	add_child(back)
	await get_tree().process_frame
	assert_true(LocationFights.resume_encounter(back, snapshot), "the round-start save is picked up")
	await get_tree().process_frame
	var figures := _figures(back)
	assert_eq(figures.size(), 1, "one Sentinel is on the board")
	var again := _foe(back)
	assert_true(again != null and not again.has_meta(StepDown.META), "the foe's, with no stride to make")
	assert_true(again != null and Vector2(again.position.x - square.x, again.position.z - square.z).length() < 0.05, "standing where the round began")
	assert_true(not (back.npc_tokens.get("amber_sentinel") as Node3D).visible, "and the person on the dais is not there as well")
	back.queue_free()


func test_a_colossus_is_faint_over_a_friend_behind_it() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.look_at_from_position(Vector3(0.0, 6.0, 12.0), Vector3(0.0, 2.0, 0.0))
	var root := Node3D.new()
	add_child(root)
	var big := CombatToken.create(Combatant.new(Monster.from_data(Compendium.shared().monster_data("amber_golem")), &"enemy", Vector2i(0, 0)), FIGURE)
	root.add_child(big)
	big.position = Vector3.ZERO
	var hero := Pregens.build("ilse_varga", 3)
	var friend := CombatToken.create(Combatant.new(hero, &"party", Vector2i(0, -3)))
	root.add_child(friend)
	friend.position = Vector3(0.0, 0.0, -3.0)
	assert_true(big._tall > CombatToken.TALL, "the Sentinel is drawn tall (%.1f)" % big._tall)
	assert_true(big.hides_a_friend(), "a friend directly behind it is hidden by it")
	friend.position = Vector3(0.0, 0.0, 3.0)
	assert_true(not big.hides_a_friend(), "one in front of it is not")
	friend.position = Vector3(7.0, 0.0, -3.0)
	assert_true(not big.hides_a_friend(), "nor one off to the side")
	friend.position = Vector3(0.0, 0.0, -3.0)
	for _i in 12:
		big._ghost_look = 0.0
		big._ghost_step(0.1)
	assert_true(absf(big._ghost - CombatToken.GHOST) < 0.01, "it fades to %.2f of its strength (%.2f)" % [CombatToken.GHOST, big._ghost])
	assert_true(absf(big.sprite.modulate.a - CombatToken.GHOST) < 0.02, "as drawn")
	friend.position = Vector3(7.0, 0.0, -3.0)
	for _i in 12:
		big._ghost_look = 0.0
		big._ghost_step(0.1)
	assert_true(absf(big._ghost - 1.0) < 0.01, "and back to full when nothing is behind it")
	root.queue_free()
	cam.queue_free()


func test_the_four_entries_name_the_figure_and_the_person_and_keep_the_stat_block() -> void:
	var loc := JSON.parse_string(FileAccess.get_file_as_string("res://data/locations/%s.json" % LEDGE)) as Dictionary
	var found := 0
	for enc: Variant in loc["encounters"]:
		for mo: Variant in (enc as Dictionary)["monsters"]:
			var md := mo as Dictionary
			if str(md.get("name", "")) != "The Amber Sentinel":
				continue
			found += 1
			assert_eq(str(md.get("art", "")), FIGURE, "%s draws it as the colossus" % str((enc as Dictionary)["id"]))
			assert_eq(str((md.get("steps_down", {}) as Dictionary).get("npc", "")), "amber_sentinel", "and says whose place it takes")
			assert_eq(str(md["monster"]), "amber_golem", "the stat block is the Amber Golem's")
	assert_eq(found, 4, "the three sentinel_wakes and sentinel_stops_you")
	var golem := Combatant.new(Monster.from_data(Compendium.shared().monster_data("amber_golem")), &"enemy", Vector2i.ZERO)
	assert_eq(golem.size_cells, 2, "Large, two squares by two (no Gargantuan)")
