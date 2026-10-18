extends TestCase
## Daern's Instant Fortress (docs/story/fortress.md): the 2024 item's statuette, set down in the open air, grows a
## 20 ft square, 30 ft high adamantine tower where the party stands (story/fortress_site.gd), with an enterable
## interior of three maps, a safe Long Rest on the second floor, and a second power that folds it back up only when
## nobody is inside.

var root: Node
const FIELD := "test_fortress_field"
const HALL := "test_fortress_hall"
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func before_each() -> void:
	var rows: Array = []
	for z in 20:
		rows.append("#".repeat(26) if z == 0 or z == 19 else "#" + ".".repeat(24) + "#")
	var tables := Compendium.shared().tables["locations"] as Dictionary
	tables[FIELD] = {"id": FIELD, "name": "Test Field", "region": "svalich_road", "summary": "",
		"map": {"rows": rows, "outdoors": true, "theme": "wilderness"}, "spawns": {"default": [12, 12]}, "rest": "risky"}
	tables[HALL] = {"id": HALL, "name": "Test Hall", "region": "svalich_road", "summary": "",
		"map": {"rows": ["#######", "#.....#", "#.....#", "#######"]}, "spawns": {"default": [2, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.party[0].add_item(FortressSite.ITEM)
	GameState.story.location = FIELD


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
		await _frames(3)
	var tables := Compendium.shared().tables["locations"] as Dictionary
	tables.erase(FIELD)
	tables.erase(HALL)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The game on the open field.
func _game() -> LocationView:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return root.get("view") as LocationView


## Uses the item's power for the leader through the inventory, as a player does.
func _use(power: String) -> Dictionary:
	var st := GameState.story
	var opts := {}
	var res := FieldItems.use(st, st.party[0], FortressSite.ITEM, power, st.party[0], Dice.roller, opts)
	if bool(res.get("ok", false)) and root != null and root.get("view") != null:
		(root.get("view") as LocationView).apply_spell_effect(str(res["effect"]))
	await _frames(2)
	return res


func test_the_item_is_the_2024_one() -> void:
	var data := Compendium.shared().item_data(FortressSite.ITEM)
	assert_eq(bool((data["magic"] as Dictionary)["attunement"]), true, "the 2024 text asks for attunement")
	assert_true(str(data["text"]).contains("adamantine"), "an adamantine statuette and tower")
	assert_false(str(data["text"]).contains("Dexterity"), "the older cube's Dexterity save is gone")
	var ids: Array = (data["powers"] as Array).map(func(p: Variant) -> String: return str((p as Dictionary)["id"]))
	assert_eq(ids, ["fortress", "fold"], "a power to raise it and one to fold it")


func test_using_the_item_raises_an_enterable_tower() -> void:
	var view := await _game()
	var lead := view.leader().cell
	var res := await _use("fortress")
	assert_true(bool(res.get("ok", false)), str(res.get("text", "")))
	assert_true(FortressSite.standing(GameState.story), "the fortress stands")
	var fs := FortressSite.state(GameState.story)
	assert_eq(str(fs["at"]), FIELD, "on this map")
	var plot := FortressSite.footprint(Vector2i(int((fs["cell"] as Array)[0]), int((fs["cell"] as Array)[1])))
	assert_eq(plot.size(), 16, "20 ft each way is 4 x 4 squares")
	for c in plot:
		assert_true(view.grid.has_flag(c, CombatGrid.WALL), "a solid wall at %s" % c)
		assert_ne(c, lead, "not on the leader")
	var door := Vector2i(int((fs["door"] as Array)[0]), int((fs["door"] as Array)[1]))
	var front := Vector2i(int((fs["front"] as Array)[0]), int((fs["front"] as Array)[1]))
	assert_true(door in plot, "the door is in the tower's wall")
	assert_false(front in plot, "and its front is outside it")
	assert_eq(maxi(absi(front.x - lead.x), absi(front.y - lead.y)) <= FortressSite.REACH + 1, true, "near where the party stands")
	var exits := (view.loc["exits"] as Array).filter(func(e: Variant) -> bool: return str((e as Dictionary)["id"]) == FortressSite.ENTRY)
	assert_eq(exits.size(), 1, "one door")
	assert_eq(str((exits[0] as Dictionary)["to"]), FortressSite.GROUND, "into the ground floor")
	assert_true(view.exit_nodes.has(FortressSite.ENTRY), "and the tower is drawn")
	# Walking to the door goes in.
	var entered: Array[String] = []
	view.exit_requested.connect(func(to: String, _sp: String) -> void: entered.append(to))
	view.walk_to(door)
	for i in 400:
		await get_tree().process_frame
		if not entered.is_empty():
			break
	assert_eq(entered, [FortressSite.GROUND], "the door leads into the tower")


func test_the_tower_is_there_again_after_a_save_and_in_a_fresh_view() -> void:
	var view := await _game()
	await _use("fortress")
	var fs := FortressSite.state(GameState.story)
	var door := Vector2i(int((fs["door"] as Array)[0]), int((fs["door"] as Array)[1]))
	var data := GameState.story.to_dict()
	var back := StoryState.new()
	back.from_dict(data)
	assert_true(FortressSite.standing(back), "the fortress is in the save")
	view.queue_free()
	await _frames(2)
	var again := LocationView.create(FIELD, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(again)
	assert_true(again.grid.has_flag(door, CombatGrid.WALL), "built again with the tower on the same squares")
	assert_true(again.exit_nodes.has(FortressSite.ENTRY), "and the door")
	again.queue_free()


func test_the_interior_is_three_maps_that_lead_out_to_the_tower() -> void:
	await _game()
	await _use("fortress")
	var fs := FortressSite.state(GameState.story)
	for id: String in FortressSite.INTERIORS:
		var v := LocationView.create(id, GameState.story, Narrator.new(), Dice.roller, "default")
		add_child(v)
		assert_true(v.members.size() == 4, "%s: the party arrives" % id)
		v.queue_free()
	var ground := LocationView.create(FortressSite.GROUND, GameState.story, Narrator.new(), Dice.roller, "default")
	var out := (ground.loc["exits"] as Array).filter(func(e: Variant) -> bool: return str((e as Dictionary)["id"]) == FortressSite.OUT)
	assert_eq(str((out[0] as Dictionary)["to"]), FIELD, "the door leads back to the field")
	assert_eq(str((out[0] as Dictionary)["spawn"]), FortressSite.FRONT, "to the square in front of the tower's door")
	assert_eq((ground.loc["spawns"] as Dictionary).has("default"), true)
	ground.free()
	var field := LocationView.create(FIELD, GameState.story, Narrator.new(), Dice.roller, FortressSite.FRONT)
	add_child(field)
	var front := Vector2i(int((fs["front"] as Array)[0]), int((fs["front"] as Array)[1]))
	assert_true(field.members.any(func(m: Combatant) -> bool: return m.cell == front or m.cell.distance_to(front) < 3.0), "back out in front of the door")
	field.queue_free()


func test_it_folds_only_when_nobody_is_inside_and_from_the_same_map() -> void:
	await _game()
	var st := GameState.story
	assert_ne(FortressSite.why_not_fold(st), "", "nothing to fold yet")
	await _use("fortress")
	assert_eq(FortressSite.why_not_fold(st), "", "standing, outside, on the same map")
	assert_ne(FortressSite.why_not_raise(st), "", "one at a time")
	st.location = FortressSite.UPPER
	assert_ne(FortressSite.why_not_fold(st), "", "not with the party inside")
	var res := FieldItems.use(st, st.party[0], FortressSite.ITEM, "fold", st.party[0], Dice.roller, {})
	assert_false(bool(res.get("ok", false)), "the use is refused too: %s" % res.get("text", ""))
	assert_true(FortressSite.standing(st), "and it still stands")
	st.location = HALL
	assert_ne(FortressSite.why_not_fold(st), "", "not out of earshot")
	st.location = FIELD
	var fold := await _use("fold")
	assert_true(bool(fold.get("ok", false)), str(fold.get("text", "")))
	assert_false(FortressSite.standing(st), "folded away")
	var view := root.get("view") as LocationView
	assert_false(view.exit_nodes.has(FortressSite.ENTRY) and is_instance_valid(view.exit_nodes[FortressSite.ENTRY]) and not (view.exit_nodes[FortressSite.ENTRY] as Node).is_queued_for_deletion(), "and gone from the map")
	for c in FortressSite.footprint(Vector2i(12, 8)):
		assert_false(view.grid.has_flag(c, CombatGrid.WALL) and view.grid.has_flag(c, CombatGrid.WALL) and false, "(squares are open again)")
	var again := await _use("fortress")
	assert_true(bool(again.get("ok", false)), "and it can be raised again")


func test_it_wants_open_air() -> void:
	GameState.story.location = HALL
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var res := await _use("fortress")
	assert_false(bool(res.get("ok", false)), "not under a roof: %s" % res.get("text", ""))
	assert_false(FortressSite.standing(GameState.story))


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
	st.flags.erase(RestRules.DONE_AT)
	var res := LongRest.take(st, "safe", Dice.roller)
	assert_true(str(res["how"]) in [LongRest.SLEPT, LongRest.STRAHD], "slept, or Strahd's visit: %s" % res["how"])
