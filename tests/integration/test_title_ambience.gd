extends TestCase
## The title screen's movement (ui/menu/title_ambience.gd): it covers the screen over the key art, bats keep circling,
## flybys, bursts and crows come and go without piling up, the travellers keep walking the road and coming back, the
## leaves on the wind stay on screen, and the glows stay where the art puts the moon and the coach lamp.


func test_bats_come_and_go() -> void:
	var host := Control.new()
	host.size = Vector2(1600, 900)
	add_child(host)
	var art := TextureRect.new()
	art.texture = load("res://art/ui/title_backdrop.png") as Texture2D
	host.add_child(art)
	var amb := TitleAmbience.new()
	amb.art = art
	host.add_child(amb)
	await get_tree().process_frame
	amb.size = host.size
	amb.set_process(false)
	var most := 0
	var saw_flyby := false
	var saw_burst := false
	var saw_crow := false
	var walked := 0.0
	for i in 2400:    # two minutes at 20 steps a second
		amb.call("_process", 0.05)
		var bats := amb.get("_bats") as Array
		most = maxi(most, bats.size())
		for b: Variant in bats:
			saw_flyby = saw_flyby or str((b as Dictionary)["kind"]) == "fly"
			saw_burst = saw_burst or str((b as Dictionary)["kind"]) == "burst"
			saw_crow = saw_crow or bool((b as Dictionary).get("crow", false))
		for w: Variant in amb.get("_walkers") as Array:
			walked = maxf(walked, float((w as Dictionary)["d"]))
	var left := (amb.get("_bats") as Array).filter(func(b: Variant) -> bool: return str((b as Dictionary)["kind"]) == "orbit")
	assert_eq(left.size(), TitleAmbience.CIRCLERS, "the circling bats stay")
	assert_true(saw_flyby and saw_burst and saw_crow, "flybys, bursts and crows happen")
	assert_true((amb.get("_walkers") as Array).size() >= 2, "travellers on the road")
	assert_true(walked > 100.0, "and they walk")
	assert_eq((amb.get("_flecks") as Array).size(), TitleAmbience.FLECKS, "the leaves and ash are recycled, not lost")
	var g := amb.gust
	assert_true(g >= 0.0 and g <= 1.0, "the wind stays in range")
	assert_true(most < TitleAmbience.CIRCLERS + 20, "finished bats are dropped (most at once: %d)" % most)
	var moon := amb.to_screen(TitleAmbience.MOON)
	assert_true(moon.x > 800.0 and moon.x < 1300.0 and moon.y > 80.0 and moon.y < 260.0, "the moon is where the art has it: %s" % moon)
	host.queue_free()
