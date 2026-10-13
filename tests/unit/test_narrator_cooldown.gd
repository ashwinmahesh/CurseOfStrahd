extends TestCase
## The Narrator's `cooldown n` (story/narrator.gd): n game minutes between a trigger's lines, or n rounds within one
## fight. Lane 24's find (2026-10-12): the parser's line number overwrote the minutes, so every cooldown was the line's
## number in its file instead (lake_zarovich's "cooldown 30" became 10; combat lines cooled for hundreds of rounds).

const LINES := """# a comment, so the cooldown's line number isn't its minutes
~ test:minutes
| The wind changes.
| The water darkens.
cooldown 30

~ combat:test_crit
| A clean strike.
| A cruel strike.
cooldown 3
"""


func _story() -> StoryState:
	return SideQuestPlay.party(["ilse_varga"], 3, "lake_zarovich", 12)


func test_the_cooldown_keeps_its_minutes() -> void:
	var f := DialogueFile.parse(LINES, "narrator/test_cooldown")
	var cool := (f.nodes["test:minutes"] as Array).filter(func(s: Dictionary) -> bool: return str(s["t"]) == "cooldown")
	assert_eq(int((cool[0] as Dictionary)["minutes"]), 30)
	assert_eq(int((cool[0] as Dictionary)["n"]), 5, "n stays the line number (once-flags in saves are keyed on it)")


func test_a_cooldown_in_minutes_is_honoured() -> void:
	var n := Narrator.new(1)
	n.add_file(DialogueFile.parse(LINES, "narrator/test_cooldown"))
	var st := _story()
	assert_ne(n.line("test:minutes", st), "")
	st.advance_minutes(29)
	assert_eq(n.line("test:minutes", st), "", "29 minutes: still cooling")
	st.advance_minutes(1)
	assert_ne(n.line("test:minutes", st), "", "30 minutes: speaks again")


func test_a_cooldown_in_rounds_is_honoured_within_a_fight() -> void:
	var n := Narrator.new(1)
	n.add_file(DialogueFile.parse(LINES, "narrator/test_cooldown"))
	var st := _story()
	assert_ne(n.line("combat:test_crit", st, null, {"round": 1, "fight": "a"}), "")
	assert_eq(n.line("combat:test_crit", st, null, {"round": 3, "fight": "a"}), "", "two rounds on: cooling")
	assert_ne(n.line("combat:test_crit", st, null, {"round": 4, "fight": "a"}), "", "three rounds on: speaks")
	assert_ne(n.line("combat:test_crit", st, null, {"round": 1, "fight": "b"}), "", "a new fight's round 1 isn't cooling")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(n.line("combat:test_crit", back, null, {"round": 2, "fight": "b"}), "", "and the memory saves")


## The real files: lake_zarovich's lines that cool for 30 minutes stay quiet for 29 of them.
func test_the_lake_cools_for_thirty_minutes() -> void:
	var key := ""
	var df := DialogueFile.load_key("narrator/lake_zarovich")
	for node: String in df.order:
		for s: Dictionary in df.nodes[node]:
			if str(s["t"]) == "cooldown" and int(s["minutes"]) == 30 and key == "":
				key = node
	assert_ne(key, "", "a 30-minute cooldown at the lake")
	var n := Narrator.new(1)
	var st := _story()
	var spoke := false
	for i in 20:   # until its conditions let it speak
		if n.line(key, st) != "":
			spoke = true
			break
		st.advance_minutes(60)
	assert_true(spoke, "%s speaks at all" % key)
	st.advance_minutes(29)
	assert_eq(n.line(key, st), "", "%s cools for 30 minutes, not its line number" % key)
