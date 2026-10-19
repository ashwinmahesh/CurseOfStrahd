extends TestCase
## `hero_named:<name>` (story/story_conditions.gd, docs/contracts/dialogue.md): true when any party member goes by that
## name, whoever is speaking. It reads the name a player typed for a custom hero (a nod that reacts to a name is a
## variant line, never a plot): case-insensitive, the whole name or its first word, `_` for a space.


func _hero(hero_name: String) -> Character:
	var b := CharacterBuilder.new(null, {"appearance": {"custom": true, "art": "hero_01", "voice": "hero_male"}})
	b.set_class("fighter")
	b.set_background("soldier")
	b.set_species("human")
	b.set_name(hero_name)
	return b.preview()


func _story(names: Array[String]) -> StoryState:
	var st := StoryState.new()
	for n in names:
		st.party.append(_hero(n))
	return st


func test_it_matches_a_party_members_name() -> void:
	var st := _story(["Vesper"])
	assert_true(StoryConditions.check("hero_named:vesper", st), "Vesper")
	assert_false(StoryConditions.check("hero_named:vesperish", st), "another name")
	assert_false(StoryConditions.check("hero_named:vesp", st), "not a prefix")


func test_it_ignores_case_on_both_sides() -> void:
	assert_true(StoryConditions.check("hero_named:vesper", _story(["VESPER"])))
	assert_true(StoryConditions.check("hero_named:VESPER", _story(["vesper"])))
	assert_true(StoryConditions.check("hero_named:Vesper", _story(["vEsPeR"])))


func test_it_matches_the_first_name_or_the_whole_name() -> void:
	var st := _story(["Vesper Brightwater"])
	assert_true(StoryConditions.check("hero_named:vesper", st), "the first name")
	assert_true(StoryConditions.check("hero_named:vesper_brightwater", st), "the whole name, `_` for a space")
	assert_false(StoryConditions.check("hero_named:brightwater", st), "not the surname alone")
	assert_true(StoryConditions.check("hero_named:vesper", _story(["  Vesper  "])), "stray spaces don't matter")


func test_any_party_member_will_do_whoever_is_speaking() -> void:
	var st := _story(["Oskar Brann", "Vesper"])
	assert_true(StoryConditions.check("hero_named:vesper", st), "the second hero")
	var oskar := st.party[0]
	assert_true(StoryConditions.check("hero_named:vesper", st, oskar), "the Narrator's actor is someone else")
	assert_false(StoryConditions.check("hero_named:vesper", StoryState.new()), "an empty party")


func test_it_joins_with_the_other_terms() -> void:
	var st := _story(["Vesper"])
	assert_true(StoryConditions.check("hero_named:vesper and not flag.test_x", st))
	assert_false(StoryConditions.check("not hero_named:vesper", st))
	assert_true(StoryConditions.check("hero_named:nobody or hero_named:vesper", st))


func test_a_narrator_variant_can_read_it() -> void:
	var n := Narrator.new(1)
	n.add_file(DialogueFile.parse("~ test:named\n| [once and hero_named:vesper] A name worn thin.\n| Fog.\n", "narrator/test_named"))
	assert_eq(n.line("test:named", _story(["Oskar Brann"])), "Fog.", "not named Vesper")
	var st := _story(["Vesper"])
	assert_eq(n.line("test:named", st), "A name worn thin.", "named Vesper, once")
	assert_eq(n.line("test:named", st), "Fog.", "and the once is spent")
