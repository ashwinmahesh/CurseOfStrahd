extends TestCase
## The vaults' small things (Amber Temple Look Plan step 10, AmberGlow): the hollow's crimson thread (faint always, bright
## once the party has read the hollow: flag amber_thread_seen, set in amber_temple/vosk:hollow_ok), the honey-glow doors'
## amber panes with a light both sides, glints on the heaps of the vault of offerings, and the sanctum's cold braziers
## flaring violet for the fight with Vosk.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _view() -> LocationView:
	var v := LocationView.create("amber_temple_vault", GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _case_of(node: Node) -> AmberGlow.Case:
	for c in node.find_children("*", "Node3D", true, false):
		if c is AmberGlow.Case:
			return c as AmberGlow.Case
	return null


func _settle(case: AmberGlow.Case) -> void:
	for i in 12:
		case._process(1.0)
		if case.light != null:
			case.light.light_energy = case.light.base_energy


func test_the_hollows_thread_is_faint_until_it_is_seen() -> void:
	var v := _view()
	await _frames(3)
	var hollow := _case_of(v.prop_nodes["hollow_sarcophagus"] as Node)
	assert_true(hollow != null and hollow.kind == "hollow", "the hollow is the largest block")
	assert_true(hollow.thread != null, "a thread rises out of it")
	var line := hollow.find_child("Thread", false, false) as MeshInstance3D
	assert_true(line != null and line.mesh is CylinderMesh and (line.mesh as CylinderMesh).height > 8.0, "a long thin line")
	assert_true((line.mesh as CylinderMesh).top_radius < 0.06, "thin as a hair")
	var top := hollow.position.y + line.position.y + (line.mesh as CylinderMesh).height / 2.0
	assert_true(top > 8.0, "rising out of the top of the amber into the dark (%.1f)" % top)
	AmberGlow.refresh(v)
	_settle(hollow)
	var faint := float(hollow.thread.get_shader_parameter("strength"))
	assert_true(is_equal_approx(faint, AmberGlow.THREAD_FAINT), "faint at first (%.2f)" % faint)
	GameState.story.set_flag("amber_thread_seen")
	AmberGlow.refresh(v)
	_settle(hollow)
	var bright := float(hollow.thread.get_shader_parameter("strength"))
	assert_true(bright > faint * 3.0, "bright once it has been seen (%.2f)" % bright)
	v.queue_free()


## Reading the hollow with Arcana sets the flag, once.
func test_reading_the_hollow_sets_the_flag() -> void:
	var st := GameState.story
	assert_false(bool(st.get_flag("amber_thread_seen", false)), "not at first")
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	assert_true(r.start("amber_temple/vosk:hollow_ok"), "the line starts")
	var b := r.next()
	for i in 10:
		if str(b["kind"]) in ["options", "end"]:
			break
		b = r.next()
	assert_true(bool(st.get_flag("amber_thread_seen", false)), "the thread is seen")


func test_the_honey_doors_are_amber_and_light_both_sides() -> void:
	var v := _view()
	await _frames(3)
	var door := v.door_nodes.get("honey_doors") as Node3D
	assert_true(door != null, "the honey-glow doors stand in the hall")
	var case := _case_of(door)
	assert_true(case != null and case.kind == "door", "their panes are amber")
	assert_eq(case.glass.size(), 4, "two panes, each of two passes of the amber glass")
	assert_true(case.light != null and case.light.has_meta("amber"), "with an amber light that falls on both sides of the doorway")
	assert_true(case.is_in_group(&"amber_cases"), "and is one of the temple's amber (it goes dark when the temple is sealed)")
	AmberGlow.refresh(v)
	_settle(case)
	var lit := float(case.glass[0].get_shader_parameter("glow"))
	assert_true(lit > 0.2, "glowing (%.2f)" % lit)
	GameState.story.set_flag("amber_temple_sealed")
	AmberGlow.refresh(v)
	_settle(case)
	assert_true(float(case.glass[0].get_shader_parameter("glow")) < 0.05, "dark once sealed")
	v.queue_free()


func test_the_offerings_glint() -> void:
	var v := _view()
	await _frames(3)
	var glints := v.get_node_or_null("OfferingGlints")
	assert_true(glints != null, "the vault of offerings glints")
	if glints != null:
		assert_true(glints.get_child_count() >= AmberGlow.GLINTS_PER_HEAP * 2, "over its heaps of gold (%d)" % glints.get_child_count())
		var seen := {}
		for g in glints.get_children():
			seen[(g as Node3D).position] = true
		assert_eq(seen.size(), glints.get_child_count(), "each hung in its own place")
	v.queue_free()


func test_the_braziers_flare_for_the_fight_with_vosk() -> void:
	var v := _view()
	await _frames(3)
	var flare := v.get_node_or_null("SanctumFlare") as Node3D
	assert_true(flare != null and flare.get_child_count() >= 1, "the sanctum's cold braziers each have a violet flame waiting")
	assert_false(flare.visible, "cold at first")
	v.in_combat = true
	v.last_encounter = {"id": "hollow_eyed"}
	AmberGlow.refresh(v)
	assert_false(flare.visible, "another fight leaves them cold")
	v.last_encounter = {"id": "vosk_unmasked"}
	AmberGlow.refresh(v)
	assert_true(flare.visible, "the fight with Vosk flares them")
	v.in_combat = false
	AmberGlow.refresh(v)
	assert_false(flare.visible, "and they are cold again after")
	v.queue_free()


func test_classic_has_none_of_it() -> void:
	Look.set_style("classic", false)
	var v := _view()
	await _frames(3)
	assert_true(v.get_node_or_null("OfferingGlints") == null and v.get_node_or_null("SanctumFlare") == null, "no glints or flares in Classic")
	var door := v.door_nodes.get("honey_doors") as Node3D
	assert_true(door == null or _case_of(door) == null, "the doors keep their picture")
	v.queue_free()
