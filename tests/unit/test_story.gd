extends TestCase
## Story systems (ADR 0008): conditions, the dialogue runner (lines, options, checks, effects, branches,
## interjections, combat), the Narrator's variants and cooldowns, quests and the journal, and saving the story.

const FIXTURE := """
# A test conversation.
~ start
Narrator: The door creaks.
Ismark [weary]: Strangers. {name} looks tired.
interject class:cleric: I'll pray for the house.
interject class:bard: Nobody here sings.
set met_test
quest test_quest met
* Who are you? -> who
* [Insight DC 5] Read him. -> read | misread
* [if flag.secret] You know the secret. -> secret
* [Wizard] Cast a spell. -> spell
* [Bard] Sing. -> who
* Fight! -> fight

~ who
if flag.met_test and not flag.secret
Ismark: I'm Ismark.
elif flag.secret
Ismark: You know.
else
Ismark: Nobody.
endif
give dagger 2
gold +10
xp milestone
-> END

~ read
set read_ok
-> END

~ misread
-> END

~ secret
-> END

~ spell
Player: Behold.
-> END

~ fight
combat test_fight
"""

const NARRATOR := """
~ enter:test_room
| The room waits.
| [class:wizard] {name} smells old magic.
cooldown 10

~ examine:once_thing
| A thing.
once
"""


func before_each() -> void:
	var f := DialogueFile.parse(FIXTURE, "test/fixture")
	assert_true(f.errors.is_empty(), str(f.errors))
	DialogueFile.register(f)
	Compendium.shared().tables["quests"]["test_quest"] = {"id": "test_quest", "name": "Test Quest", "summary": "",
		"stages": [{"id": "met", "journal": "We met him."}, {"id": "done", "journal": "Done.", "ends": "success"}]}


func _party() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("hedda_ironvow", 1))
	st.party.append(TestChars.pregen("silvain_aster", 1))
	return st


func test_conditions() -> void:
	var st := _party()
	st.set_flag("a", true)
	st.set_flag("n", 3)
	assert_true(StoryConditions.check("flag.a and flag.n >= 3", st))
	assert_false(StoryConditions.check("flag.a and not (flag.n == 3)", st))
	assert_true(StoryConditions.check("class:cleric", st))
	assert_false(StoryConditions.check("class:rogue", st))
	assert_true(StoryConditions.check("species:elf or species:orc", st))
	assert_true(StoryConditions.check("", st))
	assert_false(StoryConditions.check("flag.missing", st))
	st.attitudes["ismark"] = "friendly"
	assert_true(StoryConditions.check("attitude.ismark == friendly", st))


func test_runner_lines_interjections_and_options() -> void:
	var st := _party()
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start("test/fixture:start"))
	var b := r.next()
	assert_eq(str(b["kind"]), "line")
	assert_true(bool(b["narrator"]))
	b = r.next()
	assert_true(str(b["name"]).begins_with("Ismark"), "the speaker's name from data/npcs (or as written)")
	assert_true(str(b["text"]).contains("Hedda"), "{name} is the speaker")
	b = r.next()
	assert_eq(str(b["name"]), "Hedda Ironvow", "the cleric interjects")
	b = r.next()
	assert_eq(str(b["kind"]), "notice", "quest stage notice (no bard to interject)")
	assert_true(bool(st.get_flag("met_test")))
	assert_eq(st.quest_stage("test_quest"), "met")
	b = r.next()
	assert_eq(str(b["kind"]), "options")
	var texts: Array = (b["options"] as Array).map(func(o: Dictionary) -> String: return str(o["text"]))
	assert_true("Cast a spell." in texts, "a Wizard is in the party")
	assert_false("Sing." in texts, "no Bard")
	assert_false("You know the secret." in texts, "flag not set")
	var read := (b["options"] as Array)[1] as Dictionary
	assert_true(str(read["label"]).contains("Insight DC 5"))
	assert_true(float((read["check"] as Dictionary)["chance"]) > 0.5)


func test_skill_check_branches_and_effects() -> void:
	var st := _party()
	var r := DialogueRunner.new(st, DiceRoller.new(TestChars.seed_for_d20(15)))
	r.start("test/fixture:start")
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	var check := r.choose(1)
	assert_eq(str(check["kind"]), "check")
	assert_true(bool(check["success"]))
	assert_eq(str(r.next()["kind"]), "end")
	assert_true(bool(st.get_flag("read_ok")))
	assert_true(st.last_check)


func test_branch_items_gold_and_milestone() -> void:
	var st := _party()
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.start("test/fixture:start")
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	b = r.choose(0)
	assert_eq(str(b["text"]), "I'm Ismark.", "if branch taken")
	var notices: Array[String] = []
	b = r.next()
	while str(b["kind"]) == "notice":
		notices.append(str(b["text"]))
		b = r.next()
	assert_eq(str(b["kind"]), "end")
	assert_eq(notices.size(), 3)
	assert_eq(st.gold, 10.0)
	assert_eq(st.milestones, 1)
	assert_eq(st.target_level(), 2)
	assert_true(st.can_level_up(st.party[0]))
	var daggers := 0
	for e in st.party[0].inventory:
		if str(e["id"]) == "dagger":
			daggers += int(e["qty"])
	assert_true(daggers >= 2)
	# Replaying the same milestone line doesn't count twice.
	r.start("test/fixture:who")
	while str(r.next()["kind"]) != "end":
		pass
	assert_eq(st.milestones, 1)


func test_class_tagged_option_switches_the_speaker_and_combat_ends() -> void:
	var st := _party()
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.start("test/fixture:start")
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	var idx := -1
	for i in (b["options"] as Array).size():
		if str((b["options"] as Array)[i]["text"]) == "Cast a spell.":
			idx = i
	b = r.choose(idx)
	assert_eq(str(b["name"]), "Silvain Aster", "the wizard says it")
	r.start("test/fixture:fight")
	b = r.next()
	assert_eq(str(b["kind"]), "end")
	assert_eq(str(b["combat"]), "test_fight")


func test_narrator_variants_cooldowns_and_once() -> void:
	var st := _party()
	var n := Narrator.new(3)
	n.add_file(DialogueFile.parse(NARRATOR, "narrator/test"))
	var wizard := st.party[1]
	var line := n.line("enter:test_room", st, wizard)
	assert_eq(line, "Silvain smells old magic.", "the wizard variant wins for a wizard")
	assert_eq(n.line("enter:test_room", st, wizard), "", "cooling down")
	st.advance_minutes(11)
	assert_eq(n.line("enter:test_room", st, st.party[0]), "The room waits.")
	assert_eq(n.line("examine:once_thing", st), "A thing.")
	assert_eq(n.line("examine:once_thing", st), "", "once")


func test_journal_and_story_save_round_trip() -> void:
	var st := _party()
	st.set_quest_stage("test_quest", "met")
	st.set_quest_stage("test_quest", "done")
	var j := QuestLog.journal(st)
	assert_eq(j.size(), 1)
	assert_eq((j[0]["entries"] as Array).size(), 2)
	assert_eq(str(j[0]["status"]), "success")
	st.set_flag("x", 3)
	st.gold = 12.5
	st.positions.append(Vector2i(4, 5))
	st.loc_state("room")["doors"]["front"] = "open"
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(copy.party.size(), 2)
	assert_eq(copy.party[1].name, "Silvain Aster")
	assert_eq(int(copy.get_flag("x")), 3)
	assert_eq(copy.gold, 12.5)
	assert_eq(copy.positions[0], Vector2i(4, 5))
	assert_eq(str((copy.loc_state("room")["doors"] as Dictionary)["front"]), "open")
	assert_eq(copy.quest_stage("test_quest"), "done")
	Compendium.shared().tables["quests"].erase("test_quest")


func test_effects_and_concentration_survive_a_save() -> void:
	var st := _party()
	var hedda := st.party[0]
	var silvain := st.party[1]
	var conc := hedda.begin_concentration("bless", "Bless")
	conc.attach(hedda, Effect.new("Bless", &"spell", "bless").with_modifier("bonus_die", {"dice": "1d4", "on": ["attack"]}))
	conc.attach(silvain, Effect.new("Bless", &"spell", "bless").with_modifier("bonus_die", {"dice": "1d4", "on": ["attack"]}))
	var armor := Effect.new("Mage Armor", &"spell", "mage_armor").with_modifier("ac_formula", {"base": 13, "abilities": ["dex"]})
	armor.lasting({"kind": "hours", "amount": 8})
	silvain.add_effect(armor)
	var ac := silvain.ac_value()
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	var h2 := copy.party[0]
	var s2 := copy.party[1]
	assert_eq(s2.ac_value(), ac, "Mage Armor kept")
	assert_eq(s2.modifiers_for(&"bonus_die").size(), 1, "Bless kept on Silvain")
	assert_true(h2.concentration != null)
	assert_eq(h2.concentration.effect_count(), 2, "Concentration relinked to both Blessed creatures")
	h2.concentration.end("test")
	assert_eq(s2.modifiers_for(&"bonus_die").size(), 0, "ending it removes Bless everywhere")



func test_purchases_need_the_gold_and_level_and_gold_conditions() -> void:
	var f := DialogueFile.parse("""
~ shop
Bildrath: Buy.
* Rope (10 gp) -> rope
* Potion (500 gp) -> potion
* [if gold >= 5 and level >= 1] Leave a tip. -> END

~ rope
gold -10
give rope 1
-> END

~ potion
gold -500
-> END
""", "test/shop")
	assert_true(f.errors.is_empty(), str(f.errors))
	DialogueFile.register(f)
	var st := _party()
	st.gold = 20.0
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.start("test/shop:shop")
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	var opts := b["options"] as Array
	assert_eq(opts.size(), 3)
	assert_true(bool(opts[0]["enabled"]))
	assert_false(bool(opts[1]["enabled"]), "500 gp is out of reach")
	assert_eq(str(r.choose(1)["kind"]), "options", "choosing it does nothing")
	assert_eq(st.gold, 20.0)
	r.choose(0)
	assert_eq(st.gold, 10.0)
	assert_false(StoryConditions.check("level >= 2", st))
	assert_true(StoryConditions.check("gold > 5 and level == 1", st))


func test_narrator_merges_a_trigger_written_in_two_regions() -> void:
	var n := Narrator.new(5)
	n.add_file(DialogueFile.parse("~ test:merge\n| [flag.inside] The house listens while you rest.\n", "narrator/a"))
	n.add_file(DialogueFile.parse("~ test:merge\n| You rest a while.\n", "narrator/b"))
	var st := _party()
	assert_eq(n.line("test:merge", st), "You rest a while.")
	st.set_flag("inside", true)
	assert_eq(n.line("test:merge", st), "The house listens while you rest.", "the conditioned variant wins where it holds")


func test_sacrifice_takes_the_chosen_member_for_good() -> void:
	var f := DialogueFile.parse("~ altar\nNarrator: One must die.\nsacrifice\nset gave_one\n-> END\n", "test/altar")
	assert_true(f.errors.is_empty(), str(f.errors))
	DialogueFile.register(f)
	var st := _party()
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.start("test/altar:altar")
	assert_eq(str(r.next()["kind"]), "line")
	var b := r.next()
	assert_eq(str(b["kind"]), "pick_member")
	assert_eq((b["members"] as Array).size(), 2)
	assert_eq(str(r.next()["kind"]), "pick_member", "it waits for the choice")
	b = r.pick_member(1)
	assert_true(str(b["text"]).contains("Silvain"))
	assert_eq(st.party.size(), 1)
	assert_eq(str(st.fallen[0]["name"]), "Silvain Aster")
	assert_eq(str(r.next()["kind"]), "end")
	assert_true(bool(st.get_flag("gave_one")))
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(copy.fallen.size(), 1)


func test_failed_checks_offer_heroic_inspiration_and_tactical_mind() -> void:
	var f := DialogueFile.parse("~ door\n* [Athletics DC 40] Force it. -> ok | no\n~ ok\nset forced\n-> END\n~ no\n-> END\n", "test/aids")
	DialogueFile.register(f)
	var st := StoryState.new()
	var ilse := TestChars.pregen("ilse_varga", 2)
	ilse.finish_long_rest()
	ilse.heroic_inspiration = true
	st.party.append(ilse)
	var r := DialogueRunner.new(st, DiceRoller.new(4))
	r.start("test/aids:door")
	r.next()
	var b := r.choose(0)
	assert_false(bool(b["success"]))
	var ids: Array = (b["aids"] as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true("heroic_inspiration" in ids and "tactical_mind" in ids, str(ids))
	var wind := ilse.resource_left("second_wind")
	b = r.use_aid("tactical_mind")
	assert_false(bool(b["success"]), "DC 40 is out of reach")
	assert_eq(ilse.resource_left("second_wind"), wind, "a Tactical Mind that still fails isn't spent")
	b = r.use_aid("heroic_inspiration")
	assert_false(ilse.heroic_inspiration, "spent")
	var after: Array = (b["aids"] as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_false("heroic_inspiration" in after)
	assert_eq(str(r.next()["kind"]), "end")
	assert_false(bool(st.get_flag("forced")))


func test_respec_rebuilds_a_member_who_keeps_their_belongings() -> void:
	var f := DialogueFile.parse("~ eva\nrespec\nset read_again\n-> END\n", "test/respec")
	DialogueFile.register(f)
	var st := _party()
	st.milestones = 1
	var hedda := st.party[0]
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.start("test/respec:eva")
	var b := r.next()
	assert_eq(str(b["kind"]), "pick_member")
	assert_eq(str(b["purpose"]), "respec")
	b = r.pick_member(0)
	assert_eq(str(b["kind"]), "respec")
	assert_eq(int(b["index"]), 0)
	var fresh := TestChars.pregen("silvain_aster", 1)
	var items := hedda.inventory.size()
	st.respec_member(hedda, fresh)
	assert_true(st.party[0] == fresh)
	assert_eq(fresh.inventory.size(), items, "belongings kept")
	assert_eq(fresh.id, hedda.id)
	assert_true(st.can_level_up(fresh), "milestones bring them back up")
	st.options["respec"] = false
	r.start("test/respec:eva")
	assert_eq(str(r.next()["kind"]), "end", "the owner can switch respec off")


## Owner rule (2026-10-06): a failed Persuasion, Intimidation, Deception or Insight attempt is gone for good; other
## checks and successful attempts aren't.
func test_a_failed_social_check_cant_be_tried_again() -> void:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", 1))
	var f := DialogueFile.parse("""
~ menu
* [Persuasion DC 40] Please? -> menu | menu
* [Perception DC 40] Look closer. -> menu | menu
* [Insight DC 40] Is she lying? -> menu | menu
* Goodbye. -> END
""", "test/spent")
	assert_true(f.errors.is_empty(), str(f.errors))
	DialogueFile.register(f)
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	r.start("test/spent:menu")
	var opts := r.next()["options"] as Array
	assert_eq(opts.size(), 4)
	var check := r.choose(0)
	assert_false(bool(check["success"]), "DC 40 fails")
	var again := r.next()["options"] as Array
	assert_eq(again.size(), 3, "the failed plea is gone")
	assert_false(again.any(func(o: Variant) -> bool: return str((o as Dictionary)["text"]) == "Please?"))
	r.choose(0)
	assert_eq((r.next()["options"] as Array).size(), 3, "a failed Perception check can be tried again")
	r.choose(1)
	assert_eq((r.next()["options"] as Array).size(), 2, "a failed Insight check is gone too")
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	var r2 := DialogueRunner.new(copy, DiceRoller.new(3))
	r2.start("test/spent:menu")
	assert_eq((r2.next()["options"] as Array).size(), 2, "still gone after a save and a new conversation")
