extends TestCase
## Sunbeams and moonbeams out of doors (Visual Polish Plan 2, SunShafts): they fall where light breaks through gaps
## in the trees and between houses, never on a wall or off the map, spread apart; they lie along the key light, are
## brightest when the light is low and fade in rain; and indoors and in the Classic finish there are none.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)
	SunShafts.set_enabled(true)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _shafts(v: LocationView) -> SunShafts:
	return v.atmosphere.get_node_or_null("SunShafts") as SunShafts


func test_beams_fall_in_the_gaps_never_on_walls_and_spread_apart() -> void:
	# A wood with a clearing and a road through it, an open field to the east.
	var rows: Array[String] = []
	for z in 24:
		var row := ""
		for x in 40:
			var wood := x < 20 and not (x >= 6 and x <= 13 and z >= 6 and z <= 15) and x != 3
			row += "#" if wood else "."
		rows.append(row)
	var grid := CombatGrid.from_rows(rows)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spots := SunShafts.spots(grid, rng)
	assert_true(spots.size() >= SunShafts.FEWEST, "some beams: %d" % spots.size())
	assert_true(spots.size() <= SunShafts.MOST, "not too many: %d" % spots.size())
	for i in spots.size():
		var c := spots[i]
		assert_false(grid.has_flag(c, CombatGrid.WALL), "%s isn't a wall or a tree" % c)
		assert_true(c.x < 24, "%s is by the wood, not out in the open field" % c)
		for j in range(i + 1, spots.size()):
			var o := spots[j]
			assert_true(maxi(absi(o.x - c.x), absi(o.y - c.y)) >= SunShafts.SPACING, "%s and %s are spread apart" % [c, o])
	rng.seed = 7
	assert_eq(SunShafts.spots(grid, rng), spots, "the same beams every visit")


func test_beams_follow_the_time_of_day_and_the_weather() -> void:
	Look.set_style("modern", false)
	var v := _view("into_the_mists_road")
	var s := _shafts(v)
	assert_true(s != null, "the road out of the Mists has beams")
	if s == null:
		v.queue_free()
		return
	assert_false(s.beams.is_empty(), "it found gaps for them")
	GameState.story.minute_of_day = 12 * 60
	v.update_daylight()
	v.atmosphere.settle()
	var day := s.target()
	GameState.story.minute_of_day = 18 * 60
	v.update_daylight()
	var dusk := s.target()
	assert_true(day > 0.0, "beams by day")
	assert_true(dusk > day, "the low sun at dusk lights them most")
	s._update(0.0, true)
	var beam := s.beams[0]["beam"] as MeshInstance3D
	var down := -v.atmosphere.sun.global_basis.z.normalized()
	var up := beam.global_basis.y.normalized()
	assert_true(up.y >= SunShafts.LOWEST - 0.01, "never lying flat across the ground")
	assert_true(Vector2(up.x, up.z).dot(Vector2(-down.x, -down.z)) > 0.0, "leaning back toward the light")
	v.atmosphere.mood["weather"] = [{"kind": "rain", "amount": 300}]
	s._update(0.0, true)
	assert_true(s.target() < dusk * 0.5, "rain thins them")
	SunShafts.set_enabled(false)
	assert_false(s.visible, "switched off at once (captures and the perf probe)")
	v.queue_free()


func test_none_indoors_or_in_classic() -> void:
	Look.set_style("modern", false)
	var inside := _view("death_house_ground")
	assert_true(_shafts(inside) == null, "no beams indoors (the windows have their own)")
	inside.queue_free()
	Look.set_style("classic", false)
	var road := _view("into_the_mists_road")
	assert_true(_shafts(road) == null, "Classic stays as it was frozen")
	road.queue_free()
