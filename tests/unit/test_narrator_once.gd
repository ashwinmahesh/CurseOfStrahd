extends TestCase
## `[once]` Narrator variants (story/narrator.gd, docs/contracts/dialogue.md): `| [once] Text` or
## `| [once and <condition>] Text` plays one time a playthrough, then drops out and the trigger's other lines carry on.
## While it hasn't played (and its condition holds) it comes before every other line, conditioned or plain: a one-off
## line plays as soon as its moment comes, and a trigger-level `once` would silence the whole trigger after it.

const LINES := """# a comment, so no line number is mistaken for anything
~ test:once_plain
| [once] The first night, the fire will not light.
| The fire lights.
| The fire lights slowly.

~ test:once_cond
| [once and flag.test_gifted] A stranger wears a borrowed face.
| You sleep badly.

~ test:two_onces
| [once] One.
| [once] Two.
| Plain.

~ test:cond_only
| [flag.test_gifted] Conditioned, but not once.
| Plain.

~ test:over_specific
| [flag.test_gifted] Conditioned.
| [once] One-off.
| Plain.

~ test:cooled
| [once] A first line.
| A later line.
cooldown 10
"""


func _narrator() -> Narrator:
	var n := Narrator.new(1)
	n.add_file(DialogueFile.parse(LINES, "narrator/test_once"))
	return n


func _story() -> StoryState:
	return SideQuestPlay.party(["ilse_varga"], 3, "vallaki", 12)


func _variants(node: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in DialogueFile.parse(LINES, "narrator/test_once").nodes[node]:
		if str(s["t"]) == "variant":
			out.append(s)
	return out


func test_the_parser_reads_the_once_prefix() -> void:
	var plain := _variants("test:once_plain")
	assert_true(bool(plain[0]["once"]), "`[once]` is a once variant")
	assert_eq(str(plain[0]["cond"]), "", "with no other condition")
	assert_eq(str(plain[0]["text"]), "The first night, the fire will not light.")
	assert_false(bool(plain[1]["once"]), "a plain line is not")
	var cond := _variants("test:once_cond")
	assert_true(bool(cond[0]["once"]))
	assert_eq(str(cond[0]["cond"]), "flag.test_gifted", "`[once and <condition>]` keeps the condition")
	var only := _variants("test:cond_only")
	assert_false(bool(only[0]["once"]), "a condition alone isn't once")
	assert_eq(str(only[0]["cond"]), "flag.test_gifted")


func test_a_once_variant_beats_the_plain_ones_one_time() -> void:
	var n := _narrator()
	var st := _story()
	assert_eq(n.line("test:once_plain", st), "The first night, the fire will not light.", "unplayed, it comes first")
	for i in 12:
		var text := n.line("test:once_plain", st)
		assert_true(text.begins_with("The fire lights"), "then the plain lines carry on: %s" % text)


func test_a_conditioned_once_waits_for_its_condition() -> void:
	var n := _narrator()
	var st := _story()
	assert_eq(n.line("test:once_cond", st), "You sleep badly.", "the condition fails: the plain line")
	st.set_flag("test_gifted")
	assert_eq(n.line("test:once_cond", st), "A stranger wears a borrowed face.", "now it holds: the once line")
	assert_eq(n.line("test:once_cond", st), "You sleep badly.", "and it never plays again")
	assert_eq(n.line("test:once_cond", st), "You sleep badly.")


func test_two_once_variants_each_play_once() -> void:
	var n := _narrator()
	var st := _story()
	var first := [n.line("test:two_onces", st), n.line("test:two_onces", st)]
	first.sort()
	assert_eq(first, ["One.", "Two."], "both once lines, one after the other")
	for i in 6:
		assert_eq(n.line("test:two_onces", st), "Plain.", "then only the plain line")


func test_a_conditioned_variant_that_isnt_once_still_repeats() -> void:
	var n := _narrator()
	var st := _story()
	st.set_flag("test_gifted")
	for i in 4:
		assert_eq(n.line("test:cond_only", st), "Conditioned, but not once.", "it beats the plain line every time")


func test_an_unplayed_once_line_comes_before_conditioned_ones_too() -> void:
	var n := _narrator()
	var st := _story()
	st.set_flag("test_gifted")
	assert_eq(n.line("test:over_specific", st), "One-off.", "first, though a conditioned line holds")
	for i in 4:
		assert_eq(n.line("test:over_specific", st), "Conditioned.", "then the conditioned line, as before")


func test_the_memory_saves() -> void:
	var n := _narrator()
	var st := _story()
	assert_eq(n.line("test:once_plain", st), "The first night, the fire will not light.")
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	var again := _narrator()
	for i in 8:
		assert_true(again.line("test:once_plain", back).begins_with("The fire lights"), "a loaded game doesn't replay it")


func test_a_cooldown_holds_a_once_line_until_it_speaks() -> void:
	var n := _narrator()
	var st := _story()
	assert_eq(n.line("test:cooled", st), "A first line.")
	assert_eq(n.line("test:cooled", st), "", "cooling")
	st.advance_minutes(10)
	assert_eq(n.line("test:cooled", st), "A later line.", "the once line is spent")


## Every variant in the real Narrator files has its `once` read by the parser: a `once` left in a condition would read as
## an unknown term (false) and the line would never play. (`make validate` checks the same on the text.)
func test_real_variants_never_leave_once_in_a_condition() -> void:
	var dir := DirAccess.open("res://narrative/narrator")
	var once_word := RegEx.create_from_string("\\bonce\\b")
	for f in dir.get_files():
		if not f.ends_with(".dialogue"):
			continue
		var df := DialogueFile.load_key("narrator/" + f.get_basename())
		for node: String in df.order:
			for s: Dictionary in df.nodes[node]:
				if str(s["t"]) == "variant":
					assert_true(once_word.search(str(s["cond"])) == null,
						"%s %s: `once` only leads a variant's brackets (`[once and ...]`): %s" % [f, node, s["cond"]])
