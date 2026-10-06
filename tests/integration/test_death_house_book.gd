extends TestCase
## Death House as the book has it (owner ask 2026-10-06, docs/regions/death_house_book_check.md): every portrait
## hangs in its own room, the first two floors hold nobody until the party refuses the altar, and the rooms,
## secret doors and fights are the book's.


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _find(loc: Dictionary, key: String, id: String) -> Dictionary:
	for t: Variant in loc.get(key, []):
		if str((t as Dictionary).get("id", "")) == id:
			return t as Dictionary
	return {}


func _area_of(loc: Dictionary, cell: Vector2i) -> String:
	for a: Variant in loc.get("areas", []):
		var cs := (a as Dictionary)["cells"] as Array
		var p := Vector2i(int((cs[0] as Array)[0]), int((cs[0] as Array)[1]))
		var q := Vector2i(int((cs[1] as Array)[0]), int((cs[1] as Array)[1]))
		if cell.x >= mini(p.x, q.x) and cell.x <= maxi(p.x, q.x) and cell.y >= mini(p.y, q.y) and cell.y <= maxi(p.y, q.y):
			return str((a as Dictionary)["id"])
	return ""


## The old portraits hung on the wrong face of their walls: in the den, and inside the secret study.
func test_portraits_hang_in_their_own_rooms() -> void:
	for want: Array in [["death_house_upper", "hall_family_portrait", "dh_upper_hall"],
			["death_house_third", "master_portrait", "dh_master_suite"]]:
		var v := LocationView.create(str(want[0]), GameState.story, null, Dice.roller, "default")
		add_child(v)
		await get_tree().process_frame
		var node := v.prop_nodes[str(want[1])] as Node3D
		var sprite: Sprite3D = null
		for c: Node in node.find_children("*", "Sprite3D", true, false):
			sprite = c as Sprite3D
			break
		assert_true(sprite != null, "%s is drawn" % want[1])
		var at := sprite.global_position
		var nearest := Vector2i(-1, -1)
		var best := INF
		for z in v.grid.depth:
			for x in v.grid.width:
				var c := Vector2i(x, z)
				if v.grid.has_flag(c, CombatGrid.WALL):
					continue
				var d := Vector2(at.x, at.z).distance_to(Vector2(v.board.cell_center(c).x, v.board.cell_center(c).z))
				if d < best:
					best = d
					nearest = c
		assert_eq(_area_of(v.loc, nearest), str(want[2]), "%s faces into %s" % [want[1], want[2]])
		v.queue_free()


## The book's ground and second floors hold nobody to talk to and nothing to fight, until the house turns.
func test_the_first_two_floors_are_empty_until_a_refusal() -> void:
	for id: String in ["death_house_ground", "death_house_upper"]:
		var loc := _loc(id)
		assert_true((loc.get("npcs", []) as Array).is_empty(), "%s has no NPCs" % id)
		for e: Variant in loc.get("encounters", []):
			var enc := e as Dictionary
			var when := str(enc.get("when", ""))
			assert_true(enc["trigger"] == "dialogue" or when.contains("death_house_refused"),
				"%s: %s only after a refusal" % [id, enc["id"]])


func test_the_rooms_and_fights_are_the_books() -> void:
	var third := _loc("death_house_third")
	assert_eq(str(_find(third, "encounters", "storage_broom")["trigger"]), "enter_area:dh_third_storage", "the broom is in the third floor's storage room (area 14)")
	assert_true(int(_find(third, "doors", "attic_stair_door").get("secret_dc", 0)) > 0, "the attic stair is behind a secret door off the balcony")
	assert_true(int(_find(third, "doors", "mirror_stair_door").get("secret_dc", 0)) > 0, "and behind the nursemaid's mirror")
	var attic := _loc("death_house_attic")
	var ex := _find(attic, "exits", "secret_stair_down")
	var c := ex["cell"] as Array
	assert_eq(_area_of(attic, Vector2i(int(c[0]), int(c[1]))), "dh_storage_room", "the stair down starts in the attic storage room (area 18)")
	assert_false(_find(attic, "props", "nursemaid_trunk").is_empty(), "the nursemaid's remains are in the attic")
	assert_false(_find(attic, "areas", "dh_spare_bedroom_2").is_empty(), "two spare bedrooms (areas 17 and 19)")
	var d1 := _loc("death_house_dungeon_1")
	for area: String in ["dh_family_crypts", "dh_cult_dormitory", "dh_well_chamber", "dh_pit_passage", "dh_cult_refectory",
			"dh_larder", "dh_ghoul_passage", "dh_lower_stair", "dh_shrine", "dh_trapdoor_stair", "dh_durst_chambers", "dh_durst_quarters"]:
		assert_false(_find(d1, "areas", area).is_empty(), "the dungeon has %s" % area)
	var counts := {"larder_grick": 1, "passage_ghouls": 4, "shrine_shadows": 5, "den_mimic": 1, "crypt_insects": 1}
	for enc_id: String in counts:
		assert_eq((_find(d1, "encounters", enc_id)["monsters"] as Array).size(), int(counts[enc_id]), enc_id)
	for m: Variant in _find(d1, "encounters", "durst_reunion")["monsters"]:
		assert_eq(str((m as Dictionary)["monster"]), "ghast", "Gustav and Elisabeth are both ghasts")
	assert_eq(int(_find(_loc("death_house_third"), "containers", "jewel_box").get("gold", 0)), 900, "the master suite's jewels")
