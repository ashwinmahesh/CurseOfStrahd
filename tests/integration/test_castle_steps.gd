extends TestCase
## Owner, 2026-10-15: "There are places where there should be small steps in Castle Ravenloft. We shouldn't just be
## stepping straight up onto 5ft bricks. There should be small steps leading to it." Every 5 ft rise between two
## walkable built floors in the castle is drawn with a short flight of steps (Stairs.flight, ArenaBoard._flights): the
## high tower's landings, Strahd's dais, the roofs. Drawing only: the rules grid keeps its heights.


func after_each() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


func _view(loc: String) -> LocationView:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		GameState.story.party.append(Pregens.build(id, 10))
	var v := LocationView.create(loc, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(v)
	await get_tree().process_frame
	return v


static func _names(v: LocationView) -> Array[String]:
	var out: Array[String] = []
	for f: Node3D in v.board.flights:
		out.append(str(f.name))
	return out


func test_the_high_tower_climbs_by_steps_between_its_landings() -> void:
	var v: LocationView = await _view("castle_ravenloft_spires")
	var names := _names(v)
	for want: String in ["Flight_6_17_7_17", "Flight_9_4_9_3", "Flight_27_2_28_2", "Flight_29_10_29_11"]:
		assert_true(want in names, "a flight at %s (%s)" % [want, names])
	assert_eq(names.size(), 12, "one for each square of every 5 ft rise on the stair")
	var flight := v.board.flights[names.find("Flight_6_17_7_17")]
	assert_eq(flight.get_child_count(), Stairs.FLIGHT_STEPS, "small steps, not one block")
	var tallest := 0.0
	for step: Node in flight.get_children():
		var mi := step as MeshInstance3D
		tallest = maxf(tallest, mi.position.y + (mi.mesh as BoxMesh).size.y / 2.0)
		assert_true(mi.position.x > 6.0 and mi.position.x < 7.0, "in the square below, against the face")
	assert_between(tallest, 0.6, 1.0, "the top step stands below the landing it leads to")
	assert_eq(v.grid.height(Vector2i(6, 17)), 0, "the rules grid is as it was: the floor below is 0 ft")
	assert_eq(v.grid.height(Vector2i(7, 17)), 5, "and the stair 5 ft up")


func test_strahds_dais_and_the_roofs_have_their_steps() -> void:
	var tomb: LocationView = await _view("castle_ravenloft_catacombs_strahd")
	var names := _names(tomb)
	assert_true("Flight_7_9_7_10" in names and "Flight_6_13_7_13" in names, "up onto the dais from the floor")
	assert_true("Flight_8_12_9_12" in names, "and up from its lower ring to the coffin's")
	tomb.queue_free()
	await get_tree().process_frame
	var roofs: LocationView = await _view("castle_ravenloft_spires_roofs")
	assert_true("Flight_24_5_25_5" in _names(roofs), "the step off the roof walk")
