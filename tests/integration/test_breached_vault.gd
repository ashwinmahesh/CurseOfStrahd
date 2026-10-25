extends TestCase
## The breached vault off the Amber Temple's vault stair (Dungeon Expansion Plan T2, X33d; docs/regions/amber_temple.md §4.9):
## a side vault the wardens bricked up and someone broke into, with three more vestiges: Zrin-Hala, the howling storm, Delban,
## the star of ice and hate, and Vaund the evasive, whose block stands in a niche behind a hidden door. Each calls, talks,
## offers a dark gift of its own and can be refused; none changes the hollow's offer or the endings' reading of
## `dark_gifts_taken`.

const BREACH := "amber_temple_breached_vault"
const VAULT := "amber_temple_vault"
const FILE := "amber_temple/vestiges:"
const IDS: Array[String] = ["zrin_hala", "delban", "vaund"]


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _cell(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


func _find(loc_id: String, key: String, id: String) -> Dictionary:
	for t: Variant in _loc(loc_id)[key]:
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


## The squares reachable on foot (four ways, doors count as open) from `from`, not stepping on `blocked`.
func _reach(rows: Array, from: Vector2i, blocked: Dictionary = {}) -> Dictionary:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= str(rows[n.y]).length() or seen.has(n) or blocked.has(n):
				continue
			if str(rows[n.y])[n.x] in ["#", " ", "w"]:
				continue
			seen[n] = true
			todo.append(n)
	return seen


# --- The map and its joins ---------------------------------------------------------------------------------------------------

func test_the_breach_joins_the_vault_stair_to_the_new_vault_both_ways() -> void:
	var out := _find(VAULT, "exits", "vault_breach")
	var back := _find(BREACH, "exits", "breach_to_vault")
	assert_eq(str(out["to"]), BREACH)
	assert_eq(str(back["to"]), VAULT)
	for pair: Array in [[VAULT, out], [BREACH, back]]:
		var loc := _loc(str(pair[0]))
		var e := pair[1] as Dictionary
		var rows := (loc["map"] as Dictionary)["rows"] as Array
		var c := _cell(e["cell"])
		assert_eq(str(rows[c.y])[c.x], "#", "%s stands in a wall" % e["id"])
		var beside := false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.y >= 0 and n.y < rows.size() and n.x >= 0 and n.x < str(rows[n.y]).length() and str(rows[n.y])[n.x] == ".":
				beside = true
		assert_true(beside, "with open floor beside it")
		var dest := _loc(str(e["to"]))
		var spawn := _cell((dest["spawns"] as Dictionary)[str(e["spawn"])])
		assert_eq(str(((dest["map"] as Dictionary)["rows"] as Array)[spawn.y][spawn.x]), ".", "and it arrives on open floor")
		for word: String in ["stair", "up to", "down to"]:
			assert_false(word in (str(e["id"]) + " " + str(e["label"])).to_lower(), "%s's words don't promise a stair" % e["id"])


## Nothing of the old vault moved: the stair room's arrivals are where they were and nothing stands on the new one.
func test_the_old_vault_gained_one_exit_and_one_arrival_and_lost_nothing() -> void:
	var vault := _loc(VAULT)
	var spawns := vault["spawns"] as Dictionary
	assert_eq(_cell(spawns["default"]), Vector2i(4, 2))
	assert_eq(_cell(spawns["from_upper"]), Vector2i(4, 2))
	assert_eq(_cell(spawns["from_deep"]), Vector2i(35, 12))
	var at := _cell(spawns["from_breach"])
	for key: String in ["props", "containers", "npcs", "doors"]:
		for t: Variant in vault.get(key, []):
			assert_ne(_cell((t as Dictionary)["cell"]), at, "nothing stands on the breach's arrival")


## Two of the three blocks are in the open chamber; the third lies behind a hidden door and is reached only through it.
func test_vaunds_block_is_behind_a_hidden_door() -> void:
	var loc := _loc(BREACH)
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	var door := _find(BREACH, "doors", "breach_niche_door")
	assert_true(int(door["secret_dc"]) >= 15, "found only by a careful search")
	var start := _cell((loc["spawns"] as Dictionary)["from_vault"])
	var shut := _reach(rows, start, {_cell(door["cell"]): true})
	for id: String in ["sarc_zrin_hala", "sarc_delban"]:
		var c := _cell(_find(BREACH, "props", id)["cell"])
		var near := false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if shut.has(c + d):
				near = true
		assert_true(near, "%s can be walked up to without the hidden door" % id)
	var vaund := _cell(_find(BREACH, "props", "sarc_vaund")["cell"])
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		assert_false(shut.has(vaund + d), "Vaund's block can't be walked up to with the door shut")
	var open := _reach(rows, start)
	var near_open := false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if open.has(vaund + d):
			near_open = true
	assert_true(near_open, "and can once it is open")
	for y in rows.size():
		for x in str(rows[y]).length():
			if str(rows[y])[x] in [".", "~"]:
				assert_true(open.has(Vector2i(x, y)), "(%d, %d) can be walked to once the door is open" % [x, y])


func test_each_vestige_stands_on_a_low_square_and_calls_like_the_sixteen() -> void:
	for vid: String in IDS:
		var p := _find(BREACH, "props", "sarc_" + vid)
		var rows := (_loc(BREACH)["map"] as Dictionary)["rows"] as Array
		var c := _cell(p["cell"])
		assert_eq(str(rows[c.y])[c.x], "=", "%s stands on its '=' square" % vid)
		assert_eq(int(p["approach"]), 3)
		assert_eq(str(p["call"]), FILE + vid + "_call")
		assert_eq(str(p["dialogue"]), FILE + vid)
		var when := str(p["call_when"])
		assert_true("flag.amber_temple_sealed" in when and ("flag.vestige_%s_heard" % vid) in when and ("gift:gift_of_%s" % vid) in when,
			"%s calls only while the temple is open, unheard and its gift untaken" % vid)
		assert_true(AmberGlow.shapes().has(vid), "%s holds a shape in its block" % vid)


# --- The three gifts ---------------------------------------------------------------------------------------------------------

func _mods(gift: String, part: String) -> Array:
	return ((Compendium.shared().get_entry("dark_gifts", gift)[part] as Dictionary)["modifiers"]) as Array


func _has(mods: Array, want: Dictionary) -> bool:
	for m: Variant in mods:
		var ok := true
		for k: String in want:
			if str((m as Dictionary).get(k, "")) != str(want[k]):
				ok = false
		if ok:
			return true
	return false


func test_zrin_halas_gift_is_a_bolt_and_the_storms_resistance_for_a_wild_temper() -> void:
	assert_true(_has(_mods("gift_of_zrin_hala", "benefit"), {"stat": "resistance", "value": "lightning"}))
	assert_true(_has(_mods("gift_of_zrin_hala", "benefit"), {"stat": "resistance", "value": "thunder"}))
	assert_true(_has(_mods("gift_of_zrin_hala", "benefit"), {"stat": "spell", "value": "lightning_bolt"}), "Lightning Bolt")
	assert_true(_has(_mods("gift_of_zrin_hala", "cost"), {"stat": "disadvantage", "on": "check:stealth"}))
	assert_true(_has(_mods("gift_of_zrin_hala", "cost"), {"stat": "disadvantage", "on": "save:wis"}))


func test_delbans_gift_is_a_cone_of_cold_and_cold_resistance_for_a_weakness_to_fire() -> void:
	assert_true(_has(_mods("gift_of_delban", "benefit"), {"stat": "resistance", "value": "cold"}))
	assert_true(_has(_mods("gift_of_delban", "benefit"), {"stat": "spell", "value": "cone_of_cold"}), "Cone of Cold")
	assert_true(_has(_mods("gift_of_delban", "cost"), {"stat": "vulnerability", "value": "fire"}))
	assert_true(_has(_mods("gift_of_delban", "cost"), {"stat": "disadvantage", "on": "check:persuasion"}))


func test_vaunds_gift_is_a_step_and_quick_feet_for_a_thinner_hide_and_a_suspicious_eye() -> void:
	assert_true(_has(_mods("gift_of_vaund", "benefit"), {"stat": "advantage", "on": "save:dex"}))
	assert_true(_has(_mods("gift_of_vaund", "benefit"), {"stat": "spell", "value": "misty_step"}), "Misty Step")
	assert_true(_has(_mods("gift_of_vaund", "cost"), {"stat": "hp_max", "value": "-level"}))
	assert_true(_has(_mods("gift_of_vaund", "cost"), {"stat": "disadvantage", "on": "check:insight"}))


## Accepting plays through the conversation the way a player would: ask what is offered, accept, pick who takes it.
func _accept(st: StoryState, vid: String) -> void:
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	assert_true(r.start(FILE + vid), "starts " + vid)
	var picks: Array[String] = ["What are you offering", "I accept"]
	var b := r.next()
	for i in 60:
		match str(b["kind"]):
			"end":
				return
			"options":
				var opts := b["options"] as Array
				var want := picks.pop_front() as String if not picks.is_empty() else ""
				var idx := opts.size() - 1
				for j in opts.size():
					if want != "" and str((opts[j] as Dictionary)["text"]).contains(want):
						idx = j
						break
				b = r.choose(idx)
			"pick_member":
				b = r.pick_member(0)
			_:
				b = r.next()


func test_accepting_gives_the_gift_counts_it_and_changes_the_one_who_took_it() -> void:
	var st := SideQuestPlay.party(["hedda_ironvow", "silvain_aster"], 5, BREACH, 12)
	var hedda := st.party[0]
	var before := hedda.max_hp()
	_accept(st, "zrin_hala")
	assert_true("gift_of_zrin_hala" in hedda.dark_gifts(), "Hedda carries Zrin-Hala's gift")
	assert_true(hedda.resistance_source(&"lightning") != "" and hedda.resistance_source(&"thunder") != "", "and the storm runs off her")
	assert_eq(int(st.get_flag("dark_gifts_taken")), 1, "the hollow's count has it")
	assert_true(st.party[1].dark_gifts().is_empty(), "and Silvain carries nothing")
	_accept(st, "vaund")
	assert_true("gift_of_vaund" in hedda.dark_gifts())
	assert_eq(hedda.max_hp(), before - 5, "Vaund's price: one Hit Point a level")
	assert_eq(int(st.get_flag("dark_gifts_taken")), 2)
	assert_eq(StoryConditions.check("gift:gift_of_vaund", st), true, "and the gift: condition sees it")


## Refusing, or taking nobody, costs nothing and leaves the offer.
func test_refusing_or_taking_nobody_leaves_everything_as_it_was() -> void:
	for vid: String in IDS:
		var st := SideQuestPlay.party(["hedda_ironvow"], 5, BREACH, 12)
		var beats := SideQuestPlay.play(st, FILE + vid, ["What are you offering", "No."])
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(int(st.get_flag("dark_gifts_taken")), 0, "%s: nothing taken" % vid)
		assert_true(st.party[0].dark_gifts().is_empty(), "%s: nothing carried" % vid)


# --- The words ---------------------------------------------------------------------------------------------------------------

func test_each_vestige_has_its_whole_conversation_and_a_way_out_of_every_menu() -> void:
	var f := DialogueFile.load_key("amber_temple/vestiges")
	for vid: String in IDS:
		for node: String in [vid, vid + "_call", vid + "_menu", vid + "_want", vid + "_offer", vid + "_price", vid + "_lid", vid + "_lid_fail", vid + "_accept", vid + "_refuse"]:
			assert_true(f.nodes.has(node), "node %s exists" % node)
		var st := SideQuestPlay.party(["hedda_ironvow"], 5, BREACH, 12)
		var first := SideQuestPlay.play(st, FILE + vid, ["Step away"])
		assert_eq(SideQuestPlay.missing(first), "", "%s's menu can be left" % vid)
		assert_true(st.get_flag("vestige_%s_heard" % vid), "and it has been heard")
		var again := SideQuestPlay.play(st, FILE + vid, ["Step away"])
		assert_eq(SideQuestPlay.missing(again), "", "and again")
		var sealed := SideQuestPlay.party(["hedda_ironvow"], 5, BREACH, 12)
		sealed.set_flag("amber_temple_sealed")
		assert_true(SideQuestPlay.text(SideQuestPlay.play(sealed, FILE + vid)).contains("wardens' seal"), "%s says nothing once the temple is sealed" % vid)


func test_the_vaults_own_lines_exist() -> void:
	var n := Narrator.new(1)
	var st := SideQuestPlay.party(["hedda_ironvow"], 5, BREACH, 12)
	for key: String in ["enter:amber_temple_breached_vault", "examine:breach_bricks", "open:breach_niche_door"]:
		assert_true(n.line(key, st, null) != "", "the Narrator says something for %s" % key)
