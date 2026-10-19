extends TestCase
## The option tag `[ends:<quest>]` / `[ends:<quest> if <condition>]` (Side Quest Failure Plan F4, docs/contracts/dialogue.md): the
## file parses it beside the other tags, and the runner names the quests choosing that option closes, so the dialogue box can
## mark it. A condition that doesn't hold, or a quest that has already ended, leaves the option unmarked.

const DIALOGUE := """
~ menu
Narrator: The basket sits between you.
* [ends:the_fourth_sister] (Take the basket and let her go.) -> END
* [ends:the_fourth_sister] [ends:the_priests_son] Both at once. -> END
* [ends:the_fourth_sister if flag.late] Only when it is late. -> END
* [Cleric] [ends:the_priests_son] Say a prayer. -> END
* [if flag.shown] [ends:the_priests_son if flag.late and not flag.early] Another way. -> END
* Walk away. -> END
"""


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/ends"))


func _story() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	return st


func _menu(st: StoryState) -> Array:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/ends:menu"))
	assert_eq(str(r.next()["kind"]), "line")
	var b := r.next()
	assert_eq(str(b["kind"]), "options")
	return b["options"] as Array


func test_the_tag_parses_beside_the_others() -> void:
	var f := DialogueFile.parse(DIALOGUE, "test/ends")
	assert_true(f.errors.is_empty(), str(f.errors))
	var opts := (f.nodes["menu"] as Array).filter(func(s: Variant) -> bool: return str((s as Dictionary)["t"]) == "option")
	assert_eq(opts.size(), 6)
	var first := opts[0] as Dictionary
	assert_eq(first["ends"], [{"quest": "the_fourth_sister", "cond": ""}])
	assert_eq(str(first["text"]), "(Take the basket and let her go.)", "the tag isn't part of the words")
	assert_eq(first["tags"], [] as Array[String], "and it isn't a label either")
	assert_eq(str(first["selector"]), "", "nor a selector (it has a colon)")
	var both := opts[1] as Dictionary
	assert_eq((both["ends"] as Array).size(), 2)
	assert_eq(str(((opts[2] as Dictionary)["ends"] as Array)[0]["cond"]), "flag.late")
	var prayer := opts[3] as Dictionary
	assert_eq(str(prayer["selector"]), "class:cleric", "a class tag still picks who says it")
	assert_eq((prayer["ends"] as Array).size(), 1)
	var gated := opts[4] as Dictionary
	assert_eq(str(gated["cond"]), "flag.shown")
	assert_eq(str(((gated["ends"] as Array)[0] as Dictionary)["cond"]), "flag.late and not flag.early")
	assert_eq((opts[5] as Dictionary)["ends"], [] as Array, "an ordinary option has none")


func test_the_menu_names_what_each_option_closes() -> void:
	var opts := _menu(_story())
	assert_eq(opts.size(), 4, "the Cleric's option and the flag-gated one are hidden")
	assert_eq(opts[0]["ends"], ["The Fourth Sister"] as Array[String])
	assert_eq(opts[1]["ends"], ["The Fourth Sister", "The Priest's Son"] as Array[String])
	assert_eq(opts[2]["ends"], [] as Array[String], "its condition doesn't hold yet")
	assert_eq(opts[3]["ends"], [] as Array[String], "walking away closes nothing")


func test_a_condition_that_holds_marks_it() -> void:
	var st := _story()
	st.set_flag("late", true)
	var opts := _menu(st)
	assert_eq(opts[2]["ends"], ["The Fourth Sister"] as Array[String])


func test_a_menu_where_every_option_closes_the_same_quest_is_a_beat() -> void:
	DialogueFile.register(DialogueFile.parse("""
~ beat
Narrator: He sits by the fire.
* [ends:the_fourth_sister] (Sit beside him.) -> END
* [ends:the_fourth_sister] I am sorry. -> END
""", "test/ends_beat"))
	DialogueFile.register(DialogueFile.parse("""
~ mixed
Narrator: He sits by the fire.
* [ends:the_fourth_sister] (Sit beside him.) -> END
* [ends:the_priests_son] I am sorry. -> END
""", "test/ends_mixed"))
	for key: String in ["test/ends_beat:beat", "test/ends_mixed:mixed"]:
		var r := DialogueRunner.new(_story(), DiceRoller.new(1))
		assert_true(r.start(key))
		r.next()
		var opts := r.next()["options"] as Array
		var marked := opts.filter(func(o: Variant) -> bool: return not ((o as Dictionary)["ends"] as Array).is_empty())
		if key.ends_with(":beat"):
			assert_eq(marked.size(), (2 if DialogueRunner.MARK_UNIFORM_MENUS else 0), "a beat wears no seals (unless the switch is flipped)")
		else:
			assert_eq(marked.size(), 2, "different quests are choices: both marked")


func test_a_quest_already_over_has_nothing_left_to_close() -> void:
	var st := _story()
	assert_true(st.set_quest_stage("the_fourth_sister", "given"))
	var opts := _menu(st)
	assert_eq(opts[0]["ends"], [] as Array[String], "it has failed already: no seal on the choice")
	assert_eq(opts[1]["ends"], ["The Priest's Son"] as Array[String], "the other quest's name is still there")
