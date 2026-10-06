extends TestCase
## The title screen's movement (ui/menu/title_ambience.gd): it covers the screen over the key art, bats keep circling,
## flybys and bursts come and go without piling up, and the glows stay where the art puts the moon and the coach lamp.


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
	for i in 2400:    # two minutes at 20 steps a second
		amb.call("_process", 0.05)
		var bats := amb.get("_bats") as Array
		most = maxi(most, bats.size())
		for b: Variant in bats:
			saw_flyby = saw_flyby or str((b as Dictionary)["kind"]) == "fly"
			saw_burst = saw_burst or str((b as Dictionary)["kind"]) == "burst"
	var left := (amb.get("_bats") as Array).filter(func(b: Variant) -> bool: return str((b as Dictionary)["kind"]) == "orbit")
	assert_eq(left.size(), TitleAmbience.CIRCLERS, "the circling bats stay")
	assert_true(saw_flyby and saw_burst, "flybys and bursts happen")
	assert_true(most < TitleAmbience.CIRCLERS + 20, "finished bats are dropped (most at once: %d)" % most)
	var moon := amb.to_screen(TitleAmbience.MOON)
	assert_true(moon.x > 800.0 and moon.x < 1300.0 and moon.y > 80.0 and moon.y < 260.0, "the moon is where the art has it: %s" % moon)
	host.queue_free()
