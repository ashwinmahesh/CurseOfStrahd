extends TestCase
## The finale for the allies (Story Allies Presence Plan, package F1; narrative/strahd/final.dialogue, narrative/castle_ravenloft/
## catacombs_sergei.dialogue, catacombs_coffin.dialogue, gates_dinner.dialogue, data/endings/strahd_destroyed.json and
## strahd_triumphant.json, docs/story/allies_finale.md). Ireena can answer Strahd at his parley as herself; at Sergei's tomb and at the
## coffin she shows what she learned and what the lessons gave her hands; Ezmerelda and Izek have a word at the dinner and over the
## coffin; her epilogue says whether she kept his letter or the sword. Kasimir's lines in the castle are package K2's.

const PARLEY := "strahd/final:parley"
const ANSWERS := "strahd/final:ireena_answers"
const TOMB := "castle_ravenloft/catacombs_sergei:ireena_first_sight"
const COFFIN := "castle_ravenloft/catacombs_coffin"


func _party(location: String = "castle_ravenloft_gates") -> StoryState:
	return SideQuestPlay.party(["ilse_varga", "hedda_ironvow"], 10, location, 20)


## Ireena along, knowing whose face she wears and trusting the party.
func _ready_to_answer() -> StoryState:
	var st := _party()
	assert_true(st.add_guest("ireena"))
	st.set_flag("ireena_knows_tatyana")
	st.set_flag("ireena_trust", 3)
	return st


func _says(beats: Array[Dictionary], words: String) -> bool:
	return SideQuestPlay.text(beats).contains(words)


func _menu(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			for o: Variant in b["options"] as Array:
				if bool((o as Dictionary).get("enabled", true)):
					out.append(str((o as Dictionary)["text"]))
	return out


func _has_option(beats: Array[Dictionary], words: String) -> bool:
	for t in _menu(beats):
		if t.contains(words):
			return true
	return false


# --- The parley ---------------------------------------------------------------------------------------------------------------

func test_ireena_can_answer_him_only_when_she_knows_trusts_and_is_along() -> void:
	assert_true(_has_option(SideQuestPlay.play(_ready_to_answer(), PARLEY, ["We yield"]), "Let Ireena answer him"))
	var apart := _party()
	apart.set_flag("ireena_knows_tatyana")
	apart.set_flag("ireena_trust", 3)
	assert_false(_has_option(SideQuestPlay.play(apart, PARLEY, ["We yield"]), "Let Ireena answer him"), "not along")
	var unaware := _ready_to_answer()
	unaware.flags.erase("ireena_knows_tatyana")
	assert_false(_has_option(SideQuestPlay.play(unaware, PARLEY, ["We yield"]), "Let Ireena answer him"), "does not know whose face she wears")
	var cool := _ready_to_answer()
	cool.set_flag("ireena_trust", 2)
	assert_false(_has_option(SideQuestPlay.play(cool, PARLEY, ["We yield"]), "Let Ireena answer him"), "does not yet trust the party")
	var done := _ready_to_answer()
	done.set_flag("ireena_answered_strahd")
	assert_false(_has_option(SideQuestPlay.play(done, PARLEY, ["We yield"]), "Let Ireena answer him"), "once")


func test_her_answer_decides_nothing_and_comes_back_to_the_price() -> void:
	var st := _ready_to_answer()
	var beats := SideQuestPlay.play(st, PARLEY, ["Let Ireena answer him", "We came to end you"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "My name is Ireena Kolyana, and I am the burgomaster's daughter"))
	assert_true(_says(beats, "I am not a price to be paid on your stairs"))
	assert_true(_says(beats, "Keep the name Kolyan gave you a little longer, Tatyana"))
	assert_false(_says(beats, "I kept your last letter"), "no letter, no word of it")
	assert_true(bool(st.get_flag("ireena_answered_strahd", false)))
	assert_eq(str(st.get_flag("strahd_parley", "")), "fight", "the party's own answer, after hers")
	var yield_st := _ready_to_answer()
	SideQuestPlay.play(yield_st, ANSWERS, ["We yield"])
	assert_eq(str(yield_st.get_flag("strahd_parley", "")), "yield", "her answer set nothing: the menu was still the party's")
	var give := _ready_to_answer()
	assert_true(_has_option(SideQuestPlay.play(give, ANSWERS, ["We yield"]), "Take her, then"), "and the price is still on the table")


func test_the_kept_letter_comes_up_only_when_she_kept_it() -> void:
	var st := _ready_to_answer()
	st.set_flag("ireena_kept_letter")
	var beats := SideQuestPlay.play(st, ANSWERS, ["We yield"])
	assert_true(_says(beats, "I kept your last letter in my coat, though never because I meant to come to you"))
	assert_true(_says(beats, "in this house that is answer enough"))


# --- Sergei's tomb and the coffin ---------------------------------------------------------------------------------------------

func test_at_the_tomb_she_knows_whose_face_it_is_when_she_has_read_the_book() -> void:
	var st := _party("castle_ravenloft_catacombs_tombs")
	assert_true(st.add_guest("ireena"))
	assert_true(_says(SideQuestPlay.play(st, TOMB), "I've dreamed your face for years and never known whose it was"))
	var knows := _party("castle_ravenloft_catacombs_tombs")
	assert_true(knows.add_guest("ireena"))
	knows.set_flag("ireena_knows_tatyana")
	var beats := SideQuestPlay.play(knows, TOMB)
	assert_true(_says(beats, "You are the brother from his book. I knew your face before the water showed it to me."))
	assert_false(_says(beats, "never known whose it was"))


func test_when_she_drives_the_stake_her_hands_and_her_answer_show_what_she_learned() -> void:
	var plain := _party("castle_ravenloft_catacombs_strahd")
	assert_true(plain.add_guest("ireena"))
	var p := SideQuestPlay.play(plain, COFFIN + ":ireena_stake")
	assert_true(_says(p, "Tatyana."))
	assert_true(("\n" + SideQuestPlay.text(p)).contains("\nNo.\n"), "the bare refusal")
	assert_false(_says(p, "steady from cold mornings"))
	assert_false(_says(p, "from your own pages"))
	var taught := _party("castle_ravenloft_catacombs_strahd")
	assert_true(taught.add_guest("ireena"))
	taught.set_flag("ireena_lessons", 2)
	taught.set_flag("ireena_knows_tatyana")
	var t := SideQuestPlay.play(taught, COFFIN + ":ireena_stake")
	assert_true(_says(t, "steady from cold mornings of patient sword practice"))
	assert_true(_says(t, "I know her name from your own pages, and it is not mine."))
	assert_false(("\n" + SideQuestPlay.text(t)).contains("\nNo.\n"), "no bare refusal when she knows")
	var once := _party("castle_ravenloft_catacombs_strahd")
	assert_true(once.add_guest("ireena"))
	once.set_flag("ireena_lessons", 1)
	assert_false(_says(SideQuestPlay.play(once, COFFIN + ":ireena_stake"), "steady from cold mornings"), "one lesson is not enough")


func test_ezmerelda_and_izek_have_a_word_over_the_coffin() -> void:
	var asleep := _party("castle_ravenloft_catacombs_strahd")
	asleep.minute_of_day = 12 * 60
	assert_true(asleep.add_guest("ezmerelda"))
	assert_true(asleep.add_guest("izek"))
	var a := SideQuestPlay.play(asleep, COFFIN + ":asleep")
	assert_true(_says(a, "Nobody touches the stake until every hand is set. That is the rule."))
	assert_true(_says(a, "He looks smaller in a box. Do it before he wakes."))
	var alone := _party("castle_ravenloft_catacombs_strahd")
	alone.minute_of_day = 12 * 60
	var none := SideQuestPlay.play(alone, COFFIN + ":asleep")
	assert_false(_says(none, "Nobody touches the stake"))
	assert_false(_says(none, "smaller in a box"))
	var resting := _party("castle_ravenloft_catacombs_strahd")
	assert_true(resting.add_guest("ezmerelda"))
	assert_true(resting.add_guest("izek"))
	assert_true(resting.add_guest("ireena"))
	var r := SideQuestPlay.play(resting, COFFIN + ":resting")
	assert_true(_says(r, "Still talking from the bottom of a box"))
	assert_true(_says(r, "Stay behind my arm, Ireena. He is done reaching for you."))
	var without := _party("castle_ravenloft_catacombs_strahd")
	assert_true(without.add_guest("izek"))
	assert_false(_says(SideQuestPlay.play(without, COFFIN + ":resting"), "Stay behind my arm"), "only for the sister who is there")


# --- The dinner ---------------------------------------------------------------------------------------------------------------

func test_the_host_greets_the_huntress_and_the_brother() -> void:
	var st := _party()
	st.set_flag("strahd_invitation", "accepted")
	assert_true(st.add_guest("ezmerelda"))
	assert_true(st.add_guest("ireena"))
	assert_true(st.add_guest("izek"))
	var beats := SideQuestPlay.play(st, "castle_ravenloft/gates_dinner:start", ["Excuse yourselves"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "Welcome to my table, Ezmerelda, though Rudolph would never have approved"))
	assert_true(_says(beats, "as cold as the silver"))
	assert_true(_says(beats, "So this is the brother who found his way to my gates"))
	assert_true(_says(beats, "I stand behind her chair"))
	var bare := _party()
	bare.set_flag("strahd_invitation", "accepted")
	var b := SideQuestPlay.play(bare, "castle_ravenloft/gates_dinner:start", ["Excuse yourselves"])
	assert_false(_says(b, "Ezmerelda"))
	assert_false(_says(b, "the brother who found his way"))
	var lone := _party()
	lone.set_flag("strahd_invitation", "accepted")
	assert_true(lone.add_guest("izek"))
	assert_false(_says(SideQuestPlay.play(lone, "castle_ravenloft/gates_dinner:start", ["Excuse yourselves"]), "the brother who found his way"), "she is not at the table")


# --- Her epilogue -------------------------------------------------------------------------------------------------------------

func _slide(ending: String, st: StoryState) -> String:
	for s in Endings.slides(Endings.get_ending(ending), st):
		if str(s["topic"]) == "ireena":
			return str(s["text"])
	return ""


func test_her_epilogue_says_whether_she_kept_the_letter_or_the_sword() -> void:
	var letter := _party()
	assert_true(letter.add_guest("ireena"))
	letter.set_flag("ireena_trust", 4)
	letter.set_flag("ireena_kept_letter")
	assert_true(_slide("strahd_destroyed", letter).contains("gave his last letter to the fire"))
	var sword := _party()
	assert_true(sword.add_guest("ireena"))
	sword.set_flag("ireena_lessons", 3)
	assert_true(_slide("strahd_destroyed", sword).contains("spars with her brother Ismark before breakfast"))
	var plain := _party()
	assert_true(plain.add_guest("ireena"))
	assert_true(_slide("strahd_destroyed", plain).contains("Ireena walks out of the castle's shadow"), "the usual one otherwise")
	var cool := _party()
	assert_true(cool.add_guest("ireena"))
	cool.set_flag("ireena_trust", 3)
	cool.set_flag("ireena_kept_letter")
	assert_false(_slide("strahd_destroyed", cool).contains("last letter to the fire"), "needs the trust too")

	var hiding := _party()
	hiding.set_flag("ireena_trust", 4)
	hiding.set_flag("ireena_kept_letter")
	assert_true(_slide("strahd_triumphant", hiding).contains("keeps it still"), "the devil endured")
	var armed := _party()
	armed.set_flag("ireena_lessons", 3)
	assert_true(_slide("strahd_triumphant", armed).contains("naked sword beside her bed"))
	var lady := _party()
	assert_true(lady.add_guest("ireena"))
	lady.set_flag("ireena_lessons", 3)
	lady.set_flag("ireena_trust", 4)
	lady.set_flag("ireena_kept_letter")
	assert_true(_slide("strahd_triumphant", lady).contains("lady of the castle"), "carried to the castle she is the bride, whatever she kept")
	var krezk := _party()
	krezk.set_flag("ireena_in_krezk")
	krezk.set_flag("ireena_lessons", 3)
	assert_true(_slide("strahd_triumphant", krezk).contains("black carriage stops at the gate"), "behind Krezk's wall the carriage comes")
	var plain_dark := _party()
	assert_true(_slide("strahd_triumphant", plain_dark).contains("hides, and runs"), "and the usual one when nothing was kept")


func test_nothing_here_names_the_count_in_her_own_mouth() -> void:
	var text := FileAccess.get_file_as_string("res://narrative/strahd/final.dialogue")
	var start := text.find("~ ireena_answers")
	var stop := text.find("~ trapped")
	var block := text.substr(start, stop - start)
	for line in block.split("\n"):
		if line.begins_with("Ireena"):
			assert_false(line.contains("Strahd"), "she never says his name: " + line)
