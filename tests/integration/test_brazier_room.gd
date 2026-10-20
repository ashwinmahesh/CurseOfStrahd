extends TestCase
## The brazier room below the dungeon (Dungeon Expansion Plan C4, docs/regions/castle_ravenloft_larders.md §17): the low
## door in the dungeon hall, the western stair with its warding glyph and the wax image that melts at the first blow, the
## brazier room's seven stones that carry the party (by `move`) to places it has been, the iron knights that wake only if
## the brazier, the hourglass or a knight is attacked, the tunnel through the Pillarstone with its trapdoor and the marble
## chute to a north cell, and the way on to the catacombs. The knights' fight is tuned in test_scaled_boss_fights_brazier.

const ROOM := "castle_ravenloft_brazier_room"
const DUNGEON := "castle_ravenloft_larders_dungeon"
const CATA := "castle_ravenloft_catacombs"
const FILE := "castle_ravenloft/larders_brazier:"

## The two maps' rows as they were before the room: only the squares the plan carves may differ (rule 2).
const DUNGEON_ROWS: Array[String] = [
	"########################################",
	"#....#...............#.....#.....=.....#",
	"#....#...#...#...#...#.....#...........#",
	"#......................=...............#",
	"#....#...#...#...#...#.....#...........#",
	"#....#...............#.....#...........#",
	"####################..######...........#",
	"####################..######...........#",
	"####...#...#...#...#..#...##...........#",
	"####...#...#...#...#..#...####.#########",
	"####...#...#...#...#..#...####........##",
	"#####.###.###.###.##..##.############.##",
	"#......................................#",
	"#........................#.............#",
	"#..##.###.###.###.########.............#",
	"#..#...#...#...#...#######.............#",
	"#..#...#...#...#...#######.............#",
	"#..#...#...#...#...#######.............#",
	"#..#######################....=======.=#",
	"##.#######################.............#",
	"#..............#.........#.............#",
	"#..............#.........#.............#",
	"#....=...=........===....#.............#",
	"#..............#.......................#",
	"#..............#.........#.............#",
	"#..............#.........#.............#",
	"########################################"]

const CATACOMBS_ROWS: Array[String] = [
	"############################################",
	"###.####################################.###",
	"#..........................................#",
	"#..........................................#",
	"#..........................................#",
	"########..###########..###########..########",
	"#......#..#....#....#..#....#....#..#......#",
	"#...~..#..#....#....#..#....#....#..#......#",
	"#..............#............#.......#......#",
	"#......#..#....#....#..#....#....#.........#",
	"#......#..#....#....#..#....#....#..#......#",
	"#......#..###########..###########..#......#",
	"########..#.....#..........#.....#..#......#",
	"#......#..#.....#..#....#..#.....#..########",
	"#.........#.....#..........#........#......#",
	"#......#........#..........#........#......#",
	"#......#..#.....#..........#...............#",
	"########..#.....#..#....#..#.....#..#......#",
	"#......#..#.....#..........#.....#..#......#",
	"#......#..###########..###########..########",
	"#......#..#....#....#..#....#....#..#......#",
	"#.........#....#....#..#....#....#..#......#",
	"#......#............#.......#..............#",
	"#......#..#....#....#..#....#....#..#......#",
	"#......#..#....#....#..#....#....#..#......#",
	"########..###########..###########..########",
	"#........................................~.#",
	"#..............~...........................#",
	"#..........................................#",
	"#####.######################################",
	"############################################"]

## The stones: colour, the place it leads (a location id or id:spawn) and what the party must have done to be offered it.
const STONES := [
	["violet", "tsolenka_pass_guard_tower", ["visited:tsolenka_pass_guard_tower"]],
	["orange", "castle_ravenloft_spires_roofs", ["visited:castle_ravenloft_spires_roofs"]],
	["red", "van_richtens_tower_interior", ["visited:van_richtens_tower_interior"]],
	["green", "castle_ravenloft_catacombs:from_tunnel", ["visited:castle_ravenloft_catacombs"]],
	["indigo", "castle_ravenloft_court_weeping", ["visited:castle_ravenloft_court_weeping"]],
	["blue", "amber_temple_entrance", ["visited:amber_temple_entrance", "flag:tsolenka_gate_open"]],
	["yellow", "castle_ravenloft_catacombs_strahd", ["visited:castle_ravenloft_catacombs_strahd"]],
]

var root: Node


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _party(location: String = ROOM) -> StoryState:
	return SideQuestPlay.party(["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"], 10, location, 12)


## The party with everything the stones are gated on done.
func _travelled(location: String = ROOM) -> StoryState:
	var st := _party(location)
	for stone: Array in STONES:
		for need: String in stone[2]:
			if need.begins_with("visited:"):
				st.visited[need.substr(8)] = true
			else:
				st.set_flag(need.substr(5))
	return st


func _prop(loc_id: String, prop_id: String) -> Dictionary:
	for p: Variant in _loc(loc_id)["props"]:
		if str((p as Dictionary)["id"]) == prop_id:
			return p as Dictionary
	return {}


func _trap(loc_id: String, trap_id: String) -> Dictionary:
	for t: Variant in _loc(loc_id)["traps"]:
		if str((t as Dictionary)["id"]) == trap_id:
			return t as Dictionary
	return {}


func _enc(loc_id: String, id: String) -> Dictionary:
	for e: Variant in _loc(loc_id)["encounters"]:
		if str((e as Dictionary)["id"]) == id:
			return e as Dictionary
	return {}


func _cell(v: Variant) -> Vector2i:
	return Vector2i(int((v as Array)[0]), int((v as Array)[1]))


## The squares of `rows` reachable on foot (no diagonals, doors count as open) from `from`.
func _reach(rows: Array, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= str(rows[n.y]).length() or seen.has(n):
				continue
			if str(rows[n.y])[n.x] in ["#", " ", "w"]:
				continue
			seen[n] = true
			todo.append(n)
	return seen


func _moved(beats: Array[Dictionary]) -> Dictionary:
	return (beats[-1] as Dictionary).get("move", {}) as Dictionary


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _options(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b["kind"]) == "options":
			for o: Variant in b["options"]:
				out.append(str((o as Dictionary)["text"]))
	return out


# --- The maps ---------------------------------------------------------------------------------------------------------

func test_the_room_is_one_walk_from_the_dungeon_stair_to_the_catacombs() -> void:
	var loc := _loc(ROOM)
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	var spawns := loc["spawns"] as Dictionary
	var reach := _reach(rows, _cell(spawns["from_dungeon"]))
	for e: Variant in loc["exits"]:
		assert_true(reach.has(_cell((e as Dictionary)["cell"])), "the exit %s can be walked to" % (e as Dictionary)["id"])
	for sp: String in spawns:
		assert_true(reach.has(_cell(spawns[sp])), "the arrival %s is on the way" % sp)
	for p: Variant in loc["props"]:
		var c := _cell((p as Dictionary)["cell"])
		assert_true(reach.has(c) or str(rows[c.y])[c.x] in ["#", "="], "%s stands on the way, on the brazier or on a wall" % (p as Dictionary)["id"])
	for t: Variant in loc["traps"]:
		for c: Variant in (t as Dictionary)["cells"]:
			assert_eq(str(rows[_cell(c).y])[_cell(c).x], ".", "%s lies on open floor" % (t as Dictionary)["id"])
			assert_true(reach.has(_cell(c)))
	for e: Variant in loc["encounters"]:
		for m: Variant in (e as Dictionary)["monsters"]:
			assert_true(reach.has(_cell((m as Dictionary)["cell"])), "%s starts on open floor" % (e as Dictionary)["id"])


func test_the_glyph_fills_the_landing_and_the_trapdoor_fills_the_tunnel() -> void:
	var rows := (_loc(ROOM)["map"] as Dictionary)["rows"] as Array
	for trap_id: String in ["brazier_glyph_ward", "brazier_trapdoor_hatch"]:
		var cells := {}
		for c: Variant in _trap(ROOM, trap_id)["cells"]:
			cells[_cell(c)] = true
		# every walkable square of the passage at one of the trap's columns is in the trap: it can't be walked round, only
		# disarmed or sprung
		for c: Vector2i in cells.keys():
			for y in range(rows.size()):
				if str(rows[y])[c.x] != "#":
					assert_true(cells.has(Vector2i(c.x, y)), "%s: column %d, row %d is part of it" % [trap_id, c.x, y])


func test_the_dungeon_and_the_catacombs_only_gained_squares() -> void:
	var d := (_loc(DUNGEON)["map"] as Dictionary)["rows"] as Array
	assert_eq(d.size(), DUNGEON_ROWS.size())
	for i in d.size():
		var want := DUNGEON_ROWS[i]
		if i == 6 or i == 7:
			want = want.substr(0, 15) + "." + want.substr(16)   # the nook behind the low door
		assert_eq(str(d[i]), want, "row %d of the dungeon is as it was" % i)
	var c := (_loc(CATA)["map"] as Dictionary)["rows"] as Array
	assert_eq(c.size(), CATACOMBS_ROWS.size())
	for i in c.size():
		var want := CATACOMBS_ROWS[i]
		if i == 29:
			want = want.substr(0, 38) + "." + want.substr(39)   # the tunnel's mouth in the lower gallery's south wall
		assert_eq(str(c[i]), want, "row %d of the catacombs is as it was" % i)


func test_nothing_that_stood_in_the_dungeon_or_the_catacombs_moved() -> void:
	var dungeon := _loc(DUNGEON)
	var spawns := dungeon["spawns"] as Dictionary
	assert_eq(_cell(spawns["default"]), Vector2i(2, 3))
	assert_eq(_cell(spawns["from_larders"]), Vector2i(2, 3))
	assert_eq(_cell(spawns["from_lift"]), Vector2i(24, 9))
	var old_exits := {"larders_dungeon_up": Vector2i(2, 1), "larders_lift_up": Vector2i(24, 8)}
	for e: Variant in dungeon["exits"]:
		if old_exits.has(str((e as Dictionary)["id"])):
			assert_eq(_cell((e as Dictionary)["cell"]), old_exits[str((e as Dictionary)["id"])])
	assert_eq(_cell(_prop(DUNGEON, "larders_cold_brazier")["cell"]), Vector2i(15, 3), "the cold brazier stands where it did")
	assert_eq(_cell(_prop(DUNGEON, "larders_tally_skeleton")["cell"]), Vector2i(13, 7))
	var cata := _loc(CATA)["spawns"] as Dictionary
	assert_eq(_cell(cata["default"]), Vector2i(3, 3))
	assert_eq(_cell(cata["from_larders"]), Vector2i(40, 3))
	assert_eq(_cell(cata["from_tombs"]), Vector2i(5, 27))
	assert_eq(_cell(cata["from_strahd"]), Vector2i(18, 14))


func test_the_ways_join_up_in_both_directions() -> void:
	var by_id := {}
	for loc_id: String in [ROOM, DUNGEON, CATA]:
		for e: Variant in _loc(loc_id)["exits"]:
			by_id[str((e as Dictionary)["id"])] = e
	var pairs := [
		["larders_west_stair_down", ROOM, "from_dungeon"],
		["brazier_stair_up", DUNGEON, "from_west_stair"],
		["brazier_tunnel_end", CATA, "from_tunnel"],
		["cat_tunnel_mouth", ROOM, "from_catacombs"]]
	for p: Array in pairs:
		var e := by_id[p[0]] as Dictionary
		assert_eq(str(e["to"]), p[1])
		assert_eq(str(e["spawn"]), p[2])
		assert_true((_loc(p[1])["spawns"] as Dictionary).has(p[2]), "%s has the arrival %s" % [p[1], p[2]])
	assert_true((_loc(DUNGEON)["spawns"] as Dictionary).has("from_chute"), "the cell the chute drops into")
	assert_true((_loc(ROOM)["spawns"] as Dictionary).has("from_chute"), "and the tunnel the chute climbs back to")
	var door := {}
	for d: Variant in _loc(DUNGEON)["doors"]:
		if str((d as Dictionary)["id"]) == "larders_west_stair_door":
			door = d as Dictionary
	assert_eq(_cell(door["cell"]), Vector2i(15, 6), "the low door is in the hall's south wall")
	var chute := _prop(DUNGEON, "larders_chute_mouth")
	assert_true(_cell(chute["cell"]).y == 7, "and the chute opens high in a north cell's wall")


func test_the_landing_cell_is_a_north_cell_with_no_one_in_it() -> void:
	var landing := _cell((_loc(DUNGEON)["spawns"] as Dictionary)["from_chute"])
	assert_true(landing.x >= 12 and landing.x <= 14 and landing.y >= 8 and landing.y <= 10, "the third north cell")
	for n: Variant in _loc(DUNGEON)["npcs"]:
		assert_false(_cell((n as Dictionary)["cell"]) == landing, "nobody stands on the landing square")


# --- The foes ---------------------------------------------------------------------------------------------------------

func test_the_wax_image_has_one_hit_point_and_the_knight_is_a_golem_with_the_plans_numbers() -> void:
	var wax := _enc(ROOM, "brazier_wax_strahd")
	assert_eq(str(wax["trigger"]), "flag:brazier_glyph_woken")
	assert_eq(int((wax["monsters"] as Array)[0]["hp"]), 1, "it melts at the first blow that lands")
	var golems := _enc(ROOM, "brazier_golems")
	assert_eq(str(golems["trigger"]), "dialogue", "only a conversation's choice starts it: it can always be avoided")
	assert_eq((golems["monsters"] as Array).size(), 1, "one golem: the other knight is only armour (two at any Hit Points lose the party in three rounds)")
	assert_eq(_cell((golems["monsters"] as Array)[0]["cell"]), Vector2i(16, 4), "from the west alcove")
	assert_eq(int((golems["monsters"] as Array)[0]["hp"]), 300, "tuned from the stat block's 252 to 3 wins in 8 under the current rules")
	var comp := Compendium.shared()
	var block := comp.get_entry("monsters", "iron_golem")
	assert_eq(int((block["hp"] as Dictionary)["average"]), 252)
	assert_eq(int(block["ac"]), 20)
	assert_eq(int(block["cr"]), 16)
	assert_eq(str(block["size"]), "large")
	assert_true("fire" in (block["immunities"] as Array), "fire heals it")
	var absorbs := false
	for t: Variant in block["traits"]:
		absorbs = absorbs or str((t as Dictionary).get("absorb", "")) == "fire"
	assert_true(absorbs)
	assert_false(block.has("art"), "it wears its own sprite now, not another creature's")
	assert_true(ResourceLoader.exists("res://art/sprites/iron_golem/walk.tres"), "its walk sheet")
	assert_true(ResourceLoader.exists("res://art/sprites/iron_golem/attack.tres"), "its attack sheet")
	assert_true(ResourceLoader.exists("res://art/portraits/iron_golem.png"), "and its own portrait")
	assert_eq(CombatToken.height_for("iron_golem"), 2.6, "drawn 2.6 high (a Large figure of about 12 ft)")


# --- The stones -------------------------------------------------------------------------------------------------------

func test_a_party_that_has_been_nowhere_is_offered_no_stone() -> void:
	var st := _party()
	var beats := SideQuestPlay.play(st, FILE + "brazier")
	assert_eq(SideQuestPlay.missing(beats), "")
	for o: String in _options(beats):
		assert_false(o.begins_with("Throw the"), "no stone for a place it has not been: %s" % o)
	assert_true(SideQuestPlay.text(beats).contains("bright pebbles"), "they are only coloured pebbles")
	assert_true(_moved(beats).is_empty())
	assert_true("Leave the brazier alone." in _options(beats), "and there is a way out")


func test_each_stone_is_offered_only_for_a_place_the_party_has_been() -> void:
	for stone: Array in STONES:
		var st := _party()
		for need: String in stone[2]:
			if need.begins_with("visited:"):
				st.visited[need.substr(8)] = true
			else:
				st.set_flag(need.substr(5))
		var beats := SideQuestPlay.play(st, FILE + "brazier")
		var offered: Array[String] = []
		for o: String in _options(beats):
			if o.begins_with("Throw the"):
				offered.append(o)
		assert_eq(offered.size(), 1, "just the %s stone" % stone[0])
		assert_true(str(offered[0]).contains(str(stone[0])), "the %s stone, for %s" % [stone[0], stone[1]])


func test_the_blue_stone_needs_the_tsolenka_gate_open_as_well_as_the_temple_visited() -> void:
	var st := _party()
	st.visited["amber_temple_entrance"] = true
	var shut := SideQuestPlay.play(st, FILE + "brazier")
	for o: String in _options(shut):
		assert_false(o.contains("blue"), "the temple is not on the way yet")
	st.set_flag("tsolenka_gate_open")
	var open := SideQuestPlay.play(st, FILE + "brazier")
	var found := false
	for o: String in _options(open):
		found = found or o.contains("blue")
	assert_true(found)


func test_each_stone_carries_the_party_to_its_place_after_a_few_minutes() -> void:
	for stone: Array in STONES:
		var st := _travelled()
		var before := st.total_minutes()
		var beats := SideQuestPlay.play(st, FILE + "brazier", ["Throw the %s" % stone[0], "Step into the coloured fire"])
		assert_eq(SideQuestPlay.missing(beats), "", "the %s stone" % stone[0])
		var want := str(stone[1]).split(":")
		var got := _moved(beats)
		assert_eq(str(got.get("location", "")), want[0], "the %s stone goes to %s" % [stone[0], want[0]])
		if want.size() > 1:
			assert_eq(str(got.get("spawn", "")), want[1])
		assert_eq(st.total_minutes() - before, 5, "it takes a few minutes")
		var back := SideQuestPlay.play(_travelled(), FILE + "brazier", ["Throw the %s" % stone[0], "Let the fire turn white"])
		assert_true(_moved(back).is_empty(), "or the party steps back and goes nowhere")


func test_every_place_a_stone_goes_exists_with_its_arrival() -> void:
	for stone: Array in STONES:
		var want := str(stone[1]).split(":")
		var loc := _loc(want[0])
		assert_false(loc.is_empty(), "%s is a location" % want[0])
		if want.size() > 1:
			assert_true((loc["spawns"] as Dictionary).has(want[1]))


func test_the_hourglass_has_its_verse_with_a_line_for_every_stone() -> void:
	var beats := SideQuestPlay.play(_party(), FILE + "hourglass", ["Read the verse"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var text := SideQuestPlay.text(beats)
	for stone: Array in STONES:
		assert_true(text.contains(str(stone[0]).capitalize() + " "), "the verse names %s" % stone[0])
	assert_true(_moved(beats).is_empty())


# --- The knights ------------------------------------------------------------------------------------------------------

func test_striking_a_knight_the_hourglass_or_kicking_the_brazier_wakes_them() -> void:
	var cases := [[FILE + "knight", "Strike one"], [FILE + "hourglass", "Strike the hanging"], [FILE + "brazier", "Kick the stone"]]
	for c: Array in cases:
		var st := _party()
		assert_false(st.get_flag("brazier_golems_awake"))
		var beats := SideQuestPlay.play(st, c[0], [c[1]])
		assert_eq(SideQuestPlay.missing(beats), "", str(c[0]))
		assert_eq(SideQuestPlay.combat_of(beats), "brazier_golems", "%s starts the knights' fight" % c[0])
		assert_true(st.get_flag("brazier_golems_awake"))


func test_leaving_the_knights_alone_is_always_possible_and_wakes_nothing() -> void:
	for ref: String in [FILE + "knight", FILE + "hourglass", FILE + "brazier"]:
		var st := _party()
		var beats := SideQuestPlay.play(st, ref)
		assert_eq(SideQuestPlay.combat_of(beats), "", "the last option leaves them be (%s)" % ref)
		assert_false(st.get_flag("brazier_golems_awake"))
	var st := _party()
	st.set_flag("brazier_golems_beaten")
	var after := SideQuestPlay.play(st, FILE + "brazier")
	for o: String in _options(after):
		assert_false(o.contains("Kick"), "nothing left to wake once they are broken")


func test_the_knights_fight_is_still_there_until_it_is_won() -> void:
	var st := _party()
	assert_false(SideQuestPlay.encounter(st, ROOM, "brazier_golems").is_empty())
	st.set_flag("brazier_golems_beaten")
	assert_true(SideQuestPlay.encounter(st, ROOM, "brazier_golems").is_empty())


# --- The trapdoor and the chute ---------------------------------------------------------------------------------------

func test_the_slide_drops_the_party_into_a_north_cell_a_few_minutes_later() -> void:
	var st := _party()
	var before := st.total_minutes()
	var beats := SideQuestPlay.play(st, FILE + "slide")
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(str(_moved(beats).get("location", "")), DUNGEON)
	assert_eq(str(_moved(beats).get("spawn", "")), "from_chute")
	assert_eq(st.total_minutes() - before, 5)


func test_no_way_up_the_chute_without_magic_and_a_spell_that_climbs_takes_the_party_back() -> void:
	var st := _party(DUNGEON)
	var plain := SideQuestPlay.play(st, FILE + "chute")
	assert_eq(_options(plain), ["Leave the chute alone."] as Array[String], "nothing climbs it without a spell")
	assert_true(_moved(plain).is_empty())
	for spell: String in ["spider_climb", "levitate", "fly"]:
		var who := _party(DUNGEON)
		who.party[1].granted_spells.append({"id": spell, "at_level": 1, "ability": "int", "source": "a test", "uses": 0,
			"recharge": "", "at_will": true})
		var beats := SideQuestPlay.play(who, FILE + "chute", [spell.replace("_", " ").capitalize().substr(0, 5)])
		assert_eq(SideQuestPlay.missing(beats), "", spell)
		assert_eq(str(_moved(beats).get("location", "")), ROOM, "%s takes the party back up" % spell)
		assert_eq(str(_moved(beats).get("spawn", "")), "from_chute")


# --- The way in -------------------------------------------------------------------------------------------------------

func test_the_low_door_is_unlocked_and_the_stair_behind_it_is_a_dead_end_that_leads_down() -> void:
	var door := {}
	for d: Variant in _loc(DUNGEON)["doors"]:
		if str((d as Dictionary)["id"]) == "larders_west_stair_door":
			door = d as Dictionary
	assert_false(bool(door.get("locked", false)))
	assert_true(int(door.get("lock_dc", 0)) == 0 and int(door.get("secret_dc", 0)) == 0, "plain: a party that looks round the hall finds it")
	var rows := (_loc(DUNGEON)["map"] as Dictionary)["rows"] as Array
	assert_eq(str(rows[8])[15], "#", "and the nook has no other way in or out")
	assert_eq(str(rows[7])[14], "#")
	assert_eq(str(rows[7])[16], "#")


# --- In the game ------------------------------------------------------------------------------------------------------

func _boot(location: String) -> LocationView:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = location
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return root.get("view") as LocationView


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	root = null
	await _frames(1)


func test_stepping_on_the_glyph_raises_the_wax_image_and_a_fight_begins() -> void:
	var v := await _boot(ROOM)
	assert_eq(v.loc_id, ROOM)
	assert_false(v.in_combat)
	v.members[0].cell = Vector2i(7, 10)
	assert_true(LocationTraps._check_traps(v), "the step set something off")
	await _frames(4)
	assert_true(GameState.story.get_flag("brazier_glyph_woken"))
	assert_true(v.in_combat, "and the image of the count fights")
	var foes := v.combat_view.e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy")
	assert_eq(foes.size(), 1)
	assert_eq((foes[0] as Combatant).creature.max_hp(), 1, "one hit point: the first blow that lands melts it")


func test_the_trapdoor_tips_and_the_next_step_slides_the_party_to_the_cell() -> void:
	var v := await _boot(ROOM)
	v.members[0].cell = Vector2i(34, 22)
	assert_true(LocationTraps._check_traps(v), "the floor tips")
	assert_true(GameState.story.get_flag("brazier_trapdoor_fell"))
	assert_false(v.in_combat)
	var asked: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: asked.append(ref))
	assert_true(LocationNpcs._check_calls(v), "and the next step's check finds the slab's talk")
	assert_eq(asked, [FILE + "slide"] as Array[String])
	assert_false(LocationNpcs._check_calls(v), "once")


func test_a_disarmed_trapdoor_lets_the_party_walk_over_it() -> void:
	var v := await _boot(ROOM)
	(GameState.story.loc_state(ROOM)["traps"] as Dictionary)["brazier_trapdoor_hatch"] = "disarmed"
	v.members[0].cell = Vector2i(34, 22)
	assert_false(LocationTraps._check_traps(v))
	assert_false(GameState.story.get_flag("brazier_trapdoor_fell"))
	assert_false(LocationNpcs._check_calls(v), "and the slab says nothing")


func test_a_found_glyph_and_trapdoor_are_drawn_on_the_board() -> void:
	var v := await _boot(ROOM)
	for id: String in ["brazier_glyph_ward", "brazier_trapdoor_hatch"]:
		(GameState.story.loc_state(ROOM)["traps"] as Dictionary)[id] = "found"
	LocationTraps._mark_found_traps(v)
	assert_true(v.trap_marks.has("brazier_glyph_ward"), "the glyph shows once it is found")
	assert_true(v.trap_marks.has("brazier_trapdoor_hatch"), "and so does the trapdoor")
	assert_eq(TrapSight.look_for(_trap(ROOM, "brazier_glyph_ward")), "floor_glyphs")
	assert_eq(TrapSight.look_for(_trap(ROOM, "brazier_trapdoor_hatch")), "roof_hatch")


func test_the_west_knight_steps_out_as_a_large_golem_and_its_twin_stays() -> void:
	var v := await _boot(ROOM)
	assert_true(v.start_encounter("brazier_golems"))
	await _frames(3)
	var foes := v.combat_view.e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy")
	assert_eq(foes.size(), 1)
	for f: Combatant in foes:
		assert_eq(f.size_cells, 2, "Large: two squares across")
		assert_true(str(f.creature.id).begins_with("iron_golem"), "an iron golem (%s)" % f.creature.id)
		assert_eq(f.cell, Vector2i(16, 4), "out of the west alcove")
		assert_eq(f.creature.max_hp(), 300)
	assert_true(v.prop_nodes.has("brazier_knight_east"), "and the east knight stays on its square")


func test_the_tunnel_and_the_dungeon_stair_load_on_arrival() -> void:
	var v := await _boot(ROOM)
	var spawn := _cell((_loc(ROOM)["spawns"] as Dictionary)["from_catacombs"])
	assert_true(v.leader().cell != spawn)
	root.queue_free()
	root = null
	await _frames(2)
	var w := await _boot(DUNGEON)
	assert_eq(w.loc_id, DUNGEON)
	assert_true(w.exit_nodes.has("larders_west_stair_down"), "the stair down is drawn")


# --- The words --------------------------------------------------------------------------------------------------------

func test_every_new_place_and_thing_has_its_narrator_line() -> void:
	var n := Narrator.new(1)
	var st := _party(ROOM)
	for key: String in ["enter:larders_west_stair", "enter:castle_ravenloft_brazier_room", "enter:brazier_room", "enter:brazier_centre_stair",
			"enter:brazier_tunnel", "trap:brazier_glyph_ward:found", "trap:brazier_glyph_ward:triggered",
			"trap:brazier_trapdoor_hatch:found", "trap:brazier_trapdoor_hatch:triggered", "examine:brazier_wax_puddle"]:
		assert_true(n.line(key, st, null) != "", "the Narrator says something for %s" % key)
	var broken := _party(ROOM)
	broken.set_flag("brazier_golems_beaten")
	assert_true(n.line("enter:brazier_room", broken, null).contains("Split plates"), "and another once the knights are broken")
	var melt := _party(ROOM)
	melt.set_flag("brazier_glyph_woken")
	assert_true(n.line("combat:kill", melt, null).contains("tallow"), "the image melts at the blow that kills it")
	var elsewhere := _party("vallaki")
	elsewhere.set_flag("brazier_glyph_woken")
	assert_false(n.line("combat:kill", elsewhere, null).contains("tallow"), "and only here")


func test_no_narrator_line_in_the_room_runs_over_thirty_five_words() -> void:
	for path: String in ["res://narrative/castle_ravenloft/larders_brazier.dialogue"]:
		for raw: String in FileAccess.get_file_as_string(path).split("\n"):
			if raw.begins_with("Narrator:"):
				assert_true(raw.substr(9).strip_edges().split(" ", false).size() <= 35, raw)
