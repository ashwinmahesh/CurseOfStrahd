extends TestCase
## World sounds (A3, lane 11): every place's floor has footsteps, fires and running water get beds where they are,
## and every container model makes a sound as it opens.


func test_every_place_has_footsteps() -> void:
	var c := Compendium.shared()
	for id: String in c.table("locations"):
		var map := c.get_entry("locations", id).get("map", {}) as Dictionary
		var floor_ := WorldSounds.floor_for(id, ArenaBoard.theme_for(map))
		for difficult: bool in [false, true]:
			var step := WorldSounds.step_for(floor_, difficult, bool(map.get("outdoors", false)))
			assert_false(Audio.files("sfx", step).is_empty(), "%s walks on %s (%s)" % [id, floor_, step])


func test_floors_follow_the_place_then_its_theme() -> void:
	assert_eq(WorldSounds.floor_for("castle_ravenloft_main_floor", "manor"), "stone", "the castle's halls are stone")
	assert_eq(WorldSounds.floor_for("death_house_ground", "manor"), "wood", "a manor's own floor is wood")
	assert_eq(WorldSounds.floor_for("amber_temple_road", "wilderness"), "snow")
	assert_eq(WorldSounds.step_for("grass", true, true), "step_mud", "brambles and bog squelch outdoors")
	assert_eq(WorldSounds.step_for("stone", true, false), "step_gravel", "and crunch indoors")


func test_fires_and_water_get_beds() -> void:
	var loc := {"lights": [{"cell": [2, 2], "kind": "fire"}, {"cell": [4, 1], "kind": "candle"}, {"cell": [5, 5], "kind": "brazier"}]}
	var cells := WorldSounds.fire_cells(loc, [Vector2i(7, 7)] as Array[Vector2i])
	assert_eq(cells.size(), 3, "two open fires and a burning prop; the candle is too small to hear")
	var rows: Array[String] = []
	for z in 6:
		rows.append("...." + "w".repeat(20))
	var water := WorldSounds.water_cells(CombatGrid.from_rows(rows))
	assert_true(water.size() >= 1 and water.size() <= WorldSounds.MAX_WATER, "a long river gets a few beds: %d" % water.size())
	for c in water:
		assert_eq(c.x, 4, "each bed sits on the bank, beside a square the party can stand on")
	for id: String in ["hearth", "river", "waterfall"]:
		assert_false(Audio.files("loops", id).is_empty(), "loop %s" % id)
	for id: Variant in (Audio._data["water"] as Dictionary).values():
		assert_false(Audio.files("loops", str(id)).is_empty(), "water bed %s" % id)


func test_every_container_makes_a_sound() -> void:
	var c := Compendium.shared()
	for id: String in c.table("locations"):
		for ct: Variant in c.get_entry("locations", id).get("containers", []):
			var model := str((ct as Dictionary).get("model", ""))
			assert_false(Audio.files("sfx", WorldSounds.container_sound(model)).is_empty(), "%s's %s" % [id, model])
	for id: String in ["lever", "trap", "chest", "cupboard", "rummage"]:
		assert_false(Audio.files("sfx", id).is_empty(), id)
