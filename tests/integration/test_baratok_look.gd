extends TestCase
## Mount Baratok's look (the vault's "Mount Baratok Look Plan"): the stone hut stands at its real size, the place has
## its own air (light, lying snow, a falling horizon), and the fights, exits and finds the map holds keep their squares.
## The first four tests are the plan's guards: every step of it keeps them green.

const HUT := "baratok_hut"
const LOC := "mount_baratok"

## The fight ground (rows 7 to 20, the open snowfield, the glass ring and the hut yard), character for character as the
## storm fight was tuned on it (the boss series wants 2 to 4 wins in 8): the look is done with props, light and weather,
## never with these rows or heights.
const ARENA_ROWS: Array[String] = [
	"###..=........######################",
	"###...........######################",
	"###...................~~.......#####",
	"###..........~~~~~....~~.......#####",
	"#............~~~~~.............#####",
	"#..........................=...#####",
	"#.......####...~~~~................#",
	"#.......####...~~~~...........=....#",
	"#.......####.......................#",
	"#..................########........#",
	"#..................................#",
	"#......~~~~..............~~~.......#",
	"#......~~~~..............~~~.......#",
	"#######~~~~..............~~~########",
]
const ARENA_ELEVATION: Array[String] = [
	"888999999999998999988888888888888999",
	"677888888888888877777777777777778999",
	"156777777777777777777777777777778999",
	"156777777777777777777777777777778999",
	"177777777777777777777777777777778888",
	"177777777777777777777777777777777777",
	"177777777777777777777777777777777777",
	"177777777887777777777777777777777777",
	"177777777777777777777777777777777776",
	"177777777777777777777777777777777666",
	"177766666666666666666666666666666666",
	"145666666666666666666666666666666666",
	"134455555555555555555555555555566666",
	"123444555555555555555555555555555555",
]
## Where every prop and container the map had before the plan stands (the hut one row back since Step 1).
const OLD_THINGS := {
	"baratok_hut": Vector2i(25, 8), "baratok_frozen_birds": Vector2i(21, 13), "baratok_glass_ring": Vector2i(13, 18),
	"baratok_overlook": Vector2i(2, 14), "baratok_carved_post": Vector2i(18, 22), "baratok_cairn": Vector2i(8, 1),
	"baratok_cairn_opened": Vector2i(8, 1), "glass_ring_wand": Vector2i(14, 19), "summit_ioun": Vector2i(9, 2),
	"summit_frost_1": Vector2i(7, 1), "summit_frost_2": Vector2i(9, 1), "summit_frost_3": Vector2i(7, 2),
	"baratok_boulder_1": Vector2i(5, 7), "baratok_boulder_2": Vector2i(27, 12), "baratok_boulder_3": Vector2i(10, 22),
	"hut_yard_drift": Vector2i(30, 14), "hut_yard_notes": Vector2i(28, 14), "corvina_letter_birds": Vector2i(22, 13),
	"corvina_letter_ring": Vector2i(12, 17), "corvina_letter_overlook": Vector2i(3, 15), "storm_glass": Vector2i(14, 17),
	"baratok_summit_cache": Vector2i(5, 3),
}
## What the storm fight stands on: the storm (Huge) at [11, 16], A Squall (Large) at [20, 12], and the four squares the
## boss series puts the party on.
const STORM_SQUARES: Array[Rect2i] = [Rect2i(11, 16, 3, 3), Rect2i(20, 12, 2, 2), Rect2i(16, 18, 2, 2)]
const SPAWNS := {"default": Vector2i(17, 25), "from_road": Vector2i(17, 25), "from_hut": Vector2i(25, 11)}
const WAYS: Array[Vector2i] = [Vector2i(17, 27), Vector2i(18, 27), Vector2i(25, 10)]
## A square beside each of these must be reachable from the arrival on 5 ft steps: the cache, the cairn, the overlook,
## the storm's glass, the hut yard's notes, the three letters, and the glass ring's wand.
const FINDS: Array[Vector2i] = [Vector2i(5, 3), Vector2i(8, 1), Vector2i(2, 14), Vector2i(14, 17), Vector2i(28, 14),
	Vector2i(22, 13), Vector2i(12, 17), Vector2i(3, 15), Vector2i(14, 19)]


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func after_each() -> void:
	Look.set_style(Look.DEFAULT_STYLE, false)


func _view() -> LocationView:
	var v := LocationView.create(LOC, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", LOC) as Dictionary


func _cell(v: Variant) -> Vector2i:
	var a := v as Array
	return Vector2i(int(a[0]), int(a[1]))


## Every prop and container of the map by id: its square.
func _things() -> Dictionary:
	var out := {}
	for key: String in ["props", "containers"]:
		for t: Variant in _loc()[key] as Array:
			out[str((t as Dictionary)["id"])] = _cell((t as Dictionary)["cell"])
	return out


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The world box around everything a model draws.
func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Owner report (2026-10-19): "the stone hut sprite is tiny". The cottage was shrunk to keep clear of its own door
## square (ModelPiece.big_fit counts the exit as something standing there) to about half its size, a 7 ft hut the party
## stood taller than. It now stands a row back, against the rock, drawn at its `scale` times the modelled cottage.
func test_the_hut_stands_at_its_real_size() -> void:
	var v := _view()
	await _frames(2)
	var hut := v.prop_nodes.get(HUT) as Node3D
	assert_true(hut != null, "the hut is built")
	if hut == null:
		return
	var held := hut.find_children("Model_*", "Node3D", true, false)
	assert_false(held.is_empty(), "the hut is a 3D piece")
	if held.is_empty():
		return
	var model := held[0] as Node3D
	var size := (ModelPiece.manifest()[str(model.get_meta("model"))] as Dictionary)["size"] as Array
	var want := 1.0
	for p: Variant in (Compendium.shared().get_entry("locations", LOC) as Dictionary)["props"] as Array:
		if str((p as Dictionary)["id"]) == HUT:
			want = float((p as Dictionary).get("scale", 1.0))
	assert_true(want >= 1.0, "the hut asks for at least the cottage's own size (%.2f)" % want)
	var box := _bounds(model)
	assert_true(box.size.x >= float(size[0]) * want * 0.95, "the hut is as wide as asked (%.2f of %.2f)" % [box.size.x, float(size[0]) * want])
	assert_true(box.size.y >= float(size[1]) * want * 0.95, "and as tall (%.2f of %.2f)" % [box.size.y, float(size[1]) * want])
	# A party member is 1.2 units tall: the door stands over them, the eaves too.
	assert_true(box.size.y > 3.0, "the hut stands well over a person (%.2f units)" % box.size.y)
	# Its door side stays clear of the exit's square: the way in is the square in front of it.
	var door := Vector2i(25, 10)
	assert_false(Rect2(box.position.x, box.position.z, box.size.x, box.size.z).intersects(Rect2(door.x, door.y, 1, 1).grow(-0.12)),
		"the hut doesn't stand on its own doorstep")
	v.queue_free()
	await _frames(1)


## The fight ground, the fights, the ways in and out, the arrival squares, the window's light and the ward are as they
## were when the storm fight was tuned and the exits walked (the plan's guard 1).
func test_the_fight_ground_is_untouched() -> void:
	var map := _loc()["map"] as Dictionary
	var rows := map["rows"] as Array
	var heights := map["elevation"] as Array
	for i in ARENA_ROWS.size():
		assert_eq(str(rows[7 + i]), ARENA_ROWS[i], "row %d of the fight ground is as the storm was tuned on it" % (7 + i))
		assert_eq(str(heights[7 + i]), ARENA_ELEVATION[i], "and so are its heights, row %d" % (7 + i))
	var starts := {}
	for en: Variant in _loc()["encounters"] as Array:
		for m: Variant in (en as Dictionary)["monsters"] as Array:
			starts[str((m as Dictionary)["monster"])] = _cell((m as Dictionary)["cell"])
	assert_eq(starts.get("forgotten_storm"), Vector2i(11, 16), "the storm starts where it did")
	assert_eq(starts.get("air_elemental"), Vector2i(20, 12), "and so does A Squall")
	for id: String in SPAWNS:
		assert_eq(_cell((_loc()["spawns"] as Dictionary)[id]), SPAWNS[id], "the %s spawn" % id)
	var exits: Array[Vector2i] = []
	for e: Variant in _loc()["exits"] as Array:
		exits.append(_cell((e as Dictionary)["cell"]))
	for way: Vector2i in WAYS:
		assert_true(way in exits, "the way out at %s is still there" % way)
	var light := (_loc()["lights"] as Array)[0] as Dictionary
	assert_eq(_cell(light["cell"]), Vector2i(25, 9), "the hut window's light stays at its doorstep")
	var ward: Array[Vector2i] = []
	for c: Variant in ((_loc()["traps"] as Array)[0] as Dictionary)["cells"] as Array:
		ward.append(_cell(c))
	var want: Array[Vector2i] = [Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2), Vector2i(7, 1), Vector2i(9, 1)]
	assert_eq(ward, want, "the ward round the cairn")


## Every prop and container the map had stands on its square, and the quest and search things are all still there.
func test_the_old_things_keep_their_squares() -> void:
	var things := _things()
	for id: String in OLD_THINGS:
		assert_true(things.has(id), "%s is still on the map" % id)
		if things.has(id):
			assert_eq(things[id], OLD_THINGS[id], "%s stands where it did" % id)


## How far (Chebyshev) square `c` is from the nearest square of `r`; 0 on it.
func _gap(c: Vector2i, r: Rect2i) -> int:
	var dx := maxi(maxi(r.position.x - c.x, c.x - (r.end.x - 1)), 0)
	var dy := maxi(maxi(r.position.y - c.y, c.y - (r.end.y - 1)), 0)
	return maxi(dx, dy)


## Nothing new stands within two squares of the storm fight's squares (the foes' footprints and the party's start in the
## boss series), within one of an arrival, on a '=' square (fight cover: decor on it opens it) or on the hut's doorstep.
func test_nothing_new_stands_by_a_fight() -> void:
	var rows := (_loc()["map"] as Dictionary)["rows"] as Array
	for id: String in _things():
		if OLD_THINGS.has(id):
			continue
		var c := _things()[id] as Vector2i
		for r: Rect2i in STORM_SQUARES:
			assert_true(_gap(c, r) >= 3, "%s at %s is at least 3 squares from the storm fight's %s" % [id, c, r])
		for sp: String in SPAWNS:
			assert_true(_gap(c, Rect2i(SPAWNS[sp] as Vector2i, Vector2i.ONE)) >= 2, "%s at %s keeps clear of the %s arrival" % [id, c, sp])
		assert_false(str(rows[c.y])[c.x] == "=", "%s at %s isn't on fight cover" % [id, c])
		assert_false(c in [Vector2i(25, 9), Vector2i(25, 10)], "%s at %s isn't on the hut's doorstep" % [id, c])


## The squares the party can walk from `from`: open floor ('.' and '~'), eight ways without cutting a wall's corner, a
## step of at most 5 ft of height, and not through any prop or container.
func _walk(from: Vector2i) -> Dictionary:
	var map := _loc()["map"] as Dictionary
	var rows := map["rows"] as Array
	var heights := map["elevation"] as Array
	var shut := {}
	for id: String in _things():
		shut[_things()[id]] = true
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c := queue.pop_front() as Vector2i
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				var n := c + Vector2i(dx, dy)
				if n == c or seen.has(n) or not _open(rows, n) or shut.has(n):
					continue
				if dx != 0 and dy != 0 and not (_open(rows, c + Vector2i(dx, 0)) and _open(rows, c + Vector2i(0, dy))):
					continue
				if absi(_height(heights, n) - _height(heights, c)) > 1:
					continue
				seen[n] = true
				queue.append(n)
	return seen


func _open(rows: Array, c: Vector2i) -> bool:
	return c.y >= 0 and c.y < rows.size() and c.x >= 0 and c.x < str(rows[c.y]).length() and str(rows[c.y])[c.x] in ".~"


func _height(heights: Array, c: Vector2i) -> int:
	return CombatGrid.ELEVATION_CHARS.find(str(heights[c.y])[c.x])


## From the arrival on the goat track the party reaches every way out, the arrival from the hut, a square beside each
## find and all four squares the storm fight starts them on, by 5 ft steps over open floor.
func test_the_ways_and_finds_stay_reachable() -> void:
	var seen := _walk(SPAWNS["default"] as Vector2i)
	for way: Vector2i in WAYS:
		assert_true(seen.has(way), "the way out at %s is reachable" % way)
	assert_true(seen.has(SPAWNS["from_hut"] as Vector2i), "so is the arrival from the hut")
	for find: Vector2i in FINDS:
		var beside := false
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				beside = beside or seen.has(find + Vector2i(dx, dy))
		assert_true(beside, "a square beside %s is reachable" % find)
	for dx: int in [0, 1]:
		for dy: int in [0, 1]:
			assert_true(seen.has(Vector2i(16 + dx, 18 + dy)), "the storm fight's party square %s is reachable" % Vector2i(16 + dx, 18 + dy))


## The place's own air (Step 2): its own mood, flora set and horizon, snow that lies whatever the sky does, the land
## falling away past the edge, chimney smoke where the hut's chimney is. The trail and the pass keep the shared one.
func test_baratok_has_its_own_air() -> void:
	Look.set_style("modern", false)
	var a := Atmosphere.new()
	a.loc_id = LOC
	a.outdoors = true
	a.mood_id = Atmosphere.mood_for(LOC, _loc())
	var mood_id := a.mood_id
	var m := a._dressed()
	a.free()
	assert_eq(mood_id, "baratok_heights", "Baratok has a mood of its own")
	assert_eq(Flora.set_for(mood_id), "baratok", "and its own plant set")
	assert_true(float(m.get("lying_snow", 0.0)) >= 0.5, "snow lies whatever the sky does (%s)" % m.get("lying_snow"))
	var surround := m.get("surround", {}) as Dictionary
	assert_true(float(surround.get("rise", 0.0)) < 0.0, "the land falls away past the edge")
	assert_true(float(surround.get("trees", 0.0)) < ForegroundFraming.WOODED, "without wooding the screen's corners with ferns")
	var smoke := Vector3.ZERO
	for w: Variant in m.get("weather", []) as Array:
		if w is Dictionary and str((w as Dictionary).get("kind", "")) == "smoke":
			var at := ((w as Dictionary)["at"] as Array)[0] as Array
			smoke = Vector3(float(at[0]), float(at[1]), float(at[2]))
	assert_true(smoke.x > 23.8 and smoke.x < 27.2 and smoke.z > 7.1 and smoke.z < 9.9 and smoke.y > 7.0, "smoke rises over the hut (%s)" % smoke)
	assert_true((Vista.config()["styles"] as Dictionary).has("baratok"), "its horizon has a style of its own, else the woods' green ridges")
	for other: String in ["mount_baratok_trail", "mountain_pass"]:
		assert_eq(Atmosphere.mood_for(other, Compendium.shared().get_entry("locations", other)), "high_snow", "%s keeps the shared mood" % other)


## Snow marks, not leaves and mud (Step 3): the wilderness rules lay autumn leaves, mud and twigs, which are wrong on a
## snowfield. A place's clutter rules match by prefix, so the hut's interior keeps the house rules it had.
func test_snow_marks_not_leaves() -> void:
	Look.set_style("modern", false)
	var v := _view()
	await _frames(2)
	var rules := str(Clutter.rules_for(v.board))
	for gone: String in ["floor_leaves", "floor_mud", "kit_scatter_twigs"]:
		assert_false(rules.contains(gone), "no %s on a snowfield" % gone)
	assert_true(rules.contains("floor_cracks"), "a cracked crust instead")
	v.queue_free()
	await _frames(1)
	var inside := LocationView.create("mount_baratok_hut", GameState.story, null, Dice.roller, "default")
	add_child(inside)
	await _frames(2)
	var house := (SetDressing.catalog()["clutter"] as Dictionary)["themes"] as Dictionary
	assert_eq(str(Clutter.rules_for(inside.board)), str(house["house"]), "the hut's inside keeps the house's marks")
	inside.queue_free()
	await _frames(1)


## Whether the board drew wall square `c` as a tree (a 3D plant: meta `nature`) or as a rock column (a box).
func _is_tree(board: ArenaBoard, c: Vector2i) -> bool:
	for n: Variant in board.dressing.get(c, []):
		if (n as Node).has_meta("nature"):
			return true
	return false


func _is_rock(board: ArenaBoard, c: Vector2i) -> bool:
	for n: Variant in board.dressing.get(c, []):
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is BoxMesh and not (n as Node).has_meta("nature"):
			return true
	return false


## The treeline (Step 4): in the Modern look the south approach, the drop under the lookout, the field's inner blocks and
## the east edge are trees where the rules still have walls (catalog place_looks `tree_walls`), and the crags above stay
## bare rock; the frozen Classic look keeps its rock everywhere.
func test_pines_below_crags_above() -> void:
	Look.set_style("modern", false)
	var v := _view()
	await _frames(2)
	var low := Vector2i(0, 25)
	var high := Vector2i(20, 3)
	assert_true(v.board.grid.has_flag(low, CombatGrid.WALL) and v.board.grid.has_flag(high, CombatGrid.WALL), "both are still walls to the rules")
	assert_true(_is_tree(v.board, low) and not _is_rock(v.board, low), "the lower slope at %s is a tree" % low)
	assert_true(_is_rock(v.board, high) and not _is_tree(v.board, high), "the crag at %s is bare rock" % high)
	var rocks := 0
	for n: Node3D in v.board.mesh_occluders:
		if is_instance_valid(n) and n is MeshInstance3D and n.get_parent() == v.board:
			rocks += 1
	assert_true(rocks > 20, "the crags still fade like trees when they stand in the party's way (%d rock columns)" % rocks)
	v.queue_free()
	await _frames(1)
	Look.set_style("classic", false)
	var classic := _view()
	await _frames(2)
	assert_true(_is_rock(classic.board, low) and not _is_tree(classic.board, low), "Classic keeps its rock at %s" % low)
	classic.queue_free()
	await _frames(1)


## The stone hut (Step 5): the map calls it one, and the cottage model is half-timbered plaster and thatch, so the
## catalog's `swap` draws its walls in the interior's stone and its roof in slate (ModelPiece.swap_surfaces).
func test_the_hut_is_stone() -> void:
	var v := _view()
	await _frames(2)
	var hut := v.prop_nodes.get(HUT) as Node3D
	assert_true(hut != null, "the hut is built")
	if hut == null:
		return
	var surfaces: Array[String] = []
	for n: Node in hut.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m != null and m.has_meta("surface"):
				surfaces.append(str(m.get_meta("surface")))
	assert_true("dungeon/stone_wall" in surfaces, "its walls are the interior's stone (%s)" % [surfaces])
	assert_true("village/roof_slate" in surfaces, "its roof is slate")
	assert_false("village/house_wall" in surfaces or "village/roof_thatch" in surfaces, "no plaster and no thatch left")
	v.queue_free()
	await _frames(1)


## Everything the plan adds is built (decor props with no label, no text), and every light it adds is only painted
## (`visual`: it lights the picture and gives a fight no light zone), so the fights' light rules don't change at night.
func test_the_new_pieces_are_built_and_the_new_lights_are_painted() -> void:
	var v := _view()
	await _frames(2)
	for id: String in _things():
		if OLD_THINGS.has(id):
			continue
		assert_true(v.prop_nodes.has(id) or v.container_nodes.has(id), "%s is built" % id)
	for t: Variant in _loc()["props"] as Array:
		if not OLD_THINGS.has(str((t as Dictionary)["id"])):
			assert_eq(str((t as Dictionary)["kind"]), "decor", "%s is decor: no interaction and no new text" % (t as Dictionary)["id"])
			assert_false((t as Dictionary).has("label"), "%s has no label" % (t as Dictionary)["id"])
	for l: Variant in _loc()["lights"] as Array:
		if _cell((l as Dictionary)["cell"]) != Vector2i(25, 9):
			assert_true(bool((l as Dictionary).get("visual", false)), "the light at %s is only painted" % [(l as Dictionary)["cell"]])
	v.queue_free()
	await _frames(1)
