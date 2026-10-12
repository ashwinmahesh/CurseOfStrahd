extends TestCase
## Each indoor place's own look in the Modern finish (the vault's Region Variety Plan, part two): the lairs stand out
## (the dragon's fire-cracked cave, the lich's drowned cold, the Eye Below's amber), every house and church has its own
## light rather than the shared one, a place's flames take its colour, the lairs keep their own floors, and Classic is
## left as it was.


func before_each() -> void:
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


func _dressed(loc_id: String) -> Dictionary:
	var a := Atmosphere.new()
	a.loc_id = loc_id
	a.mood_id = Atmosphere.mood_for(loc_id, Compendium.shared().get_entry("locations", loc_id))
	var m := a._dressed()
	a.free()
	return m


## No indoor place is left on the bare shared look, and the three lairs' shades all differ.
func test_every_room_has_its_own_light() -> void:
	Look.set_style("modern", false)
	var locs := Compendium.shared().tables["locations"] as Dictionary
	for loc_id: String in locs:
		var loc := locs[loc_id] as Dictionary
		if bool((loc.get("map", {}) as Dictionary).get("outdoors", false)):
			continue
		assert_true(Atmosphere.mood_for(loc_id, loc) != "indoors", "%s has a look of its own" % loc_id)
	var shades := {}
	for loc_id: String in ["ghakis_lair", "khazan_undercroft", "amber_deep"]:
		shades[str((_dressed(loc_id).get("tone", {}) as Dictionary).get("shade", ""))] = loc_id
	assert_eq(shades.size(), 3, "the dragon's, the lich's and the Eye's lairs each have their own shade")


func test_the_lairs_stand_out() -> void:
	Look.set_style("modern", false)
	var dragon := _view("ghakis_lair")
	await get_tree().process_frame
	assert_eq(str(dragon.board.floor_material().get_meta("surface", "")), "cave/rock_floor", "the dragon's lair is a cave")
	assert_false(_any_room_floor(dragon.board, "interior/marble_floor"), "with no checker marble in its gallery")
	dragon.queue_free()
	await get_tree().process_frame
	var lich := _view("khazan_undercroft")
	await get_tree().process_frame
	assert_true(lich.atmosphere.wetness >= 0.8, "the lich's undercroft is drowned and wet")
	lich.queue_free()
	await get_tree().process_frame
	var eye := _view("amber_deep")
	await get_tree().process_frame
	assert_eq(str(eye.board.floor_material().get_meta("surface", "")), "amber/black_stone", "the Eye lies under amber")
	eye.queue_free()


func _any_room_floor(board: ArenaBoard, surface: String) -> bool:
	for r: Dictionary in board._rooms:
		var m := r.get("floor", null) as Material
		if m != null and str(m.get_meta("surface", "")) == surface:
			return true
	return false


## A place's flames take its own colour: St. Andral's candles gold, Barovia's church's cold.
func test_flames_take_the_place_colour() -> void:
	Look.set_style("modern", false)
	var rich := _dressed("vallaki_st_andrals").get("flame_tint", {}) as Dictionary
	var poor := _dressed("village_church").get("flame_tint", {}) as Dictionary
	assert_eq(str(rich.get("colour", "")), "wick", "St. Andral's candles burn gold")
	assert_eq(str(poor.get("colour", "")), "frost", "Barovia's church's burn thin and cold")
	var a := Atmosphere.new()
	a.mood = {"flame_tint": rich}
	var candle := OmniLight3D.new()
	candle.light_color = Look.color("candle")
	candle.light_energy = 1.0
	var before := candle.light_color
	a._tint_flame(candle, "candle")
	var gold := Look.color("wick")
	assert_true(_far(candle.light_color, gold) < _far(before, gold), "a candle there burns nearer gold")
	assert_true(candle.light_energy > 1.0, "and brighter")
	var magic := OmniLight3D.new()
	magic.light_color = Look.color("orchid")
	a._tint_flame(magic, "magic")
	assert_true(magic.light_color.is_equal_approx(Look.color("orchid")), "magic keeps its own colour")
	for n: Node in [a, candle, magic]:
		n.free()


func _far(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_classic_rooms_stay_as_they_were() -> void:
	Look.set_style("classic", false)
	for loc_id: String in ["ghakis_lair", "khazan_undercroft", "amber_deep", "vallaki_st_andrals"]:
		var mood := _dressed(loc_id)
		assert_false(mood.has("flame_tint"), "%s: no flame tint in Classic" % loc_id)
		assert_false(mood.has("modern"), "%s: nor the Modern block" % loc_id)
