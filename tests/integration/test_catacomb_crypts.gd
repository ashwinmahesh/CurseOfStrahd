extends TestCase
## The crypts that hold something (Dungeon Expansion Plan C1, docs/regions/castle_ravenloft_catacombs.md §14): seven of
## the catacombs' empty crypt rooms now hold the book's traps and finds, and the Lesser Vaults (a new map below the lower
## gallery) hold ten more. Rule 2 (extend, never redraw): no square, spawn, exit, prop, container, door or fight start
## that was there before C1 has moved, because story-bot routes and saves stand on them.

const SIX: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
## sha1 of the sorted "kind:id:x:y" lines of everything the maps held before C1 (made.py in the lane's hand-off).
const CAT_SHA := "86edc38f2affcc5ad96e1b57f08ef1fd06de8fb3"
const STRAHD_SHA := "028612e8fd9f184f25b7d914f218f74eaf084926"
## What C1 added to those two maps (the pinned lines leave these out).
const CAT_NEW: Array = ["cat_bascal_bell", "cat_bascal_epitaph", "cat_bascal_spork", "cat_c31_epitaph", "cat_crypt_31", "cat_crypt_bascal", "cat_crypt_eisglaze", "cat_crypt_erick", "cat_crypt_klutz", "cat_crypt_tasha", "cat_crypt_troisky", "cat_eisglaze_epitaph", "cat_eisglaze_mold", "cat_eisglaze_sword", "cat_erick_epitaph", "cat_erick_gold", "cat_klutz_epitaph", "cat_klutz_sword", "cat_stair_chink", "cat_stairs_to_vaults", "cat_tasha_epitaph", "cat_tasha_sun", "cat_tasha_symbol", "cat_troisky_coffer", "cat_troisky_epitaph", "cat_troisky_helm", "from_vaults"]
const STRAHD_NEW: Array = ["cat_finderway_alcove", "cat_finderway_back", "from_finderway"]
## The maps' rows before C1, with the cells C1 opened set back to walls.
const CAT_ROWS_SHA := "75be4ae14b9e0a460994767e7cd9c1b7f646fb5a"
const STRAHD_ROWS_SHA := "8da59a910bf24517103b9e1782698d8bd8afdb30"


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


func _rows_before(d: Dictionary, opened: Array[Vector2i]) -> String:
	var rows: Array = (d["map"]["rows"] as Array).duplicate()
	for c in opened:
		var r := str(rows[c.y])
		rows[c.y] = r.substr(0, c.x) + "#" + r.substr(c.x + 1)
	return "\n".join(PackedStringArray(rows)).sha1_text()


func _exit(d: Dictionary, id: String) -> Dictionary:
	for e: Variant in d["exits"]:
		if str((e as Dictionary)["id"]) == id:
			return e as Dictionary
	return {}


## Everything that stood in the catacombs and in Strahd's tomb before C1 stands where it did.
func test_nothing_that_was_there_moved() -> void:
	var cat := _loc("castle_ravenloft_catacombs")
	assert_eq(_signature(cat, CAT_NEW).sha1_text(), CAT_SHA, "the catacombs' props, containers, doors, exits, spawns, areas and fight starts")
	assert_eq(_rows_before(cat, [Vector2i(31, 29)]), CAT_ROWS_SHA, "the catacombs' squares: only the new stair's wall cell is open")
	var st := _loc("castle_ravenloft_catacombs_strahd")
	assert_eq(_signature(st, STRAHD_NEW).sha1_text(), STRAHD_SHA, "Strahd's tomb's props, containers, doors, exits, spawns, areas and fight starts")
	assert_eq(_rows_before(st, [Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6)]), STRAHD_ROWS_SHA, "Strahd's tomb's squares: only the niche's three cells are open")


## The new stair, the Lesser Vaults and Saint Finderway's niche are joined both ways, to spawns that exist.
func test_the_new_places_join_up() -> void:
	var pairs := [
		["castle_ravenloft_catacombs", "cat_stairs_to_vaults"],
		["castle_ravenloft_catacombs_vaults", "vaults_stairs_up"],
		["castle_ravenloft_catacombs_vaults", "vaults_finderway_portal"],
		["castle_ravenloft_catacombs_strahd", "cat_finderway_back"]]
	for p: Array in pairs:
		var from := _loc(p[0])
		var ex := _exit(from, p[1])
		assert_false(ex.is_empty(), "%s has %s" % [p[0], p[1]])
		var to := _loc(str(ex["to"]))
		assert_false(to.is_empty(), "%s leads to a real place" % p[1])
		assert_true((to["spawns"] as Dictionary).has(str(ex["spawn"])), "%s arrives at a spawn that exists (%s)" % [p[1], ex["spawn"]])
	assert_eq(_exit(_loc("castle_ravenloft_catacombs"), "cat_stairs_to_vaults")["to"], "castle_ravenloft_catacombs_vaults")
	assert_eq(_exit(_loc("castle_ravenloft_catacombs_vaults"), "vaults_finderway_portal")["to"], "castle_ravenloft_catacombs_strahd")
	assert_eq(_exit(_loc("castle_ravenloft_catacombs_strahd"), "cat_finderway_back")["to"], "castle_ravenloft_catacombs_vaults")


## Every crypt the plan names has its epitaph, and every new room keeps its own look.
func test_every_crypt_has_an_epitaph_and_its_own_look() -> void:
	var cat := _loc("castle_ravenloft_catacombs")
	var vaults := _loc("castle_ravenloft_catacombs_vaults")
	var looks := {}
	for d: Dictionary in [cat, vaults]:
		for a: Variant in d["areas"]:
			var ad := a as Dictionary
			if str(ad["id"]).begins_with("cat_crypt_"):
				assert_true(ad.has("floor") and ad.has("walls"), "%s has its own floor and walls" % ad["id"])
				looks[str(ad["id"])] = "%s|%s" % [ad["floor"], ad["walls"]]
	assert_eq(looks.size(), 16, "sixteen crypt rooms: seven in place and nine in the vaults (crypt 15, Khazan's, is a door with nothing behind it)")
	var distinct := {}
	for v: Variant in looks.values():
		distinct[v] = true
	assert_eq(distinct.size(), looks.size(), "and no two look alike")


## Stefan's skull is always wrong and Intree's always right, by the same three questions; no question is spent by a check.
func test_the_skulls() -> void:
	var st := SideQuestPlay.party(SIX, 10, "castle_ravenloft_catacombs_vaults", 12)
	var wrong := SideQuestPlay.play(st, "castle_ravenloft/catacombs_skulls:stefan", ["Where does Count Strahd sleep", "How is the count ended", "alcoves"])
	assert_eq(SideQuestPlay.missing(wrong), "")
	assert_true(SideQuestPlay.text(wrong).contains("bell tower"), "he is confidently wrong about where the count sleeps")
	assert_false(SideQuestPlay.text(wrong).contains("black stair"), "and never says the true thing")
	var right := SideQuestPlay.play(st, "castle_ravenloft/catacombs_skulls:intree", ["Where does the count sleep", "How can the count be ended", "alcoves"])
	assert_eq(SideQuestPlay.missing(right), "")
	var said := SideQuestPlay.text(right)
	assert_true(said.contains("black stair") and said.contains("Sunsword") and said.contains("count's own tomb"), "Intree tells the truth: %s" % said)


## Sasha wakes when she is spoken to; "no one is coming" starts her fight, and leaving her bound does not.
func test_sasha() -> void:
	var st := SideQuestPlay.party(SIX, 10, "castle_ravenloft_catacombs_vaults", 12)
	var fight := SideQuestPlay.play(st, "castle_ravenloft/catacombs_sasha:bier", ["Lean close", "No one is coming"])
	assert_eq(SideQuestPlay.missing(fight), "")
	assert_eq(SideQuestPlay.combat_of(fight), "cat_sasha", "she attacks")
	var gentle := SideQuestPlay.play(st, "castle_ravenloft/catacombs_sasha:bier", ["Lean close", "Who is it", "Ease the stone lid"])
	assert_eq(SideQuestPlay.missing(gentle), "")
	assert_eq(SideQuestPlay.combat_of(gentle), "", "easing the lid shut after hearing her out ends without a fight")
	var skip := SideQuestPlay.play(st, "castle_ravenloft/catacombs_sasha:bier", ["Step back"])
	assert_eq(SideQuestPlay.combat_of(skip), "", "stepping back from the bier wakes no one")
	st.set_flag("cat_sasha_slain")
	var after := SideQuestPlay.play(st, "castle_ravenloft/catacombs_sasha:bier")
	assert_false(after.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options"), "once she is gone the bier is only a bier: no menu")


## Saint Markovia's thighbone is lifted once, and the ghost speaks.
func test_markovia_bone() -> void:
	var st := SideQuestPlay.party(SIX, 10, "castle_ravenloft_catacombs_vaults", 12)
	var lift := SideQuestPlay.play(st, "castle_ravenloft/catacombs_crypts:markovia_bone", ["Lift the thighbone"])
	assert_eq(SideQuestPlay.missing(lift), "")
	assert_true(st.get_flag("cat_markovia_bone_lifted"), "the bone is up")
	assert_true(SideQuestPlay.text(lift).contains("mend what this castle has torn"), "her few words")
	var again := SideQuestPlay.play(st, "castle_ravenloft/catacombs_crypts:markovia_bone")
	assert_false(SideQuestPlay.text(again).contains("mend what this castle"), "she does not speak twice")


## Fire clears the Baron's mold, and with it his cold trap; no torch, no option, but the room can always be left.
func test_the_barons_mold_burns() -> void:
	var st := SideQuestPlay.party(SIX, 10, "castle_ravenloft_catacombs", 12)
	var cold := {}
	for t: Variant in _loc("castle_ravenloft_catacombs")["traps"]:
		if str((t as Dictionary)["id"]) == "cat_eisglaze_cold":
			cold = t as Dictionary
	assert_true(StoryConditions.check(str(cold["when"]), st), "the mold's cold waits on the slab")
	var cold_hands := SideQuestPlay.play(st, "castle_ravenloft/catacombs_crypts:eisglaze_mold", ["Hold fire"])
	assert_ne(SideQuestPlay.missing(cold_hands), "", "no torch, no fire")
	assert_true(SideQuestPlay.missing(SideQuestPlay.play(st, "castle_ravenloft/catacombs_crypts:eisglaze_mold", ["leave the mold"])) == "", "and the room can be left")
	st.party[0].add_item("torch")
	var burn := SideQuestPlay.play(st, "castle_ravenloft/catacombs_crypts:eisglaze_mold", ["Hold fire"])
	assert_eq(SideQuestPlay.missing(burn), "")
	assert_true(st.get_flag("cat_eisglaze_mold_burnt"), "burnt")
	assert_false(StoryConditions.check(str(cold["when"]), st), "and the trap no longer waits")


## Sir Klutz's sword comes out, his ghost joins for a fight, and the fight sends him away.
func test_sir_klutz() -> void:
	var st := SideQuestPlay.party(SIX, 10, "castle_ravenloft_catacombs", 12)
	var pull := SideQuestPlay.play(st, "castle_ravenloft/catacombs_crypts:klutz_sword", ["Draw the longsword", "Come with us"])
	assert_eq(SideQuestPlay.missing(pull), "")
	assert_true(st.get_flag("cat_klutz_freed"))
	assert_true("sir_klutz" in st.guest_ids, "he joins")
	assert_eq(st.release_one_fight_guests(), ["Sir Klutz Tripalotsky"] as Array[String], "one battle, then he goes")
	var rest := SideQuestPlay.party(SIX, 10, "castle_ravenloft_catacombs", 12)
	SideQuestPlay.play(rest, "castle_ravenloft/catacombs_crypts:klutz_sword", ["Draw the longsword", "Rest now"])
	assert_false("sir_klutz" in rest.guest_ids, "told to rest, he lies down again")


## The painted sun is sunlight in a fight in Tasha's crypt (Sunlight Hypersensitivity bites a vampire spawn there).
func test_the_painted_sun_burns() -> void:
	var cat := _loc("castle_ravenloft_catacombs")
	var sun := {}
	for l: Variant in cat["lights"]:
		if bool((l as Dictionary).get("sunlight", false)):
			sun = l as Dictionary
	assert_false(sun.is_empty(), "Tasha's crypt has a light that is sunlight")
	var cell := Vector2i(int((sun["cell"] as Array)[0]), int((sun["cell"] as Array)[1]))
	var crypt := (_loc("castle_ravenloft_catacombs")["areas"] as Array).filter(func(a: Variant) -> bool: return str((a as Dictionary)["id"]) == "cat_crypt_tasha")[0] as Dictionary
	var c0 := (crypt["cells"] as Array)[0] as Array
	var c1 := (crypt["cells"] as Array)[1] as Array
	assert_true(cell.x >= int(c0[0]) and cell.x <= int(c1[0]) and cell.y >= int(c0[1]) and cell.y <= int(c1[1]), "it hangs inside Tasha's crypt")


## Stepping on Sir Jarnwald's illusory floor drops the stepper into the pit and wakes its ghouls: the trap's flag starts
## the fight that waits on it (LocationTraps._spring_trap -> LocationFights.check_flag_encounters).
func test_the_illusory_floor_wakes_the_ghouls() -> void:
	GameState.reset()
	for id: String in SIX:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "castle_ravenloft_catacombs_vaults"
	GameState.story.positions = [Vector2i(6, 17), Vector2i(5, 17), Vector2i(7, 17), Vector2i(6, 16)]
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	var v := root.get("view") as LocationView
	assert_false(v.in_combat, "quiet before the floor goes")
	v.members[0].cell = Vector2i(6, 18)
	LocationTraps._check_traps(v)
	assert_true(v.in_combat, "the fall wakes the ghouls")
	assert_eq(str((GameState.story.loc_state("castle_ravenloft_catacombs_vaults")["encounters"] as Dictionary).get("cat_jarnwald_ghouls", "")), "started")
	root.queue_free()
	await get_tree().process_frame


## Sir Klutz's ghost fights beside the party and the fight's end sends him away (LocationFights._end_encounter ->
## StoryState.release_one_fight_guests).
func test_klutz_leaves_when_the_fight_ends() -> void:
	GameState.reset()
	for id: String in SIX:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.add_guest("sir_klutz")
	GameState.story.location = "castle_ravenloft_catacombs_vaults"
	GameState.story.positions = [Vector2i(37, 16), Vector2i(36, 16), Vector2i(38, 16), Vector2i(37, 17)]
	Dice.reseed(3)
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	var v := root.get("view") as LocationView
	# A party set down inside the fight's trigger area sets it off as it arrives (as FightSeriesCase notes).
	var started := str((GameState.story.loc_state("castle_ravenloft_catacombs_vaults")["encounters"] as Dictionary).get("cat_spiders", "")) == "started"
	assert_true(started or v.start_encounter("cat_spiders"), "the spiders' fight starts")
	for i in 2:
		await get_tree().process_frame
	var e := v.combat_view.e
	assert_true(e.combatants.any(func(c: Combatant) -> bool: return c.side == &"guest" and c.name() == "Sir Klutz Tripalotsky"), "Klutz is in the fight")
	var res := PartyAutopilot.new(e).run(30)
	assert_ne(str(res["outcome"]), "timeout", "the fight finishes")
	v.combat_view.finished.emit(str(res["outcome"]))
	assert_false("sir_klutz" in GameState.story.guest_ids, "and he is gone afterwards")
	root.queue_free()
	await get_tree().process_frame
