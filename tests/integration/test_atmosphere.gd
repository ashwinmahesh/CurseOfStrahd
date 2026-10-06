extends TestCase
## Each place's atmosphere (docs/art/atmosphere.md): every location has a mood, every mood speaks only palette colours
## and known weather, the land around an outdoor map leaves its ways out open and stays off the map, nothing the
## atmosphere adds is a square's piece for HiddenAreas, and the time of day changes the light.

const WEATHER := ["leaves", "rain", "snow", "wisps", "crows", "chimney_smoke", "window_light", "embers"]


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func _view(loc_id: String) -> LocationView:
	var v := LocationView.create(loc_id, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


func test_every_location_has_a_mood() -> void:
	var moods := Atmosphere.moods()["moods"] as Dictionary
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		var id := Atmosphere.mood_for(loc_id, locs[loc_id] as Dictionary)
		assert_true(moods.has(id), "%s's mood %s is in art/atmosphere/moods.json" % [loc_id, id])
		var mood := Atmosphere.resolve(id)
		assert_false((mood.get("times", {}) as Dictionary).is_empty(), "%s's mood %s has times of day" % [loc_id, id])


## Every mood, every place and region it's picked for and every `like` names a mood that exists.
func test_mood_names_resolve() -> void:
	var m := Atmosphere.moods()
	var moods := m["moods"] as Dictionary
	for table: String in ["places", "prefixes", "regions", "themes"]:
		for k: String in m.get(table, {}) as Dictionary:
			assert_true(moods.has(str((m[table] as Dictionary)[k])), "%s %s names a mood that exists" % [table, k])
	for id: String in moods:
		var like := str((moods[id] as Dictionary).get("like", ""))
		assert_true(like == "" or moods.has(like), "%s is like %s, which exists" % [id, like])


## Colours only from the palette (style bible), weather only of the kinds the atmosphere knows.
func test_moods_use_palette_colours_and_known_weather() -> void:
	var palette := JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/palette.json")) as Dictionary
	var colour_keys := ["sky", "ambient", "key", "mist", "mists", "fog", "shadows", "lights", "deep", "shallow", "foam",
		"glint", "core", "rim", "colour", "splash_colour"]
	var bad: Array[String] = []
	for id: String in Atmosphere.moods()["moods"] as Dictionary:
		var mood := Atmosphere.resolve(id)
		_walk(mood, id, colour_keys, palette, bad)
		for w: Variant in mood.get("weather", []):
			var kind := str(w) if not (w is Dictionary) else str((w as Dictionary).get("kind", ""))
			assert_true(kind in WEATHER, "%s's weather %s is a known kind" % [id, kind])
			if w is Dictionary:
				for c: Variant in (w as Dictionary).get("colours", []):
					if not palette.has(str(c)):
						bad.append("%s weather colour %s" % [id, c])
	assert_eq(bad, [] as Array[String], "colours not in the palette")


func _walk(d: Dictionary, path: String, keys: Array, palette: Dictionary, bad: Array[String]) -> void:
	for k: Variant in d:
		var v: Variant = d[k]
		if v is Dictionary:
			_walk(v as Dictionary, path + "/" + str(k), keys, palette, bad)
		elif v is Array:
			for e: Variant in v:
				if e is Dictionary:
					_walk(e as Dictionary, path + "/" + str(k), keys, palette, bad)
		elif str(k) in keys and v is String and not palette.has(str(v)):
			bad.append("%s/%s = %s" % [path, k, v])


## The opening road: land around the map, a road out of the village exit, the Mists to the east, and none of it on a
## map square or among the things HiddenAreas hides.
func test_the_road_has_land_around_it() -> void:
	var v := _view("into_the_mists_road")
	var a := v.atmosphere
	assert_true(a != null and a.land != null, "the road has land around it")
	var land := a.land
	# The exit at (0, 15) leads on as road; the trees beside the map stay trees.
	assert_eq(land.edge_at(Vector2(-5.0, 15.5)), AtmosphereLand.Edge.OPEN, "the road runs on out of the west exit")
	assert_eq(land.edge_at(Vector2(-5.0, 3.5)), AtmosphereLand.Edge.FOREST, "forest beyond the west edge")
	var mesh := (land.root.get_node("Land") as MeshInstance3D).mesh
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.x > v.grid.width, "the land reaches past the map")
	# No surround tree stands on the map, and the near ones fade like the board's own.
	for t: Sprite3D in land.occluders:
		var p := t.global_position
		assert_false(p.x > 0.0 and p.x < v.grid.width and p.z > 0.0 and p.z < v.grid.depth, "tree %s is off the map" % p)
		assert_true(t in v.board.occluders, "near trees fade when in front of the party")
	assert_true(a.get_parent() == v and a.get_class() == "Node", "the atmosphere is a plain node, never a square's piece")


func test_time_of_day_changes_the_light() -> void:
	var v := _view("village_of_barovia")
	GameState.story.minute_of_day = 12 * 60
	v.update_daylight()
	v.atmosphere.settle()
	var day := v.atmosphere.sun.light_color
	var day_angle := v.atmosphere.sun.rotation_degrees
	GameState.story.minute_of_day = 23 * 60
	v.update_daylight()
	v.atmosphere.settle()
	assert_ne(v.atmosphere.sun.light_color, day, "night has its own key light")
	assert_ne(v.atmosphere.sun.rotation_degrees, day_angle, "the moon comes from elsewhere")
	assert_true(v.lantern.visible, "the lantern comes out at night")


## Water squares get the moving water where the place's mood has it; a lake behind the map's frame of trees runs on
## past it.
func test_water_is_alive() -> void:
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in ["lake_zarovich", "berez", "tser_pool"]:
		if not Atmosphere.resolve(Atmosphere.mood_for(loc_id, locs[loc_id] as Dictionary)).has("water"):
			continue
		var v := _view(loc_id)
		var water := 0
		for n in v.board.get_children():
			if n is MeshInstance3D and (n as MeshInstance3D).material_override == v.atmosphere.water:
				water += 1
		assert_true(water > 0, "%s's water squares use the water material" % loc_id)
		if loc_id == "lake_zarovich" and v.atmosphere.land != null:
			assert_eq(v.atmosphere.land.edge_at(Vector2(10.5, -4.0)), AtmosphereLand.Edge.WATER, "the lake runs on north")
		v.queue_free()


## A place without a mood of its own yet keeps the look it had: no land, mist, grade or weather.
func test_places_without_a_mood_look_as_before() -> void:
	var v := _view("krezk")
	if v.atmosphere.mood_id != "outdoors_plain":
		return
	assert_true(v.atmosphere.land == null, "no land around it yet")
	assert_true(v.atmosphere.weather.follow.is_empty(), "no weather yet")
	assert_true(v.atmosphere.env.fog_enabled, "the old haze")


## Indoors there is no land around the rooms and no outdoor weather.
func test_indoors_stays_indoors() -> void:
	var v := _view("blood_of_the_vine")
	assert_true(v.atmosphere.land == null, "no land around a room")
	assert_true(v.atmosphere.weather.follow.is_empty(), "no weather indoors")
