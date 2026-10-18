extends TestCase
## NPC depth, batch 4a (docs/plans/npc_depth_and_quests.md): Krezk and the lake. Madam Profira and the Watchman, Dumitru's
## Visitor (cousins, or Fennimore up the road), the villagers' wants and secrets, The Waystone by day and The Baron's
## Island without a fight. The nodes are played directly where a roll decides which one comes next, and every failed
## roll is walked to the way on that it has.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const K := "krezk/"


func _st(hour: int = 10, location: String = "krezk", level: int = 6, party: Array[String] = FOUR) -> StoryState:
	return SideQuestPlay.party(party, level, location, hour)


func test_madam_profira_pairs_the_party_wrongly_and_the_pairs_cycle() -> void:
	var st := _st()
	assert_eq(SideQuestPlay.standing(st, "krezk", "madam_profira"), K + "profira:start")
	var first := SideQuestPlay.text(SideQuestPlay.play(st, K + "profira:start", ["not looking"]))
	assert_true(first.contains("for the good of the town"))
	assert_true(first.contains("dented plate"), "the first pairing")
	assert_eq(int(st.get_flag("profira_pairs", 0)), 1)
	var second := SideQuestPlay.text(SideQuestPlay.play(st, K + "profira:start", ["Goodbye"]))
	assert_true(second.contains("rosemary") and not second.contains("Madam Profira: Madam Profira."), "a second visit pairs again, without the introduction")
	var third := SideQuestPlay.text(SideQuestPlay.play(st, K + "profira:start", ["Goodbye"]))
	assert_true(third.contains("Nettles and dock leaf"))
	assert_eq(int(st.get_flag("profira_pairs", 0)), 3)
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "profira:start", ["Goodbye"])).contains("dented plate"), "then she starts the pairings over")


func test_profira_reads_the_romance_flags_and_never_sets_them() -> void:
	var st := _st(10, "krezk", 6, ["thistle", "wren_featherfoot", "godrick_pendlebrook", "kip_smudgewick"])
	st.set_flag("romance_thistle_wren", "together")
	var before := str(st.get_flag("romance_thistle_wren", ""))
	var text := SideQuestPlay.text(SideQuestPlay.play(st, K + "profira:start", ["Goodbye"]))
	assert_true(text.contains("dry blanket"), "Wren corrects her")
	assert_eq(str(st.get_flag("romance_thistle_wren", "")), before)
	assert_false(st.get_flag("romance_godrick_thistle", false), "nothing is set")


func test_the_watchman_wants_to_say_yes_and_cannot_read_the_list() -> void:
	var st := _st()
	st.set_flag("krezk_gate_open")
	var beats := SideQuestPlay.play(st, K + "gate:guard", ["say yes to anybody"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("say yes"))
	assert_true(st.get_flag("watchman_asked_yes", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "gate:watchman_list")).contains("chicken tracks"))
	assert_true(st.get_flag("watchman_list_known", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "gate:watchman_list_miss")).contains("not on the list"), "a missed roll still gets an answer")
	st = _st()
	st.set_flag("krezk_gate_open")
	var nos := SideQuestPlay.text(SideQuestPlay.play(st, K + "gate:guard", ["Goodbye"]))
	assert_true(nos.contains("the answer is no"), "an unprompted refusal, even from a friendly watchman")


func test_the_watchman_and_profira_end_in_one_supper() -> void:
	var st := _st()
	st.set_flag("krezk_gate_open")
	st.set_flag("profira_met")
	var beats := SideQuestPlay.play(st, K + "gate:guard", ["matter between you and Madam Profira"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("watchman_jilt_told", false))
	beats = SideQuestPlay.play(st, K + "profira:start", ["Watchman told us", "to supper"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("profira_secret_known", false))
	assert_true(st.get_flag("profira_supper_asked", false))
	beats = SideQuestPlay.play(st, K + "gate:guard", ["supper"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(st.get_flag("watchman_said_yes", false))
	var gold := st.gold
	beats = SideQuestPlay.play(st, K + "profira:start")
	assert_true(st.get_flag("profira_supper_done", false))
	assert_eq(st.gold, gold + 30)
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "profira:start", ["Goodbye"])).contains("watchman knows how to hold a spoon"))


func test_dumitrus_visitor_by_cousins_and_by_fennimore() -> void:
	var st := _st()
	var beats := SideQuestPlay.play(st, K + "townsfolk:gate_boy", ["waiting for"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("dumitrus_visitor"), "asked")
	# A failed Deception roll is spent but he points at Fennimore, and the ruse itself is a way in.
	SideQuestPlay.play(st, K + "dumitrus_visitor:cousins_fail")
	var gold := st.gold
	SideQuestPlay.play(st, K + "dumitrus_visitor:cousins_ok")
	assert_eq(st.quest_stage("dumitrus_visitor"), "done")
	assert_eq(st.gold, gold + 20)
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "townsfolk:gate_boy")).contains("tonight"), "he writes it up")
	# Fennimore's way: ask him at the crossroads; he leaves the signpost and stands inside the gate.
	st = _st(10, "svalich_crossroads")
	st.set_quest_stage("dumitrus_visitor", "asked")
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "fennimore"), "svalich_road/fennimore:start")
	beats = SideQuestPlay.play(st, "svalich_road/fennimore:start", ["boy at Krezk"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("dumitrus_visitor"), "fennimore")
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "fennimore"), "", "he has gone up the road")
	st.location = "krezk"
	assert_eq(SideQuestPlay.standing(st, "krezk", "fennimore"), "", "not through a shut gate")
	st.set_flag("krezk_gate_open")
	assert_eq(SideQuestPlay.standing(st, "krezk", "fennimore"), K + "dumitrus_visitor:fennimore_visit")
	gold = st.gold
	beats = SideQuestPlay.play(st, K + "dumitrus_visitor:fennimore_visit")
	assert_eq(st.quest_stage("dumitrus_visitor"), "done")
	assert_eq(st.gold, gold + 40)
	assert_true(SideQuestPlay.text(beats).contains("Four stars"))
	assert_eq(SideQuestPlay.standing(st, "krezk", "fennimore"), "", "the visit is done and he walks back down")
	st.location = "svalich_crossroads"
	assert_eq(SideQuestPlay.standing(st, "svalich_crossroads", "fennimore"), "svalich_road/fennimore:start", "to the signpost")


func test_the_villagers_have_wants_and_secrets() -> void:
	var st := _st()
	var text := SideQuestPlay.text(SideQuestPlay.play(st, K + "townsfolk:woodcutter", ["What would you like"]))
	assert_true(text.contains("axe"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "townsfolk:woodcutter_secret")).contains("Anna Krezkova"))
	assert_true(st.get_flag("stefan_logs_known", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "townsfolk:woodcutter_miss")).length() > 10, "a missed roll still answers")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "townsfolk:well_wife", ["taste of salt"])).contains("salt"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "townsfolk:fence_mender", ["billy gone"])).contains("complain"))
	SideQuestPlay.play(st, K + "townsfolk:bucket_wife_secret")
	assert_true(st.get_flag("sanda_prays_known", false))
	# Old Simion: the unnamed stone opens only once he's said what he wants.
	var opts := SideQuestPlay.play(st, K + "pool_folk:grave_keeper", ["That stone with no name"])
	assert_eq(SideQuestPlay.missing(opts) != "", true, "not before he has said what he wants")
	SideQuestPlay.play(st, K + "pool_folk:grave_keeper", ["What would you like"])
	assert_true(st.get_flag("simion_want_heard", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, K + "pool_folk:grave_keeper", ["That stone with no name"])).contains("dug my own"))
	SideQuestPlay.play(st, K + "pool_folk:mourner_secret")
	assert_true(st.get_flag("catrina_told", false))
	SideQuestPlay.play(st, "lake_zarovich/trail_hunter:hunter_secret")
	assert_true(st.get_flag("ilarie_ears_known", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, "abbey_of_st_markovia/belview_chores:gate")).contains("abbey gate"))


func test_the_waystone_by_day_has_a_way_on_for_every_roll() -> void:
	var st := _st(12, "krezk_road_waystone", 6)
	st.set_quest_stage("the_waystone", "rumored")
	assert_eq(SideQuestPlay.standing(st, "krezk_road_waystone", "waystone_lark"), "", "no Lark by day until the tracks are followed")
	SideQuestPlay.play(st, K + "the_waystone:tracks_ok")
	assert_true(st.get_flag("waystone_tracked", false))
	assert_eq(SideQuestPlay.standing(st, "krezk_road_waystone", "waystone_lark"), K + "the_waystone:lark_day")
	SideQuestPlay.play(st, K + "the_waystone:lark_day")
	assert_eq(st.quest_stage("the_waystone"), "asked")
	assert_true(st.get_flag("waystone_lark_day_met", false))
	# Both rolls missed: the pack hears, and it is the old fight at the stone.
	var beats := SideQuestPlay.play(st, K + "the_waystone:sing_shaky")
	assert_eq(SideQuestPlay.missing(beats), "", "a shaky song still leads on (to the Stealth roll)")
	assert_eq(SideQuestPlay.combat_of(SideQuestPlay.play(st, K + "the_waystone:watch_miss")), "waystone_wolves")
	# Both rolls made: no fight, and Yanko walks into the light either way.
	beats = SideQuestPlay.play(st, K + "the_waystone:watch_ok")
	assert_eq(SideQuestPlay.combat_of(beats), "")
	beats = SideQuestPlay.play(st, K + "the_waystone:yanko_comes", ["Let her sing"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_waystone"), "done")
	assert_eq(SideQuestPlay.combat_of(beats), "")
	# Night is still the pack, and after a fight at the stone Lark waits by day as well.
	st = _st(14, "krezk_road_waystone", 6)
	st.set_quest_stage("the_waystone", "defended")
	st.set_flag("waystone_wolves_beaten")
	assert_eq(SideQuestPlay.standing(st, "krezk_road_waystone", "waystone_lark"), K + "the_waystone:after")


func test_the_barons_island_can_be_emptied_or_hidden_without_a_fight() -> void:
	var L := "lake_zarovich/the_barons_island:"
	var st := _st(21, "zarovich_reed_island", 5)
	st.set_quest_stage("the_barons_island", "asked")
	# Rowed home: three crossings, none seen.
	var beats := SideQuestPlay.play(st, L + "vote_speech", ["Let them decide"])
	assert_eq(SideQuestPlay.missing(beats), "")
	st.set_flag("ferry_trips", 3)
	st.set_flag("ferry_seen", 1)
	beats = SideQuestPlay.play(st, L + "crossed")
	assert_eq(SideQuestPlay.combat_of(beats), "")
	assert_eq(st.quest_stage("the_barons_island"), "done")
	assert_true(st.get_flag("reed_isle_home", false))
	# Seen twice: the boatmen are on the shingle, as before.
	st = _st(21, "zarovich_reed_island", 5)
	st.set_quest_stage("the_barons_island", "asked")
	st.set_flag("ferry_trips", 3)
	st.set_flag("ferry_seen", 2)
	beats = SideQuestPlay.play(st, L + "crossed")
	assert_eq(SideQuestPlay.combat_of(beats), "reed_isle_boatmen")
	assert_ne(st.quest_stage("the_barons_island"), "done")
	# Hidden: the boat finds reeds.
	st = _st(21, "zarovich_reed_island", 5)
	st.set_quest_stage("the_barons_island", "asked")
	beats = SideQuestPlay.play(st, L + "hide_ok")
	assert_eq(SideQuestPlay.combat_of(beats), "")
	assert_eq(st.quest_stage("the_barons_island"), "done")
	assert_true(st.get_flag("reed_isle_stayed", false))
	# A missed hiding roll is the boat on the shingle.
	st = _st(21, "zarovich_reed_island", 5)
	st.set_quest_stage("the_barons_island", "asked")
	beats = SideQuestPlay.play(st, L + "hide_bad")
	assert_eq(SideQuestPlay.combat_of(beats), "reed_isle_boatmen")
	# Both lost votes and both won ones lead on.
	for node: String in ["argue_go_ok", "argue_go_miss", "argue_stay_ok", "argue_stay_miss"]:
		st = _st(21, "zarovich_reed_island", 5)
		assert_eq(SideQuestPlay.missing(SideQuestPlay.play(st, L + node)), "", node)
