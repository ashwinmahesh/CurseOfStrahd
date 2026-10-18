extends TestCase
## Van Richten's Tower: the fourth floor and the ways in (Dungeon Expansion Plan V1; Elven Tower, chapter 11): the poses
## on the door, the lightning ward and the werewolves it calls, the scaffolding to the third floor, the clay figures' lift,
## and Van Richten's own room with its armour, chest and Vistani head. Rule 2 (extend, never redraw): nothing that
## stood on the two maps before V1 has moved, because story-bot routes and saves stand on it.

const FOUR: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
const INTERIOR := "van_richtens_tower_interior"
const TOWER := "van_richtens_tower"
## sha1 of the sorted "kind:id:x:y" lines of everything the maps held before V1 (see _signature).
const TOWER_SHA := "57b9b614aa2efb79e82a15e025eb995e6412295b"
const INTERIOR_SHA := "362cf96b799913cf50e119096c21b838bfd6185d"
## sha1 of the maps' squares before V1: the island's rows, and the tower's first 35 rows (three floors, nothing moved).
const TOWER_ROWS_SHA := "d1a5d800b40f9bea3407aec9416c9a34f84799c6"
const INTERIOR_ROWS_SHA := "2ecf61ee2264d4c10c21dab58046e46d1b313fae"
## What V1 added to those maps (the pinned lines leave these out).
const TOWER_NEW: Array = ["vrt_scaffolding", "from_scaffold", "vrt_rubble_heap", "vrt_rubble_beam", "vrt_rubble_spill", "vrt_scaffold_wreck",
	"vrt_rubble_notes", "vrt_antimagic"]
const INTERIOR_NEW: Array = ["vrt_study", "lantern_from_above", "study_from_below", "lantern_from_scaffold", "lift_f1", "lift_f2", "lift_f3",
	"lift_f4", "vrt_stairs_up_3", "vrt_stairs_down_4", "vrt_scaffold_down", "vrt_lift_platform_1", "vrt_lift_statue_1", "vrt_lift_statue_2",
	"vrt_lift_statue_3", "vrt_lift_statue_4", "vrt_lift_platform_2", "vrt_lift_platform_3", "vrt_lift_platform_4", "vrt_scaffold_hole",
	"vrt_study_bed", "vrt_study_desk", "vrt_study_window", "vrt_armor", "vrt_head_chest"]
## The new fight's foes are new too; every foe of every other encounter is pinned.
const NEW_FIGHTS: Array = ["ward_wolves"]


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _signature(d: Dictionary, skip: Array) -> String:
	var lines: Array[String] = []
	for key: String in ["props", "containers", "doors", "exits"]:
		for e: Variant in d.get(key, []):
			var ed := e as Dictionary
			if not str(ed["id"]) in skip:
				lines.append("%s:%s:%d:%d" % [key, ed["id"], int((ed["cell"] as Array)[0]), int((ed["cell"] as Array)[1])])
	for s: Variant in (d["spawns"] as Dictionary):
		if not str(s) in skip:
			var c := (d["spawns"] as Dictionary)[s] as Array
			lines.append("spawn:%s:%d:%d" % [s, int(c[0]), int(c[1])])
	for e: Variant in d.get("encounters", []):
		if str((e as Dictionary)["id"]) in NEW_FIGHTS:
			continue
		for m: Variant in (e as Dictionary)["monsters"]:
			var md := m as Dictionary
			lines.append("foe:%s:%s:%d:%d" % [(e as Dictionary)["id"], md["monster"], int((md["cell"] as Array)[0]), int((md["cell"] as Array)[1])])
	for a: Variant in d.get("areas", []):
		var ad := a as Dictionary
		if not str(ad["id"]) in skip:
			var ac := ad["cells"] as Array
			lines.append("area:%s:%d,%d,%d,%d" % [ad["id"], int((ac[0] as Array)[0]), int((ac[0] as Array)[1]), int((ac[1] as Array)[0]), int((ac[1] as Array)[1])])
	lines.sort()
	return "\n".join(PackedStringArray(lines))


func _exit(d: Dictionary, id: String) -> Dictionary:
	for e: Variant in d["exits"]:
		if str((e as Dictionary)["id"]) == id:
			return e as Dictionary
	return {}


func _party(level: int = 7) -> StoryState:
	return SideQuestPlay.party(FOUR, level, TOWER, 12)


func _caster() -> StoryState:
	var st := SideQuestPlay.party(["liriel_dawnsong", "thistle"], 7, INTERIOR, 12)
	((st.party[0].spellcasting[0] as Dictionary)["prepared"] as Array).append("speak_with_dead")
	return st


func _moved(beats: Array[Dictionary]) -> Dictionary:
	return (beats.back() as Dictionary).get("move", {}) as Dictionary


func _offered(beats: Array[Dictionary], text: String) -> bool:
	return beats.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options" and (b["options"] as Array).any(
		func(o: Variant) -> bool: return str((o as Dictionary)["text"]).contains(text)))


## Everything that stood on the island and in the tower before V1 stands where it did.
func test_nothing_that_was_there_moved() -> void:
	var tower := _loc(TOWER)
	assert_eq(_signature(tower, TOWER_NEW).sha1_text(), TOWER_SHA, "the island's props, containers, exits, spawns, areas and fight starts")
	assert_eq("\n".join(PackedStringArray(tower["map"]["rows"] as Array)).sha1_text(), TOWER_ROWS_SHA, "the island's squares")
	var inside := _loc(INTERIOR)
	assert_eq(_signature(inside, INTERIOR_NEW).sha1_text(), INTERIOR_SHA, "the tower's props, containers, exits, spawns and areas")
	var rows := inside["map"]["rows"] as Array
	assert_eq(rows.size(), 47, "four floors: the old three, a blank row, and the new one below them")
	assert_eq("\n".join(PackedStringArray(rows.slice(0, 35))).sha1_text(), INTERIOR_ROWS_SHA, "the three old floors' squares")


## The stairs, the lift and the scaffolding join up, to spawns that exist.
func test_the_new_ways_join_up() -> void:
	var inside := _loc(INTERIOR)
	var spawns := inside["spawns"] as Dictionary
	for s: String in ["lift_f1", "lift_f2", "lift_f3", "lift_f4", "lantern_from_above", "study_from_below", "lantern_from_scaffold"]:
		assert_true(spawns.has(s), "the tower has spawn %s" % s)
	var up := _exit(inside, "vrt_stairs_up_3")
	var down := _exit(inside, "vrt_stairs_down_4")
	assert_eq(str(up["spawn"]), "study_from_below")
	assert_eq(str(down["spawn"]), "lantern_from_above")
	var rows := inside["map"]["rows"] as Array
	for ex: Dictionary in [up, down]:
		var c := ex["cell"] as Array
		assert_eq(str(rows[int(c[1])])[int(c[0])], ".", "%s stands on open floor" % ex["id"])
	var back := _exit(inside, "vrt_scaffold_down")
	assert_eq(str(back["to"]), TOWER)
	assert_true((_loc(TOWER)["spawns"] as Dictionary).has(str(back["spawn"])), "the scaffold's foot is a spawn on the island")
	var study := (inside["areas"] as Array).filter(func(a: Variant) -> bool: return str((a as Dictionary)["id"]) == "vrt_study")[0] as Dictionary
	var corners := study["cells"] as Array
	assert_eq([int((corners[0] as Array)[0]), int((corners[0] as Array)[1]), int((corners[1] as Array)[0]), int((corners[1] as Array)[1])], [2, 37, 11, 45],
		"Van Richten's room is the new floor")


## The door answers to the poses as well as to the name: the figures first, then a Performance check; a wrong try only warns.
func test_the_poses_open_the_door() -> void:
	var st := _party()
	var early := SideQuestPlay.play(st, "van_richtens_tower/tower:door", ["Copy the eight poses"])
	assert_ne(SideQuestPlay.missing(early), "", "the poses are not offered before the figures are studied")
	var won := 0
	var lost := 0
	for seed_value in range(1, 13):
		var s := _party()
		var beats := SideQuestPlay.play(s, "van_richtens_tower/tower:door", ["Study the eight small figures", "Copy the eight poses"], seed_value)
		assert_eq(SideQuestPlay.missing(beats), "", "seed %d" % seed_value)
		assert_true(bool(s.get_flag("tower_figures_studied", false)))
		if bool(s.get_flag("tower_door_opened", false)):
			won += 1
			assert_true(bool(s.get_flag("tower_poses_solved", false)), "it opened by the poses")
			assert_true(SideQuestPlay.text(beats).contains("swings inward"), "and the Narrator says so")
			assert_eq(s.quest_stage("the_hunters_tower"), "inside", "the journal moves as it does at the name")
		else:
			lost += 1
			assert_true(SideQuestPlay.text(beats).contains("stays shut"), "a wrong try leaves the door shut")
			assert_eq(str((beats.back() as Dictionary)["kind"]), "end", "and the menu can always be left")
	assert_true(won > 0, "the poses can be got right")
	assert_true(lost > 0, "and wrong")
	# The old way in still works: the name.
	var named := _party()
	named.set_flag("khazan_known")
	var by_name := SideQuestPlay.play(named, "van_richtens_tower/tower:door", ["Say the name"])
	assert_true(bool(named.get_flag("tower_door_opened", false)), SideQuestPlay.text(by_name))
	assert_false(bool(named.get_flag("tower_poses_solved", false)))


## Each ride is a move between the floors' lift spawns; the ground floor's menu goes up, the upper floors' come down.
func test_the_lift() -> void:
	var st := _party()
	var up := SideQuestPlay.play(st, "van_richtens_tower/the_lift:platform_f1", ["up two floors"])
	assert_eq(SideQuestPlay.missing(up), "")
	assert_eq(_moved(up), {"location": INTERIOR, "spawn": "lift_f3"})
	var top := SideQuestPlay.play(st, "van_richtens_tower/the_lift:statues_f1", ["all the way to the top"])
	assert_eq(_moved(top), {"location": INTERIOR, "spawn": "lift_f4"}, "the figures take orders too")
	var down := SideQuestPlay.play(st, "van_richtens_tower/the_lift:call_f4", ["down"])
	assert_eq(_moved(down), {"location": INTERIOR, "spawn": "lift_f1"})
	var talk := SideQuestPlay.play(st, "van_richtens_tower/the_lift:statues_f1", ["good morning"])
	assert_eq(SideQuestPlay.missing(talk), "")
	assert_eq(_moved(talk), {}, "a word that is not an order moves nobody")
	assert_eq(str((talk.back() as Dictionary)["kind"]), "end", "and the party can step off")
	assert_false(_offered(SideQuestPlay.play(st, "van_richtens_tower/the_lift:call_f4"), "up one floor"), "there is nothing above the fourth floor")
	for f: int in [2, 3, 4]:
		assert_true(SideQuestPlay.play(st, "van_richtens_tower/the_lift:call_f%d" % f).size() > 0)


## The scaffolding goes up to the third floor's hole, and the hunter's-tower quest moves as it does at the door.
func test_the_scaffolding() -> void:
	var st := _party()
	var climb := SideQuestPlay.play(st, "van_richtens_tower/the_scaffold:climb", ["Climb the rotten scaffolding"])
	assert_eq(SideQuestPlay.missing(climb), "")
	assert_eq(_moved(climb), {"location": INTERIOR, "spawn": "lantern_from_scaffold"})
	assert_eq(st.quest_stage("the_hunters_tower"), "inside")
	var shy := SideQuestPlay.play(_party(), "van_richtens_tower/the_scaffold:climb", ["leave the scaffolding"])
	assert_eq(_moved(shy), {}, "or leave it")
	var with_her := _party()
	with_her.add_guest("ezmerelda")
	SideQuestPlay.play(with_her, "van_richtens_tower/the_scaffold:climb", ["Climb the rotten scaffolding"])
	assert_eq(with_her.quest_stage("the_hunters_tower"), "with_her", "with Ezmerelda along, she sees for herself")
	var landing := _loc(INTERIOR)["spawns"]["lantern_from_scaffold"] as Array
	var rows := _loc(INTERIOR)["map"]["rows"] as Array
	assert_eq(str(rows[int(landing[1])])[int(landing[0])], ".", "the hole opens onto floor, north of the ward")
	assert_true(int(landing[1]) < 28, "north of the lightning ward on the floor")


## The armour takes its word, or its word is found on it; the chest opens for the armour, the clasp or a shoulder.
func test_the_armour_and_the_chest() -> void:
	var st := _party()
	var no_word := SideQuestPlay.play(st, "van_richtens_tower/the_study:armor", ["Say the name"])
	assert_ne(SideQuestPlay.missing(no_word), "", "the name is not on offer until the party has it")
	var read := 0
	for seed_value in range(1, 13):
		var s := _party()
		SideQuestPlay.play(s, "van_richtens_tower/the_study:armor", ["maker's mark"], seed_value)
		if bool(s.get_flag("khazan_known", false)):
			read += 1
	assert_true(read > 0, "its word can be read off it")
	var named := _party()
	named.set_flag("khazan_known")
	var obey := SideQuestPlay.play(named, "van_richtens_tower/the_study:armor", ["Say the name"])
	assert_true(bool(named.get_flag("vrt_armor_obeys", false)), SideQuestPlay.text(obey))
	var lid := SideQuestPlay.play(named, "van_richtens_tower/the_study:chest", ["Order the armour", "Close the lid"])
	assert_eq(SideQuestPlay.missing(lid), "")
	assert_true(bool(named.get_flag("vrt_head_chest_open", false)), "the armour lifts the lid")
	for pick: String in ["Work the iron clasp", "Force the lid"]:
		var opened := 0
		for seed_value in range(1, 13):
			var s := _party()
			SideQuestPlay.play(s, "van_richtens_tower/the_study:chest", [pick, "Close the lid"], seed_value)
			if bool(s.get_flag("vrt_head_chest_open", false)):
				opened += 1
		assert_true(opened > 0, "%s gets it open" % pick)
	var shut := SideQuestPlay.play(_party(), "van_richtens_tower/the_study:chest", ["Let the chest be"])
	assert_eq(str((shut.back() as Dictionary)["kind"]), "end", "the chest can be left shut")


## Speak with Dead: the head answers once, names Arrigal's camp, and keeps quiet after. Without the spell it is a tag and a head.
func test_the_head() -> void:
	var st := _caster()
	st.set_flag("vrt_head_chest_open")
	var slots := st.party[0].slots_left(3)
	var beats := SideQuestPlay.play(st, "van_richtens_tower/the_study:chest", ["Cast Speak with Dead", "which Vistani serve the castle", "Thank him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.party[0].slots_left(3), slots - 1, "a 3rd-level slot")
	assert_true(bool(st.get_flag("vrt_head_spoke", false)))
	assert_true(bool(st.get_flag("arrigal_suspected", false)), "he names Arrigal's camp, and the Vistani camp's talk has a new door")
	assert_true(SideQuestPlay.text(beats).contains("Arrigal"))
	var again := SideQuestPlay.play(st, "van_richtens_tower/the_study:chest")
	assert_false(_offered(again, "Speak with the dead man"), "a dead man answers once")
	var plain := _party()
	plain.set_flag("vrt_head_chest_open")
	var silent := SideQuestPlay.play(plain, "van_richtens_tower/the_study:chest")
	assert_true(SideQuestPlay.text(silent).contains("ASK, THEN LET HIM REST"), "without the spell, a tag in a small neat hand")
	assert_false(_offered(silent, "Speak with the dead man"))
	assert_eq(str((silent.back() as Dictionary)["kind"]), "end", "and the lid can be shut")


## The relief beside the door is reachable without stepping on the ward from every square the party may stand on, and every
## walk into the door's west leaf crosses it.
func test_the_ward_guards_the_door_not_the_riddle() -> void:
	var ward: Dictionary = {}
	for t: Variant in _loc(TOWER)["traps"]:
		if str((t as Dictionary)["id"]) == "vrt_door_ward_1":
			ward = t as Dictionary
	assert_false(ward.is_empty(), "the ward is a trap on the island")
	assert_eq(ward["damage"], "4d10", "the book's 4d10")
	assert_eq(ward["damage_type"], "lightning")
	assert_eq(ward["flag"], "tower_ward_1", "the flag the werewolves wait on")
	var st := _party()
	assert_true(StoryConditions.check(str(ward["when"]), st), "armed while the door is shut")
	st.set_flag("tower_door_opened")
	assert_false(StoryConditions.check(str(ward["when"]), st), "quiet once the door is open")
	var guest := _party()
	guest.add_guest("rictavio")
	assert_false(StoryConditions.check(str(ward["when"]), guest), "and for his own door")
	for c: Variant in ward["cells"]:
		var cc := c as Array
		assert_eq(str((_loc(TOWER)["map"]["rows"] as Array)[int(cc[1])])[int(cc[0])], ".", "the ward is on open floor")


## Stepping on the ward burns whoever stands there and calls the werewolves at once: the trap's flag starts the fight.
func test_the_ward_calls_the_werewolves() -> void:
	GameState.reset()
	for id: String in FOUR:
		var ch := Pregens.build(id, 7)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = TOWER
	GameState.story.minute_of_day = 12 * 60
	GameState.story.positions = [Vector2i(15, 12), Vector2i(15, 13), Vector2i(15, 14), Vector2i(16, 14)]
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	var v := root.get("view") as LocationView
	assert_false(v.in_combat, "quiet at the door")
	# The relief beside the door is reached from the south without stepping on the ward.
	var stand := LocationInteraction._adjacent_free(v, Vector2i(17, 10))
	assert_false(v._path(v.leader().cell, stand).any(func(c: Vector2i) -> bool: return c in [Vector2i(14, 11), Vector2i(15, 11)]), "the riddle can be tried unburnt")
	var hp := v.members[0].creature.hp
	v.members[0].cell = Vector2i(15, 11)
	assert_true(LocationTraps._check_traps(v), "the step springs it")
	assert_true(bool(GameState.story.get_flag("tower_ward_1", false)), "the ward has gone off")
	assert_true(v.members[0].creature.hp < hp, "and burned whoever stood there")
	assert_true(v.in_combat, "the werewolves come at once")
	assert_eq(str((GameState.story.loc_state(TOWER)["encounters"] as Dictionary).get("ward_wolves", "")), "started")
	for i in 2:
		await get_tree().process_frame
	var wolves := v.combat_view.e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy")
	assert_eq(wolves.size(), 5, "five werewolves for a party of level 7")
	root.queue_free()
	await get_tree().process_frame


## The ward goes off three times and the third brings the tower down (the book): two more traps on the same squares, each armed
## by the one before. It never comes down while Van Richten is at home, and never once the door is open.
func test_the_third_firing_brings_the_tower_down() -> void:
	var traps := {}
	for t: Variant in _loc(TOWER)["traps"]:
		traps[str((t as Dictionary)["id"])] = t
	for n: int in [1, 2, 3]:
		assert_true(traps.has("vrt_door_ward_%d" % n), "firing %d has its trap" % n)
	var st := _party()
	assert_false(StoryConditions.check(str((traps["vrt_door_ward_2"] as Dictionary)["when"]), st), "the second waits for the first")
	st.set_flag("tower_ward_1")
	assert_true(StoryConditions.check(str((traps["vrt_door_ward_2"] as Dictionary)["when"]), st))
	assert_false(StoryConditions.check(str((traps["vrt_door_ward_3"] as Dictionary)["when"]), st), "the third waits for the second")
	st.set_flag("tower_ward_2")
	assert_true(StoryConditions.check(str((traps["vrt_door_ward_3"] as Dictionary)["when"]), st))
	st.set_flag("rictavio_gone")
	assert_false(StoryConditions.check(str((traps["vrt_door_ward_3"] as Dictionary)["when"]), st), "not on Van Richten at home")
	st.set_flag("van_richten_reunited")
	assert_true(StoryConditions.check(str((traps["vrt_door_ward_3"] as Dictionary)["when"]), st), "his tower is empty once he has gone to the shore")
	assert_eq((traps["vrt_door_ward_3"] as Dictionary)["flag"], "tower_collapsed")
	GameState.reset()
	for id: String in FOUR:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = TOWER
	GameState.story.minute_of_day = 12 * 60
	GameState.story.set_flag("tower_wolves_beaten")   # the werewolves are dealt with: no fight in the way
	GameState.story.positions = [Vector2i(15, 13), Vector2i(15, 14), Vector2i(16, 14), Vector2i(14, 14)]
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	var v := root.get("view") as LocationView
	assert_true(SideQuestPlay.shown(GameState.story, TOWER, "vrt_scaffolding"), "the scaffolding stands")
	assert_false(SideQuestPlay.shown(GameState.story, TOWER, "vrt_rubble_heap"), "and the doorway is clear")
	for n: int in 3:
		v.members[0].creature.hp = v.members[0].creature.max_hp()
		v.members[0].cell = Vector2i(15, 11)
		assert_true(LocationTraps._check_traps(v), "firing %d goes off" % (n + 1))
		assert_false(v.in_combat, "and the wolves are beaten")
		assert_eq(bool(GameState.story.get_flag("tower_collapsed", false)), n == 2, "the tower stands until the third")
		v.members[0].cell = Vector2i(15, 13)
	v.members[0].cell = Vector2i(15, 11)
	assert_false(LocationTraps._check_traps(v), "a fourth step is only a step")
	assert_true(SideQuestPlay.shown(GameState.story, TOWER, "vrt_rubble_heap"), "the doorway is a heap now")
	assert_false(SideQuestPlay.shown(GameState.story, TOWER, "vrt_scaffolding"), "and the scaffolding is gone with the rest")
	assert_true(SideQuestPlay.shown(GameState.story, TOWER, "vrt_scaffold_wreck"))
	root.queue_free()
	await get_tree().process_frame


## Digging out: three good shifts of two hours (Athletics DC 14) reach the strongbox, hand over the Tarokka treasure the cards
## hid there, the strongbox's loot (once) and the hunter's loose pages with their flags. The door's own talk goes to the heap.
func test_the_dig_reaches_the_strongbox() -> void:
	var st := _party(10)
	st.set_flag("tower_collapsed")
	st.tarokka = {"tome": "stars_master"}
	var door := SideQuestPlay.play(st, "van_richtens_tower/tower:door")
	assert_true(SideQuestPlay.text(door).contains("snapped ribs"), "the door is gone")
	assert_true(_offered(door, "dig into the rubble"), "and its talk offers the dig")
	assert_false(_offered(SideQuestPlay.play(st, "van_richtens_tower/tower:door"), "poses"), "no riddle at a doorway that is not there")
	var start := st.total_minutes()
	var picks: Array[String] = []
	for _i in 30:
		picks.append("dig into the rubble")
	var dug := SideQuestPlay.play(st, "van_richtens_tower/the_collapse:heap", picks, 3)
	assert_eq(SideQuestPlay.missing(dug), "")
	assert_true(bool(st.get_flag("vrt_strongbox_dug", false)), "the strongbox is reached")
	assert_true(st.total_minutes() - start >= 360, "after at least three shifts of two hours")
	assert_true(bool(st.get_flag("treasure_found_tome", false)), "the Tarokka treasure comes out of it")
	assert_eq(st.gold, 120.0, "and its gold")
	var again := SideQuestPlay.play(st, "van_richtens_tower/the_collapse:heap")
	assert_false(_offered(again, "dig into the rubble"), "once is enough")
	var notes := SideQuestPlay.play(st, "van_richtens_tower/the_collapse:notes")
	assert_eq(SideQuestPlay.missing(notes), "")
	assert_true(bool(st.get_flag("van_richten_notes_read", false)) and bool(st.get_flag("van_richten_identity_known", false)) and bool(st.get_flag("den_way_known", false)),
		"the casebook's, the ledger's and the map's flags come out of the pages")
	var looted := _party(10)
	looted.set_flag("tower_collapsed")
	looted.set_flag("van_richten_strongbox_opened")
	SideQuestPlay.play(looted, "van_richtens_tower/the_collapse:heap", picks, 3)
	assert_true(bool(looted.get_flag("vrt_strongbox_dug", false)))
	assert_eq(looted.gold, 0.0, "a strongbox already emptied is not paid twice")


## The tower's ring (the book's antimagic field, 5 ft out from the walls): no spell is cast on its squares from the character sheet,
## and a fight there is fought with an Antimagic Field over them. Inside the tower, and 10 ft from the walls, magic works.
func test_the_antimagic_ring() -> void:
	var tower := _loc(TOWER)
	var ring := Wards.antimagic_areas(tower)
	assert_eq(ring.size(), 1, "one ring")
	var st := _caster()
	st.location = TOWER
	var inside: Array[Vector2i] = [Vector2i(15, 11), Vector2i(14, 11), Vector2i(12, 7), Vector2i(19, 7), Vector2i(15, 4), Vector2i(18, 11)]
	var outside: Array[Vector2i] = [Vector2i(15, 12), Vector2i(11, 7), Vector2i(20, 7), Vector2i(15, 3), Vector2i(10, 5), Vector2i(22, 11)]
	for c in inside:
		st.positions = [c]
		assert_ne(Wards.antimagic_notice(st), "", "%s is in the ring" % c)
		var cast := FieldCasting.cast(st.party, st.party[0], "cure_wounds", 0, [st.party[1]], DiceRoller.new(1), st)
		assert_false(bool(cast["ok"]), "no spell is cast at %s" % c)
		assert_eq(str(cast["text"]), Wards.antimagic_notice(st))
	for c in outside:
		st.positions = [c]
		assert_eq(Wards.antimagic_notice(st), "", "%s is outside it" % c)
	st.location = INTERIOR
	st.positions = [Vector2i(6, 8)]
	assert_eq(Wards.antimagic_notice(st), "", "inside the tower, magic works")
	var rows := tower["map"]["rows"] as Array
	var area := ring[0]
	for c: Vector2i in inside:
		assert_ne(str(rows[c.y])[c.x], "#", "the squares the ring is tested on are open ground")
	assert_true(area["antimagic"] is String, "and a caster is told why")


## In the werewolves' fight at the door the ring is an Antimagic Field zone: whoever stands in it can't cast, and the others can.
func test_the_ring_is_a_field_in_the_fight() -> void:
	GameState.reset()
	for id: String in FOUR:
		var ch := Pregens.build(id, 7)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = TOWER
	GameState.story.minute_of_day = 12 * 60
	GameState.story.positions = [Vector2i(15, 12), Vector2i(15, 13), Vector2i(15, 14), Vector2i(16, 14)]
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	var v := root.get("view") as LocationView
	v.members[0].cell = Vector2i(15, 11)
	assert_true(LocationTraps._check_traps(v), "the ward goes off")
	for i in 2:
		await get_tree().process_frame
	assert_true(v.in_combat)
	var e := v.combat_view.e
	var high := e.spells.specials.high
	var leader := e.get_c(v.members[0].id)
	assert_true(high.in_antimagic(leader), "the leader at the door is in the field")
	assert_false(high.in_antimagic(e.get_c(v.members[1].id)), "and the one ten feet back is not")
	root.queue_free()
	await get_tree().process_frame
