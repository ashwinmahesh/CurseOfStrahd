extends TestCase
## The air wavering above open fires out of doors (Visual Polish Plan 8, HeatShimmer): a camp's fire gets it, on a
## layer under the HUD that never takes a click; a room's hearth doesn't (its heat goes up the chimney), nor does the
## Classic finish; switched off it draws nothing.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)
	HeatShimmer.set_enabled(true)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _shimmer(v: LocationView) -> HeatShimmer:
	return v.atmosphere.get_node_or_null("HeatShimmer") as HeatShimmer


func test_a_camp_fire_shimmers_under_the_hud() -> void:
	Look.set_style("modern", false)
	var v := _view("vallaki_vistani_camp")
	await get_tree().process_frame   # the place's lights are dressed a frame after it's built
	await get_tree().process_frame
	var h := _shimmer(v)
	assert_true(h != null, "the Vistani camp's fire shimmers")
	if h == null:
		v.queue_free()
		return
	assert_false(h.fires.is_empty(), "it knows the fire")
	assert_true(h.layer < 1, "under the HUD and every menu (layer %d)" % h.layer)
	for p in h.find_children("*", "ColorRect", false, false):
		assert_eq((p as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "clicks go through it")
	HeatShimmer.set_enabled(false)
	await get_tree().process_frame
	assert_false(h.visible, "switched off, it draws nothing")
	v.queue_free()


func test_no_shimmer_indoors_or_in_classic() -> void:
	Look.set_style("modern", false)
	var inn := _view("vallaki_blue_water_inn")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_shimmer(inn) == null, "a hearth's heat goes up its chimney")
	inn.queue_free()
	Look.set_style("classic", false)
	var camp := _view("vallaki_vistani_camp")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_shimmer(camp) == null, "Classic stays as it was frozen")
	camp.queue_free()
