extends TestCase
## Combat impact (G2, world/combat/combat_impact.gd): which blow fells whom, where a won fight's last foe falls (not
## when a foe slipped away after it), which spells turn the camera, and that every moment gives time and the camera
## back, by itself or when the fight's view closes in the middle of it.


func test_a_blow_and_what_it_fells() -> void:
	var events := [
		{"type": "attack", "attacker": "a", "target": "z1", "hit": true},
		{"type": "damage", "id": "z1", "amount": 9},
		{"type": "death", "id": "z1"},
		{"type": "attack", "attacker": "a", "target": "z2", "hit": true},
		{"type": "damage", "id": "z2", "amount": 3},
		{"type": "turn", "id": "z2"},
		{"type": "death", "id": "z2"}]
	assert_eq(CombatImpact.window_end(events, 0), 3, "a blow lasts until the next one")
	assert_true(CombatImpact.fells(events, 0, "z1"), "the first blow fells z1")
	assert_false(CombatImpact.fells(events, 0, "z2"), "but not z2")
	assert_eq(CombatImpact.window_end(events, 3), 5)
	assert_false(CombatImpact.fells(events, 3, "z2"), "a fall after the next turn begins isn't the blow's")


func test_the_last_foe_falls_only_in_a_won_fight() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(1, 1))
	var a := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	var b := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	var events := [{"type": "death", "id": a.id}, {"type": "down", "id": hero.id}, {"type": "death", "id": b.id}]
	assert_eq(CombatImpact.last_fall(e, events), -1, "the fight is still on")
	e.state = Encounter.State.OVER
	e.outcome = "victory"
	assert_eq(CombatImpact.last_fall(e, events), 2, "the last foe's fall; a hero dropping doesn't count")
	var slipped := events.duplicate()
	slipped.append({"type": "vanish", "id": a.id})
	assert_eq(CombatImpact.last_fall(e, slipped), -1, "a foe left after it (Strahd's mist)")
	e.outcome = "defeat"
	assert_eq(CombatImpact.last_fall(e, events), -1, "a lost fight has no last foe")


func test_big_spells_turn_the_camera() -> void:
	assert_true(CombatImpact.big_spell("fireball"), "Fireball")
	assert_false(CombatImpact.big_spell("fire_bolt"), "a cantrip")
	assert_false(CombatImpact.big_spell("shatter"), "2nd level")
	assert_false(CombatImpact.big_spell("breath_weapon"), "a feature that isn't a spell")


func test_every_moment_gives_time_and_the_camera_back() -> void:
	CombatImpact.headless_too = true
	var rig := CameraRig.new()
	add_child(rig)
	var target := Node3D.new()
	add_child(target)
	target.position = Vector3(3, 0, 2)
	var before := Engine.time_scale
	# A heavy hit freezes the fight for a beat, then lets go by itself.
	var im := CombatImpact.new(rig)
	add_child(im)
	im.hit(target, 30, 40, false, false, false)
	assert_true(Engine.time_scale < before * 0.1, "a heavy hit freezes the fight")
	assert_true(rig.shake > 0.0, "and jolts the camera")
	# A beat of real time (waited out in short steps: a busy machine can run one frame longer than the freeze).
	for i in 60:
		if Engine.time_scale == before:
			break
		await get_tree().create_timer(0.05, true, false, true).timeout
	assert_eq(Engine.time_scale, before, "the freeze ends by itself")
	# The last foe's fall: slow motion and a push-in, cut short when the view closes.
	im.hit(target, 30, 40, false, true, true)
	assert_true(Engine.time_scale < before and Engine.time_scale > before * 0.1, "slow motion")
	for i in 3:
		await get_tree().process_frame
	assert_true(rig.shot_zoom < 1.0 and rig.shot_weight > 0.0, "the camera pushes in on it")
	im.queue_free()
	await get_tree().process_frame
	assert_eq(Engine.time_scale, before, "time comes back when the view closes")
	assert_eq([rig.shot_zoom, rig.shot_weight, rig.shot_pitch, rig.shake], [1.0, 0.0, 0.0, 0.0], "and so does the camera")
	# A small blow does nothing; and nothing plays where the moments are off.
	var calm := CombatImpact.new(rig)
	add_child(calm)
	calm.hit(target, 3, 40, false, false, false)
	assert_eq(Engine.time_scale, before, "a light hit doesn't freeze")
	CombatImpact.headless_too = false
	calm.hit(target, 30, 40, true, true, true)
	assert_eq(Engine.time_scale, before, "headless runs never slow")
	calm.queue_free()
	rig.queue_free()
	target.queue_free()
