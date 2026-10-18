extends TestCase
## What a found trap of the Amber Temple glows with (Amber Temple Look Plan step 13, TrapGlow): the line of warding glyphs,
## the faceless god's gaze and the frost vent each get a glow on every square of theirs when they are found, and it goes with
## the trap; the other traps and Classic get none.

const TRAPS := {"warding_glyphs": "amber_temple_vault", "faceless_gaze": "amber_temple_faceless_god", "frost_vent": "amber_temple_faceless_god"}


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _trap(loc_id: String, trap_id: String) -> Dictionary:
	for t: Variant in (Compendium.shared().get_entry("locations", loc_id) as Dictionary).get("traps", []):
		if str((t as Dictionary)["id"]) == trap_id:
			return t as Dictionary
	return {}


func _glow_of(nodes: Array[Node3D]) -> Node3D:
	for n in nodes:
		if str(n.name) == "TrapGlow":
			return n
	return null


func test_each_of_the_three_glows_on_all_its_squares() -> void:
	for trap_id: String in TRAPS:
		var loc_id := str(TRAPS[trap_id])
		var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
		add_child(v)
		await get_tree().process_frame
		var trap := _trap(loc_id, trap_id)
		assert_false(trap.is_empty(), "%s is a trap of %s" % [trap_id, loc_id])
		var nodes := TrapSight.dress(v, trap)
		var glow := _glow_of(nodes)
		assert_true(glow != null, "%s glows once found" % trap_id)
		if glow != null:
			assert_eq(glow.get_child_count(), (trap["cells"] as Array).size(), "%s on every square of it" % trap_id)
		for n in nodes:
			n.queue_free()   # (disarmed: it all goes)
		v.queue_free()
		await get_tree().process_frame


func test_other_traps_and_classic_get_none() -> void:
	var v := LocationView.create("amber_temple_vault", GameState.story, null, Dice.roller, "default")
	add_child(v)
	await get_tree().process_frame
	var ice := TrapSight.dress(v, _trap("amber_temple_vault", "stair_ice"))
	assert_true(_glow_of(ice) == null, "the black ice on the steps has none of its own")
	for n in ice:
		n.queue_free()
	v.queue_free()
	await get_tree().process_frame
	Look.set_style("classic", false)
	var c := LocationView.create("amber_temple_vault", GameState.story, null, Dice.roller, "default")
	add_child(c)
	await get_tree().process_frame
	var glyphs := TrapSight.dress(c, _trap("amber_temple_vault", "warding_glyphs"))
	assert_true(_glow_of(glyphs) == null, "Classic shows the glyphs without a glow")
	for n in glyphs:
		n.queue_free()
	c.queue_free()
