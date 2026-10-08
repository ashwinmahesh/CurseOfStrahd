extends TestCase
## Madam Eva's respec (owner reports, 2026-10-08): the hero picker has a way back, so does the altar's; the rebuild's
## equipment step shows every option with its gold (option B is often coins alone); a prebuilt hero keeps their look;
## the four retired heroes' portraits are never offered.

const RETIRED: Array[String] = ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]


func _party() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	st.party.append(TestChars.pregen("liriel_dawnsong", 1))
	return st


func _labels(n: Node) -> String:
	var out: Array[String] = []
	for c in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	for c in n.find_children("*", "Button", true, false):
		out.append((c as Button).text)
	return "\n".join(out)


func test_madam_eva_lets_you_back_out_of_the_reading() -> void:
	var st := _party()
	var r := DialogueRunner.new(st, DiceRoller.new(2))
	r.start("svalich_road/madam_eva:personal")
	assert_eq(str(r.next()["kind"]), "line")
	var pick := r.next()
	assert_eq(str(pick["kind"]), "pick_member")
	var members := pick["members"] as Array
	assert_eq(members.size(), 3, "both heroes, then the way back")
	assert_eq(str(members.back()), DialogueRunner.BACK_OUT["respec"])
	var b := r.pick_member(members.size() - 1)
	assert_eq(str(b["kind"]), "line", "no creator opens")
	assert_true(str(b["text"]).contains("Keep the road you have"), str(b["text"]))
	assert_eq(str(r.next()["kind"]), "options", "back to her menu")
	assert_eq(st.party.size(), 2)


func test_rebuilding_someone_goes_on_as_before() -> void:
	var st := _party()
	var r := DialogueRunner.new(st, DiceRoller.new(2))
	r.start("svalich_road/madam_eva:personal")
	r.next()
	r.next()
	var b := r.pick_member(1)
	assert_eq(str(b["kind"]), "respec")
	assert_eq(int(b["index"]), 1)
	st.last_check = true   # game_root.respec, when the creator finishes
	b = r.next()
	assert_true(str(b["text"]).contains("You are who you are now"), str(b["text"]))
	r.start("svalich_road/madam_eva:personal")
	r.next()
	r.next()
	r.pick_member(0)
	st.last_check = false   # or when it's cancelled
	assert_true(str(r.next()["text"]).contains("Keep the road you have"), "backing out of the creator says so too")


func test_the_altar_can_be_refused_at_the_last_moment() -> void:
	var st := _party()
	var r := DialogueRunner.new(st, DiceRoller.new(2))
	r.start("death_house/altar:sacrifice_done")
	var pick := r.next()
	assert_eq(str(pick["kind"]), "pick_member")
	var members := pick["members"] as Array
	assert_eq(str(members.back()), DialogueRunner.BACK_OUT["sacrifice"])
	var b := r.pick_member(members.size() - 1)
	assert_eq(str(b["kind"]), "line")
	assert_true(str(b["text"]).contains("No one moves"), str(b["text"]))
	assert_eq(st.party.size(), 2, "nobody lost")
	assert_true(st.fallen.is_empty())
	assert_false(bool(st.get_flag("death_house_sacrificed")))
	r.next()
	assert_eq(r.node, "choose", "back to the altar's choice")


func test_a_rebuild_shows_every_equipment_option_with_its_gold() -> void:
	var st := _party()
	var cs := CreationScreen.new()
	add_child(cs)
	var start: Array[Dictionary] = [CreationScreen.rebuild_start(st.party[1])]
	cs.open_with(start, 1)
	assert_true(cs.rebuilding)
	var b := cs.b()
	b.set_class("wizard")
	b.set_background("acolyte")
	b.set_species("human")
	cs.step = CharacterBuilder.Step.EQUIPMENT
	cs.call("_draw")
	var text := _labels(cs)
	assert_true(text.contains("Option B"), "class and background option B are offered")
	assert_true(text.contains("50 gp to buy your own gear"), "acolyte's option B is its gold:\n" + text)
	assert_true(text.contains("8 gp"), "option A's coins are listed with its gear")
	assert_true(text.contains("keeps everything they carry"), "the rebuild says no gear is handed out again")
	cs.queue_free()


func test_a_prebuilt_hero_keeps_their_look() -> void:
	var st := _party()
	var liriel := st.party[1]
	var start := CreationScreen.rebuild_start(liriel)
	assert_eq(str((start["appearance"] as Dictionary)["art"]), "liriel_dawnsong")
	var cs := CreationScreen.new()
	add_child(cs)
	var starting: Array[Dictionary] = [start]
	cs.open_with(starting, 1)
	cs.step = CharacterBuilder.Step.APPEARANCE
	cs.call("_draw")
	var text := _labels(cs)
	assert_true(text.contains("look stays as it is"), text)
	for id in RETIRED:
		assert_false(text.contains(id.get_slice("_", 0).capitalize()), "%s's look isn't offered" % id)
	cs.queue_free()


func test_the_retired_heroes_are_never_offered_as_looks() -> void:
	var looks := CreationScreen.looks()
	assert_true(looks.size() >= 6, str(looks))
	for id in RETIRED:
		assert_false(id in looks, "%s retired" % id)
	for id in looks:
		assert_true(ResourceLoader.exists("res://art/portraits/%s.png" % id), "%s has a portrait" % id)
	var cs := CreationScreen.new()
	add_child(cs)
	var empty: Array[Dictionary] = []
	cs.open_with(empty)
	cs.step = CharacterBuilder.Step.APPEARANCE
	cs.call("_draw")
	var text := _labels(cs)
	assert_true(text.contains("Thistle"), "the four-slot flow offers the current heroes:\n" + text)
	assert_false(text.contains("Ilse"), "not the retired ones")
	cs.queue_free()
