extends TestCase
## Fronds framing the view in the woods (Visual Polish Plan 11, ForegroundFraming): on wooded wild maps only, in the
## bottom corners under the HUD, never taking a click and never reaching the middle of the screen where the party
## stands; gone for fights and conversations; none in towns, indoors or in the Classic finish.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)
	ModeController.force(ModeController.Mode.EXPLORATION)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _framing(v: LocationView) -> ForegroundFraming:
	return v.atmosphere.get_node_or_null("ForegroundFraming") as ForegroundFraming


func test_fronds_frame_the_woods_clear_of_the_middle() -> void:
	Look.set_style("modern", false)
	var v := _view("into_the_mists_road")
	await get_tree().process_frame
	var f := _framing(v)
	assert_true(f != null, "the road through the woods is framed")
	if f == null:
		v.queue_free()
		return
	assert_true(f.layer < 10, "under the HUD (layer %d)" % f.layer)
	assert_true(f.visible, "shown while exploring")
	var size := f.get_viewport().get_visible_rect().size
	for r in f.find_children("*", "TextureRect", false, false):
		var frond := r as TextureRect
		assert_eq(frond.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s lets clicks through" % frond.name)
		# The frond's own quad as drawn (turned), against a grid of points over the middle of the screen.
		var t := frond.get_global_transform()
		var quad := PackedVector2Array([t * Vector2.ZERO, t * Vector2(frond.size.x, 0.0), t * frond.size,
			t * Vector2(0.0, frond.size.y)])
		for gx in 5:
			for gy in 5:
				var p := size * Vector2(0.3 + 0.1 * gx, 0.25 + 0.1 * gy)
				assert_false(Geometry2D.is_point_in_polygon(p, quad), "%s keeps clear of the middle (%s)" % [frond.name, p])
	v.in_combat = true
	f._update(1.0, false)
	assert_false(f.visible, "gone for a fight")
	v.in_combat = false
	ModeController.force(ModeController.Mode.DIALOGUE)
	f._update(1.0, false)
	assert_false(f.visible, "gone for a conversation")
	v.queue_free()


func test_none_in_towns_indoors_or_classic() -> void:
	Look.set_style("modern", false)
	for id: String in ["village_of_barovia", "death_house_ground"]:
		var v := _view(id)
		assert_true(_framing(v) == null, "%s isn't framed" % id)
		v.queue_free()
	Look.set_style("classic", false)
	var road := _view("into_the_mists_road")
	assert_true(_framing(road) == null, "Classic stays as it was frozen")
	road.queue_free()
