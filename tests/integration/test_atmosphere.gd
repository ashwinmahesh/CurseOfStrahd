extends TestCase
## Each place's atmosphere (docs/art/atmosphere.md): every location has a mood, every mood speaks only palette colours
## and known weather, the land around an outdoor map leaves its ways out open and stays off the map, nothing the
## atmosphere adds is a square's piece for HiddenAreas, and the time of day changes the light.

const WEATHER := ["leaves", "rain", "snow", "wisps", "dust", "crows", "chimney_smoke", "window_light", "embers"]


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
		"glint", "core", "rim", "colour", "splash_colour", "shade", "map", "map_edge"]
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


## A lake that runs past the map's edge isn't fenced by a row of trees standing in the water.
func test_the_lake_runs_past_the_edge() -> void:
	var v := _view("lake_zarovich")
	var edge := 0
	for n in v.board.get_children():
		if n is MeshInstance3D and str(n.name).begins_with("WaterEdge"):
			edge += 1
	assert_true(edge > 0, "the frame across the lake is open water")
	var c := Vector2i(10, 0)
	for n: Node3D in v.board.dressing.get(c, []):
		assert_false(n.visible, "no tree stands in the lake at %s" % c)
	assert_true(v.grid.has_flag(c, CombatGrid.WALL), "the rules still wall the edge off")


## Every outdoor place has land around it, and none of the land's trees stand within reach of where people walk.
func test_outdoor_places_have_land() -> void:
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in ["krezk", "berez", "castle_ravenloft_gates"]:
		if not locs.has(loc_id):
			continue
		var v := _view(loc_id)
		assert_true(v.atmosphere.land != null, "%s has land around it" % loc_id)
		for t: Sprite3D in v.atmosphere.land.occluders:
			var c := Vector2i(floori(t.global_position.x), floori(t.global_position.z))
			if v.grid.in_bounds(c):
				assert_true(v.grid.has_flag(c, CombatGrid.VOID), "%s: a land tree stands only on empty ground (%s)" % [loc_id, c])
		v.queue_free()


## Indoors there is no land around the rooms and no outdoor weather.
func test_indoors_stays_indoors() -> void:
	var v := _view("blood_of_the_vine")
	assert_true(v.atmosphere.land == null, "no land around a room")
	assert_true(v.atmosphere.weather.follow.is_empty(), "no weather indoors")


## The renderer for each finish (Improvement Ideas W2): Classic keeps the renderer it was frozen with whatever the
## preset, and Modern's presets step up in how many lamps cast shadows.
func test_graphics_presets() -> void:
	var was := Look.style()
	Look.set_style("classic", false)
	Graphics.set_preset("high", false)
	assert_eq(Graphics.spec(), Graphics.CLASSIC, "Classic keeps its frozen renderer")
	assert_eq(Graphics.lamp_shadows(), 0, "no lamp shadows in Classic")
	Look.set_style("modern", false)
	var budgets: Array[int] = []
	for p: String in Graphics.PRESETS:
		Graphics.set_preset(p, false)
		budgets.append(Graphics.lamp_shadows())
	assert_true(budgets[0] < budgets[1] and budgets[1] < budgets[2], "more lamps cast shadows as the preset rises")
	Graphics.set_preset(Graphics.DEFAULT_PRESET, false)
	Look.set_style(was, false)


## In the Modern finish the lights nearest the party cast shadows, up to the preset's budget, and no others.
func test_lamps_nearest_the_party_cast_shadows() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	Graphics.set_preset("medium", false)
	var v := _view("death_house_ground")
	v.atmosphere.call("_update_lamp_shadows")
	var focus := v.rig.global_position
	var shadowed: Array[float] = []
	var plain: Array[float] = []
	for n in v.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		if not l.is_visible_in_tree() or l.light_energy <= 0.01:
			continue
		(shadowed if l.shadow_enabled else plain).append(l.global_position.distance_to(focus))
	assert_false(shadowed.is_empty(), "the house's lamps cast shadows")
	assert_eq(shadowed.size(), mini(Graphics.lamp_shadows(), shadowed.size() + plain.size()), "the budget is filled")
	if not plain.is_empty():
		assert_true(shadowed.max() <= plain.min(), "the shadows go to the nearest lights")
	v.queue_free()
	Graphics.set_preset(Graphics.DEFAULT_PRESET, false)
	Look.set_style(was, false)


## The Modern sun's shadows reach only as far as the camera sees, so they follow the zoom, in the preset's splits.
func test_sun_shadows_follow_the_zoom() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	Graphics.set_preset("high", false)
	var v := _view("village_of_barovia")
	v.rig.distance = 10.0
	v.atmosphere.call("_fit_sun_shadows")
	var close := v.atmosphere.sun.directional_shadow_max_distance
	v.rig.distance = 25.0
	v.atmosphere.call("_fit_sun_shadows")
	assert_true(v.atmosphere.sun.directional_shadow_max_distance > close, "zoomed out, the shadows reach further")
	var splits := DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if Graphics.sun_splits() == 4 \
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	assert_eq(v.atmosphere.sun.directional_shadow_mode, splits, "the preset's splits")
	var flat := 0
	for n in v.board.get_children():
		if n is MeshInstance3D and str(n.name).begins_with("Floor") and (n as MeshInstance3D).position.y < 0.0 \
				and (n as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			flat += 1
	assert_true(flat > 0, "level floor squares cast no shadow")
	v.queue_free()
	Look.set_style(was, false)


## In the Modern finish each light takes its kind (W5): soft or crisp shadows by its size, and a window indoors is the
## key light coming in, steady, with a shaft of light through the haze.
func test_lights_take_their_kind() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	var v := _view("death_house_ground")
	var kinds := {}
	var shafts := 0
	for n in v.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		var kind := str(l.get_meta("light_kind", ""))
		kinds[kind] = true
		if kind == "window":
			if l is CandleFlicker:
				assert_eq((l as CandleFlicker).flicker, 0.0, "a window's light is steady")
			if l.find_child("WindowBeam", false, false) != null:
				shafts += 1
	for k: String in ["lamp", "window", "lantern"]:
		assert_true(kinds.has(k), "Death House's %s is dressed as one" % k)
	assert_true(shafts >= 1, "a window indoors lets a shaft of light in")
	v.queue_free()
	Look.set_style(was, false)


## A swaying flame drifts a little from where it stands, and comes back to rest when it stops (W5).
func test_a_swaying_flame_comes_back_to_rest() -> void:
	var f := CandleFlicker.new()
	f.position = Vector3(2, 1, 3)
	add_child(f)
	f.set_meta("sway", true)
	var moved := false
	for i in 40:
		f._process(0.05)
		moved = moved or not f.position.is_equal_approx(Vector3(2, 1, 3))
	assert_true(moved, "it sways while asked")
	assert_true(f.position.distance_to(Vector3(2, 1, 3)) <= f.sway * 1.5, "but only a little")
	f.set_meta("sway", false)
	for i in 80:
		f._process(0.05)
	assert_true(f.position.is_equal_approx(Vector3(2, 1, 3)), "and it comes back to rest")
	f.queue_free()



## The Modern grade (W16) is the place's own: cool shade by default, a mood's colour where it has one, and every time
## of day resolves to palette colours.
func test_each_mood_has_its_own_grade() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	var village := _view("village_of_barovia")
	var night := village.atmosphere._tone("night")
	var day := village.atmosphere._tone("day")
	assert_eq(str(night["shade"]), "night", "the village's night shade is night blue")
	assert_eq(str(day["shade"]), "slate", "and its overcast day blue-grey")
	village.queue_free()
	var berez := _view("berez")
	assert_eq(str(berez.atmosphere._tone("night")["shade"]), "bog_deep", "Berez keeps its sick green")
	berez.queue_free()
	for id: String in Atmosphere.moods()["moods"] as Dictionary:
		var a := Atmosphere.new()
		a.mood = Atmosphere.resolve(id)
		for t: String in ["day", "dusk", "night", "dawn", "any"]:
			assert_true(Look.color(str(a._tone(t)["shade"])) is Color, "%s %s" % [id, t])
		a.free()
	Look.set_style(was, false)


## The presets step down the heavy effects (W17): Low draws the world smaller and drops the haze and bounced light,
## and a change of preset reaches the place on screen at once.
func test_presets_reach_the_place_on_screen() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	Graphics.set_preset("high", false)
	var v := _view("village_of_barovia")
	await get_tree().process_frame
	assert_true(v.atmosphere.env.volumetric_fog_enabled and v.atmosphere.env.ssil_enabled, "High: haze and bounce")
	Graphics.set_preset("low", false)
	assert_false(v.atmosphere.env.volumetric_fog_enabled, "Low drops the haze at once")
	assert_false(v.atmosphere.env.ssil_enabled, "and the bounced light")
	assert_true(get_viewport().scaling_3d_scale < 1.0, "and draws the world smaller")
	assert_eq(v.atmosphere.sun.light_angular_distance, 0.0, "with plain sun shadows")
	Graphics.set_preset(Graphics.DEFAULT_PRESET, false)
	assert_true(is_equal_approx(get_viewport().scaling_3d_scale, 1.0), "High draws it full size again")
	v.queue_free()
	Look.set_style(was, false)


## The frame-time meter (W17) sits on the window, hidden until F3.
func test_the_frame_meter_waits_for_f3() -> void:
	var v := _view("village_of_barovia")
	await get_tree().process_frame
	await get_tree().process_frame
	var meter := get_tree().root.get_node_or_null(FrameMeter.NODE_NAME) as FrameMeter
	assert_true(meter != null, "on the window")
	var meters := 0
	for n in get_tree().root.get_children():
		if n is FrameMeter:
			meters += 1
	assert_eq(meters, 1, "just one, however many places open")
	assert_eq(meter.visible, FrameMeter.shown(), "shown as the setting says")
	v.queue_free()


## Weather lies on the surfaces in the Modern finish (W12): rain wets Vallaki's streets, snow lies at the Abbey, and
## a dry place is dry; Classic is frozen without it.
func test_weather_on_surfaces() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	var expect := {"vallaki": [true, false], "abbey_of_st_markovia": [false, true], "village_of_barovia": [false, false]}
	for loc_id: String in expect:
		var v := _view(loc_id)
		await get_tree().process_frame
		var e := expect[loc_id] as Array
		assert_eq(v.atmosphere.wetness > 0.0, bool(e[0]), "%s wet" % loc_id)
		assert_eq(v.atmosphere.snow_cover > 0.0, bool(e[1]), "%s snowy" % loc_id)
		v.queue_free()
		await get_tree().process_frame
	Look.set_style("classic", false)
	var c := _view("vallaki")
	await get_tree().process_frame
	assert_eq(c.atmosphere.wetness, 0.0, "Classic stays as it was")
	c.queue_free()
	Look.set_style(was, false)


## The party leaves footprints on ground that takes them (W12): mud, snow, marsh and bare earth, not cobbles.
func test_footprints_on_soft_ground() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	var v := _view("berez")
	var soft := Vector2i(-1, -1)
	for z in v.grid.depth:
		for x in v.grid.width:
			if soft.x < 0 and v.atmosphere._ground_at(Vector2i(x, z)) != "":
				soft = Vector2i(x, z)
	assert_true(soft.x >= 0, "Berez has ground that takes footprints")
	var tok := v.tokens[v.members[0].id] as Node3D
	tok.global_position = v.board.cell_center(soft)
	v.atmosphere._footprints()
	tok.global_position = v.board.cell_center(soft) + Vector3(0.4, 0, 0)
	v.atmosphere._footprints()
	assert_true(v.atmosphere._prints.size() >= 1, "a step leaves a print")
	v.queue_free()
	Look.set_style(was, false)




## The castle's carved piers light their sconces in the Modern finish (the flames found in the kit's own meshes).
func test_castle_piers_light_their_sconces() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	var v := _view("castle_ravenloft_main_floor")
	var named := 0
	for n in v.board.find_children("*", "OmniLight3D", true, false):
		if str(n.get_meta("light_kind", "")) == "candle" and n.get_parent() is MeshInstance3D:
			named += 1
	assert_true(named >= 2, "the piers' sconces are lit (%d)" % named)
	v.queue_free()
	Look.set_style(was, false)


## The Death House's hearths light the room in the Modern finish (their modelled fire, W5).
func test_hearths_light_the_room() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	var v := _view("death_house_ground")
	var fires := 0
	for n in v.find_children("*", "OmniLight3D", true, false):
		if str(n.get_meta("light_kind", "")) == "fire":
			fires += 1
	assert_true(fires >= 2, "its hearths burn (%d)" % fires)
	v.queue_free()
	Look.set_style(was, false)


## Barovia's sky (W13) is drawn outdoors in the Modern finish, and the moon shows plainest at night.
func test_the_sky_outdoors() -> void:
	var was := Look.style()
	Look.set_style("modern", false)
	GameState.story.minute_of_day = 23 * 60
	var v := _view("village_of_barovia")
	await get_tree().process_frame
	var post := (v.post.mesh as QuadMesh).material as ShaderMaterial
	assert_true(bool(post.get_shader_parameter("sky_on")), "the sky over the village")
	assert_eq(float(post.get_shader_parameter("sky_moon")), 1.0, "the moon at night")
	v.queue_free()
	var inside := _view("death_house_ground")
	await get_tree().process_frame
	var ipost := (inside.post.mesh as QuadMesh).material as ShaderMaterial
	assert_false(bool(ipost.get_shader_parameter("sky_on")), "no sky indoors")
	inside.queue_free()
	Look.set_style(was, false)
