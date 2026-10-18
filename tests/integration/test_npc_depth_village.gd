extends TestCase
## NPC depth, batch 1 (docs/plans/npc_depth_and_quests.md): the village's people have something to want and something to
## hide, nobody always has news, and no roll is the only way to anything. The Fourth Rumour's whole quest, Vasile and
## Petre with nothing new (and one wrong rumour), Petre's coat, Anca's letters, Goodwife Viorica's candle, Parriwimple's
## book, Bildrath's ledger, Mirabel's nicknames, and the goat in the shop, the church and at the Death House gate.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const V := "village_of_barovia/"


func _st(hour: int = 10) -> StoryState:
	return SideQuestPlay.party(FOUR, 2, "village_of_barovia", hour)


func test_nothing_new_in_turn_then_a_wrong_rumour_that_petra_puts_right() -> void:
	var st := _st()
	var first := SideQuestPlay.text(SideQuestPlay.play(st, V + "townsfolk:vasile", ["Heard anything"]))
	assert_true(first.contains("same three rumours"), "the first time: the old three")
	assert_true(st.quest_stage("polite_caller") != "" and st.quest_stage("cut_after_noon") != "", "and they start their quests")
	var again := SideQuestPlay.text(SideQuestPlay.play(st, V + "townsfolk:vasile", ["Heard anything"]))
	assert_true(again.contains("a crow sat on the well-beam") or again.contains("A crow sat on the well-beam"), "nothing new: the crow")
	var wrong := SideQuestPlay.text(SideQuestPlay.play(st, V + "townsfolk:vasile", ["Heard anything"]))
	assert_true(wrong.contains("Woof"), "then the wolfhound that talks")
	assert_true(st.get_flag("vasile_wrong_heard", false))
	var petra := SideQuestPlay.text(SideQuestPlay.play(st, V + "townsfolk:goodwife", ["dog has learned to talk"]))
	assert_true(petra.contains("drowned choir"), "Goodwife Petra: Vasile says a lot of things")


func test_petres_coat_by_a_gift_never_by_a_roll() -> void:
	var st := _st()
	st.gold = 0
	var none := SideQuestPlay.text(SideQuestPlay.play(st, V + "townsfolk:petre", ["good coat"]))
	assert_false(st.get_flag("petre_coat_known", false), "poor: he says nothing and nothing is closed")
	assert_true(none.contains("keeps the wet off my shoulders"))
	st.gold = 5
	var paid := SideQuestPlay.text(SideQuestPlay.play(st, V + "townsfolk:petre", ["good coat", "gold piece"]))
	assert_true(paid.contains("All right. The coat."))
	assert_true(paid.contains("Ireena"))
	assert_true(st.get_flag("petre_coat_known", false))
	assert_eq(roundi(st.gold), 4)


func test_anca_learns_her_name_and_tells_the_cellar_the_weather() -> void:
	var st := _st()
	var beats := SideQuestPlay.play(st, V + "townsfolk:acolyte", ["Can you read", "Write her name"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Now the path knows who sweeps it"))
	assert_true(st.get_flag("anca_letters", false))
	beats = SideQuestPlay.play(st, V + "townsfolk:anca_secret")
	assert_true(SideQuestPlay.text(beats).contains("I only tell him the weather"))
	assert_true(st.get_flag("anca_secret_known", false))
	beats = SideQuestPlay.play(st, V + "townsfolk:acolyte")
	assert_true(SideQuestPlay.text(beats).contains("the broom remembers"), "she remembers it on the next visit")


func test_goodwife_vioricas_candle() -> void:
	var st := _st()
	st.gold = 3
	var beats := SideQuestPlay.play(st, V + "indoor_folk:shopper", ["Do you need help", "Put a gold piece"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Tomorrow is my boy's name-day"))
	assert_true(st.get_flag("viorica_candle", false))
	assert_eq(roundi(st.gold), 2)
	beats = SideQuestPlay.play(st, V + "indoor_folk:shopper")
	assert_true(SideQuestPlay.text(beats).contains("warmer than the street"), "afterwards")
	assert_false(SideQuestPlay.text(beats).contains("Three coppers for a candle"))


func test_goodwife_viorica_without_a_gold_piece_loses_nothing() -> void:
	var st := _st()
	st.gold = 0
	var beats := SideQuestPlay.play(st, V + "indoor_folk:shopper", ["Do you need help"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_false(st.get_flag("viorica_candle", false))


func test_sorina_and_the_priests_son() -> void:
	var st := _st()
	var beats := SideQuestPlay.play(st, V + "indoor_folk:sorina_told")
	assert_true(SideQuestPlay.text(beats).contains("a poker and a prayer"))
	assert_true(st.get_flag("sorina_doru_known", false))


func test_parriwimples_book_and_bildraths_ledger() -> void:
	var st := _st()
	st.set_flag("parriwimple_befriended")
	var beats := SideQuestPlay.play(st, V + "parriwimple:start", ["What do you do at night", "bad business"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("Goodwife Viorica owes for salt"))
	assert_true(st.get_flag("parriwimple_book_shown", false))
	beats = SideQuestPlay.play(st, V + "bildrath:ledger_insight")
	assert_true(SideQuestPlay.text(beats).contains("lost, wolves"))
	assert_true(st.get_flag("bildrath_ledger_known", false))


func test_mirabel_names_the_party_by_class() -> void:
	var st := _st()
	var said := SideQuestPlay.text(SideQuestPlay.play(st, V + "vistani:nicknames"))
	assert_true(said.contains("Kettle"), "the paladin")
	assert_true(said.contains("Candle-end"), "the cleric")
	assert_true(said.contains("Bramble"), "the ranger")
	assert_true(said.contains("Soup-bone"), "the wizard")
	assert_false(said.contains("Thimble"), "no monk in this party")
	assert_true(said.contains("Pockets") and said.contains("Sparrow"))


func test_the_fourth_rumour_sold_plainly() -> void:
	var st := _st()
	var beats := SideQuestPlay.play(st, V + "townsfolk:vasile", ["fourth rumour", "bald under his wig", "plainly"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_fourth_rumour"), "planted")
	assert_eq(str(st.get_flag("fourth_rumour_seed", "")), "baron")
	var arik := SideQuestPlay.text(SideQuestPlay.play(st, V + "arik:start", ["Heard anything interesting"]))
	assert_true(arik.contains("Wig."))
	assert_true(st.get_flag("fourth_rumour_echoed", false))
	st.gold = 0
	beats = SideQuestPlay.play(st, V + "townsfolk:vasile", ["About that rumour"])
	assert_eq(st.quest_stage("the_fourth_rumour"), "done")
	assert_eq(roundi(st.gold), 10)
	assert_true(SideQuestPlay.text(beats).contains("wearing somebody else's boots"))


func test_the_tuesday_rumour_gets_one_discount_out_of_spite() -> void:
	var st := _st()
	st.set_quest_stage("the_fourth_rumour", "planted")
	st.set_flag("fourth_rumour_seed", "tuesday")
	st.set_flag("fourth_rumour_echoed")
	var beats := SideQuestPlay.play(st, V + "bildrath:start", ["They're saying it's Tuesday"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("purely cultural matter"))
	assert_true(st.get_flag("bildrath_discount", false))


func test_an_unbelieved_rumour_leaves_the_way_open() -> void:
	# Every roll failed: Vasile offers his own, and the plain telling is still there.
	var st := _st()
	var beats := SideQuestPlay.play(st, V + "the_fourth_rumour:sold_fail")
	assert_true(SideQuestPlay.text(beats).contains("Goodwife Petra's well actually has a bottom"))
	assert_eq(st.quest_stage("the_fourth_rumour"), "")
	beats = SideQuestPlay.play(st, V + "the_fourth_rumour:sell", ["plainly"])
	assert_eq(st.quest_stage("the_fourth_rumour"), "planted")


func test_the_goat_in_the_shop_the_church_and_at_the_gate() -> void:
	var st := _st()
	assert_eq(SideQuestPlay.standing(st, "bildraths_mercantile", "barovia_goat"), V + "townsfolk:goat_shop")
	assert_eq(SideQuestPlay.standing(st, "village_church", "barovia_goat"), V + "townsfolk:goat_church")
	assert_eq(SideQuestPlay.standing(st, "village_of_barovia", "barovia_goat") != "", true)
	for node: String in ["goat_shop", "goat_church", "goat_gate"]:
		var beats := SideQuestPlay.play(st, V + "townsfolk:" + node)
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_eq(str(beats[-1]["kind"]), "end", node + " has an exit")
	var talks := SideQuestPlay.text(SideQuestPlay.play(st, V + "townsfolk:goat_gate_speaks"))
	assert_true(talks.contains("The little doll in the attic"))
