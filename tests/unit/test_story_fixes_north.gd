extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's findings at Krezk, the Abbey and Argynvostholt, and in the companions'
## own quests ("QA - Wiki Walkthrough Findings" in the vault), each played the way a party meets it.


## Finding 26: lighting the beacon took Cosmin (and Sir Godfrey, the only one who could clear Ioan) away. Cosmin waits
## now, and Ioan's own stone is enough for him.
func test_the_squire_ends_when_the_order_rests_first() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 8, "argynvostholt", 12)
	st.set_quest_stage("the_squire", "met")
	st.set_flag("cosmin_met")
	st.set_flag("order_fate", "rest")
	assert_eq(SideQuestPlay.standing(st, "argynvostholt", "argynvostholt_cosmin"), "argynvostholt/the_squire:cosmin")
	SideQuestPlay.play(st, "argynvostholt/the_squire:cosmin", ["Look at the last headstone"])
	if not bool(st.get_flag("ioan_stone_read", false)):
		st.set_flag("ioan_stone_read")   # the roll missed: read it as a second visit would
		SideQuestPlay.play(st, "argynvostholt/the_squire:cosmin")
	assert_eq(st.quest_stage("the_squire"), "gone_home")


## Finding 27: remembering the oath on the way to joining the party skipped Sir Godfrey's plate and the Order's step.
func test_godfrey_gives_his_plate_on_the_ally_path() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 8, "argynvostholt", 12)
	st.set_quest_stage("the_order_of_the_silver_dragon", "commander")
	st.set_flag("order_oath_learned")
	SideQuestPlay.play(st, "argynvostholt/godfrey:ally_oath")
	assert_true(st.party_has_item("armor_plus_1__plate_armor"), "his plate")
	assert_eq(st.quest_stage("the_order_of_the_silver_dragon"), "remembering")


## Finding 30: once the Abbot's fate was settled, Clovin often ended the talk with no menu: no drink, no rumours.
func test_clovin_keeps_his_menu_after_the_abbot() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 7, "abbey_of_st_markovia", 12)
	st.set_flag("clovin_met")
	st.set_flag("abbot_fate", "broken")
	st.set_quest_stage("mothers_ninth_improvement", "asked")
	var beats := SideQuestPlay.play(st, "abbey_of_st_markovia/clovin:start", ["could use a drink"])
	assert_eq(SideQuestPlay.missing(beats), "", "the drink is on offer")
	assert_true(bool(st.get_flag("clovin_befriended", false)))


## Finding 32: pulling Wren back from Rahadin hid his scene for good, and The Last Lesson stuck.
func test_wren_can_face_rahadin_again() -> void:
	var st := SideQuestPlay.party(["wren_featherfoot"], 10, "castle_ravenloft_court", 12)
	st.set_quest_stage("the_last_lesson", "let_her_rest")
	SideQuestPlay.play(st, "companions/lesson:rahadin", ["Pull Wren back", "We'll find our own way"])
	assert_true(bool(st.get_flag("wren_rahadin_met", false)))
	var beats := SideQuestPlay.play(st, "castle_ravenloft/court_rahadin:menu", ["Tell him who your teacher was", "Go for his throat"])
	assert_eq(SideQuestPlay.missing(beats), "", "his option comes back")
	assert_eq(st.quest_stage("the_last_lesson"), "unlearned")


## Finding 33: the locket given to Strahd or burned could still be offered at the Pool and overwritten.
func test_a_settled_locket_stays_settled() -> void:
	var st := SideQuestPlay.party(["tamsin_tealeaf"], 10, "castle_ravenloft_court", 22)
	st.set_quest_stage("the_locket", "kept")
	SideQuestPlay.play(st, "castle_ravenloft/personal_locket:burn")
	assert_eq(str(st.get_flag("locket_fate", "")), "burned")
	var pool := SideQuestPlay.play(st, "krezk/pool:pool_menu", ["Take out the locket"])
	assert_ne(SideQuestPlay.missing(pool), "", "no locket at the pool any more")
	assert_eq(st.quest_stage("the_locket"), "burned")


## Finding 34: Liriel learns what the Abbot is making only if she was there when he said it, which happens once.
func test_liriel_learns_of_the_bride_later() -> void:
	var st := SideQuestPlay.party(["liriel_dawnsong"], 7, "abbey_of_st_markovia_chapel", 12)
	st.set_quest_stage("carry_the_dawn", "the_angel")
	st.set_flag("abbot_met")
	st.set_flag("abbot_bride_revealed")
	SideQuestPlay.play(st, "abbey_of_st_markovia/abbot:start", ["Goodbye"])
	assert_eq(st.quest_stage("carry_the_dawn"), "the_fall")


## Finding 35: the beacon's light took Sir Godfrey before he could knight Godrick. He knights him first now.
func test_godfrey_knights_godrick_at_the_beacon() -> void:
	var st := SideQuestPlay.party(["godrick_pendlebrook"], 8, "argynvostholt_beacon", 22)
	st.set_quest_stage("the_ladle", "kept_faith")
	for f: String in ["godfrey_met", "ladle_sword_shown"]:
		st.set_flag(f)
	SideQuestPlay.play(st, "argynvostholt/beacon:godfrey_check")
	assert_eq(st.quest_stage("the_ladle"), "knighted")


## Finding 36: a failed reading at the fire, with Vosk already gone down to the vaults, left Kip's contract unread.
func test_kip_reads_his_contract_by_the_next_camp() -> void:
	var st := SideQuestPlay.party(["kip_smudgewick"], 5, "vallaki", 22)
	st.set_quest_stage("the_fine_print", "the_assessor")
	st.set_flag("kip_reading_failed")
	SideQuestPlay.play(st, "camp/kip:talk_reading")
	assert_eq(st.quest_stage("the_fine_print"), "the_small_print")


## Finding 37: Grandda's blaze above the lake sent Thistle to a den the map didn't show.
func test_the_lake_blaze_puts_the_den_on_the_map() -> void:
	var st := SideQuestPlay.party(["thistle"], 5, "lake_zarovich_trail", 12)
	st.set_quest_stage("fens_trail", "the_blazes")
	SideQuestPlay.play(st, "companions/fen:blaze_lake")
	assert_true(bool(st.get_flag("den_way_known", false)))
	assert_eq(st.quest_stage("fens_trail"), "the_wolf_road")


## Finding 38: Ratatoille's supper could end his quest before he asked Mordenkainen, and hid the asking for good.
func test_ratatoille_can_still_ask_the_master() -> void:
	var st := SideQuestPlay.party(["ratatoille"], 9, "mount_baratok_hut", 12)
	st.set_quest_stage("a_seat_at_the_table", "his_own_table")
	SideQuestPlay.play(st, "companions/table:apprentice")
	assert_true(bool(st.get_flag("ratatoille_master_asked", false)))
	assert_eq(st.quest_stage("a_seat_at_the_table"), "his_own_table", "the ending stands")
