extends TestCase
## Kasimir walks his road (Story Allies Presence Plan, package K1; narrative/allies/kasimir.dialogue, his menu in
## narrative/vallaki/kasimir.dialogue, data/npcs/kasimir_velikov.json, data/flags/allies_kasimir.json). Once he has told
## of Patrina and the party is headed for the mountains the camp offers "Come with us to the temple": he walks with the
## party (his temple scenes play as for the Tarokka's Seer) and cannot be sent home on the way up. If the party dealt with
## Patrina without him he can be told at the camp (laid to rest, or destroyed). After the temple he offers to go home
## unless asked to stay. His hub (the camp's menu, a click while he travels) shows the three newest topics unheard, each
## once.

const CAMP := "vallaki_vistani_camp"
const START := "vallaki/kasimir:start"
const HUB := "allies/kasimir:talk"
const KASIMIR := "kasimir_velikov"


func _party(level: int = 9, location: String = CAMP) -> StoryState:
	return SideQuestPlay.party(["ilse_varga", "hedda_ironvow"], level, location, 12)


## Kasimir has told of Patrina.
func _told(st: StoryState) -> StoryState:
	st.set_flag("kasimir_met")
	st.set_flag("kasimir_sister_told")
	return st


## Every menu the beats showed, as the texts of the options that were enabled.
func _menus(beats: Array[Dictionary]) -> Array:
	var out: Array = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			var texts: Array[String] = []
			for o: Variant in b["options"] as Array:
				if bool((o as Dictionary).get("enabled", true)):
					texts.append(str((o as Dictionary)["text"]))
			out.append(texts)
	return out


func _has(menu: Array, words: String) -> bool:
	for t: Variant in menu:
		if str(t).contains(words):
			return true
	return false


func _says(beats: Array[Dictionary], words: String) -> bool:
	return SideQuestPlay.text(beats).contains(words)


func _ends(beats: Array[Dictionary]) -> bool:
	return str(beats[-1].get("kind", "")) == "end"


## The topics a hub menu offered, in the order shown (every option but the exit).
func _topics(menu: Array) -> Array[String]:
	var names := {"festival": "festival", "Arabelle": "arabelle", "Bluto": "bluto", "Tome": "tome", "dark gift": "gift",
		"dragon": "dragon", "scholar": "broker"}
	var out: Array[String] = []
	for t: Variant in menu:
		for key: String in names:
			if str(t).contains(key):
				out.append(str(names[key]))
	return out


# --- The offer and the way he joins --------------------------------------------------------------------------------------

func test_the_camp_offers_to_take_him_to_the_temple_once_he_has_told_of_her_and_the_party_is_headed_up() -> void:
	assert_false(_has(_menus(SideQuestPlay.play(_told(_party(5)), START))[0], "Come with us to the temple"), "level 5: too soon")
	assert_true(_has(_menus(SideQuestPlay.play(_told(_party(8)), START))[0], "Come with us to the temple"), "level 8")
	var seen := _told(_party(5))
	seen.visited["tsolenka_pass"] = true
	assert_true(_has(_menus(SideQuestPlay.play(seen, START))[0], "Come with us to the temple"), "or they have stood at the pass")
	var untold := _party(9)
	untold.set_flag("kasimir_met")
	assert_false(_has(_menus(SideQuestPlay.play(untold, START))[0], "Come with us to the temple"), "he hasn't told of her yet")
	var done := _told(_party(9))
	done.set_flag("patrina_fate", "rest")
	assert_false(_has(_menus(SideQuestPlay.play(done, START))[0], "Come with us to the temple"), "Patrina is at rest")
	var gone := _told(_party(9))
	gone.set_flag("patrina_destroyed")
	assert_false(_has(_menus(SideQuestPlay.play(gone, START))[0], "Come with us to the temple"), "Patrina is gone")
	var along := _told(_party(9))
	assert_true(along.add_guest(KASIMIR))
	assert_false(_has(_menus(SideQuestPlay.play(along, START))[0], "Come with us to the temple"), "he is already along")
	var ally := _told(_party(9))
	ally.tarokka = {"ally": "seer"}
	var menu := _menus(SideQuestPlay.play(ally, START))[0] as Array
	assert_false(_has(menu, "Come with us to the temple"), "the Seer's ally has his own way in")
	assert_true(_has(menu, "Madam Eva's cards named you"))


func test_asking_him_along_makes_him_a_guest_and_empties_the_camp() -> void:
	var st := _told(_party())
	assert_eq(SideQuestPlay.standing(st, CAMP, KASIMIR), "vallaki/kasimir:start")
	var beats := SideQuestPlay.play(st, START, ["Come with us to the temple"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "let me be the first to speak to her"), "his one request")
	assert_true(_ends(beats), "the scene ends")
	assert_true(KASIMIR in st.guest_ids, "he walks with the party")
	assert_eq(SideQuestPlay.standing(st, CAMP, KASIMIR), "", "and the camp's stool is empty")
	var node: Array = DialogueFile.load_key("allies/kasimir").nodes["come"]
	var gives := false
	for s: Dictionary in node:
		gives = gives or str(s["t"]) == "tarokka_give"
	assert_true(gives, "the Beggar's treasure he keeps goes with the road, as in his other ways of joining")
	# At the camp the party can still send him home (nothing keeps him there), and the offer comes back.
	assert_eq(st.guest_stays(KASIMIR), "")
	assert_true(st.send_guest_home(KASIMIR))
	assert_eq(SideQuestPlay.standing(st, CAMP, KASIMIR), "vallaki/kasimir:start")
	assert_true(_has(_menus(SideQuestPlay.play(st, START))[0], "Come with us to the temple"))


func test_he_is_not_sent_back_down_the_mountain_before_he_reaches_her_or_after_he_has_traded_his_years() -> void:
	var st := _told(_party(9, "tsolenka_pass"))
	st.add_guest(KASIMIR)
	assert_ne(st.guest_stays(KASIMIR), "", "on the pass, with his sister unresolved")
	assert_false(st.send_guest_home(KASIMIR))
	st.location = "amber_temple_entrance"
	assert_ne(st.guest_stays(KASIMIR), "", "and in the temple")
	st.location = CAMP
	assert_eq(st.guest_stays(KASIMIR), "", "but not at the camp")
	st.location = "tsolenka_pass"
	st.set_flag("patrina_fate", "rest")
	assert_eq(st.guest_stays(KASIMIR), "", "free to go once she is at rest")
	var bargain := _told(_party(9, "vallaki"))
	bargain.add_guest(KASIMIR)
	bargain.set_flag("kasimir_bargain", "made")
	bargain.set_flag("patrina_fate", "restored")
	assert_ne(bargain.guest_stays(KASIMIR), "", "he has a year left and will not spend it at a Vistani fire")
	var ally := _told(_party(9, "vallaki"))
	ally.tarokka = {"ally": "seer"}
	ally.add_guest(KASIMIR)
	assert_ne(ally.guest_stays(KASIMIR), "", "the Seer's ally always sees it through")


func test_a_guest_who_falls_on_the_mountain_is_patched_up_not_carried_home() -> void:
	var up := _told(_party(9, "tsolenka_pass"))
	up.add_guest(KASIMIR)
	up.guests[0].hp = 0
	up.guests[0].dead = true
	assert_eq(up.see_to_fallen_guests(), [] as Array[String], "nobody is sent home from the pass")
	assert_true(KASIMIR in up.guest_ids)
	assert_eq(up.guests[0].hp, 1)
	var down := _told(_party(9, "vallaki"))
	down.add_guest(KASIMIR)
	down.guests[0].hp = 0
	down.guests[0].dead = true
	assert_eq(down.see_to_fallen_guests(), ["Kasimir Velikov"] as Array[String], "in the valley he is carried home to heal")


# --- At the camp, after the temple ----------------------------------------------------------------------------------------

func test_laid_to_rest_without_him_the_party_can_tell_him_in_as_many_pieces_as_they_choose() -> void:
	var st := _told(_party())
	st.set_flag("patrina_fate", "rest")
	var first := SideQuestPlay.play(st, START)
	assert_true(_says(first, "mountain air"), "he sees it on them")
	assert_true(_has(_menus(first)[0], "word of Patrina"))
	var whole := SideQuestPlay.play(st, START, ["word of Patrina", "done waiting", "stones hurt", "very good at quiet"])
	assert_eq(SideQuestPlay.missing(whole), "")
	assert_true(_says(whole, "do not go after it"), "the net")
	assert_true(_ends(whole))
	assert_true(bool(st.get_flag("kasimir_heard_rest", false)), "the side flag the epilogue reads")
	var after := SideQuestPlay.play(st, START)
	assert_true(_says(after, "second saddest place in the camp"), "a lighter greeting afterwards")
	assert_false(_has(_menus(after)[0], "word of Patrina"), "told once")
	var brief := _told(_party())
	brief.set_flag("patrina_fate", "rest")
	SideQuestPlay.play(brief, START, ["word of Patrina", "done waiting", "That is all she said"])
	assert_true(bool(brief.get_flag("kasimir_heard_rest", false)), "the first piece is enough")
	var later := _told(_party())
	later.set_flag("patrina_fate", "rest")
	var postponed := SideQuestPlay.play(later, START, ["word of Patrina", "Not yet"])
	assert_true(_says(postponed, "wait a little longer"))
	assert_false(bool(later.get_flag("kasimir_heard_rest", false)), "they can come back")
	assert_true(_has(_menus(SideQuestPlay.play(later, START))[0], "word of Patrina"))


func test_nothing_to_tell_when_he_stood_before_her_himself_or_has_not_told_of_her() -> void:
	var peace := _told(_party())
	peace.set_flag("patrina_fate", "rest")
	peace.set_flag("kasimir_at_peace")
	var beats := SideQuestPlay.play(peace, START)
	assert_false(_has(_menus(beats)[0], "word of Patrina"), "she said it to him herself")
	assert_true(_says(beats, "second saddest place in the camp"), "and the camp sees a lighter man")
	var strangers := _party()
	strangers.set_flag("kasimir_met")
	strangers.set_flag("patrina_fate", "rest")
	assert_false(_has(_menus(SideQuestPlay.play(strangers, START))[0], "word of Patrina"), "he hasn't told them whose sister she was")


func test_destroyed_he_asks_only_whether_she_was_afraid_and_his_warmth_goes_whatever_they_answer() -> void:
	for pick: String in ["No. She was angry", "Yes. She was afraid", "We cannot say"]:
		var st := _told(_party())
		st.set_flag("patrina_destroyed")
		var first := SideQuestPlay.play(st, START)
		assert_true(_says(first, "you do not look at me"), pick + ": he reads it in their faces")
		var beats := SideQuestPlay.play(st, START, ["we must speak of Patrina", pick])
		assert_eq(SideQuestPlay.missing(beats), "", pick)
		assert_true(_says(beats, "was she afraid"), pick)
		assert_true(_ends(beats), pick + ": he does not ask them to stay")
		assert_true(bool(st.get_flag("kasimir_heard_destroyed", false)), pick)
		assert_true(bool(st.get_flag("kasimir_cold", false)), pick + ": the warmth is gone")
		var again := SideQuestPlay.play(st, START)
		assert_true(_says(again, "conclude our business"), pick + ": curt from then on")
		assert_false(_has(_menus(again)[0], "we must speak of Patrina"), pick + ": told once")
		assert_eq(st.guest_stays(KASIMIR), "")


func test_his_scrolls_cost_a_quarter_more_once_he_is_cold_and_nothing_else_changes() -> void:
	var st := _told(_party())
	assert_eq(Trade.buy_price(st, KASIMIR, 100.0), 100.0)
	assert_eq(Trade.buy_price(st, KASIMIR, 4.0), 4.0)
	st.set_flag("kasimir_cold")
	assert_eq(Trade.buy_price(st, KASIMIR, 100.0), 125.0, "a quarter more")
	assert_eq(Trade.sell_price(st, KASIMIR, 100.0), 100.0, "what he pays is as it was")
	assert_eq(st.attitude(KASIMIR), "indifferent")
	var hub := SideQuestPlay.play(st, HUB)
	assert_eq(SideQuestPlay.missing(hub), "")
	assert_true(_says(hub, "let us keep moving"), "the hub still answers, curtly")


# --- Walking with the party after the temple ------------------------------------------------------------------------------

func _after_rest() -> StoryState:
	var st := _told(_party(9, "amber_temple_faceless_god"))
	assert_true(st.add_guest(KASIMIR))
	st.set_flag("patrina_met")
	st.set_flag("patrina_kasimir_met")
	st.set_flag("kasimir_at_peace")
	st.set_flag("patrina_fate", "rest")
	return st


func test_after_she_is_at_rest_he_asks_to_go_home_and_the_party_can_let_him_go() -> void:
	var st := _after_rest()
	var beats := SideQuestPlay.play(st, HUB, ["Go home"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "inclined, for once, to obey her"), "the question comes first")
	assert_true(_says(beats, "door I could not open alone"))
	assert_true(_ends(beats))
	assert_false(KASIMIR in st.guest_ids, "he goes home")
	assert_true(bool(st.get_flag("kasimir_homeward_asked", false)))
	assert_eq(SideQuestPlay.standing(st, CAMP, KASIMIR), "vallaki/kasimir:start", "to his stool by the wagon")
	var camp := SideQuestPlay.play(st, START)
	assert_true(_says(camp, "second saddest place in the camp"))


func test_or_the_party_asks_him_to_stay_and_he_stays() -> void:
	var st := _after_rest()
	var beats := SideQuestPlay.play(st, HUB, ["Stay with us"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "A road will do."))
	assert_true(KASIMIR in st.guest_ids, "still along")
	assert_true(bool(st.get_flag("kasimir_homeward_asked", false)))
	assert_true(_ends(beats))
	var again := SideQuestPlay.play(st, HUB)
	assert_false(_says(again, "inclined, for once"), "asked once")
	assert_true(_says(again, "before the road takes us"), "his road opening instead")
	assert_eq(st.guest_stays(KASIMIR), "", "and the Party screen can still send him home")


func test_or_they_decide_later_and_the_question_comes_back() -> void:
	var st := _after_rest()
	var beats := SideQuestPlay.play(st, HUB, ["decide later"])
	assert_true(_says(beats, "another mile"))
	assert_true(KASIMIR in st.guest_ids)
	assert_false(bool(st.get_flag("kasimir_homeward_asked", false)))
	assert_true(_says(SideQuestPlay.play(st, HUB), "inclined, for once"), "asked again at the next talk")


func test_the_seers_ally_and_a_man_who_traded_his_years_are_not_asked_to_go_home() -> void:
	var ally := _after_rest()
	ally.tarokka = {"ally": "seer"}
	assert_false(_says(SideQuestPlay.play(ally, HUB), "inclined, for once"), "the Seer's ally sees it through")
	var bargain := _told(_party(9, "amber_temple_faceless_god"))
	bargain.add_guest(KASIMIR)
	bargain.set_flag("kasimir_bargain", "made")
	bargain.set_flag("patrina_fate", "restored")
	var beats := SideQuestPlay.play(bargain, HUB)
	assert_false(_says(beats, "inclined, for once"))
	assert_true(_says(beats, "my count is smaller"), "he counts instead")


# --- The hub -------------------------------------------------------------------------------------------------------------

## A party at the camp with every topic open: a dark gift taken, the Tome in the pack, the lake and the festival settled.
func _full() -> StoryState:
	var st := _told(_party(9))
	st.party[0].add_item("tome_of_strahd")
	st.set_flag("dark_gifts_taken", 1)
	st.set_flag("bluto_fate", "saved")
	st.set_flag("vallaki_backed", "baron")
	st.set_flag("arabelle_rescued")
	return st


func test_the_hub_shows_the_three_newest_topics_unheard_and_hearing_one_makes_room_for_the_next() -> void:
	var st := _full()
	var beats := SideQuestPlay.play(st, HUB, ["dark gift", "scholar", "dragon", "Tome"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var menus := _menus(beats)
	assert_eq(_topics(menus[0] as Array), ["gift", "broker", "dragon"] as Array[String], "the newest three, newest first")
	assert_eq(_topics(menus[1] as Array), ["broker", "dragon", "tome"] as Array[String], "the gift is heard, so the Tome comes up")
	assert_eq(_topics(menus[2] as Array), ["dragon", "tome", "bluto"] as Array[String])
	assert_eq(_topics(menus[3] as Array), ["tome", "bluto", "festival"] as Array[String])
	assert_eq(_topics(menus[4] as Array), ["bluto", "festival", "arabelle"] as Array[String], "the last of them")
	assert_true(_has(menus[0] as Array, "Let us talk of something else"), "at the camp the way out goes back to his menu")
	for flag_id: String in ["kasimir_heard_gift", "kasimir_heard_broker", "kasimir_heard_dragon", "kasimir_heard_tome"]:
		assert_true(bool(st.get_flag(flag_id, false)), flag_id)


func test_every_topic_plays_once_and_then_the_hub_has_nothing_new() -> void:
	var st := _full()
	var beats := SideQuestPlay.play(st, HUB, ["dark gift", "scholar", "dragon", "Tome", "Bluto", "festival", "Arabelle"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var menus := _menus(beats)
	assert_eq(_topics(menus[menus.size() - 2] as Array), [] as Array[String], "all heard")
	assert_true(_says(beats, "no new words for you today"))
	var again := SideQuestPlay.play(st, HUB)
	assert_eq(_topics(_menus(again)[0] as Array), [] as Array[String], "nothing replays")
	assert_true(_says(again, "no new words for you today"))
	assert_true(_ends(again), "and the exits work")


func test_travelling_with_the_party_he_has_no_vallaki_news() -> void:
	var st := _full()
	st.add_guest(KASIMIR)
	var menu := _menus(SideQuestPlay.play(st, HUB))[0] as Array
	assert_eq(_topics(menu), ["gift", "broker", "dragon"] as Array[String])
	var rest := _menus(SideQuestPlay.play(st, HUB, ["dark gift", "scholar", "dragon"]))
	assert_eq(_topics(rest[3] as Array), ["tome"] as Array[String], "the Tome, and none of the Vistani fire's news")
	assert_true(_has(rest[0] as Array, "That is all we need for now"), "on the road the way out ends it")


func test_the_hub_opens_to_the_state_he_is_in() -> void:
	var camp := SideQuestPlay.play(_told(_party()), HUB)
	assert_true(_says(camp, "The fire is warm"))
	var road := _told(_party())
	road.add_guest(KASIMIR)
	assert_true(_says(SideQuestPlay.play(road, HUB), "before the road takes us"))
	var cold := _told(_party())
	cold.set_flag("kasimir_cold")
	assert_true(_says(SideQuestPlay.play(cold, HUB), "let us keep moving"))
	var counting := _told(_party())
	counting.add_guest(KASIMIR)
	counting.set_flag("kasimir_bargain", "made")
	assert_true(_says(SideQuestPlay.play(counting, HUB), "my count is smaller"))


func test_a_party_that_has_not_been_told_of_the_temple_hears_no_warnings() -> void:
	var st := _party(9)
	st.set_flag("kasimir_met")
	var menu := _menus(SideQuestPlay.play(st, HUB))[0] as Array
	assert_eq(_topics(menu), [] as Array[String], "he hasn't told them of the temple")
	var told := _told(_party(5))
	assert_eq(_topics(_menus(SideQuestPlay.play(told, HUB))[0] as Array), [] as Array[String], "and a low party isn't headed up")


func _hear(st: StoryState, pick: String) -> Array[Dictionary]:
	var beats := SideQuestPlay.play(st, HUB, [pick])
	assert_eq(SideQuestPlay.missing(beats), "", pick)
	return beats


func test_the_festival_news_follows_how_the_town_ended() -> void:
	for pair: Array in [["baron", "orders his people to smile"], ["wachter", "quiet clerk of the castle"], ["neither", "Committees move slowly"]]:
		var st := _told(_party())
		st.set_flag("vallaki_backed", str(pair[0]))
		assert_true(_says(_hear(st, "festival"), str(pair[1])), str(pair[0]))
		assert_true(bool(st.get_flag("kasimir_heard_festival", false)))


func test_the_lake_news_follows_arabelle_and_bluto() -> void:
	var saved := _told(_party())
	saved.set_flag("arabelle_rescued")
	assert_true(_says(_hear(saved, "Arabelle"), "has not sung like that"))
	var lost := _told(_party())
	lost.set_flag("arabelle_lost")
	assert_true(_says(_hear(lost, "Arabelle"), "small girl"))
	for pair: Array in [["vistani", "walked down to the water"], ["killed", "short end to a small madness"],
			["drowned", "short end to a small madness"], ["saved", "You left him his life"], ["left", "You left him his life"]]:
		var st := _told(_party())
		st.set_flag("bluto_fate", str(pair[0]))
		assert_true(_says(_hear(st, "Bluto"), str(pair[1])), str(pair[0]))


func test_the_temple_warnings_read_from_the_temples_own_flags() -> void:
	var before := _told(_party())
	assert_true(_says(_hear(before, "dragon"), "do not take my word on the day"), "before the vestige has spoken")
	var heard := _told(_party())
	heard.set_flag("vestige_tarakamedes_heard")
	assert_true(_says(_hear(heard, "dragon"), "Do not tell me what it said"), "after")
	var refused := _told(_party())
	refused.set_flag("vestige_tarakamedes_heard")
	refused.set_flag("kasimir_bargain", "refused")
	assert_true(_says(_hear(refused, "dragon"), "you pulled me back"), "after they talked him out of it")
	var traded := _told(_party())
	traded.set_flag("vestige_tarakamedes_heard")
	traded.set_flag("kasimir_bargain", "made")
	assert_false("dragon" in _topics(_menus(SideQuestPlay.play(traded, HUB))[0] as Array), "after the bargain it is the temple's, and K2's")
	var unmet := _told(_party())
	assert_true(_says(_hear(unmet, "scholar"), "the politest voice is the one with a price list"))
	var met := _told(_party())
	met.set_flag("vosk_met")
	assert_true(_says(_hear(met, "scholar"), "never lack for ink"))


func test_the_tome_and_the_dark_gift() -> void:
	var st := _told(_party())
	assert_false("tome" in _topics(_menus(SideQuestPlay.play(st, HUB))[0] as Array), "no Tome, no pages")
	st.party[0].add_item("tome_of_strahd")
	assert_true(_says(_hear(st, "Tome"), "He did not even write her down"))
	var gift := _told(_party())
	assert_false("gift" in _topics(_menus(SideQuestPlay.play(gift, HUB))[0] as Array), "no gift taken")
	gift.set_flag("dark_gifts_taken", 2)
	assert_true(_says(_hear(gift, "dark gift"), "the bill is collected at the end"))


# --- Wiring ----------------------------------------------------------------------------------------------------------------

func test_clicking_him_opens_the_hub_and_every_conversation_has_a_way_out() -> void:
	assert_eq(GuestTalk.ref_for(KASIMIR), HUB, "guest_talk in data/npcs/kasimir_velikov.json")
	var file := DialogueFile.load_key("allies/kasimir")
	assert_true(file != null and file.nodes.has("talk") and file.nodes.has("hub_menu"))
	var states: Array[StoryState] = [_full(), _after_rest(), _told(_party())]
	states[2].set_flag("patrina_destroyed")
	for st: StoryState in states:
		for ref: String in [HUB, START]:
			var beats := SideQuestPlay.play(st, ref)
			assert_true(_ends(beats), ref + ": plays out to its end")
	for ref: String in ["allies/kasimir:hub_menu", "allies/kasimir:homeward"]:
		var runner := DialogueRunner.new(_after_rest(), DiceRoller.new(3))
		assert_true(runner.start(ref))
		var b := runner.next()
		for i in 20:
			if str(b["kind"]) == "options":
				break
			b = runner.next()
		assert_eq(str(b["kind"]), "options", ref)
		assert_true(AllyVisitAnswer.exit_option(runner, b["options"] as Array) >= 0, ref + ": the story bot has a way out")
