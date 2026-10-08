extends TestCase
## Storyline QA (2026-10-08): places and people that a playthrough could reach only by luck, or not at all. make
## validate's tools/data/story_reach.py finds the rest of this kind from the data; these play the fixes through.


## The Fourth Sister's lane and the Ravens' Ransom's hill trail were maps that only a random road encounter opened. Once
## their quests start they are travel places, a short road from the mill and from the lake shore.
func test_the_millers_lane_and_the_hill_trail_are_on_the_map_once_their_quests_start() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "old_bonegrinder_hill", 10)
	st.visited["old_bonegrinder_hill"] = true
	assert_false(_known(st, "millers_lane"), "the lane isn't on the map before anyone mentions Mouse")
	st.set_quest_stage("the_fourth_sister", "rumored")
	assert_true(_known(st, "millers_lane"), "the rumour puts the miller's lane on the map")
	assert_eq(str(Travel.place("millers_lane")["location"]), "old_bonegrinder_track", "where Mouse and her hut are")
	assert_false(Travel.route("old_bonegrinder", "millers_lane", st).is_empty(), "a road down from the mill")

	var lake := SideQuestPlay.party(["ilse_varga"], 6, "lake_zarovich", 10)
	lake.visited["vallaki"] = true
	lake.visited["lake_zarovich"] = true
	assert_false(_known(lake, "lake_hill_trail"), "the trail isn't on the map before the errand")
	lake.set_quest_stage("the_ravens_ransom", "asked")
	assert_true(_known(lake, "lake_hill_trail"), "Urwin's errand puts the hill trail on the map")
	assert_eq(str(Travel.place("lake_hill_trail")["location"]), "lake_zarovich_trail", "where Bray's cage hangs")
	assert_false(Travel.route("lake_zarovich", "lake_hill_trail", lake).is_empty(), "a road up from the shore")

	var fen := SideQuestPlay.party(["thistle"], 6, "lake_zarovich", 10)
	fen.visited["vallaki"] = true
	fen.visited["lake_zarovich"] = true
	fen.set_quest_stage("fens_trail", "the_trail")
	assert_false(_known(fen, "lake_hill_trail"), "not before Grandda's first blaze")
	fen.set_quest_stage("fens_trail", "the_blazes")
	assert_true(_known(fen, "lake_hill_trail"), "the first blaze leads on to the trail with the next one")


## Kolyan raised and told "Rest a while" waited at a grave that only said "Fresh earth" ever after: the destined ally
## and the 500 gp were gone. He waits on it now, ready to ride.
func test_kolyan_raised_and_told_to_wait_still_joins() -> void:
	var st := SideQuestPlay.party(["hedda_ironvow", "ilse_varga"], 9, "village_of_barovia", 12)
	st.gold = 600.0
	st.tarokka = Tarokka.draw(1)
	st.tarokka["ally"] = "horseman"
	var beats := SideQuestPlay.play(st, "village_of_barovia/kolyan:grave", ["Call him back", "Rest a while"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("kolyan_raised", false)), "raised")
	assert_false("kolyan_indirovich" in st.guest_ids, "and left to wait")
	beats = SideQuestPlay.play(st, "village_of_barovia/kolyan:grave", ["Ride with us"])
	assert_eq(SideQuestPlay.missing(beats), "", "back at the grave, he asks to ride")
	assert_true("kolyan_indirovich" in st.guest_ids, "he joins")


func _known(st: StoryState, place_id: String) -> bool:
	return Travel.known(st).any(func(p: Dictionary) -> bool: return str(p["id"]) == place_id)
