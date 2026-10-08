extends TestCase
## A move stops the moment the mover is held to Speed 0 on the way (2024: Restrained and Grappled set Speed 0): a
## creature that fails its save walking into a Web is Restrained in the first webbed square and goes no farther
## (combat/encounter_movement.gd _walk).


func test_a_creature_restrained_by_a_web_on_its_way_stops_there() -> void:
	var e := TestCombat.open_field(3)
	var caster := TestCombat.caster_with(e, ["web"], Vector2i(0, 0))
	var bag := TestCombat.punching_bag(e, Vector2i(0, 6), 200)
	TestCombat.start_with(e, caster)
	var r := e.spells.cast(caster, "web", 2, [], Vector2(7.0, 4.0))
	assert_true(r.ok, r.reason)
	var web := e.spells.zones.object_of(caster.id, "web")
	assert_true(web != null, "the web is up")
	# The web's north-west corner, and a square just inside it: any way there crosses a webbed square first.
	var corner := Vector2i(99, 99)
	for cell: Vector2i in web.cells:
		if cell.x < corner.x or (cell.x == corner.x and cell.y < corner.y):
			corner = cell
	var inside := corner + Vector2i(1, 1)
	assert_true(inside in web.cells and corner.x >= 3, "a square inside the web, with room to walk in from the west")
	while e.current() != bag:
		e.end_turn()
	bag.cell = Vector2i(corner.x - 2, inside.y)
	bag.movement_left = bag.speed()
	TestCombat.next_d20(e, 5)
	var mr := e.move(bag, inside)
	assert_true(mr.ok, mr.reason)
	assert_true(bag.creature.has_condition(&"restrained"), "it failed its save")
	assert_true(bag.cell in web.cells and bag.cell != inside, "it stops in the first webbed square it entered")
	assert_true(bag.movement_left > 0, "with movement it can't use")
