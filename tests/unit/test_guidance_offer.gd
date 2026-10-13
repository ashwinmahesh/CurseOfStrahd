extends TestCase
## Guidance before a skill check outside a fight (story/guidance_offer.gd; Ashwin, 2026-10-13): whoever in the party can
## cast it is offered, free hands first and anyone keeping a spell with that spell named; a plain ability check or
## someone already guided gets no offer; each caster's rule decides whether they're asked (Ask), cast it at once
## (Automatic, never ending another spell) or are left out (Off); the prompt's answer casts it, ends what the caster was
## concentrating on (an exploring spell's time too) and sets the rule; the die rides on the check, named for who gave it.

var st: StoryState
var hedda: Character
var liriel: Character


func before_each() -> void:
	GuidanceOffer.headless_too = false
	st = StoryState.new()
	for id: String in ["ilse_varga", "hedda_ironvow", "liriel_dawnsong", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	hedda = st.party[1]
	liriel = st.party[2]


func after_each() -> void:
	GuidanceOffer.headless_too = false


func _casters(o: Dictionary) -> Array:
	return (o["casters"] as Array).map(func(e: Dictionary) -> Creature: return e["caster"])


func test_the_party_members_who_know_it_are_offered() -> void:
	assert_true(hedda.knows_spell("guidance") and liriel.knows_spell("guidance"), "Hedda and Liriel know Guidance")
	var o := GuidanceOffer.offer(st, st.party[0], &"persuasion", 14)
	assert_eq(_casters(o), [hedda, liriel])
	assert_eq(int(o["dc"]), 14)
	for e: Variant in o["casters"]:
		assert_eq(str((e as Dictionary)["ends"]), "", "nobody is keeping a spell")
		assert_eq(str((e as Dictionary)["rule"]), "ask", "Ask until the player says otherwise")
	assert_true(_casters(GuidanceOffer.offer(st, hedda, &"religion")).has(hedda), "a caster can guide their own check")


func test_no_offer_for_a_plain_ability_check_or_someone_already_guided() -> void:
	assert_true((GuidanceOffer.offer(st, st.party[0], &"str")["casters"] as Array).is_empty(), "Guidance names a skill")
	var fx := Effect.new("Guidance", &"spell", "guidance").with_modifier("bonus_die", {"dice": "1d4", "on": "check:athletics"})
	st.party[0].add_effect(fx)
	assert_true((GuidanceOffer.offer(st, st.party[0], &"athletics")["casters"] as Array).is_empty(), "it's on them already")
	assert_false((GuidanceOffer.offer(st, st.party[0], &"stealth")["casters"] as Array).is_empty(), "another skill still can be")


func test_someone_keeping_a_spell_comes_last_and_says_what_it_ends() -> void:
	hedda.concentration = Concentration.new(hedda, "bless", "Bless")
	var o := GuidanceOffer.offer(st, st.party[0], &"insight")
	assert_eq(_casters(o), [liriel, hedda], "free hands first")
	assert_eq(str((o["casters"] as Array)[1]["ends"]), "Bless")
	# An exploring spell cast outside a fight is kept on the story, not on the caster.
	hedda.concentration = null
	st.active_spells["detect_magic"] = {"until": st.total_minutes() + 10, "caster": hedda.id}
	o = GuidanceOffer.offer(st, st.party[0], &"insight")
	assert_eq(str((o["casters"] as Array)[1]["ends"]), "Detect Magic")
	GuidanceOffer.answer(o, 1)
	assert_false(st.spell_active("detect_magic"), "casting Guidance ended Detect Magic")


func test_casting_it_ends_the_spell_they_were_keeping_and_names_who_gave_it() -> void:
	var bless := hedda.begin_concentration("bless", "Bless")
	var o := GuidanceOffer.offer(st, st.party[0], &"athletics", 15)
	var extra := GuidanceOffer.answer(o, _casters(o).find(hedda))
	assert_true(bless.ended, "Bless ends")
	assert_eq(hedda.concentration, null, "and Guidance's minute went on the check")
	assert_eq(extra, [{"dice": "1d4", "source": "Guidance (Hedda)"}])
	var t := st.party[0].roll_check(DiceRoller.new(3), &"athletics", 15, [], [], "", [], extra)
	assert_true("Guidance (Hedda)" in t.extra_label, "the roll shows who gave it: %s" % t.describe())
	assert_between(float(t.extra), 1.0, 4.0)
	assert_eq(GuidanceOffer.answer(o, -1), [], "rolling without it adds nothing")


func test_the_rules_ask_cast_on_their_own_or_leave_a_caster_out() -> void:
	var o := GuidanceOffer.offer(st, st.party[0], &"perception")
	assert_false(GuidanceOffer.asks(o), "a headless run has no screen to ask on")
	GuidanceOffer.headless_too = true
	assert_true(GuidanceOffer.asks(o), "Ask: the prompt comes up")
	assert_eq(GuidanceOffer.automatic(o), [], "and nothing is cast unasked")
	GuidanceOffer.answer(o, -1, "auto")
	assert_eq(GuidanceOffer.rule_of(hedda), "auto", "the prompt's Next time is every offered caster's rule")
	assert_eq(GuidanceOffer.rule_of(liriel), "auto")
	o = GuidanceOffer.offer(st, st.party[0], &"perception")
	assert_false(GuidanceOffer.asks(o), "Automatic: nobody's asked")
	assert_eq(o["auto"], hedda)
	assert_eq(GuidanceOffer.automatic(o), [{"dice": "1d4", "source": "Guidance (Hedda)"}])
	hedda.concentration = Concentration.new(hedda, "bless", "Bless")
	liriel.concentration = Concentration.new(liriel, "bane", "Bane")
	o = GuidanceOffer.offer(st, st.party[0], &"perception")
	assert_eq(o["auto"], null, "Automatic never ends another spell on its own")
	assert_eq(GuidanceOffer.automatic(o), [])
	assert_false(hedda.concentration.ended)
	GuidanceOffer.set_rule(hedda, "never")
	GuidanceOffer.set_rule(liriel, "never")
	assert_true((GuidanceOffer.offer(st, st.party[0], &"perception")["casters"] as Array).is_empty(), "Off: left out")


func test_only_those_who_can_cast_and_reach_them() -> void:
	hedda.add_condition(&"unconscious", "a fall")
	liriel.add_effect(Effect.new("Silence", &"spell", "silence").with_modifier("flag", {"value": "cant_cast"}))
	assert_true((GuidanceOffer.offer(st, st.party[0], &"stealth")["casters"] as Array).is_empty(),
		"nobody unconscious or unable to cast")
	hedda.remove_condition(&"unconscious", "a fall")
	assert_eq(_casters(GuidanceOffer.offer(st, st.party[0], &"stealth")), [hedda])
	assert_true((GuidanceOffer.offer(st, st.party[0], &"stealth", 0, [st.party[0]])["casters"] as Array).is_empty(),
		"only those who can touch them (a pit's floor)")
