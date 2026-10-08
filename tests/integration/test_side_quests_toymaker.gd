extends TestCase
## The Toymaker's Masterpiece (docs/story/side_quests.md): Goodwife Marta's rumour, Blinsky's dream of von Weerg's
## jester, Pidlwick II talked round on his stair, the scene at the bottom of Blinsky's stair, the endings (he stays, or
## the cards keep him with the party), and Blinsky's masterwork given once.

const SIX: Array[String] = ["godrick_pendlebrook", "wren_featherfoot", "liriel_dawnsong", "ratatoille"]


func _vallaki() -> StoryState:
	var st := SideQuestPlay.party(SIX, 10, "vallaki", 11)
	st.set_flag("vallaki_arrived")
	return st


## Pidlwick travelling with the party, willing, and the party in Blinsky's shop.
func _at_the_shop(st: StoryState) -> void:
	st.set_flag("blinsky_met")
	st.set_flag("pidlwick_willing")
	st.set_quest_stage("toymakers_masterpiece", "willing")
	st.add_guest("pidlwick_ii")
	st.location = "vallaki_blinsky_toys"


func test_the_rumour_the_stair_and_the_jester_who_stays() -> void:
	var st := _vallaki()
	var beats := SideQuestPlay.play(st, "vallaki/townsfolk:goodwife", ["Heard anything interesting?"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("toymakers_masterpiece"), "rumored")
	st.location = "vallaki_blinsky_toys"
	beats = SideQuestPlay.play(st, "vallaki/blinsky:start", ["Did you ever make a toy that walks?", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(SideQuestPlay.text(beats).contains("von Weerg"))
	assert_eq(st.quest_stage("toymakers_masterpiece"), "asked")
	# Up at the castle: no Persuasion, but a game of catch earns the honest answer.
	st.location = "castle_ravenloft_spires"
	st.set_flag("pidlwick_met")
	beats = SideQuestPlay.play(st, "castle_ravenloft/spires_pidlwick:start",
		["There's a toymaker in Vallaki", "Toss him a pebble", "He's lonely"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("pidlwick_willing", false)))
	assert_eq(st.quest_stage("toymakers_masterpiece"), "willing")
	assert_true("pidlwick_ii" in st.guest_ids, "he comes along")
	# Blinsky's shop: nobody knows his secret yet, so the party can only watch.
	st.location = "vallaki_blinsky_toys"
	st.gold = 0
	beats = SideQuestPlay.play(st, "vallaki/blinsky:start", ["Watch him"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var said := SideQuestPlay.text(beats)
	assert_true(said.contains("I DIDN'T. THAT IS NEW."))
	assert_true(bool(st.get_flag("pidlwick_truth_known", false)), "the slate tells the rest")
	assert_eq(st.quest_stage("toymakers_masterpiece"), "home")
	assert_true(st.party_has_item("figurine_of_wondrous_power_obsidian_steed"))
	assert_false("pidlwick_ii" in st.guest_ids, "he stays with Blinsky")
	assert_eq(SideQuestPlay.standing(st, "castle_ravenloft_spires", "pidlwick_ii"), "", "not back on the stair")
	assert_eq(SideQuestPlay.standing(st, "vallaki_blinsky_toys", "pidlwick_ii"), "vallaki/toymakers_masterpiece:pidlwick_home")
	beats = SideQuestPlay.play(st, "vallaki/blinsky:start", ["Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("juggling in the window"))
	assert_false(SideQuestPlay.text(beats).contains("crate lids"), "nobody told him, so no ramp")
	beats = SideQuestPlay.play(st, "vallaki/blinsky:start", ["Goodbye"])
	assert_false(SideQuestPlay.text(beats).contains("juggling in the window"), "the window scene plays once")
	assert_false(SideQuestPlay.text(beats).contains("black stone horse"), "the horse is given once")


func test_telling_blinsky_the_truth_builds_a_ramp() -> void:
	var st := _vallaki()
	_at_the_shop(st)
	st.set_flag("pidlwick_truth_known")
	var beats := SideQuestPlay.play(st, "vallaki/blinsky:start", ["tell Blinsky what happened"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("blinsky_told", false)))
	assert_eq(st.quest_stage("toymakers_masterpiece"), "home")
	beats = SideQuestPlay.play(st, "vallaki/blinsky:start", ["Goodbye"])
	assert_true(SideQuestPlay.text(beats).contains("crate lids"))


func test_the_cards_keep_him_with_the_party() -> void:
	var st := _vallaki()
	_at_the_shop(st)
	st.tarokka["ally"] = "marionette"
	st.set_flag("pidlwick_truth_known")
	var beats := SideQuestPlay.play(st, "vallaki/blinsky:start", ["say nothing"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("toymakers_masterpiece"), "promised")
	assert_true("pidlwick_ii" in st.guest_ids, "the marionette card's ally stays with the party")
	assert_true(st.party_has_item("figurine_of_wondrous_power_obsidian_steed"))


func test_he_wont_come_in_until_hes_talked_round() -> void:
	var st := _vallaki()
	st.set_flag("blinsky_met")
	st.set_quest_stage("toymakers_masterpiece", "asked")
	st.add_guest("pidlwick_ii")
	st.location = "vallaki_blinsky_toys"
	var beats := SideQuestPlay.play(st, "vallaki/blinsky:start", ["Never mind", "Goodbye"])
	assert_eq(SideQuestPlay.missing(beats), "", "back to Blinsky's own menu")
	assert_true(SideQuestPlay.text(beats).contains("won't come past the door"))
	assert_false(bool(st.get_flag("pidlwick_met_blinsky", false)))
	# Persuasion at the door, tried with a few dice: a success goes straight into the meeting.
	var talked := false
	for seed: int in [1, 2, 3, 5, 8, 13]:
		var copy := SideQuestPlay.party(SIX, 10, "vallaki_blinsky_toys", 11)
		copy.flags = st.flags.duplicate(true)
		copy.quests = st.quests.duplicate(true)
		copy.add_guest("pidlwick_ii")
		beats = SideQuestPlay.play(copy, "vallaki/blinsky:start", ["He only wants to say hello", "Watch him"], seed)
		if copy.quest_stage("toymakers_masterpiece") == "home":
			talked = true
			assert_true(SideQuestPlay.text(beats).contains("HELLO. I AM PIDLWICK. THE SECOND."))
			break
	assert_true(talked, "some roll talks him in")
