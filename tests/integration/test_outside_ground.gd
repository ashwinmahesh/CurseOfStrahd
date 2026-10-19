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


## Owner report (2026-10-13): "The Abbey walls start high in the air." On every map with natural ground, what a wall
## square draws stands on that square's ground: the Abbey's and Argynvostholt's walls on their shelves, Barovia's yard
## walls, the Amber Temple's walls by its doors (all lifted onto their hills twice), not floating over it or sunk in it;
## and the faces and copings along those walls stand on them.
func test_walls_stand_on_raised_ground() -> void:
	var problems: Array[String] = []
	for loc: String in (Compendium.shared().tables["locations"] as Dictionary).keys():
		var map := Compendium.shared().get_entry("locations", loc).get("map", {}) as Dictionary
		if (map.get("elevation", []) as Array).is_empty() or str(map.get("theme", "")) in ArenaBoard.WILD:
			continue   # (the wilds' walls are trees and rocks, which stand on their hills: test_elevation_board)
		var v := LocationView.create(loc, GameState.story, null, Dice.roller, "default")
		add_child(v)
		await get_tree().process_frame
		var off := 0
		var sample := ""
		for c: Vector2i in v.board.dressing:
			if not v.grid.has_flag(c, CombatGrid.WALL) or v.board.house_cells.has(c) or not v.grid.has_flag(c, CombatGrid.NATURAL):
				continue
			for n: Node3D in v.board.dressing[c] as Array:
				if not n.is_visible_in_tree() or n.has_meta("nature") or n.has_meta("terrain") \
						or not Rect2(c.x, c.y, 1, 1).has_point(Vector2(n.global_position.x, n.global_position.z)):
					continue   # (the wall over a doorway beside it stands on the doorway's square, from door height)
				var box := AABB()
				var first := true
				for g: Node in [n] + n.find_children("*", "GeometryInstance3D", true, false):
					var gi := g as GeometryInstance3D
					if gi == null or not gi.is_visible_in_tree():
						continue
					box = gi.global_transform * gi.get_aabb() if first else box.merge(gi.global_transform * gi.get_aabb())
					first = false
				if first or box.size.y < 0.4:
					continue
				var d := box.position.y - v.board.floor_y(c)
				# A crag's patch (Crags.piece, place_looks `rock_shape`) follows the ground it stands on: at the corner it shares
				# with a lower square it stands half a 10 ft step (1.0, and the tuck under the ground) below the square's
				# own level, never a cliff's or a drop's depth.
				if d > 0.3 or d < (-1.2 if n.has_meta("crag") else -0.6):
					off += 1
					sample = "%s %+.1f" % [c, d]
		if off > 0:
			problems.append("%s: %d wall pieces off their ground (%s)" % [loc, off, sample])
		# The faces and copings along a wall's top stand on the wall, not a hill's height over it (the Amber Temple's
		# doors, owner 2026-10-17: "weird long floating pillars").
		var floating := 0
		for g: Node in v.board.find_children("KitFaces", "MeshInstance3D", true, false):
			var box := (g as MeshInstance3D).global_transform * (g as MeshInstance3D).get_aabb()
			var ground := v.board.cell_center(v.grid.cell_at(box.get_center())).y
			# (On a slope a face stands on its floor, up to a few feet over the wall's own square.)
			if box.end.y - ground > float(InteriorWalls.HEIGHTS["castle"]) + 1.2 or box.position.y - ground < -1.2:
				floating += 1
				sample = "%s %+.1f" % [v.grid.cell_at(box.get_center()), box.end.y - ground]
		if floating > 0:
			problems.append("%s: %d walls' faces off their wall (%s)" % [loc, floating, sample])
		v.queue_free()
		await get_tree().process_frame
	assert_eq(problems, [] as Array[String], "walls on their ground")
