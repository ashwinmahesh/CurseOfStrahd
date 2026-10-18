extends TestCase
## Daern's Instant Fortress (docs/story/fortress.md): the 2024 item's statuette, set down in the open air, grows a
## 20 ft square, 30 ft high adamantine tower where the party stands (story/fortress_site.gd), with an enterable
## interior of three maps, a safe Long Rest on the second floor, and a second power that folds it back up only when
## nobody is inside. (Before this the item built nothing: it only gave a Long Rest from the inventory.)

var root: Node
const FIELD := "test_fortress_field"
const HALL := "test_fortress_hall"
const LANE := "test_fortress_lane"
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func before_each() -> void:
	var tables := Compendium.shared().tables["locations"] as Dictionary
	tables[FIELD] = {"id": FIELD, "name": "Test Field", "region": "svalich_road", "summary": "",
		"map": {"rows": _walled(26, 20), "outdoors": true, "theme": "wilderness"}, "spawns": {"default": [12, 12]}, "rest": "risky"}
	tables[HALL] = {"id": HALL, "name": "Test Hall", "region": "svalich_road", "summary": "",
		"map": {"rows": ["#######", "#.....#", "#.....#", "#######"]}, "spawns": {"default": [2, 1]}, "rest": "safe"}
	# A path three squares wide between walls: no 4 x 4 plot anywhere.
	var lane_rows: Array = []
	for z in 12:
		lane_rows.append("#" + ".".repeat(28) + "#" if z in [4, 5, 6] else "#".repeat(30))
	tables[LANE] = {"id": LANE, "name": "Test Lane", "region": "svalich_road", "summary": "",
		"map": {"rows": lane_rows, "outdoors": true, "theme": "wilderness"}, "spawns": {"default": [14, 5]}, "rest": "risky"}
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.party[0].add_item(FortressSite.ITEM)
	assert_true(GameState.story.party[0].attune(FortressSite.ITEM), "the 2024 item asks for attunement")
	GameState.story.location = FIELD


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
		await _frames(3)
	var tables := Compendium.shared().tables["locations"] as Dictionary
	for id: String in [FIELD, HALL, LANE]:
		tables.erase(id)


## Rows of an open field `w` x `d` squares inside a wall.
static func _walled(w: int, d: int) -> Array:
	var rows: Array = []
	for z in d:
		rows.append("#".repeat(w) if z == 0 or z == d - 1 else "#" + ".".repeat(w - 2) + "#")
	return rows


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The game on `loc_id`.
func _game(loc_id: String = FIELD) -> LocationView:
	GameState.story.location = loc_id
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return root.get("view") as LocationView


## Uses the item's power for the leader as the inventory does, and lets the world dress the result.
func _use(power: String) -> Dictionary:
	var st := GameState.story
	var opts := {}
	var view := root.get("view") as LocationView
	if power == "fortress" and view != null:
		opts["plot"] = LocationFortress.plot_in(view)
	var res := FieldItems.use(st, st.party[0], FortressSite.ITEM, power, st.party[0], Dice.roller, opts)
	if bool(res.get("ok", false)) and view != null:
		view.apply_spell_effect(str(res["effect"]))
	await _frames(2)
	return res


static func _cell(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


func test_the_item_is_the_2024_one() -> void:
	var data := Compendium.shared().item_data(FortressSite.ITEM)
	assert_eq(bool((data["magic"] as Dictionary)["attunement"]), true, "the 2024 text asks for attunement")
	assert_true(str(data["text"]).contains("adamantine"), "an adamantine statuette and tower")
	assert_false(str(data["text"]).contains("Dexterity"), "the older cube's Dexterity save is gone")
	var ids: Array = (data["powers"] as Array).map(func(p: Variant) -> String: return str((p as Dictionary)["id"]))
	assert_eq(ids, ["fortress", "fold"], "a power to raise it and one to fold it")
	GameState.story.party[0].attuned.clear()
	var res := FieldItems.use(GameState.story, GameState.story.party[0], FortressSite.ITEM, "fortress", GameState.story.party[0], Dice.roller, {})
	assert_false(bool(res.get("ok", false)), "unattuned it does nothing: %s" % res.get("text", ""))


func test_using_the_item_raises_an_enterable_tower() -> void:
	var view := await _game()
	var lead := view.leader().cell
	var res := await _use("fortress")
	assert_true(bool(res.get("ok", false)), str(res.get("text", "")))
	assert_true(FortressSite.standing(GameState.story), "the fortress stands")
	var fs := FortressSite.state(GameState.story)
	assert_eq(str(fs["at"]), FIELD, "on this map")
	var origin := _cell(fs["cell"])
	var plot := FortressSite.footprint(origin)
	assert_eq(plot.size(), 16, "20 ft each way is 4 x 4 squares")
	var rows := (view.loc["map"] as Dictionary)["rows"] as Array
	for c in plot:
		assert_true(view.grid.has_flag(c, CombatGrid.WALL), "a solid wall at %s" % c)
		assert_eq(str(rows[c.y])[c.x], "#", "and the map shows it at %s" % c)
		assert_ne(c, lead, "not on the leader")
		assert_false(view.members.any(func(m: Combatant) -> bool: return m.cell == c), "nor on anyone else: %s" % c)
	var door := _cell(fs["door"])
	var front := _cell(fs["front"])
	assert_true(door in plot, "the door is in the tower's wall")
	assert_false(front in plot, "and its front is outside it")
	assert_false(view.grid.has_flag(front, CombatGrid.WALL), "open ground in front of the door")
	assert_eq(Vector2(door).distance_to(Vector2(front)), 1.0, "a step from the door")
	assert_true(maxi(absi(front.x - lead.x), absi(front.y - lead.y)) <= FortressSite.REACH + 1, "near where the party stands")
	assert_eq(str(fs["looks"]), "south", "the door looks at the opening camera when it can")
	var exits := (view.loc["exits"] as Array).filter(func(e: Variant) -> bool: return str((e as Dictionary)["id"]) == FortressSite.ENTRY)
	assert_eq(exits.size(), 1, "one door")
	assert_eq(str((exits[0] as Dictionary)["to"]), FortressSite.GROUND, "into the ground floor")
	assert_true(view.exit_nodes.has(FortressSite.ENTRY), "and the tower is drawn")
	var tower := view.exit_nodes[FortressSite.ENTRY] as Node3D
	assert_true(tower.find_children("*", "MeshInstance3D", true, false).size() > 40, "with its slits, battlement and door")
	# Walking to the door goes in.
	var entered: Array[String] = []
	view.exit_requested.connect(func(to: String, _sp: String) -> void: entered.append(to))
	view.walk_to(door)
	for i in 600:
		await get_tree().process_frame
		if not entered.is_empty():
			break
	assert_eq(entered, [FortressSite.GROUND], "the door leads into the tower")


func test_the_tower_survives_a_save_and_a_fresh_view() -> void:
	var view := await _game()
	await _use("fortress")
	var fs := FortressSite.state(GameState.story)
	var door := _cell(fs["door"])
	var saved := JSON.parse_string(JSON.stringify(GameState.story.to_dict())) as Dictionary
	var back := StoryState.from_dict(saved)
	assert_true(FortressSite.standing(back), "the fortress is in the save")
	assert_eq(_cell(FortressSite.state(back)["door"]), door, "on the same squares")
	view.queue_free()
	await _frames(2)
	var again := LocationView.create(FIELD, back, Narrator.new(), Dice.roller, "default")
	add_child(again)
	assert_true(again.grid.has_flag(door, CombatGrid.WALL), "built again with the tower on the same squares")
	assert_true(again.exit_nodes.has(FortressSite.ENTRY), "and its door")
	# A save made inside loads into the tower's own map.
	back.location = FortressSite.UPPER
	var inside := LocationView.create(FortressSite.UPPER, back, Narrator.new(), Dice.roller, "")
	add_child(inside)
	assert_eq(inside.members.size(), 4, "the party is upstairs")
	inside.queue_free()
	again.queue_free()


func test_the_interior_is_three_maps_that_lead_out_to_the_tower() -> void:
	await _game()
	await _use("fortress")
	var fs := FortressSite.state(GameState.story)
	for id: String in FortressSite.INTERIORS:
		var v := LocationView.create(id, GameState.story, Narrator.new(), Dice.roller, "default")
		add_child(v)
		assert_eq(v.members.size(), 4, "%s: the party arrives" % id)
		v.queue_free()
	var ground := LocationView.create(FortressSite.GROUND, GameState.story, Narrator.new(), Dice.roller, "default")
	var out := (ground.loc["exits"] as Array).filter(func(e: Variant) -> bool: return str((e as Dictionary)["id"]) == FortressSite.OUT)
	assert_eq(str((out[0] as Dictionary)["to"]), FIELD, "the door leads back to the field")
	assert_eq(str((out[0] as Dictionary)["spawn"]), FortressSite.FRONT, "to the square in front of the tower's door")
	ground.free()
	var field := LocationView.create(FIELD, GameState.story, Narrator.new(), Dice.roller, FortressSite.FRONT)
	add_child(field)
	var front := _cell(fs["front"])
	assert_true(field.members.any(func(m: Combatant) -> bool: return m.cell == front), "the leader steps out onto the square in front of the door")
	for m in field.members:
		assert_false(field.grid.has_flag(m.cell, CombatGrid.WALL), "nobody stands in the tower's wall")
	field.queue_free()
	# The stair and the trapdoor join the floors both ways.
	var up := Compendium.shared().get_entry("locations", FortressSite.UPPER)
	var targets := (up["exits"] as Array).map(func(e: Variant) -> String: return str((e as Dictionary)["to"]))
	assert_true(FortressSite.GROUND in targets and FortressSite.ROOF in targets, "stairs down and a trapdoor up: %s" % [targets])


func test_it_folds_only_when_nobody_is_inside_and_from_the_same_map() -> void:
	var view := await _game()
	var st := GameState.story
	assert_ne(FortressSite.why_not_fold(st), "", "nothing to fold yet")
	await _use("fortress")
	var plot := FortressSite.footprint(_cell(FortressSite.state(st)["cell"]))
	assert_eq(FortressSite.why_not_fold(st), "", "standing, outside, on the same map")
	assert_ne(FortressSite.why_not_raise(st), "", "one at a time")
	var opt := FieldItems.options(st.party, st.party[0], FortressSite.ITEM, Dice.roller, st)
	assert_eq(opt.map(func(o: Dictionary) -> bool: return bool(o["legal"])), [false, true], "the card offers the fold, not a second tower")
	st.location = FortressSite.UPPER
	assert_ne(FortressSite.why_not_fold(st), "", "not with the party inside")
	var refused := FieldItems.use(st, st.party[0], FortressSite.ITEM, "fold", st.party[0], Dice.roller, {})
	assert_false(bool(refused.get("ok", false)), "the use is refused too: %s" % refused.get("text", ""))
	assert_true(FortressSite.standing(st), "and it still stands")
	st.location = HALL
	assert_ne(FortressSite.why_not_fold(st), "", "not out of earshot")
	st.location = FIELD
	var fold := await _use("fold")
	assert_true(bool(fold.get("ok", false)), str(fold.get("text", "")))
	assert_false(FortressSite.standing(st), "folded away")
	var rows := (view.loc["map"] as Dictionary)["rows"] as Array
	for c in plot:
		assert_false(view.grid.has_flag(c, CombatGrid.WALL), "open again at %s" % c)
		assert_eq(str(rows[c.y])[c.x], ".", "and the map says so at %s" % c)
	assert_false((view.loc["exits"] as Array).any(func(e: Variant) -> bool: return str((e as Dictionary)["id"]) == FortressSite.ENTRY), "no door left")
	assert_false(view.exit_nodes.has(FortressSite.ENTRY), "and no tower")
	var again := await _use("fortress")
	assert_true(bool(again.get("ok", false)), "and it can be raised again: %s" % again.get("text", ""))


func test_it_wants_open_air_and_room() -> void:
	await _game(HALL)
	var res := await _use("fortress")
	assert_false(bool(res.get("ok", false)), "not under a roof: %s" % res.get("text", ""))
	assert_false(FortressSite.standing(GameState.story))
	root.queue_free()
	await _frames(3)
	await _game(LANE)
	var narrow := await _use("fortress")
	assert_false(bool(narrow.get("ok", false)), "not in a lane three squares wide: %s" % narrow.get("text", ""))
	assert_eq(str(narrow.get("text", "")), FortressSite.NO_ROOM)
	assert_false(FortressSite.standing(GameState.story))


func test_a_tower_never_cuts_the_map_in_two() -> void:
	# A field split by a wall with a gap five squares tall: a plot filling the gap would cut the far half off.
	var rows := _walled(30, 14)
	for z in range(1, 13):
		if z < 4 or z > 8:
			var r := str(rows[z])
			rows[z] = r.substr(0, 14) + "#" + r.substr(15)
	var loc := {"id": "test_cross", "map": {"rows": rows, "outdoors": true, "theme": "wilderness"}, "spawns": {"default": [3, 6]}}
	var grid := LocationView.grid_for(loc)
	var leader := Vector2i(12, 6)
	var plot := FortressSite.plan(loc, grid, leader, [leader])
	assert_false(plot.is_empty(), "there is room on the near side")
	for c in FortressSite.footprint(_cell(plot["cell"])):
		grid.set_flag(c, CombatGrid.WALL, true)
	var reach := grid.reachable(leader, 1, 99999, func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false,
		func(_c: Vector2i) -> bool: return false)
	assert_true(reach.has(Vector2i(20, 6)), "the far side is still reachable through the gap")


func test_a_tower_stands_on_gentle_slopes_but_not_steep_ones() -> void:
	var rows := _walled(30, 18)
	var steep: Array = []
	var gentle: Array = []
	for z in 18:
		steep.append(str(z % 10).repeat(30))   # a step up every row: four rows are 15 ft apart
		gentle.append(str(z / 2).repeat(30))   # a step every second row: at most 10 ft across the plot
	var leader := Vector2i(15, 9)
	var hill := {"id": "test_steep", "map": {"rows": rows, "elevation": steep, "outdoors": true, "theme": "wilderness"}, "spawns": {"default": [15, 9]}}
	assert_true(FortressSite.plan(hill, LocationView.grid_for(hill), leader, [leader]).is_empty(), "no tower on a steep hillside")
	var rise := {"id": "test_gentle", "map": {"rows": rows, "elevation": gentle, "outdoors": true, "theme": "wilderness"}, "spawns": {"default": [15, 9]}}
	var grid := LocationView.grid_for(rise)
	var plot := FortressSite.plan(rise, grid, leader, [leader])
	assert_false(plot.is_empty(), "but one on a gentle rise")
	var door := _cell(plot["door"])
	var front := _cell(plot["front"])
	assert_true(absi(grid.height(door) - grid.height(front)) <= CombatGrid.FEET, "its door a step from the ground in front of it")
	var tower := FortressTower.build(Vector3(15, 2, 9), "south", 2.0)
	assert_true(tower.get_node("Structure").get_node_or_null("Footing") != null, "on a footing that reaches down the slope")
	tower.free()


func test_resting_inside_is_safe_and_the_rules_hold() -> void:
	await _game()
	await _use("fortress")
	var upper := Compendium.shared().get_entry("locations", FortressSite.UPPER)
	assert_eq(str(upper["rest"]), "safe", "a Long Rest on the sleeping floor is never interrupted")
	assert_false(CampSite.makes_camp(upper), "so it is the plain rest screen, not a camp")
	assert_eq(str(Compendium.shared().get_entry("locations", FortressSite.GROUND)["rest"]), "safe")
	assert_eq(str(Compendium.shared().get_entry("locations", FortressSite.ROOF)["rest"]), "no", "the open roof is no place to sleep")
	var st := GameState.story
	st.location = FortressSite.UPPER
	assert_eq(RestRules.building_of(FortressSite.UPPER).size(), 3, "one building of three maps")
	assert_true(RestRules.waiting_fights(st, FortressSite.UPPER).is_empty(), "with nothing in it to wake the party")
	st.flags.erase(RestRules.DONE_AT)
	var res := LongRest.take(st, "safe", Dice.roller)
	assert_true(str(res["how"]) in [LongRest.SLEPT, LongRest.STRAHD], "slept, or Strahd's visit: %s" % res["how"])
	# The 16 hours since the last Long Rest still stand.
	RestRules.note_long_rest(st)
	assert_ne(RestRules.item_rest_refusal(st), "", "a second rest has to wait")
