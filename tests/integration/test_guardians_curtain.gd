extends TestCase
## The guardians' curtain before the royal tomb (Dungeon Expansion Plan C11, the book's K87): two bronze knights flank a
## curtain of blue light halfway down the stair hall. A party with no dark gift walks through and it asks nothing; a party
## carrying one is turned back to the top of the stair, once, and after that the light won't let it down. Coming up from
## the royal tomb (in by the overlook's window) it lets anyone through, and stays open to them.

const TOMBS := "castle_ravenloft_catacombs_tombs"
const WARD := Vector2i(16, 13)


func before_each() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)


func _view() -> LocationView:
	var v := LocationView.create(TOMBS, GameState.story, null, Dice.roller, "default")
	add_child(v)
	return v


## Every beat of a dialogue node played straight through.
func _play(ref: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(GameState.story, DiceRoller.new(3))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	for i in 20:
		out.append(b)
		if str(b["kind"]) == "end":
			break
		b = r.next()
	return out


func _calls(v: LocationView, at: Vector2i) -> Array[String]:
	var asked: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: asked.append(ref))
	v.leader().cell = at
	LocationNpcs._check_calls(v)
	return asked


## The hall as the book has it: the knights' squares and the walls beside them close the hall but for the ward's
## square, the curtain's light stands there, and the old guardians' fight is gone.
func test_the_hall_holds_two_knights_and_the_curtain() -> void:
	var loc := Compendium.shared().get_entry("locations", TOMBS) as Dictionary
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	assert_eq(str(rows[13]).substr(14, 5), "##.##", "the knights and the walls close the hall but for the ward")
	var knights := (loc["props"] as Array).filter(func(p: Variant) -> bool: return str((p as Dictionary)["id"]).begins_with("cat_bronze_knight"))
	assert_eq(knights.size(), 2, "two bronze knights")
	var ward := (loc["doors"] as Array).filter(func(d: Variant) -> bool: return str((d as Dictionary)["id"]) == "cat_curtain_ward")
	assert_eq(ward.size(), 1, "the curtain's ward is a door on its square")
	assert_true((loc["encounters"] as Array).all(func(e: Variant) -> bool: return str((e as Dictionary)["id"]) != "cat_guardians"),
		"no guardians' fight any more")
	var v := _view()
	await get_tree().process_frame
	var node := v.prop_nodes.get("cat_light_curtain") as Node3D
	assert_true(node != null and node.find_child("LightCurtain", true, false) is MeshInstance3D, "the light is drawn")
	assert_true(v.grid.has_flag(WARD, CombatGrid.WALL), "the ward blocks while it is shut")
	v.queue_free()


## No dark gift: the call from above lets the party by, and the ward opens.
func test_a_party_with_no_gift_walks_through() -> void:
	var v := _view()
	await get_tree().process_frame
	assert_eq(_calls(v, Vector2i(16, 11)), ["castle_ravenloft/guardians_curtain:above"] as Array[String], "the curtain calls")
	var beats := _play("castle_ravenloft/guardians_curtain:above")
	assert_true(beats.all(func(b: Dictionary) -> bool: return str(b.get("move", "")) == ""), "nobody is moved")
	assert_true(bool(GameState.story.get_flag("cat_curtain_passed_down", false)), "passed down")
	assert_true(LocationLocks._openable_doors(v).has(WARD), "the ward opens")
	v.leader().cell = Vector2i(16, 15)
	assert_false(LocationNpcs._check_calls(v), "no call from below on the way down")
	v.queue_free()


## A dark gift among the party: turned back to the top of the stair once, and the ward won't open after.
func test_a_party_with_a_gift_is_turned_back() -> void:
	GameState.story.set_flag("dark_gifts_taken", 1)
	var v := _view()
	await get_tree().process_frame
	assert_eq(_calls(v, Vector2i(16, 11)), ["castle_ravenloft/guardians_curtain:above"] as Array[String], "the curtain calls")
	var beats := _play("castle_ravenloft/guardians_curtain:above")
	var moved := beats.filter(func(b: Dictionary) -> bool: return str(b.get("move", "")) != "")
	assert_eq(moved.size(), 1, "moved once")
	if not moved.is_empty():
		var to := moved[0]["move"] as Dictionary
		assert_eq(str(to.get("location", "")), TOMBS, "to the tombs' stair")
		assert_eq(str(to.get("spawn", "")), "from_catacombs", "at its top")
	assert_false(LocationLocks._openable_doors(v).has(WARD), "the ward won't open")
	var door := ((Compendium.shared().get_entry("locations", TOMBS) as Dictionary)["doors"] as Array).filter(
		func(d: Variant) -> bool: return str((d as Dictionary)["id"]) == "cat_curtain_ward")[0] as Dictionary
	var said: Array[String] = []
	v.narration.connect(func(t: String) -> void: said.append(t))
	LocationLocks._use_door(v, door)
	assert_eq(said, [str(door["locked_text"])] as Array[String], "the light says why")
	v.queue_free()


## In by the window and up from the royal tomb: the curtain lets the party by, gift or not, and stays open to it.
func test_coming_up_from_the_tomb_it_lets_anyone_by() -> void:
	GameState.story.set_flag("dark_gifts_taken", 1)
	var v := _view()
	await get_tree().process_frame
	assert_eq(_calls(v, Vector2i(16, 15)), ["castle_ravenloft/guardians_curtain:below"] as Array[String], "the curtain calls from below")
	_play("castle_ravenloft/guardians_curtain:below")
	assert_true(bool(GameState.story.get_flag("cat_curtain_from_below", false)), "came up through it")
	assert_true(LocationLocks._openable_doors(v).has(WARD), "the ward opens to them")
	v.queue_free()
