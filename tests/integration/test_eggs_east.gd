extends TestCase
## Package R5 of the small-winks plan (docs/story/eggs.md, docs/plans/gemini_eggs/r5/): the lake, Van Richten's Tower,
## Berez and Mount Baratok. The pedlar's second and third tins at the reedy inlet and on the marsh track, the jar marked
## DO NOT, a hungry orb under the Mad Mage's furs (fed a scroll, it lights his hearth), Mordenkainen on whose it is, and
## a saucer on his sill. Each waits where the player has to look, none moves a main story flag, and every conversation
## they touch keeps its way out.

const PARTY: Array[String] = ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]
const M := "mount_baratok/"

var root: Node
var said: Array[String] = []


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	get_tree().paused = false
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _boot(loc_id: String) -> LocationView:
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 9)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = loc_id
	GameState.story.minute_of_day = 11 * 60
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	said.clear()
	var v := root.get("view") as LocationView
	v.narration.connect(func(text: String) -> void: said.append(text))
	v.toast.connect(func(text: String) -> void: said.append(text))
	return v


func _spec(loc_id: String, id: String) -> Dictionary:
	for t: Variant in Compendium.shared().get_entry("locations", loc_id).get("props", []):
		if str((t as Dictionary)["id"]) == id:
			return t as Dictionary
	return {}


func _action(v: LocationView, cell: Vector2i, id: String) -> Dictionary:
	for a: Variant in v.actions_at(cell)["actions"]:
		if str((a as Dictionary)["id"]) == id:
			return a as Dictionary
	return {}


func _said(part: String) -> bool:
	return said.any(func(s: String) -> bool: return s.contains(part))


func _st(location: String) -> StoryState:
	return SideQuestPlay.party(PARTY, 9, location, 11)


## The leader rolls and fails, then the next best hand rolls and passes.
func _fail_then_pass(v: LocationView, loc_id: String, spec: Dictionary, check_id: String) -> Character:
	var check := WorldChecks.find(spec, check_id)
	var who := v.leader().creature as Character
	WorldChecks.record(GameState.story, loc_id, check, who, false)
	LocationChecks._resolve(v, spec, check, who, false)
	assert_false(WorldChecks.done(GameState.story, loc_id, check), "a failure is not done")
	var failure_said := said.duplicate()
	said.clear()
	var next := WorldChecks.roller(GameState.story, loc_id, check)
	assert_true(next != null and next != who, "another hand may still try")
	WorldChecks.record(GameState.story, loc_id, check, next, true)
	LocationChecks._resolve(v, spec, check, next, true)
	assert_true(WorldChecks.done(GameState.story, loc_id, check), "a success is done")
	said.append_array(failure_said)
	return next


func test_the_reedy_inlets_hummock_needs_a_shovel_and_holds_the_pedlars_second_tin() -> void:
	var v := await _boot("lake_inlet")
	var spec := _spec("lake_inlet", "inlet_hummock")
	var cell := LocationView._cell(spec["cell"])
	assert_false(v.thing_at(cell).is_empty(), "the hummock is on the board")
	assert_true(_action(v, cell, "check:inlet_dig").is_empty(), "no shovel, no digging")
	(v.leader().creature as Character).add_item("shovel")
	var line := _action(v, cell, "check:inlet_dig")
	assert_false(line.is_empty(), "with a shovel in the party it can be dug: %s" % [v.actions_at(cell)["actions"]])
	assert_true(str(line["label"]).begins_with("Dig here (Athletics DC 10"), str(line["label"]))
	var gold := GameState.story.gold
	var digger := _fail_then_pass(v, "lake_inlet", spec, "inlet_dig")
	assert_true(_said("cold grey soup"), "the failure has its line: %s" % [said])
	assert_true(_said("rusted box smelling of tallow"), "and the success: %s" % [said])
	assert_eq(GameState.story.gold, gold + 40.0)
	assert_true(digger.carries("potion_of_healing_greater"), "a Potion of Greater Healing goes to whoever dug")
	assert_true(bool(GameState.story.get_flag("eggs_spade_second", false)))
	var entry := JournalScreen._codex_entry("pedlar_note_inlet")
	assert_eq(str(entry["title"]), "A pedlar's second note")
	assert_true(str(entry["text"]).contains("where the old road drowns in the marsh"), "it points on to the marsh track")
	assert_true(str(entry["text"]).ends_with("A man who trusts his spade"), "signed, and never named")
	assert_true(Narrator.new(3).line("examine:inlet_hummock", GameState.story, digger).contains("the hole you dug"),
		"once dug, the hummock says so")


func test_the_marsh_slab_holds_the_pedlars_last_tin_and_his_spade_head() -> void:
	var v := await _boot("berez_marsh_track")
	var spec := _spec("berez_marsh_track", "marsh_spade_slab")
	var cell := LocationView._cell(spec["cell"])
	assert_false(v.thing_at(cell).is_empty(), "the slab is on the board")
	assert_true(_action(v, cell, "check:marsh_dig").is_empty(), "no shovel, no digging")
	(v.leader().creature as Character).add_item("shovel")
	var line := _action(v, cell, "check:marsh_dig")
	assert_false(line.is_empty(), "with a shovel in the party it can be dug: %s" % [v.actions_at(cell)["actions"]])
	assert_true(str(line["label"]).begins_with("Dig here (Athletics DC 12"), str(line["label"]))
	var gold := GameState.story.gold
	var digger := _fail_then_pass(v, "berez_marsh_track", spec, "marsh_dig")
	assert_true(_said("boiled cabbage"), "the failure has its line: %s" % [said])
	assert_true(_said("lard-tin"), "and the success: %s" % [said])
	assert_eq(GameState.story.gold, gold + 60.0)
	assert_true(digger.carries("pedlars_spade_head"))
	assert_true(bool(GameState.story.get_flag("eggs_spade_third", false)))
	var entry := JournalScreen._codex_entry("pedlar_note_marsh")
	assert_eq(str(entry["title"]), "A pedlar's last note")
	assert_true(str(entry["text"]).contains("take the old iron with it"), "the spade-head is the gift")
	assert_true(str(entry["text"]).ends_with("A man who trusts his spade"), "signed, and never named")
	assert_true(Narrator.new(3).line("examine:marsh_spade_slab", GameState.story, digger).contains("tipped back now"),
		"once dug, the slab says so")
	var item := Compendium.shared().item_data("pedlars_spade_head")
	assert_eq(str(item["category"]), "gear")
	assert_eq(float(item["cost_gp"]), 25.0)
	assert_true(Compendium.playable(item))
	assert_true(ArtPaths.exists("art/icons/items/pedlars_spade_head.png"), "its icon is framed")


func test_the_jar_marked_do_not_turns_to_face_whoever_looks_at_it() -> void:
	var v := await _boot("van_richtens_tower_interior")
	var spec := _spec("van_richtens_tower_interior", "vrt_jars")
	var cell := LocationView._cell(spec["cell"])
	var line := _action(v, cell, "check:jar_do_not")
	assert_false(line.is_empty(), "the jar is offered: %s" % [v.actions_at(cell)["actions"]])
	assert_true(str(line["label"]).begins_with("Look at the jar marked DO NOT (Arcana DC 13"), str(line["label"]))
	assert_false(_action(v, cell, "check:remedies_sort").is_empty(), "the shelf's own check is still there")
	var looker := _fail_then_pass(v, "van_richtens_tower_interior", spec, "jar_do_not")
	assert_true(_said("clouded thick as tallow"), "the failure has its line: %s" % [said])
	assert_true(_said("turns slowly in the jar"), "and the success: %s" % [said])
	assert_true(bool(GameState.story.get_flag("eggs_jar_seen", false)), "part two of the sky-man's three is seen")
	var entry := JournalScreen._codex_entry("jar_marked_do_not")
	assert_eq(str(entry["title"]), "The jar marked DO NOT")
	assert_true(str(entry["text"]).contains("shaped like a squid") and str(entry["text"]).contains("DO NOT OPEN"))
	assert_true(_action(v, cell, "check:jar_do_not").is_empty(), "once seen, it isn't offered again")
	assert_true(looker != null)


func test_lifting_the_furs_finds_the_orb_and_it_shows_by_the_bed() -> void:
	var v := await _boot("mount_baratok_hut")
	var bed := _spec("mount_baratok_hut", "baratok_bed")
	var orb := _spec("mount_baratok_hut", "baratok_orb")
	var cell := LocationView._cell(orb["cell"])
	assert_true(v.thing_at(cell).is_empty(), "nothing shows on the square before the furs are lifted")
	assert_false(_action(v, LocationView._cell(bed["cell"]), "check:lift_furs").is_empty(), "the bed offers it")
	var finder := _fail_then_pass(v, "mount_baratok_hut", bed, "lift_furs")
	assert_true(_said("only frost, shed hairs"), "the failure has its line: %s" % [said])
	assert_true(_said("slow violet pulse"), "and the success: %s" % [said])
	assert_true(bool(GameState.story.get_flag("eggs_orb_found", false)))
	var entry := JournalScreen._codex_entry("chalk_on_a_rag")
	assert_eq(str(entry["title"]), "Chalk on a rag")
	assert_true(str(entry["text"]).contains("Keep it fed"))
	assert_false(v.thing_at(cell).is_empty(), "the orb shows from then on: %s" % [orb])
	assert_true(finder != null)


func test_the_orb_drinks_a_level_one_scroll_and_lights_the_hearth_once() -> void:
	var st := _st("mount_baratok_hut")
	var plain := SideQuestPlay.play(st, M + "hungry_orb:orb", ["Feed it"])
	assert_ne(SideQuestPlay.missing(plain), "", "nothing to feed it without a scroll")
	var bare := SideQuestPlay.play(st, M + "hungry_orb:orb")
	assert_true(SideQuestPlay.text(bare).contains("warm as a nesting hen"), SideQuestPlay.text(bare))
	assert_eq(str(bare[-1]["kind"]), "end", "with nothing picked, the menu still lets you go")
	assert_false(st.get_flag("eggs_orb_fed", false))
	st.party[0].add_item("spell_scroll__fireball")
	st.party[0].add_item("spell_scroll_cantrip")
	var too_big := SideQuestPlay.play(st, M + "hungry_orb:orb", ["Feed it"])
	assert_ne(SideQuestPlay.missing(too_big), "", "only a first-level scroll will do, not a third-level one or a cantrip's")
	assert_true(st.party_has_item("spell_scroll__fireball"), "and those stay in their packs")
	st.party[1].add_item("spell_scroll_level_1")
	assert_true(st.party_has_item("spell_scroll_level_1"), "'any first-level scroll' finds the particular spell it became")
	var fed := SideQuestPlay.play(st, M + "hungry_orb:orb", ["Feed it"])
	assert_eq(SideQuestPlay.missing(fed), "")
	var text := SideQuestPlay.text(fed)
	assert_true(text.contains("contented purr") and text.contains("clean yellow flame"), text)
	assert_true(st.get_flag("eggs_orb_fed", false))
	assert_false(st.party_has_item("spell_scroll_level_1"), "the scroll is spent")
	assert_true(st.party_has_item("spell_scroll__fireball"), "and only that one")
	assert_eq(str(fed[-1]["kind"]), "end")
	var again := SideQuestPlay.play(st, M + "hungry_orb:orb")
	assert_true(SideQuestPlay.text(again).contains("the fire it lit is still burning"), SideQuestPlay.text(again))
	assert_false(again.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options"), "it eats once")


func test_the_hearth_keeps_a_saucer_on_its_sill_and_burns_once_the_orb_is_fed() -> void:
	var st := _st("mount_baratok_hut")
	var who := st.party[0]
	var seen := {}
	for seed in 12:
		seen[Narrator.new(seed).line("examine:baratok_cold_hearth", st, who)] = true
	assert_true(seen.keys().any(func(l: Variant) -> bool: return str(l).contains("saucer of fresh cream")), "the saucer is among its lines")
	assert_true(seen.keys().any(func(l: Variant) -> bool: return str(l).contains("never had a fire")), "and so is the old one")
	st.set_flag("eggs_orb_fed")
	for seed in 6:
		assert_true(Narrator.new(seed).line("examine:baratok_cold_hearth", st, who).contains("A clean yellow fire burns"),
			"fed, it burns")


func test_mordenkainen_says_whose_the_orb_is_once_it_is_found_and_the_talk_still_ends() -> void:
	var st := _st("mount_baratok_hut")
	st.set_flag("mordenkainen_restored")
	var early := SideQuestPlay.play(st, M + "mordenkainen:start", ["Whose is it"])
	assert_ne(SideQuestPlay.missing(early), "", "the question waits until the orb is found")
	st.set_flag("eggs_orb_found")
	var told := SideQuestPlay.play(st, M + "mordenkainen:start", ["Whose is it"])
	assert_eq(SideQuestPlay.missing(told), "")
	var text := SideQuestPlay.text(told)
	assert_true(text.contains("old beard with a pipe") and text.contains("breastbone"), text)
	assert_true(st.get_flag("eggs_orb_asked", false))
	assert_eq(str(told[-1]["kind"]), "end", "and the talk still ends")
	var again := SideQuestPlay.play(st, M + "mordenkainen:start", ["Whose is it"])
	assert_ne(SideQuestPlay.missing(again), "", "he says it once")
	var mad := _st("mount_baratok_hut")
	mad.set_flag("eggs_orb_found")
	var before := SideQuestPlay.play(mad, M + "mordenkainen:start", ["Whose is it"])
	assert_ne(SideQuestPlay.missing(before), "", "the broken mage has nothing to say about it")


func test_the_digs_and_the_orb_keep_two_from_every_fight_start() -> void:
	for pair: Array in [["lake_inlet", "inlet_hummock"], ["berez_marsh_track", "marsh_spade_slab"], ["mount_baratok_hut", "baratok_orb"]]:
		var loc := Compendium.shared().get_entry("locations", str(pair[0]))
		var c := LocationView._cell(_spec(str(pair[0]), str(pair[1]))["cell"])
		var starts: Array = (loc.get("foe_spots", []) as Array).duplicate()
		for e: Variant in loc.get("encounters", []):
			for m: Variant in (e as Dictionary).get("monsters", []):
				if (m as Dictionary).has("cell"):
					starts.append((m as Dictionary)["cell"])
		for s: Variant in starts:
			var sc := LocationView._cell(s)
			assert_true(maxi(absi(c.x - sc.x), absi(c.y - sc.y)) >= 2, "%s at %s is within 2 of a fight start at %s" % [pair[1], c, sc])


func test_the_winks_set_only_side_flags() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/world_checks.json"))
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/eggs_east.json"))
	var world_ids: Array = (world["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	var own_ids: Array = (own["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	for id: String in ["eggs_spade_second", "eggs_spade_third", "eggs_orb_found", "eggs_jar_seen"]:
		assert_true(id in world_ids, "%s is registered with the world checks" % id)
	assert_eq(own_ids, ["eggs_orb_fed", "eggs_orb_asked"], "the conversations' flags are the package's own, and that is all")
