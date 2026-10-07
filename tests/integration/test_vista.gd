extends TestCase
## What lies past a map's edge (Improvement Ideas W13, docs/art/atmosphere.md "Vistas") and the camera that tilts
## up to see it: every outdoor place is on the travel art, its mountains are drawn, Castle Ravenloft stands at its true
## bearing where it can be seen (never from the castle itself), Lake Zarovich only near the lake; past the farthest
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
	var want := (Vector2(float(at[0]), float(at[1])) - here).normalized()
	var got := Vector2(castle.position.x - vista.centre.x, castle.position.z - vista.centre.z).normalized()
	assert_true(got.dot(want) > 0.99, "the castle stands toward its bearing on the travel art")
	assert_true(vista.get_node_or_null("LakeZarovich") == null, "no lake from the village")
	v.queue_free()
	var vallaki := _view("vallaki")
	assert_true(vallaki.atmosphere.land.vista.get_node_or_null("LakeZarovich") != null, "Lake Zarovich past Vallaki")
	vallaki.queue_free()
	var gates := _view("castle_ravenloft_gates")
	if gates.atmosphere.land != null and gates.atmosphere.land.vista != null:
		assert_true(gates.atmosphere.land.vista.get_node_or_null("CastleRavenloft") == null, "no far castle at its own gates")
	gates.queue_free()


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
