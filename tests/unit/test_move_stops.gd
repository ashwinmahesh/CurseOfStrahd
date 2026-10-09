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


## A move stopped in an ally's space it was passing through goes back to the last square it could stop in (QA FN-18:
## a griffon's Opportunity Attack grabbed the mover as it stepped out of an ally's square, and the two shared it).
func test_a_mover_stopped_in_an_allys_space_steps_back() -> void:
	var e := TestCombat.encounter(["##########", "#####.####", "#####.####", "#####.####", "#####.####", "#####..###",
		"#####.####", "#####.####", "##########"], 1)
	var mover := TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 6), 5)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 4), 5)
	var griffon := TestCombat.foe(e, "griffon", Vector2i(6, 5))
	TestCombat.start_with(e, mover)
	griffon.reaction_rules["opportunity_attack"] = "auto"
	mover.creature.hp = 200
	TestCombat.next_d20(e, 20)
	e.move(mover, Vector2i(5, 2))
	while e.pending != null:
		e.answer_reaction(true)
	assert_true(mover.creature.has_condition(&"grappled"), "grabbed on the way")
	assert_ne(mover.cell, ally.cell, "not left in the ally's square")
	assert_eq(mover.cell, Vector2i(5, 5), "back where it could stop")


## A teleport needs room for the whole creature (QA FN-19): a Large creature's corner square was all that was checked.
func test_a_large_creature_teleports_only_where_it_fits() -> void:
	var e := TestCombat.encounter(["........", "........", "....#...", "........", "........"], 1)
	var steed := TestCombat.foe(e, "giant_elk", Vector2i(1, 1))
	steed.side = &"party"
	TestCombat.start_with(e, steed)
	assert_false(e.feature_actions.room_at(steed, Vector2i(3, 1)), "a 2 x 2 at (3, 1) would cover the wall at (4, 2)")
	assert_false(e.feature_actions._teleport(steed, Vector2i(3, 1), 30).ok, "so it can't land there")
	assert_true(e.feature_actions._teleport(steed, Vector2i(5, 0), 30).ok, "where it fits, it lands")
