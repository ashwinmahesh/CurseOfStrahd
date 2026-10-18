extends TestCase
## Owner, 2026-10-17: "Audit all areas and place small steps where appropriate so we're not just stepping onto 5 ft
## blocks because it looks weird (ex Werewolf den)." Every place now draws a short flight of small steps up each 5 ft
## rise between two walkable built floors, as Castle Ravenloft has since 2026-10-15 (test_castle_steps.gd): the
## werewolf den's ledges, the Argynvostholt beacon's tower stair, Ghakis's hoard mound, Krezk's and Vallaki's watch
## platforms; room clutter (Furnish) keeps off them. Drawing only: the rules grid keeps its heights. Natural ground
## 5 ft apart is a slope already, and a prop stood on (a cart, a vat, a tree's perch) is climbed as its model shows, so
## neither gets steps.


func after_each() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


func _view(loc: String) -> LocationView:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		GameState.story.party.append(Pregens.build(id, 5))
	var v := LocationView.create(loc, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(v)
	await get_tree().process_frame
	return v


static func _names(v: LocationView) -> Array[String]:
	var out: Array[String] = []
	for f: Node3D in v.board.flights:
		out.append(str(f.name))
	return out


static func _walked(g: CombatGrid, c: Vector2i) -> bool:
	return g.in_bounds(c) and (g.flags(c) & (CombatGrid.WALL | CombatGrid.VOID | CombatGrid.WATER)) == 0


## Each 5 ft rise in the rules from a walkable square up onto a walkable built floor (not natural ground, not a prop
## stood on): the flight it should have, "Flight_<lower x>_<lower z>_<upper x>_<upper z>" -> the upper square.
static func _rises(g: CombatGrid) -> Dictionary:
	var out := {}
	for z in g.depth:
		for x in g.width:
			var c := Vector2i(x, z)
			if not _walked(g, c) or g.has_flag(c, CombatGrid.NATURAL) or g.raised.has(c):
				continue
			for d: Vector2i in SetDressing.FACES:
				var n := c + d
				if _walked(g, n) and not g.raised.has(n) and g.height(c) - g.height(n) == CombatGrid.FEET:
					out["Flight_%d_%d_%d_%d" % [n.x, n.y, c.x, c.y]] = c
	return out


func test_every_5_ft_rise_between_built_floors_has_its_steps() -> void:
	var ids: Array = (Compendium.shared().tables["locations"] as Dictionary).keys()
	ids.sort()
	var places: Array[String] = []
	for id: String in ids:
		var want := _rises(LocationView.grid_for(Compendium.shared().get_entry("locations", id)))
		if want.is_empty():
			continue
		places.append(id)
		var v: LocationView = await _view(id)
		var names := _names(v)
		for f: String in want:
			if CastleBuilder.walk_at(v.board, want[f] as Vector2i):
				continue   # the castle gates' wall walk: CastleBuilder steps it with its own piece
			assert_true(f in names, "%s: small steps up the 5 ft rise %s" % [id, f])
		for c: Vector2i in v.board.stepped:
			assert_ne(str(v.board.occupied.get(c, "")), "furnish",
					"%s: no room clutter stands in the steps at %s" % [id, c])
		v.queue_free()
		await get_tree().process_frame
	for id: String in ["werewolf_den_caves", "argynvostholt_beacon", "ghakis_lair", "krezk", "vallaki"]:
		assert_true(id in places, "%s has 5 ft rises (%s)" % [id, places])


func test_the_werewolf_den_steps_up_to_its_ledges() -> void:
	var v: LocationView = await _view("werewolf_den_caves")
	var names := _names(v)
	for want: String in ["Flight_12_12_12_11", "Flight_12_11_12_10", "Flight_19_6_19_7", "Flight_19_8_19_9",
			"Flight_15_26_15_25"]:
		assert_true(want in names, "a flight at %s (%s)" % [want, names])
	assert_false("Flight_17_23_16_23" in names, "a 10 ft face is a climb, not a flight of steps")
	var flight := v.board.flights[names.find("Flight_12_12_12_11")]
	assert_eq(flight.get_child_count(), Stairs.FLIGHT_STEPS, "small steps, not one block")
	for step: Node in flight.get_children():
		var mi := step as MeshInstance3D
		assert_true(mi.position.z > 12.0 and mi.position.z < 12.5, "in the square below, against the face")
		assert_true(mi.position.y + (mi.mesh as BoxMesh).size.y / 2.0 < 1.0, "each step below the block it leads to")
	assert_eq(v.grid.height(Vector2i(12, 12)), 0, "the rules grid is as it was: the cave floor is 0 ft")
	assert_eq(v.grid.height(Vector2i(12, 11)), 5, "the block 5 ft up")
	assert_eq(v.grid.height(Vector2i(12, 10)), 10, "and the ledge 10 ft up")


## Vallaki's watch platform stands on the town's raised ground: the steps start from that ground's own height.
func test_steps_up_from_natural_ground_start_on_it() -> void:
	var v: LocationView = await _view("vallaki")
	var names := _names(v)
	assert_true("Flight_42_22_43_22" in names, "up from the street onto the platform's step (%s)" % [names])
	var flight := v.board.flights[names.find("Flight_42_22_43_22")]
	var low := INF
	for step: Node in flight.get_children():
		var mi := step as MeshInstance3D
		low = minf(low, mi.position.y + (mi.mesh as BoxMesh).size.y / 2.0)
	assert_between(low, v.board.floor_y(Vector2i(42, 22)), v.board.floor_y(Vector2i(43, 22)),
			"the lowest step stands above the street and below the platform")


## A prop stood on 5 ft up keeps its own model: Barovia's hay cart is climbed onto, not stepped up to.
func test_a_prop_stood_on_gets_no_steps() -> void:
	var v: LocationView = await _view("village_of_barovia")
	assert_eq(v.board.flights.size(), 0, "no flights up to the hay cart")
