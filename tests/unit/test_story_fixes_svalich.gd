extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's findings on the Svalich road and in the Tarokka's treasures ("QA - Wiki
## Walkthrough Findings" in the vault, #63, #64, #67, #70-#72), each played the way a party meets it.


## Finding 63: Madam Eva's own treasure was never marked found, so her chest held a second copy. Older saves mend.
func test_evas_treasure_is_found_once() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 2, "tser_pool_eva_tent", 20)
	st.tarokka = {"tome": "stars_2", "symbol": "swords_6", "sword": "coins_7", "ally": "mists", "enemy": "donjon"}
	SideQuestPlay.play(st, "svalich_road/madam_eva:treasure_here", ["Goodbye"])
	assert_true(st.party_has_item("tome_of_strahd"))
	assert_true(bool(st.get_flag("treasure_found_tome", false)), "found")
	assert_eq(st.quest_stage("find_the_tome"), "found")
	assert_true(Tarokka.take_from("tser_pool_eva_tent", st).is_empty(), "and her chest is empty after")
	var old := SideQuestPlay.party(["ilse_varga"], 2, "tser_pool_eva_tent", 20)
	old.tarokka = st.tarokka.duplicate()
	old.set_flag("tser_treasure_given")   # a 1.0.x save: given by hand, never marked
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(old.to_dict())) as Dictionary)
	assert_true(bool(back.get_flag("treasure_found_tome", false)), "an old save is mended on load")


## Finding 64: unbinding the abbey garden's scarecrows lost the treasure sewn into the stitched one.
func test_the_unbound_scarecrow_gives_up_its_treasure() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "abbey_of_st_markovia_garden", 12)
	st.tarokka = {"tome": "glyphs_2", "symbol": "swords_6", "sword": "coins_7", "ally": "mists", "enemy": "donjon"}
	st.set_flag("abbey_scarecrows_unbound")
	var beats := SideQuestPlay.play(st, "abbey_of_st_markovia/garden_sentry:sentry", ["Cut the stitches"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.party_has_item("tome_of_strahd"))


## Finding 67: Arabelle drowning, when the cards named her, left find_the_ally open.
func test_losing_arabelle_loses_the_ally() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "vallaki_vistani_camp", 22)
	st.tarokka = {"ally": "tempter"}   # Arabelle
	st.set_quest_stage("find_the_ally", "foretold")
	SideQuestPlay.play(st, "vallaki/vistani_camp:lost")
	assert_eq(st.quest_stage("find_the_ally"), "lost")


## Finding 70: the Tax Collector's lid opens once Luvash's daughter is home, and the Beggar's treasure is Kasimir's to
## trade for a road into the mountains.
func test_the_vistani_treasures_keep_the_verses_promises() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "vallaki_vistani_camp", 12)
	st.tarokka = {"tome": "coins_8", "symbol": "coins_6", "sword": "coins_7", "ally": "mists", "enemy": "donjon"}
	var chest := {}
	for c: Variant in Compendium.shared().get_entry("locations", "vallaki_vistani_camp")["containers"]:
		if str((c as Dictionary)["id"]) == "luvash_chest":
			chest = c as Dictionary
	assert_true(bool(chest.get("locked", false)), "locked")
	assert_false(StoryConditions.check(str(chest.get("unlocked_when", "")), st), "till she's home")
	st.set_flag("arabelle_rescued")
	assert_true(StoryConditions.check(str(chest.get("unlocked_when", "")), st), "then open")
	SideQuestPlay.play(st, "vallaki/vistani_camp:luvash_grateful")
	assert_true(st.party_has_item("tome_of_strahd"), "Luvash opens it for the party")
	st.set_flag("kasimir_met")
	st.set_flag("kasimir_sister_told")
	var beats := SideQuestPlay.play(st, "vallaki/kasimir:menu", ["road into the mountains", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.party_has_item("holy_symbol_of_ravenkind"), "Kasimir trades the Beggar's")


## Finding 71: a failed look at Iosif or his wagon still let the party go for a chain it never saw. A success shows
## it; asking why he never gets down lets the party pull the blanket off.
func test_the_tinkers_chain_needs_seeing_or_asking() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 3, "svalich_crossroads", 12)
	st.set_flag("tinker_met")
	st.set_quest_stage("the_tinkers_wagon", "met")
	st.set_flag("tinker_seen")   # both tries spent and failed
	st.set_flag("wagon_seen")
	var beats := SideQuestPlay.play(st, "svalich_road/the_tinkers_wagon:menu", ["Go for the chain"])
	assert_ne(SideQuestPlay.missing(beats), "", "no chain nobody saw")
	beats = SideQuestPlay.play(st, "svalich_road/the_tinkers_wagon:menu", ["get down off the board", "Pull the blanket"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(SideQuestPlay.combat_of(beats), "tinkers_wagon")


## Finding 72: one night for the whole game, 19:00 to 6:00.
func test_one_night() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 1, "village_of_barovia", 19)
	GameState.minute_of_day = 19 * 60
	assert_eq(GameState.is_night(), st.is_night())
	assert_true(GameState.is_night())
	GameState.minute_of_day = 8 * 60
