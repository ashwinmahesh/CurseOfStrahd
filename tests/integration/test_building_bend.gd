extends TestCase
## Natural shapes for buildings (the vault's Natural Maps Plan, B1; BuildingBend): houses, yard walls, palisades and
## building-sized props lean, bow and sag instead of standing ruler-straight, by at most a quarter of a square
## sideways, by style (timber most, the castle none), the same every time a place is built; the rules grid, the
## Classic look and the pieces hung on a wall (they follow it) are untouched.


func before_each() -> void:
	GameState.reset()
	ModeController.force(ModeController.Mode.EXPLORATION)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _house_bend(seed_: int = 1) -> BuildingBend:
	var board := ArenaBoard.new()
	board.place = "bend_test_%d" % seed_
	var parts: Array[Rect2] = [Rect2(4, 3, 5, 3), Rect2(4, 6, 2, 3)]
	var bend := BuildingBend.for_house(board, "timber", parts, parts[0], 2.2, 1.6)
	board.free()
	return bend


## Rule 2 of the plan: nothing a token stands beside moves more than its style's reach sideways (a quarter of a square,
## half for timber walls), whatever the kind of bend or where on the building the point is. The roof is overhead and may
## reach a quarter square further over the walls' top, at the ridge, over the middle of the building; the ridge sags and
## the eaves wave, nothing leaps.
func test_a_bend_never_moves_a_point_more_than_its_reach() -> void:
	var bends: Array[BuildingBend] = [_house_bend(1), _house_bend(2), _house_bend(3)]
	var board := ArenaBoard.new()
	board.place = "bend_test_walls"
	for kind_height: Array in [[1.0, true], [3.0, true], [2.2, false]]:
		var b := BuildingBend.for_wall(board, "timber", float(kind_height[0])) if bool(kind_height[1]) else BuildingBend.for_logs(board, "timber", float(kind_height[0]))
		bends.append(b)
	board.free()
	for bend in bends:
		assert_true(bend != null, "timber bends")
		if bend == null:
			continue
		var worst := 0.0
		var worst_low := 0.0
		var worst_up := 0.0
		for xi in 24:
			for zi in 24:
				for yi in 12:
					var p := Vector3(2.0 + xi * 0.45, yi * 0.33, 1.0 + zi * 0.45)
					var q := bend.apply(p)
					var side := Vector2(q.x - p.x, q.z - p.z).length()
					worst = maxf(worst, side)
					if p.y <= 2.0:
						worst_low = maxf(worst_low, side)
					worst_up = maxf(worst_up, absf(q.y - p.y))
		assert_true(worst_low <= bend._field_max + 0.0001, "the walls: sideways a little under their reach (%.3f of %.2f)" % [worst_low, bend._field_max])
		assert_true(worst <= bend._roof_max + 0.0001, "the roof: at most %.2f (%.3f)" % [bend._roof_max, worst])
		assert_true(worst > 0.04, "and it does move (%.3f)" % worst)
		assert_true(worst_up < 1.2, "up and down: a sag and a wave, no leaps (%.3f)" % worst_up)


## `bent` over an array is `apply` point by point, for every kind of bend.
func test_bending_an_array_is_bending_each_point() -> void:
	var board := ArenaBoard.new()
	board.place = "bend_test_array"
	var bends: Array[BuildingBend] = [_house_bend(4), BuildingBend.for_wall(board, "timber", 1.0), BuildingBend.for_wall(board, "timber", 3.0),
		BuildingBend.for_logs(board, "clapboard", 2.2), BuildingBend.for_prop(0.8, AABB(Vector3(-1.4, 0, -1.1), Vector3(2.8, 3.2, 2.2)), 77)]
	board.free()
	var points := PackedVector3Array()
	for i in 200:
		points.append(Vector3(1.0 + fmod(i * 0.731, 9.0), fmod(i * 0.377, 3.4), 1.0 + fmod(i * 1.113, 8.0)))
	for bend in bends:
		var at := Vector2(2.0, -3.0)
		var all := bend.bent(points, at)
		for i in points.size():
			var one := bend.apply(points[i] + Vector3(at.x, 0.0, at.y)) - Vector3(at.x, 0.0, at.y)
			assert_true(one.distance_to(all[i]) < 0.0005, "point %d agrees (%s vs %s)" % [i, one, all[i]])
			if one.distance_to(all[i]) >= 0.0005:
				break


## A place comes out the same every time it is built, and no two places or buildings bend alike.
func test_a_bend_is_the_same_every_time_and_differs_by_place() -> void:
	var a := _house_bend(1)
	var b := _house_bend(1)
	var c := _house_bend(2)
	var p := Vector3(5.3, 1.7, 3.1)
	assert_eq(a.apply(p), b.apply(p), "the same place bends the same way")
	assert_ne(a.apply(p), c.apply(p), "another place does not")
	assert_eq(a.apply(Vector3(5.0, 0.0, 3.0)).y, 0.0, "the foot stays on the ground")


## The amounts: timber most, then clapboard, stone, the church; Castle Ravenloft's yards none; none at all in Classic.
func test_each_style_bends_by_its_own_amount() -> void:
	var board := ArenaBoard.new()
	board.place = "village_of_barovia"
	var timber := BuildingBend.amount_for(board, "timber")
	var clap := BuildingBend.amount_for(board, "clapboard")
	var stone := BuildingBend.amount_for(board, "stone")
	var church := BuildingBend.amount_for(board, "church")
	assert_true(timber > clap and clap > stone and stone > church and church > 0.0, "timber most, the church least of the town styles (%s)" % [[timber, clap, stone, church]])
	assert_eq(timber, 1.0, "a Barovian cottage bends the full amount")
	assert_eq(BuildingBend.reach_for("timber"), 0.5, "timber walls may reach half a square into the street (Ashwin's pick)")
	for style: String in ["clapboard", "stone", "church"]:
		assert_eq(BuildingBend.reach_for(style), BuildingBend.MAX_OUT, "%s walls stay inside a quarter square" % style)
	board.place = "castle_ravenloft_gates"
	assert_eq(BuildingBend.amount_for(board, "stone"), 0.0, "Castle Ravenloft stays as raised by power")
	board.place = "village_of_barovia"
	Look.set_style("classic", false)
	assert_eq(BuildingBend.amount_for(board, "timber"), 0.0, "the Classic look is frozen")
	board.free()


## The village's houses are bent kit houses: their points sit off the grid, and every point stays near the building's
## box (the cut-away's, which was never snug: eaves and the chimney cap stood outside it before the bend; a bent wall
## reaches a quarter square past the straight one, a church's buttresses a good deal more).
func test_village_houses_are_bent_and_stay_near_their_box() -> void:
	var v := _view("village_of_barovia")
	await _frames(2)
	var board := v.board
	var bent := 0
	for b: Dictionary in board.buildings:
		if not b.has("kit"):
			continue
		var bend := b.get("bend") as BuildingBend
		assert_true(bend != null, "a village house has its bend")
		if bend == null:
			continue
		bent += 1
		var box := b["aabb"] as AABB
		var root := b["root"] as Node3D
		# (Across only: the roof's eaves and the chimney cap stood a little outside the box before the bend, too.)
		var flat_box := AABB(Vector3(box.position.x, -100.0, box.position.z), Vector3(box.size.x, 200.0, box.size.z))
		for node: Array in [[b["walls"], 0.5], [(b["upper"] as Node3D).get_node("Roof"), 0.7]]:
			var inside := ((node[0] as MeshInstance3D).mesh.get_aabb())
			inside.position += root.position
			assert_true(flat_box.grow(float(node[1])).encloses(AABB(Vector3(inside.position.x, 0.0, inside.position.z), Vector3(inside.size.x, 0.0, inside.size.z))),
				"its %s is near its box (%s in %s)" % [(node[0] as Node).name, inside, box])
		# Off the grid: the straight house's corner posts stand exactly on the rectangle's corners; here at least one moved.
		var r := b["rect"] as Rect2i
		var moved := false
		for corner: Vector2 in [Vector2(r.position), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(r.end)]:
			var q := bend.apply(Vector3(corner.x, 0.0, corner.y))
			moved = moved or Vector2(q.x - corner.x, q.z - corner.y).length() > 0.01
		assert_true(moved, "its corners drift off true")
	assert_true(bent >= 8, "the village's houses are bent (%d)" % bent)
	v.queue_free()


## How far past each house's rectangle its walls reach (the corner posts, trim, a door's step: whatever the modules are)
## and how far each hung piece stands off the first surface a ray finds, for the village built bent or straight (the
## catalog's bend taken away): {"reach": {rect: reach}, "off": {"rect|name": offset}}.
func _village_measures(straight: bool) -> Dictionary:
	var saved: Variant = BuildingKit.settings().get("bend")
	if straight:
		BuildingKit.settings().erase("bend")
	var v := _view("village_of_barovia")
	await _frames(2)
	var out := {"reach": {}, "off": {}}
	for b: Dictionary in v.board.buildings:
		if not b.has("kit"):
			continue
		var walls := b["walls"] as MeshInstance3D
		var r := b["rect"] as Rect2i
		var reach := 0.0
		for i in walls.mesh.get_surface_count():
			for p: Vector3 in walls.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				reach = maxf(reach, maxf(maxf(r.position.x - p.x, p.x - r.end.x), maxf(r.position.y - p.z, p.z - r.end.y)))
		(out["reach"] as Dictionary)["%s" % r] = reach
		var tri := TriangleMesh.new()
		tri.create_from_faces(walls.mesh.get_faces())
		var root := b["root"] as Node3D
		for extra: Variant in b["extras"]:
			var holder := extra as Node3D
			if holder == null or not is_instance_valid(holder):
				continue
			var pieces: Array[Node] = holder.find_children("Model_*", "Node3D", true, false)
			pieces.append(holder)
			for n: Node in pieces:
				if not n.has_meta("hung"):
					continue
				var piece := n as Node3D
				var front := piece.global_transform.basis.z.normalized()
				var from := piece.global_position + front * 0.4 - root.position
				var hit := tri.intersect_ray(from, -front)
				if not hit.is_empty():
					(out["off"] as Dictionary)["%s|%s" % [r, piece.name]] = 0.4 - from.distance_to(hit["position"] as Vector3)
	v.queue_free()
	await _frames(1)
	if straight:
		BuildingKit.settings()["bend"] = saved
	return out


## A bent house moves its walls out of the square it stands in by at most a quarter of a square (rule 2), so a token in
## the middle of the square beside it and its ring stay clear; where the rules grid puts it is untouched.
func test_a_bent_wall_leaves_the_middle_of_the_square_beside_it_clear() -> void:
	var flat := (await _village_measures(true))["reach"] as Dictionary
	var crooked := (await _village_measures(false))["reach"] as Dictionary
	var moved := 0
	for key: String in flat:
		assert_true(crooked.has(key), "the same house stands: %s" % key)
		var more := float(crooked.get(key, 0.0)) - float(flat[key])
		assert_true(more <= BuildingBend.reach_for("timber") + 0.005, "%s reaches at most its reach further (%.3f)" % [key, more])
		if more > 0.03:
			moved += 1
	assert_true(moved >= 6, "most houses lean or bow out (%d)" % moved)


## A sign, a lantern or a window hung on a bent house goes to its wall: it stands off the first surface a ray finds about
## as far as it does on the straight house, a hair proud of the bent wall. (A door's leaf stands in its bay, which a ray
## through the leaf measures against the jamb or the step as it happens to fall: left out.)
func test_pieces_hung_on_a_bent_house_follow_its_wall() -> void:
	var flat := (await _village_measures(true))["off"] as Dictionary
	var crooked := (await _village_measures(false))["off"] as Dictionary
	var checked := 0
	var problems: Array[String] = []
	for key: String in flat:
		if not crooked.has(key) or key.to_lower().contains("door"):
			continue
		var d := float(crooked[key]) - float(flat[key])
		checked += 1
		if absf(d) > 0.08:
			problems.append("%s is %.3f from where it stands on the straight house" % [key, d])
	assert_eq(problems, [] as Array[String], "pieces on the wall")
	assert_true(checked >= 3, "some pieces are hung on houses (%d)" % checked)


## Yard walls carry on from square to square (one field for the place), the palisade's logs lean each their own way, and
## a town wall (Krezk's) bends by its own height.
func test_yard_walls_and_palisades_bend_as_one_line() -> void:
	var v := _view("vallaki")
	await _frames(2)
	var logs := v.board.get_node_or_null("Palisade") as MeshInstance3D
	assert_true(logs != null, "Vallaki's palisade stands")
	if logs != null:
		var flat := BuildingKit.merge([["kit_palisade", Transform3D(Basis(), Vector3(0, 0, 0))]])
		var bent_logs := BuildingKit.merge([["kit_palisade", Transform3D(Basis(), Vector3(0, 0, 0))]], "", BuildingBend.for_logs(v.board, "clapboard", TownBuilder.PALISADE_H))
		assert_ne(flat.mesh.get_aabb().size, bent_logs.mesh.get_aabb().size, "the bend moves a log's points")
		flat.free()
		bent_logs.free()
	var bend := BuildingBend.for_wall(v.board, "clapboard", 1.0)
	assert_true(bend != null and bend == BuildingBend.for_wall(v.board, "clapboard", 1.0), "one wall bend for the place, kept")
	# Two squares of a straight wall share their edge: the point on it is moved the same whichever square asks.
	var edge := Vector3(10.0, 0.6, 7.5)
	assert_eq(bend.apply(edge), bend.apply(edge), "continuous across squares")
	v.queue_free()


## Building-sized props (the cottage, Baba Lysaga's hut, the mill) bend: the model's meshes are its own copies with
## moved points, inside a quarter square of the straight model.
func test_building_sized_props_bend() -> void:
	assert_true(ModelPiece.bend_amount("cottage") > 0.0, "the cottage bends")
	assert_true(ModelPiece.bend_amount("hut_lysaga") >= ModelPiece.bend_amount("windmill"), "a hut more than a mill")
	assert_eq(ModelPiece.bend_amount("dead_tree_a"), 0.0, "a tree does not")
	var board := ArenaBoard.new()
	board.place = "mount_baratok_hut"
	var straight := ModelPiece.instance("cottage")
	var crooked := ModelPiece.instance_bent(board, "cottage", Vector2i(5, 5))
	var a := _box_of(straight)
	var b := _box_of(crooked)
	assert_ne(a.size, b.size, "the cottage is not the straight model")
	assert_true(b.grow(0.001).encloses(a.grow(-0.4)) , "and still the same house")
	assert_true(absf(a.size.x - b.size.x) <= BuildingBend.MAX_OUT * 2.0 + 0.01 and absf(a.size.z - b.size.z) <= BuildingBend.MAX_OUT * 2.0 + 0.01,
		"within a quarter of a square all round")
	# A swap (Mount Baratok's stone hut) and a tint find the model's surfaces by the names Blender gave them.
	var swapped := ModelPiece.instance_bent(board, "cottage", Vector2i(5, 5))
	var names_before := _surface_names(straight)
	assert_eq(_surface_names(swapped), names_before, "the bent cottage keeps the surfaces' names")
	swapped.free()
	var again := ModelPiece.instance_bent(board, "cottage", Vector2i(5, 5))
	assert_eq(_box_of(again), b, "the same on the same square")
	straight.free()
	crooked.free()
	again.free()
	board.free()


func _surface_names(model: Node3D) -> Array[String]:
	var out: Array[String] = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			out.append(src.resource_name if src != null else "")
	return out


func _box_of(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := mi.transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
