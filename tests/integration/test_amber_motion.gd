extends TestCase
## The Amber Temple's small motion (Amber Temple Look Plan step 11, AmberMotion): the hall of echoes' candles burn frost-blue
## but for Patrina's, and paper flakes fall over her book; Vosk's cup steams and Exethanter's notes stir in the library;
## Yrrga's eye follows the leader; amber seeps from the weeping crack. Classic has none of it.

var _level := 1


func before_each() -> void:
	_level = 1
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _party(level: int) -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func _view(loc_id: String, level: int = 1) -> LocationView:
	_party(level)
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_the_hall_of_echoes_is_cold_but_for_patrinas_candle() -> void:
	var v := _view("amber_temple_faceless_god")
	await _frames(8)
	AmberGlow.refresh(v)
	assert_true(v.has_meta("echoes_frosted"), "the candles of the hall of echoes have been tinted")
	var cold := 0
	var warm_near_patrina := 0
	for l: Node in v.find_children("*", "OmniLight3D", true, false):
		var light := l as OmniLight3D
		var cell := v.grid.cell_at(light.global_position)
		if not AmberMotion.ECHOES.has_point(cell):
			continue
		if AmberMotion._near_patrina(light.global_position):
			if light.light_color.r > light.light_color.b:
				warm_near_patrina += 1   # (her desk's own candle: the location's light there, and the candle's)
		elif light.light_color.b > light.light_color.r and (str(l.name).begins_with("PropLight") or str(l.name).begins_with("FlameLight")):
			cold += 1
	assert_true(cold >= 3, "the hall's candle lights are frost-blue (%d)" % cold)
	assert_true(warm_near_patrina >= 1, "the one beside Patrina's clear desk stays warm (%d)" % warm_near_patrina)
	var flakes := v.get_node_or_null("PaperFlakes") as GPUParticles3D
	assert_true(flakes != null and flakes.emitting, "paper flakes fall")
	assert_true(absf(flakes.position.x - AmberMotion.BOOK_AT.x) < 0.5 and absf(flakes.position.z - AmberMotion.BOOK_AT.y) < 0.5, "over her book")
	v.queue_free()


func test_the_library_steams_and_stirs() -> void:
	var v := _view("amber_temple_library")
	await _frames(4)
	assert_true(v.npc_tokens.has("vosk"), "Vosk sits in the library")
	await _frames(2)
	var steam := v.get_node_or_null("CupSteam") as GPUParticles3D
	assert_true(steam != null and steam.emitting, "his cup steams")
	var notes := v.prop_nodes.get("exethanter_notes") as Node3D
	assert_true(notes != null, "Exethanter's notes are pinned up")
	var pieces := notes.find_children("Model_*", "Node3D", false, false)
	if not pieces.is_empty():
		var seen := {}
		for i in 40:
			await get_tree().process_frame
			seen[snappedf((pieces[0] as Node3D).rotation.z, 0.0001)] = true
		assert_true(seen.size() > 3, "the notes stir (%d positions)" % seen.size())
	v.queue_free()


func test_yrrgas_eye_follows_the_leader() -> void:
	var v := _view("amber_temple_vault")
	await _frames(4)
	var yrrga := (v.prop_nodes["sarc_yrrga"] as Node3D).find_children("*", "Node3D", true, false).filter(
		func(n: Node) -> bool: return n is AmberGlow.Case)[0] as AmberGlow.Case
	assert_true(yrrga.gaze_quad != null, "its eye can look")
	var cam := v.rig.camera
	var right := cam.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var base := yrrga.global_position
	var leader := v.tokens[v.leader().id] as Node3D
	leader.global_position = base + right * 5.0
	AmberMotion.refresh(v)
	for i in 8:
		yrrga._process(0.5)
	var to_right := yrrga.gaze_quad.global_position - (yrrga.global_transform * yrrga._gaze_base)
	leader.global_position = base - right * 5.0
	AmberMotion.refresh(v)
	for i in 8:
		yrrga._process(0.5)
	var to_left := yrrga.gaze_quad.global_position - (yrrga.global_transform * yrrga._gaze_base)
	assert_true(to_right.dot(right) > 0.04, "it looks toward a party to its right (%.2f)" % to_right.dot(right))
	assert_true(to_left.dot(right) < -0.04, "and to its left (%.2f)" % to_left.dot(right))
	assert_true(to_right.length() < 0.2 and to_left.length() < 0.2, "never far from where it hangs")
	v.queue_free()


func test_the_weeping_crack_seeps_once_it_shows() -> void:
	var low := _view("amber_temple_vault", 1)
	await _frames(3)
	assert_true(low.prop_nodes.get("vault_weeping_crack") == null, "the crack doesn't show to a low party")
	low.queue_free()
	var v := _view("amber_temple_vault", 10)
	await _frames(3)
	var crack := v.prop_nodes.get("vault_weeping_crack") as Node3D
	assert_true(crack != null, "it shows at level 10")
	assert_true(crack.get_node_or_null("AmberSeep") != null and crack.get_node_or_null("SeepLight") != null, "amber seeps from it, with a low light")
	v.queue_free()


func test_classic_has_none_of_it() -> void:
	Look.set_style("classic", false)
	var v := _view("amber_temple_faceless_god")
	await _frames(4)
	assert_true(v.get_node_or_null("PaperFlakes") == null, "no paper flakes in Classic")
	assert_false(v.has_meta("echoes_frosted"), "no frost candles")
	v.queue_free()
