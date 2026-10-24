extends TestCase
## The tomb of King Barov and Queen Ravenovia in the old tombs (held ask of 2026-10-23: their tombs should stand side by side,
## every room still reachable). The sarcophagi share one dais; the queen's, which holds the Tarokka treasure, was four squares
## from the king's and now stands beside it. Nothing else of the room, its doors or its final battle moved.

const TOMBS := "castle_ravenloft_catacombs_tombs"


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", TOMBS)


func _cell(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


func _find(key: String, id: String) -> Dictionary:
	for t: Variant in _loc()[key]:
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


## The squares reachable on foot (four ways, doors count as open) from `from`.
func _reach(rows: Array, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= str(rows[n.y]).length() or seen.has(n):
				continue
			if str(rows[n.y])[n.x] in ["#", " ", "w"]:
				continue
			seen[n] = true
			todo.append(n)
	return seen


func test_the_king_and_queen_lie_side_by_side_on_the_dais() -> void:
	var king := _cell(_find("props", "cat_barov_sarcophagus")["cell"])
	var queen := _cell(_find("containers", "cat_ravenovia_sarcophagus")["cell"])
	assert_eq(king, Vector2i(14, 22), "the king's square is where it was")
	assert_eq(queen, king + Vector2i(1, 0), "the queen's is the next square along")
	var rows := (_loc()["map"] as Dictionary)["rows"] as Array
	for c: Vector2i in [king, queen]:
		assert_eq(str(rows[c.y])[c.x], "_", "%s is on the dais" % c)


func test_the_queens_treasure_is_still_the_places_hoard() -> void:
	var queen := _find("containers", "cat_ravenovia_sarcophagus")
	assert_eq(str(((_loc()["treasure_spots"] as Dictionary)["castle_ravenloft_tomb_of_barov_and_ravenovia"] as Dictionary)["container"]), "cat_ravenovia_sarcophagus")
	assert_eq(int(queen["gold"]), 60)
	assert_eq(str(((queen["items"] as Array)[0] as Dictionary)["id"]), "perfume")


## Every open square of the three rooms and the passage is on one walk from the arrival, the royal chamber's included.
func test_every_room_of_the_old_tombs_is_still_reachable() -> void:
	var loc := _loc()
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	var reach := _reach(rows, _cell((loc["spawns"] as Dictionary)["default"]))
	for y in rows.size():
		for x in str(rows[y]).length():
			if str(rows[y])[x] in [".", "_", "="]:
				assert_true(reach.has(Vector2i(x, y)), "(%d, %d) can be walked to" % [x, y])
	var king := _cell(_find("props", "cat_barov_sarcophagus")["cell"])
	var queen := _cell(_find("containers", "cat_ravenovia_sarcophagus")["cell"])
	for c: Vector2i in [king, queen]:
		var beside := 0
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if reach.has(c + d) and (c + d) != king and (c + d) != queen:
				beside += 1
		assert_true(beside >= 2, "%s can be reached from open squares beside it" % c)


func test_no_foe_of_the_royal_battle_starts_on_a_sarcophagus() -> void:
	var king := _cell(_find("props", "cat_barov_sarcophagus")["cell"])
	var queen := _cell(_find("containers", "cat_ravenovia_sarcophagus")["cell"])
	for e: Variant in _loc()["encounters"]:
		if str((e as Dictionary)["id"]) != "cat_royal_final":
			continue
		for m: Variant in (e as Dictionary)["monsters"]:
			assert_false(_cell((m as Dictionary)["cell"]) in [king, queen], "a foe of cat_royal_final stands on a sarcophagus")
