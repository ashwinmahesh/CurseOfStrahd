extends TestCase
## The dialogue statement `move <location>[:<spawn>]` (Dungeon Expansion Plan E1, docs/contracts/dialogue.md): it reads,
## it ends the conversation naming where the party goes, `time +n` and the Narrator's lines before it play, and nothing
## after it does. The game side (the party arriving behind the cover) is test_move_in_game.

const DIALOGUE := """
~ drop
Narrator: The floor gives way beneath you.
time +240
move test_move_b:landing
Narrator: This line is never reached.

~ bare
move test_move_b

~ same_map
Narrator: The trapdoor drops you a floor down.
move test_move_a:cell

~ guarded
if flag.dropped
move test_move_b:landing
endif
Narrator: Nothing happens.

~ then_a_fight
move test_move_b:landing
combat wolves
"""


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/move"))


func _story() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("thistle", 1))
	return st


func _runner(st: StoryState) -> DialogueRunner:
	return DialogueRunner.new(st, DiceRoller.new(1))


func test_it_reads_a_location_and_a_spawn() -> void:
	var f := DialogueFile.parse(DIALOGUE, "test/move")
	assert_true(f.errors.is_empty(), str(f.errors))
	var s := (f.nodes["drop"] as Array)[2] as Dictionary
	assert_eq(str(s["t"]), "move")
	assert_eq(str(s["location"]), "test_move_b")
	assert_eq(str(s["spawn"]), "landing")
	var bare := (f.nodes["bare"] as Array)[0] as Dictionary
	assert_eq(str(bare["location"]), "test_move_b")
	assert_eq(str(bare["spawn"]), "default", "no spawn named: the default one, as an exit that names none")


func test_a_move_that_does_not_read_is_an_error() -> void:
	for bad: String in ["move", "move a:b:c", "move a:", "move :b", "move a b", "move a:b c"]:
		var f := DialogueFile.parse("~ n\n%s\n" % bad, "test/bad")
		assert_false(f.errors.is_empty(), "'%s' should not read" % bad)


func test_it_ends_the_conversation_and_names_where() -> void:
	var st := _story()
	var r := _runner(st)
	assert_true(r.start("test/move:drop"))
	var b := r.next()
	assert_eq(str(b["kind"]), "line", "the Narrator's line plays first")
	assert_true(str(b["text"]).contains("floor gives way"))
	var before := st.total_minutes()
	b = r.next()
	assert_eq(str(b["kind"]), "end", "the move ends it, and the line after it never plays")
	assert_eq(st.total_minutes() - before, 240, "`time +240` before it passed")
	assert_true(r.finished)
	var move := b["move"] as Dictionary
	assert_eq(str(move["location"]), "test_move_b")
	assert_eq(str(move["spawn"]), "landing")
	assert_eq(str(b["combat"]), "", "no fight of the conversation's own")


func test_a_move_within_the_same_map_reads_the_same() -> void:
	var r := _runner(_story())
	r.start("test/move:same_map")
	assert_eq(str(r.next()["kind"]), "line")
	var b := r.next()
	assert_eq(str(b["kind"]), "end")
	assert_eq(str((b["move"] as Dictionary)["location"]), "test_move_a")
	assert_eq(str((b["move"] as Dictionary)["spawn"]), "cell")


func test_an_end_without_a_move_names_none() -> void:
	var st := _story()
	var r := _runner(st)
	r.start("test/move:guarded")
	var b := r.next()
	assert_eq(str(b["kind"]), "line", "the flag isn't set: the move is skipped")
	assert_eq(str(r.next()["kind"]), "end")
	assert_true(r.move_to.is_empty())
	st.set_flag("dropped", true)
	r.start("test/move:guarded")
	b = r.next()
	assert_eq(str(b["kind"]), "end", "set: the party goes at once")
	assert_eq(str((b["move"] as Dictionary)["location"]), "test_move_b")


func test_the_next_conversation_starts_clean() -> void:
	var r := _runner(_story())
	r.start("test/move:bare")
	assert_true(r.next().has("move"))
	r.start("test/move:guarded")
	r.next()
	var b := r.next()
	assert_eq(str(b["kind"]), "end")
	assert_false(b.has("move"), "a runner played again keeps nothing of the last move")


func test_a_fight_after_a_move_is_not_the_conversations() -> void:
	var r := _runner(_story())
	r.start("test/move:then_a_fight")
	var b := r.next()
	assert_eq(str(b["kind"]), "end")
	assert_true(b.has("move"))
	assert_eq(str(b["combat"]), "", "the party moves; what waits there starts as it does for any exit")
