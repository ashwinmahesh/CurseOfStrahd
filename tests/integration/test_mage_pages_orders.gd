extends TestCase
## The Mage's Lost Pages must finish whatever order the party does things in (Ashwin, 2026-10-19: he cast Greater
## Restoration on Mordenkainen, found all three letters and had no way to talk to him), and every story ally the cards
## can name, who then cannot be sent home, must stay talkable. Walks: the four ways to bring his name back, the letters
## found before or after it, joining before or after the letters, a click on him or Give... on the road, and the
## same gap for Sir Godfrey and Rictavio (docs/story/side_quests.md, The Mage's Lost Pages).

const PAGES := "mount_baratok/mordenkainen"
const QUEST := "the_mages_lost_pages"
const LETTERS: Array[String] = ["corvina_letter_1", "corvina_letter_2", "corvina_letter_3"]
const PARTY: Array[String] = ["hedda_ironvow", "ratatoille", "liriel_dawnsong", "godrick_pendlebrook"]

## Cures: [name, flags to set first, the menu picks that bring his name back].
const CURES := [
	["the witch's jar", ["mordenkainen_memory_jar_taken"], ["Uncork the witch's jar"]],
	["Greater Restoration", [], ["Cast Greater Restoration"]],
	["the spellbook and its last page", ["mordenkainen_spellbook_found"], ["Show him the spellbook", "Read him the last page"]],
]


func _hut(level: int = 9) -> StoryState:
	var st := SideQuestPlay.party(PARTY, level, "mount_baratok_hut", 12)
	st.set_flag("mordenkainen_met")
	return st


func _letters(st: StoryState) -> void:
	for f in LETTERS:
		st.set_flag(f)


func _says(beats: Array[Dictionary], words: String) -> bool:
	return SideQuestPlay.text(beats).contains(words)


func _ended(beats: Array[Dictionary]) -> bool:
	return str(beats[-1].get("kind", "")) == "end"


## Brings his name back by `cure` through his own conversation.
func _cure(st: StoryState, cure: Array) -> void:
	for f: Variant in cure[1] as Array:
		st.set_flag(str(f))
	var picks: Array[String] = []
	for p: Variant in cure[2] as Array:
		picks.append(str(p))
	var beats := SideQuestPlay.play(st, PAGES + ":start", picks)
	assert_eq(SideQuestPlay.missing(beats), "", "cure: %s" % cure[0])
	assert_true(bool(st.get_flag("mordenkainen_restored", false)), "%s brings him back" % cure[0])


func _options(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			for o: Variant in b["options"] as Array:
				if bool((o as Dictionary).get("enabled", true)):
					out.append(str((o as Dictionary)["text"]))
	return out


func _has_option(beats: Array[Dictionary], words: String) -> bool:
	for t in _options(beats):
		if t.contains(words):
			return true
	return false


# --- At the hut: the name and the letters in either order ---------------------------------------------------------------

func test_every_cure_and_either_order_of_letters_and_name_ends_with_the_quest_done_at_the_hut() -> void:
	for cure: Array in CURES:
		for letters_first: bool in [true, false]:
			var st := _hut()
			if letters_first:
				_letters(st)
			_cure(st, cure)
			if not letters_first:
				var asked := SideQuestPlay.play(st, PAGES + ":start", ["Heard anything interesting?"])
				assert_eq(SideQuestPlay.missing(asked), "", "%s: asked for the pages" % cure[0])
				assert_eq(st.quest_stage(QUEST), "asked", "%s: the quest begins" % cure[0])
				_letters(st)
			var beats := SideQuestPlay.play(st, PAGES + ":start", ["Heard anything interesting?", "Let him rage"])
			assert_eq(SideQuestPlay.missing(beats), "", "%s, letters %s" % [cure[0], "first" if letters_first else "after"])
			assert_eq(st.quest_stage(QUEST), "named", "%s, letters %s: the quest is done" % [cure[0], "first" if letters_first else "after"])
			assert_true(st.party_has_item("ring_of_telekinesis"), "and Corvina's ring is given")
			assert_true(_ended(beats), "and the talk closes")


func test_talking_him_back_works_in_either_order_too() -> void:
	for letters_first: bool in [true, false]:
		var st := _hut()
		if letters_first:
			_letters(st)
		for seed_n in range(1, 40):
			SideQuestPlay.play(st, PAGES + ":start", ["Talk him back"], seed_n)
			if bool(st.get_flag("mordenkainen_restored", false)):
				break
		assert_true(bool(st.get_flag("mordenkainen_restored", false)), "talked back within 40 tries")
		if not letters_first:
			SideQuestPlay.play(st, PAGES + ":start", ["Heard anything interesting?"])
			_letters(st)
		SideQuestPlay.play(st, PAGES + ":start", ["Heard anything interesting?", "Let him rage"])
		assert_eq(st.quest_stage(QUEST), "named")


func test_the_letters_alone_never_move_the_quest_without_him_and_the_menu_always_offers_them() -> void:
	var st := _hut()
	_cure(st, CURES[1] as Array)
	_letters(st)
	var beats := SideQuestPlay.play(st, PAGES + ":start", ["We found three letters", "Let him rage"])
	assert_eq(SideQuestPlay.missing(beats), "", "his menu says so plainly, without asking for news first")
	assert_eq(st.quest_stage(QUEST), "named")


# --- On the road: joining before or after the letters ---------------------------------------------------------------------

func _ally_party(cure: Array) -> StoryState:
	var st := _hut()
	st.tarokka = {"ally": "broken_one"}
	_cure(st, cure)
	return st


func test_joining_with_the_letters_already_in_hand_hands_them_over_at_once() -> void:
	for cure: Array in CURES:
		var st := _ally_party(cure)
		_letters(st)
		var beats := SideQuestPlay.play(st, PAGES + ":start", ["Madam Eva's cards named you"])
		assert_eq(SideQuestPlay.missing(beats), "", cure[0])
		assert_true("mordenkainen" in st.guest_ids, "he joins")
		assert_eq(st.quest_stage(QUEST), "named", "%s: the letters are read on the spot" % cure[0])
		assert_true(st.party_has_item("ring_of_telekinesis"))
		assert_true(_ended(beats), "and the talk closes")


func test_joining_first_then_finding_the_letters_on_the_mountain_finishes_it() -> void:
	var st := _ally_party(CURES[1] as Array)
	SideQuestPlay.play(st, PAGES + ":start", ["Madam Eva's cards named you"])
	assert_eq(st.quest_stage(QUEST), "asked", "he asks for his pages as he joins")
	st.location = "mount_baratok"
	SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:letter_birds", ["Chip the whole shell away"])
	SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:letter_ring", ["Break the glass around it"])
	var beats := SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:letter_overlook", ["Dig the whole drift out"])
	assert_eq(st.quest_stage(QUEST), "named", "the third letter is read to him where they stand")
	assert_true(_says(beats, "standing in the snow"), "on the mountain")


func test_letters_found_off_the_mountain_after_he_joined_can_still_be_handed_over() -> void:
	# The letters can be in the pack without the last one having been picked up beside him (a save, a different order):
	# a click on him and Give... both reach them.
	var st := _ally_party(CURES[1] as Array)
	SideQuestPlay.play(st, PAGES + ":start", ["Madam Eva's cards named you"])
	st.location = "svalich_crossroads"
	_letters(st)
	assert_eq(GuestTalk.ref_for("mordenkainen"), PAGES + ":companion", "a click on him opens his own talk")
	var gifts := GuestTalk.gifts(st, "mordenkainen")
	assert_eq(gifts.size(), 1, "and Give... has the letters")
	assert_eq(str(gifts[0]["label"]), "The three lost letters")
	var talk := SideQuestPlay.play(st, PAGES + ":companion")
	assert_true(_has_option(talk, "We found three letters"), "his talk offers them first")
	assert_true(_has_option(talk, "Nothing. Let's go."), "and has a way out")
	assert_false(_has_option(talk, "Goodbye."), "the farewell is for the hut")
	assert_false(_has_option(talk, "Madam Eva's cards named you"), "and does not ask him to join again")
	var give := SideQuestPlay.play(st, str(gifts[0]["ref"]))
	assert_eq(SideQuestPlay.missing(give), "")
	assert_eq(st.quest_stage(QUEST), "named")
	assert_true(_says(give, "without looking up"), "off the mountain there is no snow")
	assert_true(GuestTalk.gifts(st, "mordenkainen").is_empty(), "nothing left to give once he has them")
	assert_false(_has_option(SideQuestPlay.play(st, PAGES + ":companion"), "We found three letters"), "and the option goes")


func test_with_the_quest_already_done_his_road_talk_still_opens_and_closes() -> void:
	var st := _ally_party(CURES[1] as Array)
	_letters(st)
	SideQuestPlay.play(st, PAGES + ":start", ["Madam Eva's cards named you"])
	var beats := SideQuestPlay.play(st, PAGES + ":companion")
	assert_true(_says(beats, "Make it brief"))
	assert_true(_ended(beats))


func test_he_is_not_locked_out_with_a_promise_instead_of_the_cards() -> void:
	var st := _hut()
	_cure(st, CURES[0] as Array)
	_letters(st)
	st.set_flag("mordenkainen_promised_aid")
	var beats := SideQuestPlay.play(st, PAGES + ":start", ["Heard anything interesting?", "You promised to come with us"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage(QUEST), "named")


# --- The same gap in the other allies the cards can name ---------------------------------------------------------------

## Cards -> the ally the cards name; every one is listed here with how a party that has taken them can still reach what
## they hold: their own talk (`guest_talk`), or a stand-in that the story already has.
const ALLIES := {
	"rictavio": "guest_talk",
	"emil_toranescu": "no conversation to lose: the pack menu is chatter",
	"mordenkainen": "guest_talk",
	"victor_vallakovich": "no conversation to lose: the circle is an attic matter, finished before he travels",
	"sir_godfrey_gwilym": "guest_talk",
	"ismark": "no conversation to lose: his errands are at the village before the cards",
	"kolyan_indirovich": "no conversation to lose: banter only",
	"parriwimple": "no conversation to lose: banter only",
	"davian_martikov": "his daughter Stefania takes the family's news (stefania:news -> davian:menu)",
	"arabelle": "no conversation to lose: banter only",
	"ezmerelda": "guest_talk",
	"pidlwick_ii": "guest_talk",
	"kasimir_velikov": "guest_talk",
}


func test_every_ally_the_cards_can_name_is_accounted_for() -> void:
	var outcomes := JSON.parse_string(FileAccess.get_file_as_string("res://data/tarokka/outcomes.json")) as Dictionary
	for card: Variant in (outcomes["ally"] as Dictionary):
		var o: Variant = (outcomes["ally"] as Dictionary)[card]
		if not o is Dictionary or str((o as Dictionary).get("npc", "")) == "":
			continue
		var npc := str((o as Dictionary)["npc"])
		assert_true(ALLIES.has(npc), "%s (card %s) has a note on how a party that took them still reaches their conversation" % [npc, card])
		if str(ALLIES.get(npc, "")) == "guest_talk":
			assert_true(GuestTalk.ref_for(npc) != "", "%s has a guest_talk" % npc)


func test_the_three_travelling_talks_open_and_close() -> void:
	for pair: Array in [["mordenkainen", PAGES + ":companion"], ["sir_godfrey_gwilym", "argynvostholt/godfrey:companion"], ["rictavio", "vallaki/rictavio:companion"]]:
		assert_eq(GuestTalk.ref_for(str(pair[0])), str(pair[1]))
		var st := _hut()
		st.set_flag("mordenkainen_restored")
		assert_true(st.add_guest(str(pair[0])), "%s travels" % pair[0])
		var beats := SideQuestPlay.play(st, str(pair[1]))
		assert_eq(SideQuestPlay.missing(beats), "", str(pair[0]))
		assert_true(_ended(beats), "%s: the talk closes" % pair[0])


func test_godfrey_on_the_road_can_still_knight_godrick() -> void:
	var st := _hut()
	st.set_flag("godfrey_remembers")
	st.set_quest_stage("the_ladle", "kept_faith")
	assert_true(st.add_guest("sir_godfrey_gwilym"))
	var beats := SideQuestPlay.play(st, "argynvostholt/godfrey:companion", ["Ask Sir Godfrey to knight him"])
	assert_eq(SideQuestPlay.missing(beats), "", "the knighting is reachable while he travels")


func test_rictavio_on_the_road_still_answers_for_aurel_and_never_walks_out_on_the_party() -> void:
	var st := SideQuestPlay.party(["silvain_aster", "ilse_varga", "hedda_ironvow"], 5, "vallaki", 12)
	st.tarokka = {"ally": "artifact"}
	st.set_flag("rictavio_met")
	st.set_flag("vallaki_backed", "wachter")
	st.set_quest_stage("aurels_last_chapter", "the_cipher")
	assert_true(st.add_guest("rictavio"))
	var beats := SideQuestPlay.play(st, "vallaki/rictavio:companion")
	assert_true(_has_option(beats, "Aurel Mirescu"), "Silvain's question is still there")
	assert_false(_has_option(beats, "Madam Eva's cards"), "and he is not asked to join again")
	assert_false(bool(st.get_flag("rictavio_gone", false)), "he doesn't leave a party he is travelling with")
	st.set_flag("rictavio_unmasked")
	var hunter := SideQuestPlay.play(st, "vallaki/rictavio:companion")
	assert_true(_has_option(hunter, "Aurel Mirescu"), "unmasked too")
	assert_true(_has_option(hunter, "tools of the trade"), "and his wares")
	assert_false(_has_option(hunter, "Madam Eva's cards"))
	assert_false(bool(st.get_flag("rictavio_gone", false)))
	assert_true(_ended(hunter))
