extends TestCase
## The fight pulses (Visual Polish Plan 3, ScreenPulse): one layer per window over the world and under the HUD that
## never takes a click, reused from pulse to pulse, rising and falling back to hidden in real time; nothing when
## they're off or asked for a kind that doesn't exist.


func before_each() -> void:
	ScreenPulse.headless_too = true
	ScreenPulse.set_enabled(true)


func after_each() -> void:
	ScreenPulse.headless_too = false
	ScreenPulse.set_enabled(true)
	for n in get_tree().get_nodes_in_group(ScreenPulse.GROUP):
		(n as Node).queue_free()


func test_one_layer_under_the_hud_that_never_takes_a_click() -> void:
	var p := ScreenPulse.play(self, "engage")
	assert_true(p != null, "a pulse plays")
	if p == null:
		return
	await get_tree().process_frame   # it joins the window at the end of the frame, then plays
	assert_true(p.layer < 1, "under the HUD and every menu (layer %d)" % p.layer)
	assert_eq((p.get_child(0) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "clicks go through it")
	assert_true(p.visible, "shown while it plays")
	assert_eq(ScreenPulse.play(self, "crit", Vector3(2, 0, 1)), p, "the next pulse reuses the layer")
	assert_eq(get_tree().get_nodes_in_group(ScreenPulse.GROUP).size(), 1, "one layer for the window")


func test_it_rises_then_falls_back_to_hidden() -> void:
	var p := ScreenPulse.play(self, "kill")
	if p == null:
		fail("no pulse")
		return
	await get_tree().process_frame
	var k := ScreenPulse.KINDS["kill"] as Dictionary
	var seconds := float(k["time"]) * GameSettings.combat_pace()
	p._tw.custom_step(seconds * float(k["rise"]))
	assert_between(p.amount(), 0.95, 1.0, "at its peak after the rise")
	p._tw.custom_step(seconds)
	assert_false(p.visible, "hidden again once it's over, costing nothing")
	assert_eq(p.amount(), 0.0)


func test_nothing_when_off_or_unknown() -> void:
	ScreenPulse.set_enabled(false)
	assert_true(ScreenPulse.play(self, "engage") == null, "captures' before shots turn it off")
	ScreenPulse.set_enabled(true)
	assert_true(ScreenPulse.play(self, "no_such_pulse") == null, "an unknown kind plays nothing")
	ScreenPulse.headless_too = false
	assert_true(ScreenPulse.play(self, "engage") == null, "never in headless runs")
