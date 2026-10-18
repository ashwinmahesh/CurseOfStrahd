extends TestCase
## The Tsolenka gate's wards (dungeon expansion P1): the curtain of green fire behind the raised portcullis, a trap the party
## can put out with Arcana or Dispel Magic or walk into, with the two stone demons and the standing stones at the bridge's ends that went in beside it.
## Nothing that was walkable, a spawn, an exit or a prop on the pass moved (the plan's rule 2). The tower's upper floors are
## test_tsolenka_tower_top.gd.


const PASS := "tsolenka_pass"


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _rows(id: String) -> Array:
	return (_loc(id)["map"] as Dictionary)["rows"] as Array


func _open(id: String, cell: Array) -> bool:
	return str(_rows(id)[int(cell[1])])[int(cell[0])] != "#"


## A data cell ([x, y], read back as floats) as a square.


func _xy(cell: Variant) -> Vector2i:
	return Vector2i(int((cell as Array)[0]), int((cell as Array)[1]))


func _cells_of(entries: Array, key: String = "cell") -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e: Variant in entries:
		out.append(_xy((e as Dictionary)[key]))
	return out


func _prop(id: String, prop_id: String) -> Dictionary:
	for p: Variant in _loc(id)["props"]:
		if str((p as Dictionary)["id"]) == prop_id:
			return p as Dictionary
	return {}


func _party(level: int = 9, who: Array[String] = ["hedda_ironvow"]) -> StoryState:
	var st := SideQuestPlay.party(who, level, PASS, 12)
	st.set_flag("tsolenka_gate_open")
	return st


# --- Extend, never redraw ------------------------------------------------------------------------------


func test_the_passes_gate_and_squares_are_as_they_were() -> void:
	var map := _loc(PASS)["map"] as Dictionary
	assert_eq((map["rows"] as Array).size(), 34)
	for y: int in range(0, 8):
		assert_eq(str((map["rows"] as Array)[y]).substr(24, 12), "######..####", "the gate passage, row %d" % y)
	var doors := _cells_of(_loc(PASS)["doors"] as Array)
	assert_true(Vector2i(30, 7) in doors and Vector2i(31, 7) in doors, "the portcullis squares stay")
	var spawns := _loc(PASS)["spawns"] as Dictionary
	assert_eq(_xy(spawns["from_tower"]), Vector2i(26, 8))
	assert_eq(_xy(spawns["from_temple"]), Vector2i(30, 1))


# --- The curtain of green fire -------------------------------------------------------------------------


func test_the_curtain_fills_the_passage_behind_the_gate() -> void:
	var trap := {}
	for t: Variant in _loc(PASS)["traps"]:
		if str((t as Dictionary)["id"]) == "tsolenka_green_fire":
			trap = t as Dictionary
	assert_false(trap.is_empty(), "the trap is in the pass")
	var squares: Array = (trap["cells"] as Array).map(_xy)
	assert_eq(squares, [Vector2i(30, 6), Vector2i(31, 6)], "across the whole passage, one square behind the portcullis")
	for c: Variant in trap["cells"]:
		assert_true(_open(PASS, c as Array), "on open ground")
	assert_eq(str(trap["damage_type"]), "fire")
	assert_eq((trap["save"] as Dictionary)["ability"], "dex")
	assert_true(int(trap["detect_dc"]) >= 40, "a curtain, not a hidden trap: a Search never finds it, the pieces show it")


func test_the_curtain_stands_once_the_gate_is_up_and_until_it_is_out() -> void:
	var when := str(_prop(PASS, "tsolenka_green_fire_w")["when"])
	var st := SideQuestPlay.party(["hedda_ironvow"], 9, PASS, 12)
	assert_false(StoryConditions.check(when, st), "the portcullis is down: nothing behind it yet")
	st.set_flag("tsolenka_gate_open")
	assert_true(StoryConditions.check(when, st), "the gate is up: the curtain stands")
	st.set_flag("tsolenka_green_fire_out")
	assert_false(StoryConditions.check(when, st), "and goes when it is out")
	for t: Variant in _loc(PASS)["traps"]:
		if str((t as Dictionary)["id"]) == "tsolenka_green_fire":
			assert_eq(str((t as Dictionary)["when"]), when, "the trap follows the same condition")


func test_dispel_magic_puts_the_curtain_out_without_a_roll() -> void:
	var st := _party()
	assert_true(st.party[0].knows_spell("dispel_magic"), "Hedda has it prepared at 9")
	var beats := SideQuestPlay.play(st, "tsolenka_pass/events:green_fire", ["Cast Dispel Magic"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("tsolenka_green_fire_out", false)), "the fire is out")
	assert_true(SideQuestPlay.text(beats).contains("goes out without smoke"))


func test_arcana_unpicks_it_and_a_failure_closes_that_way_only() -> void:
	var out_somewhere := false
	var shut_somewhere := false
	for seed_value: int in range(1, 40):
		var st := _party(9, ["thistle"])
		var beats := SideQuestPlay.play(st, "tsolenka_pass/events:green_fire", ["Study the weave"], seed_value)
		assert_eq(SideQuestPlay.missing(beats), "")
		if bool(st.get_flag("tsolenka_green_fire_out", false)):
			out_somewhere = true
		else:
			shut_somewhere = true
			assert_true(bool(st.get_flag("tsolenka_fire_unpick_tried", false)), "a failure spends the try")
			var again := SideQuestPlay.play(st, "tsolenka_pass/events:green_fire", ["Study the weave"])
			assert_true(SideQuestPlay.missing(again).contains("Study the weave"), "and the Arcana option is gone")
			var back := SideQuestPlay.play(st, "tsolenka_pass/events:green_fire", ["Step back"])
			assert_eq(SideQuestPlay.missing(back), "", "but there is always a way out")
		if out_somewhere and shut_somewhere:
			break
	assert_true(out_somewhere, "some roll unpicks it")
	assert_true(shut_somewhere, "and some roll doesn't")


func test_a_party_with_neither_can_still_leave_or_walk_in() -> void:
	var st := _party(9, ["godrick_pendlebrook"])
	var beats := SideQuestPlay.play(st, "tsolenka_pass/events:green_fire", ["Step back"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_false(bool(st.get_flag("tsolenka_green_fire_out", false)), "the curtain stands: walking into it is the way")


# --- The stone demons ----------------------------------------------------------------------------------

func _vrocks(level: int, fate: String, gate_up: bool = true) -> Dictionary:
	var st := SideQuestPlay.party(["hedda_ironvow"], level, PASS, 12)
	if gate_up:
		st.set_flag("tsolenka_gate_open")
	if fate != "":
		st.set_flag("tsolenka_watch_fate", fate)
	return SideQuestPlay.encounter(st, PASS, "tsolenka_vrocks")


func test_the_stone_demons_wake_only_for_a_party_that_forced_the_gate_past_the_watch() -> void:
	for fate: String in ["", "passed", "released"]:
		assert_true(_vrocks(9, fate).is_empty(), "no wake for a watch that %s" % ("was never met" if fate == "" else fate))
	assert_true(_vrocks(9, "fought", false).is_empty(), "the watch fought but the gate still down: not yet")
	assert_false(_vrocks(9, "fought").is_empty(), "the watch fought and the gate up: they come down")


func test_the_stone_demons_are_tuned_by_level_and_wake_at_the_gate() -> void:
	for pair: Array in [[7, 200], [8, 280], [9, 380], [10, 420], [11, 420]]:
		var enc := _vrocks(int(pair[0]), "fought")
		var hps: Array = (enc["monsters"] as Array).map(func(m: Variant) -> int: return int((m as Dictionary)["hp"]))
		assert_eq(hps, [int(pair[1]), int(pair[1])], "two vrocks at level %d" % int(pair[0]))
		assert_eq(str(enc["trigger"]), "enter_area:tsolenka_gate_road")
		for m: Variant in enc["monsters"]:
			assert_eq(str((m as Dictionary)["monster"]), "vrock")
			assert_true(_open(PASS, (m as Dictionary)["cell"] as Array), "a vrock starts on open ground")


func test_the_statues_are_gone_once_the_demons_have_woken() -> void:
	var when := str(_prop(PASS, "tsolenka_vrock_w")["when"])
	var st := SideQuestPlay.party(["hedda_ironvow"], 9, PASS, 12)
	assert_true(StoryConditions.check(when, st), "stone until they wake")
	st.set_flag("tsolenka_vrocks_woke")
	assert_false(StoryConditions.check(when, st), "and an empty wall after")
	assert_eq(str(_prop(PASS, "tsolenka_vrock_e")["when"]), when, "both statues go together")


## The 2025 Monster Manual's Vrock (read twice on 2026-10-18; data/monsters/vrock.json's source note says what isn't built).
func test_the_vrock_block_is_the_2025_one() -> void:
	var v := Compendium.shared().get_entry("monsters", "vrock")
	assert_eq(int(v["ac"]), 15)
	assert_eq(int((v["hp"] as Dictionary)["average"]), 152)
	assert_eq(str((v["hp"] as Dictionary)["dice"]), "16d10+64")
	assert_eq(int(v["cr"]), 6)
	assert_eq(int(v["xp"]), 2300)
	assert_eq(str(v["size"]), "large")
	assert_eq(int((v["speed"] as Dictionary)["fly"]), 60)
	var shred := {}
	var spores := {}
	var screech := {}
	for a: Variant in v["actions"]:
		match str((a as Dictionary)["id"]):
			"shred":
				shred = a as Dictionary
			"spores":
				spores = a as Dictionary
			"stunning_screech":
				screech = a as Dictionary
	assert_eq(int((shred["attack"] as Dictionary)["bonus"]), 6, "Shred hits at +6")
	assert_eq((shred["damage"] as Array).map(func(d: Variant) -> String: return str((d as Dictionary)["dice"])), ["2d6+3", "3d6"], "2d6+3 piercing plus 3d6 poison")
	assert_eq(int((spores["save"] as Dictionary)["dc"]), 15)
	assert_eq(str(spores["recharge"]), "6", "Spores recharge on a 6")
	assert_eq(int((screech["uses"] as Dictionary)["count"]), 1, "Stunning Screech once a day")
	assert_eq(str(((screech["damage"] as Array)[0] as Dictionary)["dice"]), "3d6")


func test_the_wake_fires_as_the_party_steps_out_of_the_tower() -> void:
	var enc := _vrocks(9, "fought")
	var area_id := str(enc["trigger"]).get_slice(":", 1)
	var area := {}
	for a: Variant in _loc(PASS)["areas"]:
		if str((a as Dictionary)["id"]) == area_id:
			area = a as Dictionary
	assert_false(area.is_empty(), "the trigger names an area the pass has")
	var lo := _xy((area["cells"] as Array)[0])
	var hi := _xy((area["cells"] as Array)[1])
	var out := _xy((_loc(PASS)["spawns"] as Dictionary)["from_tower"])
	assert_true(out.x >= lo.x and out.x <= hi.x and out.y >= lo.y and out.y <= hi.y, "the tower door lets out inside that area")
	for m: Variant in enc["monsters"]:
		var at := _xy((m as Dictionary)["cell"])
		assert_true(at.x >= lo.x - 1 and at.x <= hi.x + 1 and at.y >= lo.y and at.y <= hi.y, "and the demons come down in front of the gate")

