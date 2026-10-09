extends TestCase
## The Amber Temple's doors (UI QA W-07, 2026-10-08): the party arrived on low ground and couldn't be seen. The
## interior walls' outside ground, one slab for the whole map, was lifted to the height of the first wall square that
## built it (5, by the doors) and drawn over everything lower; and the hillside the land laid on the empty squares
## rose between the camera and the party, though the map falls away there (its drop_ft).


func before_each() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		GameState.story.party.append(Pregens.build(id, 3))
	Look.set_style("modern", false)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)
	GameState.reset()


func test_nothing_is_drawn_over_the_party_on_arrival() -> void:
	var v := LocationView.create("amber_temple_entrance", GameState.story, null, Dice.roller, "default")
	add_child(v)
	for i in 3:
		await get_tree().process_frame
	var slab := v.board.find_child("OutsideGround", false, false) as GeometryInstance3D
	assert_true(slab != null, "the temple's outside ground is there")
	if slab != null:
		var top := (slab.global_transform * slab.get_aabb()).end.y
		assert_true(top < 0.1, "it lies at the map's ground level, not lifted (top %.2f)" % top)
	for m in v.members:
		var floor_y := v.board.floor_y(m.cell)
		var p := Vector3(m.cell.x + 0.5, floor_y, m.cell.y + 0.5)
		for n in v.board.find_children("*", "GeometryInstance3D", false, false):
			var g := n as GeometryInstance3D
			if not g.is_visible_in_tree() or not (str(g.name).begins_with("Outside") or str(g.name) == "Land"):
				continue
			var box := g.global_transform * g.get_aabb()
			var over := box.position.x <= p.x and box.end.x >= p.x and box.position.z <= p.z and box.end.z >= p.z \
				and box.position.y > p.y + 0.3
			assert_false(over, "%s covers %s at %.2f (%s)" % [g.name, m.id, floor_y, box])
	v.queue_free()


func test_a_map_that_falls_away_has_a_drop_past_its_empty_squares() -> void:
	assert_true(AtmosphereLand.has_drop("amber_temple_entrance"), "its drop_ft")
	assert_true(AtmosphereLand.has_drop("tser_falls"))
	assert_false(AtmosphereLand.has_drop("krezk"), "Krezk's empty squares are hillside")
	assert_false(AtmosphereLand.has_drop(""))
