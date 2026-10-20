extends TestCase
## Package R2 of the small-winks plan (docs/story/eggs.md, docs/plans/gemini_eggs/r2/): Tser Pool and the Svalich road.
## The owl the camp's children call an owlbear, the camp dog's pat, a druid a little too fond of Lavinia's bear,
## Fennimore's research assistant and his rival's guide, and Madam Eva's word for a hero named Tav. Each waits where
## the player has to look, none moves a main story flag, and every conversation they touch keeps its way out.

const PARTY: Array[String] = ["thistle", "godrick_pendlebrook", "wren_featherfoot", "ratatoille"]


func _party(location: String, hour: int = 12, level: int = 4) -> StoryState:
	return SideQuestPlay.party(PARTY, level, location, hour)


func _offered(beats: Array[Dictionary], text: String) -> bool:
	return beats.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options" and (b["options"] as Array).any(
		func(o: Variant) -> bool: return str((o as Dictionary)["text"]).contains(text)))


func test_the_owl_on_the_stage_rail_wears_a_bearskin_cap_until_someone_eases_it_off() -> void:
	var st := _party("tser_pool")
	assert_eq(SideQuestPlay.standing(st, "tser_pool", "tser_owl"), "svalich_road/tser_camp:owl", "the owl sits by the stage")
	var npc := Compendium.shared().get_entry("npcs", "tser_owl")
	assert_eq(str(npc["sprite"]), "owl", "on the owl's own art")
	assert_eq(str(npc["monster"]), "owl")
	var first := SideQuestPlay.play(st, "svalich_road/tser_camp:owl")
	assert_true(SideQuestPlay.text(first).contains("OWLBEAR. DO NOT FEED."), SideQuestPlay.text(first))
	assert_eq(str(first[-1]["kind"]), "end", "leaving it be is always there")
	# Eased off (the roll forced to pass by trying seeds): the cap comes off once, and Thistle and Wren approve.
	var freed := false
	for seed: int in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		var beats := SideQuestPlay.play(st, "svalich_road/tser_camp:owl", ["Ease the cap off"], seed)
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(str(beats[-1]["kind"]), "end")
		if st.get_flag("eggs_owl_uncapped", false):
			assert_true(SideQuestPlay.text(beats).contains("as if weighing an insult"), SideQuestPlay.text(beats))
			freed = true
			break
		assert_true(SideQuestPlay.text(beats).contains("dares your fingers"), "a failure has its own line")
	assert_true(freed, "a gentle hand gets the cap off in the end")
	var after := SideQuestPlay.play(st, "svalich_road/tser_camp:owl")
	assert_true(SideQuestPlay.text(after).contains("sits bareheaded"), SideQuestPlay.text(after))
	assert_false(_offered(after, "Ease the cap off"), "it comes off once")


func test_the_owl_knows_it_is_an_owl_when_spoken_to() -> void:
	var st := _party("tser_pool")
	var beats := SideQuestPlay.play(st, "svalich_road/tser_camp:owl", ["Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var text := SideQuestPlay.text(beats)
	assert_true(text.contains("Thistle casts Speak with Animals as a Ritual"), text)
	assert_true(text.contains("any field mouse knows my shadow"), text)
	assert_true(st.get_flag("eggs_owl_heard", false))
	assert_eq(str(beats[-1]["kind"]), "end")
	var again := SideQuestPlay.play(st, "svalich_road/tser_camp:owl")
	assert_false(_offered(again, "how it likes being a bear"), "it says its piece once")


func test_without_the_spell_the_tser_dog_can_still_be_petted_and_left() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook", "ratatoille"], 4, "tser_pool", 12)
	var leave := SideQuestPlay.play(st, "svalich_road/tser_camp:dog")
	assert_eq(str(leave[-1]["kind"]), "end", "with nothing picked the dog's menu still lets you go")
	assert_false(st.get_flag("eggs_dog_tser", false))
	var pet := SideQuestPlay.play(st, "svalich_road/tser_camp:dog", ["Pet the dog"])
	assert_eq(SideQuestPlay.missing(pet), "")
	assert_true(SideQuestPlay.text(pet).contains("the camp's common thief"), SideQuestPlay.text(pet))
	assert_true(st.get_flag("eggs_dog_tser", false), "one of the five good dogs")
	assert_eq(str(pet[-1]["kind"]), "end")
	var after := SideQuestPlay.play(st, "svalich_road/tser_camp:dog")
	assert_false(after.any(func(b: Dictionary) -> bool: return str(b["kind"]) == "options"),
		"once petted, without the spell, it is only a dog again: no menu at all")


func _druid_party() -> StoryState:
	var st := _party("tser_pool")
	var hedda := Pregens.build("hedda_ironvow", 5)
	var up := LevelUpController.new(hedda)
	assert_true(up.choose_class("druid"), "Hedda can take a level of Druid")
	st.party[1] = up.preview()
	assert_true(st.party.any(func(ch: Character) -> bool: return ch.class_level_of("druid") > 0), "a druid is along")
	return st


func test_a_druid_offers_to_dance_the_bears_part_and_lavinia_answers() -> void:
	var st := _druid_party()
	st.set_quest_stage("the_dancing_bear", "asked")
	st.set_quest_stage("the_dancing_bear", "found")
	st.set_flag("bujor_home")
	var beats := SideQuestPlay.play(st, "svalich_road/the_dancing_bear:thanks")
	var text := SideQuestPlay.text(beats)
	assert_true(text.contains("a very fine shoulder for a waltz"), text)
	assert_true(text.contains("Hold your pelt, friend"), "Lavinia answers the druid")
	assert_eq(str(beats[-1]["kind"]), "end")
	assert_eq(st.quest_stage("the_dancing_bear"), "done", "the quest ends as ever")

	var woods := _druid_party()
	woods.set_quest_stage("the_dancing_bear", "asked")
	woods.set_quest_stage("the_dancing_bear", "found")
	var gone := SideQuestPlay.text(SideQuestPlay.play(woods, "svalich_road/the_dancing_bear:thanks"))
	assert_true(gone.contains("borrow four paws") and gone.contains("it's his roof now"), gone)


func test_without_a_druid_lavinia_says_nothing_of_it() -> void:
	var st := _party("tser_pool")
	st.set_quest_stage("the_dancing_bear", "asked")
	st.set_quest_stage("the_dancing_bear", "found")
	st.set_flag("bujor_home")
	var text := SideQuestPlay.text(SideQuestPlay.play(st, "svalich_road/the_dancing_bear:thanks"))
	assert_false(text.contains("waltz") or text.contains("Hold your pelt"), text)


func test_fennimores_research_assistant_has_one_piece_of_advice() -> void:
	var st := _party("svalich_crossroads")
	var beats := SideQuestPlay.play(st, "svalich_road/fennimore:start", ["What's moving in your coat", "Cast Speak with Animals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var text := SideQuestPlay.text(beats)
	assert_true(text.contains("research assistant") and text.contains("brief inconvenience") and text.contains("Always those first"), text)
	assert_true(text.contains("Pocket-sized terror"), "Wren has a word for it")
	assert_true(st.get_flag("eggs_fennimore_pocket", false))
	assert_eq(str(beats[-1]["kind"]), "end", "back to his menu, and goodbye")
	var plain := SideQuestPlay.party(["godrick_pendlebrook", "ratatoille"], 4, "svalich_crossroads", 12)
	var no_spell := SideQuestPlay.play(plain, "svalich_road/fennimore:start", ["What's moving in your coat"])
	assert_eq(SideQuestPlay.missing(no_spell), "")
	assert_false(SideQuestPlay.text(no_spell).contains("sky-roof"), "without the spell a hamster is only a hamster")
	assert_eq(str(no_spell[-1]["kind"]), "end")


func test_fennimore_gives_away_his_rivals_guide_once_his_own_book_is_shown() -> void:
	var st := _party("svalich_crossroads")
	var early := SideQuestPlay.play(st, "svalich_road/fennimore:start", ["any rivals"])
	assert_ne(SideQuestPlay.missing(early), "", "he talks shop only once his own book is out")
	st.set_quest_stage("fennimores_guide", "asked")
	var beats := SideQuestPlay.play(st, "svalich_road/fennimore:start", ["any rivals"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("one glass eye and no shame"), SideQuestPlay.text(beats))
	assert_true(st.party_has_item("rival_monster_guide"), "his annotated copy goes into a pack")
	assert_eq(str(beats[-1]["kind"]), "end")
	var item := Compendium.shared().item_data("rival_monster_guide")
	assert_eq(str(item["category"]), "gear")
	assert_true(Compendium.playable(item))
	assert_true(str(item["text"]).contains("affectionate") and str(item["text"]).contains("A.F."), str(item["text"]))
	var again := SideQuestPlay.play(st, "svalich_road/fennimore:start", ["any rivals"])
	assert_ne(SideQuestPlay.missing(again), "", "one copy")


func test_madam_eva_remarks_on_a_hero_named_tav_once_after_the_reading() -> void:
	var st := _party("tser_pool_eva_tent")
	st.set_flag("eva_reading_done")
	var plain := SideQuestPlay.text(SideQuestPlay.play(st, "svalich_road/madam_eva:start"))
	assert_false(plain.contains("worn so thin"), "no remark for the party's own names")
	# A custom hero the player named Tav (hero_named reads the name typed, first word or whole).
	st.party[3].name = "Tav Hollowell"
	var said := SideQuestPlay.play(st, "svalich_road/madam_eva:start")
	assert_true(SideQuestPlay.text(said).contains("worn so thin by old hands"), SideQuestPlay.text(said))
	assert_eq(str(said[-1]["kind"]), "end")
	assert_false(SideQuestPlay.text(SideQuestPlay.play(st, "svalich_road/madam_eva:start")).contains("worn so thin"), "once")


func test_the_owl_keeps_two_from_every_fight_start() -> void:
	var loc := Compendium.shared().get_entry("locations", "tser_pool")
	var c := Vector2i(-1, -1)
	for n: Variant in loc["npcs"]:
		if str((n as Dictionary)["npc"]) == "tser_owl":
			c = LocationView._cell((n as Dictionary)["cell"])
	assert_ne(c, Vector2i(-1, -1))
	for e: Variant in loc.get("encounters", []):
		for m: Variant in (e as Dictionary).get("monsters", []):
			if (m as Dictionary).has("cell"):
				var s := LocationView._cell((m as Dictionary)["cell"])
				assert_true(maxi(absi(c.x - s.x), absi(c.y - s.y)) >= 2, "the owl at %s is within 2 of a fight start at %s" % [c, s])


func test_the_winks_set_only_the_packages_own_flags() -> void:
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/eggs_svalich.json"))
	var ids: Array = (own["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	assert_eq(ids, ["eggs_dog_tser", "eggs_owl_uncapped", "eggs_owl_heard", "eggs_fennimore_pocket", "eggs_rival_guide_given",
		"eggs_eva_name"])
