extends TestCase
## What lies past a map's edge (Improvement Ideas W13, docs/art/atmosphere.md "Vistas") and the camera that tilts
## up to see it: every outdoor place is on the travel art, its mountains are drawn, Castle Ravenloft stands at its true
## bearing where it can be seen (never from the castle itself), or as near it as the tilted camera frames, Lake Zarovich only near the lake; past the farthest
## zoom the wheel tilts the camera toward the horizon a step at a time and back, never in Classic, and never when a tool
## sets the distance itself.


func before_each() -> void:
	InputActions.ensure()   # the camera's wheel handler also asks about its rotate keys
	GameState.reset()
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


func _wheel(rig: CameraRig, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	rig._unhandled_input(e)


## Every outdoor place with land round it is on the travel art, so its vistas know where they are.
func test_every_outdoor_place_is_on_the_travel_art() -> void:
	var places := Vista.config()["places"] as Dictionary
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		var map := (locs[loc_id] as Dictionary).get("map", {}) as Dictionary
		if bool(map.get("outdoors", false)):
			assert_true(places.has(loc_id), "%s is placed on the travel art (art/vistas/vistas.json)" % loc_id)


## From the village: mountains, Castle Ravenloft toward its true bearing, no lake. From Vallaki: the lake. At the
## castle's gates: no castle on the horizon.
func test_landmarks_stand_where_they_are() -> void:
	Look.set_style("modern", false)
	var v := _view("village_of_barovia")
	var vista := v.atmosphere.land.vista
	assert_true(vista != null and vista.get_node_or_null("Mountains") != null, "mountains round the village")
	var castle := vista.get_node_or_null("CastleRavenloft") as Node3D
	assert_true(castle != null, "Castle Ravenloft seen from the village")
	var here := Vista.place_at("village_of_barovia") as Vector2
	var at := (Vista.config()["castle"] as Dictionary)["at"] as Array
	var truly := Vector2(float(at[0]), float(at[1])) - here
	var got := Vector2(castle.position.x - vista.centre.x, castle.position.z - vista.centre.z).normalized()
	assert_true(got.dot(Vector2.from_angle(Vista.on_skyline(truly, []))) > 0.999,
		"the castle stands toward its bearing on the travel art, where the tilted camera frames it")
	assert_true(got.dot(truly.normalized()) > 0.99, "a few degrees from its true bearing at most, from the village")
	assert_true(vista.get_node_or_null("LakeZarovich") == null, "no lake from the village")
	v.queue_free()
	var vallaki := _view("vallaki")
	assert_true(vallaki.atmosphere.land.vista.get_node_or_null("LakeZarovich") != null, "Lake Zarovich past Vallaki")
	vallaki.queue_free()
	var gates := _view("castle_ravenloft_gates")
	if gates.atmosphere.land != null and gates.atmosphere.land.vista != null:
		assert_true(gates.atmosphere.land.vista.get_node_or_null("CastleRavenloft") == null, "no far castle at its own gates")
	gates.queue_free()


## Each region's own landmark on the horizon (the vault's Region Variety Plan): Van Richten's tower toward its bearing
## from the lake shore, the windmill from the village, none from its own place nor a mountain from its own slopes, and
## never more than Vista.MAX_LANDMARKS at once.
func test_each_region_has_its_landmarks() -> void:
	Look.set_style("modern", false)
	var lake := _view("lake_zarovich")
	var vista := lake.atmosphere.land.vista
	var tower := vista.get_node_or_null("Landmark_van_richtens_tower") as Node3D
	assert_true(tower != null, "Van Richten's tower seen from the lake shore")
	var here := Vista.place_at("lake_zarovich") as Vector2
	var at := ((Vista.config()["landmarks"] as Dictionary)["van_richtens_tower"] as Dictionary)["at"] as Array
	var want := (Vector2(float(at[0]), float(at[1])) - here).normalized()
	var got := Vector2(tower.position.x - vista.centre.x, tower.position.z - vista.centre.z).normalized()
	assert_true(got.dot(want) > 0.99, "the tower stands toward its bearing on the travel art")
	assert_true(vista.find_children("Landmark_*", "", false, false).size() <= Vista.MAX_LANDMARKS, "a few at most")
	lake.queue_free()
	var village := _view("village_of_barovia")
	assert_true(village.atmosphere.land.vista.get_node_or_null("Landmark_bonegrinder") != null,
		"Old Bonegrinder's windmill seen from the village")
	village.queue_free()
	var hill := _view("old_bonegrinder_hill")
	assert_true(hill.atmosphere.land.vista.get_node_or_null("Landmark_bonegrinder") == null, "but not from its own hill")
	hill.queue_free()
	var shoulder := _view("ghakis_shoulder")
	if shoulder.atmosphere.land != null and shoulder.atmosphere.land.vista != null:
		assert_true(shoulder.atmosphere.land.vista.get_node_or_null("Landmark_mount_ghakis") == null,
			"nor Mount Ghakis from its own slopes")
	shoulder.queue_free()


## The Abbey of St. Markovia from Krezk and the Pool of the White Sun (owner ask, 2026-10-13). It is due north of
## them on the travel art, and the camera only ever looks along a diagonal, so it was never in view: these maps stand
## it north-north-east, up the mountain Krezk's track climbs, where the camera's first view tilted to the horizon has
## all of it in frame, even on a 16:10 screen (the narrowest the game's window keeps its height on). From the
## waystone down the road it keeps its bearing on the travel art.
func test_the_abbey_is_seen_from_krezk() -> void:
	Look.set_style("modern", false)
	for loc_id: String in ["krezk", "krezk_pool_of_the_white_sun"]:
		var v := _view(loc_id)
		var abbey := v.atmosphere.land.vista.get_node_or_null("Landmark_abbey") as MeshInstance3D
		assert_true(abbey != null, "the Abbey on the horizon from %s" % loc_id)
		if abbey != null:
			v.rig.distance = v.rig.zoom_max
			v.rig.horizon = 1.0
			v.rig.snap_to_target()
			var cam := v.rig.camera
			var half_high := cam.fov / 2.0
			var half_wide := rad_to_deg(atan(tan(deg_to_rad(half_high)) * 1.6))
			var size := (abbey.mesh as QuadMesh).size
			for share: float in [0.5, 1.0]:
				var at := cam.global_transform.affine_inverse() * (abbey.global_position + Vector3(0, size.y * share, 0))
				var across := rad_to_deg(absf(atan2(at.x, -at.z))) + rad_to_deg(atan2(size.x / 2.0, -at.z))
				var up := rad_to_deg(atan2(at.y, -at.z))
				assert_true(at.z < 0.0 and across < half_wide and absf(up) < half_high,
					"from %s the camera's first view has the Abbey in frame, %s (%.1f degrees across, %.1f up)" % [
					loc_id, "its tower" if share > 0.9 else "its middle", across, up])
		v.queue_free()
	var road := _view("krezk_road_waystone")
	var vista := road.atmosphere.land.vista
	var far_abbey := vista.get_node_or_null("Landmark_abbey") as Node3D
	assert_true(far_abbey != null, "the Abbey seen from the waystone")
	if far_abbey != null:
		var here := Vista.place_at("krezk_road_waystone") as Vector2
		var at := ((Vista.config()["landmarks"] as Dictionary)["abbey"] as Dictionary)["at"] as Array
		var want := (Vector2(float(at[0]), float(at[1])) - here).normalized()
		var got := Vector2(far_abbey.position.x - vista.centre.x, far_abbey.position.z - vista.centre.z).normalized()
		assert_true(got.dot(want) > 0.99, "from the waystone it stands toward its bearing on the travel art")
	road.queue_free()


## How far `way` (an angle, as Vector2.angle) is from the nearest diagonal, where the tilted camera looks.
func _off_diagonal(way: float) -> float:
	var diagonal := floorf(way / (PI / 2.0)) * (PI / 2.0) + PI / 4.0
	return absf(angle_difference(diagonal, way))


func _near(actual: float, expected: float, within: float, msg: String) -> void:
	assert_between(actual, expected - within, expected + within, msg)


## A bearing (degrees clockwise from north) as an angle (Vector2.angle: x east, y south) and back.
func _angle(bearing: float) -> float:
	return deg_to_rad(bearing - 90.0)


func _bearing(way: float) -> float:
	return fposmod(rad_to_deg(way) + 90.0, 360.0)


## The tilted camera only ever looks along a diagonal (2026-10-13): a landmark due north, east, south or west of a
## place stands turned into the arc the camera frames round the nearest diagonal, on its own side (Vista.on_skyline),
## and one that would hide another stands just past it. From Krezk, Mount Baratok (14 degrees east of north on the
## travel art) stands north-east beside the Abbey; from the Abbey, Krezk stands south-south-west, down its switchback;
## from the forest road the castle, due south, and the windmill, due north, stand where the camera finds them.
func test_landmarks_stand_where_the_camera_looks() -> void:
	var toward := func(bearing: float) -> Vector2: return Vector2.from_angle(_angle(bearing))
	var none: Array[float] = []
	_near(_bearing(Vista.on_skyline(toward.call(45.0), none)), 45.0, 0.01, "a way the camera frames is kept")
	_near(_bearing(Vista.on_skyline(toward.call(3.0), none)), 45.0 - rad_to_deg(Vista.IN_VIEW), 0.01,
		"a landmark just east of north stands north-north-east")
	_near(_bearing(Vista.on_skyline(toward.call(357.0), none)), 315.0 + rad_to_deg(Vista.IN_VIEW), 0.01,
		"one just west of north stands north-north-west")
	_near(_bearing(Vista.on_skyline(toward.call(181.0), none)), 225.0 - rad_to_deg(Vista.IN_VIEW), 0.01,
		"one just west of south stands south-south-west")
	var one: Array[float] = [_angle(45.0)]
	_near(_bearing(Vista.on_skyline(toward.call(40.0), one)), 45.0 - rad_to_deg(Vista.SPREAD), 0.01,
		"one that would hide another stands just past it, on the side nearer its own way")
	var full: Array[float] = [_angle(30.0), _angle(45.0), _angle(60.0)]
	assert_true(is_nan(Vista.on_skyline(toward.call(45.0), full)), "and none stands where there's no room left")
	Look.set_style("modern", false)
	for loc_id: String in ["krezk", "abbey_of_st_markovia", "road_forest"]:
		var v := _view(loc_id)
		var vista := v.atmosphere.land.vista
		for n: Node in vista.get_children():
			if n.name.begins_with("Landmark_") or n.name == "CastleRavenloft":
				var at := (n as Node3D).position - vista.centre
				assert_true(_off_diagonal(Vector2(at.x, at.z).angle()) <= Vista.IN_VIEW + 0.001,
					"from %s, %s stands where the tilted camera looks" % [loc_id, n.name])
		var want: Dictionary = {"krezk": ["Landmark_mount_baratok", "Landmark_abbey"],
			"abbey_of_st_markovia": ["Landmark_krezk"], "road_forest": ["CastleRavenloft", "Landmark_bonegrinder"]}
		for id: String in want[loc_id] as Array:
			assert_true(vista.get_node_or_null(id) != null, "from %s, %s is on the skyline" % [loc_id, id])
		var krezk := vista.get_node_or_null("Landmark_krezk") as Node3D
		if loc_id == "abbey_of_st_markovia" and krezk != null:
			var down := krezk.position - vista.centre
			_near(_bearing(Vector2(down.x, down.z).angle()), 213.0, 0.5, "Krezk down the Abbey's switchback")
		v.queue_free()


## In play the vistas lie past the camera's far plane; they draw after the screen pass, farthest first.
func test_vistas_cost_nothing_in_play() -> void:
	Look.set_style("modern", false)
	var v := _view("into_the_mists_road")
	var vista := v.atmosphere.land.vista
	var ring := vista.get_node("Mountains") as MeshInstance3D
	var radius := float(Vista.config()["radius"])
	assert_true(radius > v.rig.camera.far, "the mountains lie past the far plane in play")
	assert_true((ring.material_override as ShaderMaterial).render_priority > Look.POST_PRIORITY, "drawn after the screen pass")
	v.queue_free()


## Past the farthest zoom the wheel tilts the camera toward the horizon a quarter at a time, and back; zooming in
## undoes the tilt first. Distances set directly don't tilt, and Classic never does.
func test_the_camera_tilts_past_its_farthest_zoom() -> void:
	Look.set_style("modern", false)
	var rig := CameraRig.new()
	add_child(rig)
	rig.zoom_max = 30.0
	rig.distance = 29.0
	_wheel(rig, true)
	assert_eq(rig.distance, 30.0, "the wheel zooms out to the farthest play zoom first")
	assert_eq(rig.horizon, 0.0, "no tilt in play")
	for i in CameraRig.HORIZON_STEPS + 2:
		_wheel(rig, true)
	assert_eq(rig.horizon, 1.0, "then tilts all the way in a few steps")
	rig.snap_to_target()
	assert_true(absf(rig.camera.rotation_degrees.x - CameraRig.HORIZON_PITCH_DEG) < 0.01, "looking out toward the horizon")
	assert_true(rig.camera.far >= CameraRig.HORIZON_FAR - 0.1, "far enough to see the mountains")
	_wheel(rig, false)
	assert_true(rig.horizon < 1.0 and is_equal_approx(rig.distance, 30.0), "zooming in undoes the tilt first")
	rig.horizon = 0.0
	rig.distance = 60.0
	rig.snap_to_target()
	assert_true(absf(rig.camera.rotation_degrees.x - CameraRig.PITCH_DEG) < 0.01, "a distance set directly doesn't tilt")
	Look.set_style("classic", false)
	rig.distance = 30.0
	for i in CameraRig.HORIZON_STEPS:
		_wheel(rig, true)
	assert_eq(rig.horizon, 0.0, "Classic never tilts")
	rig.queue_free()


## Classic (frozen) has no vistas.
func test_classic_has_no_vistas() -> void:
	Look.set_style("classic", false)
	var v := _view("village_of_barovia")
	assert_true(v.atmosphere.land == null or v.atmosphere.land.vista == null, "no vistas in Classic")
	v.queue_free()
