extends TestCase
## Potion of Animal Friendship (The Goatherd's Count): drunk as a Bonus Action, it lets the drinker cast Animal
## Friendship (DC 13) at will for an hour, at a beast in a fight and wherever the story asks for the spell outside one.


func test_in_a_fight_the_drinker_charms_a_beast() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 1)
	(c.creature as Character).add_item("potion_of_animal_friendship")
	var wolf := TestCombat.foe(e, "wolf", Vector2i(6, 2))
	TestCombat.start_with(e, c)
	assert_true(e.items.use(c, "potion_of_animal_friendship", "drink", [c], Vector2.INF).ok)
	assert_false(c.bonus_available, "a Bonus Action")
	TestCombat.next_d20(e, 1)
	assert_true(e.items.use(c, "potion_of_animal_friendship", "animal_friendship", [wolf], Vector2(6, 2)).ok)
	assert_true(wolf.creature.has_condition(&"charmed"))


func test_outside_a_fight_the_story_counts_the_spell_for_the_hour() -> void:
	var st := StoryState.new()
	var ch := TestChars.pregen("silvain_aster", 1)
	st.party.append(ch)
	ch.add_item("potion_of_animal_friendship")
	assert_false(StoryState.member_matches(ch, "knows:animal_friendship"))
	assert_true(bool(FieldItems.use(st, ch, "potion_of_animal_friendship", "drink", ch, DiceRoller.new(2))["ok"]))
	assert_true(StoryState.member_matches(ch, "knows:animal_friendship"), "the grey mare's Animal Friendship option opens")
	st.advance_minutes(61)
	assert_false(StoryState.member_matches(ch, "knows:animal_friendship"), "the hour is up")


## The grey mare at the milestone: "Cast Animal Friendship" is there for a drinker while the potion's hour lasts, and
## gone once it's up.
func test_the_grey_mares_option_while_the_hour_lasts() -> void:
	var ids: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "kip_smudgewick", "ratatoille"]
	var st := SideQuestPlay.party(ids, 3, "svalich_crossroads", 20)
	st.set_quest_stage("the_grey_mare", "asked")
	assert_false(_offered(st, "Cast Animal Friendship"), "nobody here knows it")
	var ch := st.party[0]
	ch.add_item("potion_of_animal_friendship")
	assert_true(bool(FieldItems.use(st, ch, "potion_of_animal_friendship", "drink", ch, DiceRoller.new(2))["ok"]))
	assert_true(_offered(st, "Cast Animal Friendship"), "the drinker can cast it at her")
	st.advance_minutes(61)
	assert_false(_offered(st, "Cast Animal Friendship"), "the hour is up")


## Whether the mare's first choice offers an option containing `want`, enabled.
func _offered(st: StoryState, want: String) -> bool:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("svalich_road/grey_mare:mare"))
	var b := r.next()
	for i in 40:
		if str(b["kind"]) in ["options", "end"]:
			break
		b = r.next()
	if str(b["kind"]) != "options":
		return false
	return (b["options"] as Array).any(func(o: Variant) -> bool: return bool((o as Dictionary)["enabled"]) and str((o as Dictionary)["text"]).contains(want))
