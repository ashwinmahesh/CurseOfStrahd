extends TestCase
## Changing spells any time outside a fight (owner's house rule, 2026-10-14; deviations.md): the casters whose spells
## the 2024 rules let them change when they finish a Long Rest - Clerics, Druids, Wizards, Paladins and Rangers their
## prepared spells, a Wizard or High Elf a cantrip, a Circle of the Land Druid their land - change them without a rest,
## any number at once. Always-prepared spells stay, slots spent aren't refunded, and concentration and spells already
## cast carry on. Bards, Sorcerers and Warlocks (a level up) and the choices only a rest changes keep their rules.


func _state(chars: Array) -> StoryState:
	var st := StoryState.new()
	for ch: Character in chars:
		st.party.append(ch)
	return st


## "<character id>/<choice key>" for each entry the any-time screen offers.
func _keys(st: StoryState, who: Character = null) -> Array:
	return PrepareScreen.preparable(st, PrepareScreen.ANYTIME, who).map(func(e: Dictionary) -> String:
		return "%s/%s" % [(e["ch"] as Character).id, (e["choice"] as Choice).key])


func _store(ch: Character, key: String, picks: Array) -> void:
	(ch.build["choices"] as Dictionary)[key] = picks.duplicate()
	ch.refresh()


## `n` legal options of `c` that aren't picked.
func _fresh(c: Choice, n: int) -> Array[String]:
	var out: Array[String] = []
	for o in c.options:
		if o.legal and not o.id in c.picks and out.size() < n:
			out.append(o.id)
	return out


func test_the_casters_a_long_rest_lets_change_spells_can_at_any_time() -> void:
	var cleric := TestChars.pregen("hedda_ironvow", 3)
	var paladin := TestChars.pregen("godrick_pendlebrook", 3)
	var ranger := TestChars.pregen("thistle", 3)
	var wizard := TestChars.pregen("silvain_aster", 3)
	var druid := TestChars.custom("druid", "human", 3)
	var keys := _keys(_state([cleric, paladin, ranger, wizard, druid]))
	for want: String in ["hedda_ironvow/cleric.prepared", "godrick_pendlebrook/paladin.prepared", "thistle/ranger.prepared",
			"silvain_aster/wizard.prepared", "silvain_aster/wizard.cantrips"]:
		assert_true(want in keys, "%s: %s" % [want, keys])
	assert_true(keys.any(func(k: String) -> bool: return k.ends_with("/druid.prepared")), "a Druid's prepared spells: %s" % [keys])
	# A Cleric's and a Druid's cantrips change at a level up, so the Prepare screen has none of them.
	assert_false("hedda_ironvow/cleric.cantrips" in keys, "a Cleric swaps a cantrip at a level up")
	assert_false(keys.any(func(k: String) -> bool: return k.ends_with("/druid.cantrips")), "a Druid swaps a cantrip at a level up")


func test_a_high_elf_changes_the_lineage_cantrip_at_any_time() -> void:
	var ch := TestChars.pregen("ratatoille", 1)
	var key := "species.lineage.high_elf_lineage.cantrip"
	assert_true("ratatoille/%s" % key in _keys(_state([ch])), "the High Elf cantrip is offered")


func test_known_spell_casters_and_rest_only_choices_stay_out() -> void:
	var casters: Array[Character] = [TestChars.custom("bard", "human", 3), TestChars.custom("sorcerer", "human", 3),
		TestChars.custom("warlock", "human", 3)]
	for ch: Character in casters:
		assert_true(_keys(_state([ch])).is_empty(), "%s changes spells at a level up, not a rest: %s" % [ch.name, _keys(_state([ch]))])
	# A Fighter's Weapon Mastery and a Druid's Wild Shape forms are a rest's to change, and no spells.
	var fighter := TestChars.custom("fighter", "human", 3)
	var st_f := _state([fighter])
	assert_false(PrepareScreen.preparable(st_f).is_empty(), "a Long Rest lets a Fighter swap a mastery")
	assert_true(_keys(st_f).is_empty(), "but that isn't a spell")
	var druid := TestChars.custom("druid", "human", 3)
	var forms := PrepareScreen.preparable(_state([druid])).filter(func(e: Dictionary) -> bool: return (e["choice"] as Choice).kind == "beast_form")
	assert_false(forms.is_empty(), "a Long Rest lets a Druid swap a Wild Shape form")
	assert_true(PrepareScreen.preparable(_state([druid]), PrepareScreen.ANYTIME).filter(func(e: Dictionary) -> bool:
		return (e["choice"] as Choice).kind == "beast_form").is_empty(), "the form waits for a rest")


func test_a_land_and_an_allegiance_that_grant_spells_change_at_any_time() -> void:
	var druid := TestChars.custom("druid", "human", 3, {"druid_subclass": ["circle_of_the_land"], "circle_of_the_land_spells": ["arid"]})
	var land := druid.choice("circle_of_the_land.3.circle_of_the_land_spells")
	assert_true(land != null and land.replaceable == "long_rest", "the land is a Long Rest choice")
	assert_true("%s/circle_of_the_land.3.circle_of_the_land_spells" % druid.id in _keys(_state([druid])), "offered: %s" % [_keys(_state([druid]))])
	_store(druid, "circle_of_the_land.3.circle_of_the_land_spells", ["polar"])
	var known := druid.known_spells().map(func(k: Dictionary) -> String: return str(k["id"]))
	assert_true("fog_cloud" in known and not "burning_hands" in known, "the polar land's spells now: %s" % [known])
	var rogue := TestChars.custom("rogue", "human", 3, {"rogue_subclass": ["scion_of_the_three"]})
	var scion: Array = _keys(_state([rogue])).filter(func(k: String) -> bool: return k.contains("dread_allegiance"))
	assert_eq(scion.size(), 1, "a Scion of the Three's allegiance grants a cantrip: %s" % [_keys(_state([rogue]))])


func test_nobody_dead_and_one_character_at_a_time() -> void:
	var cleric := TestChars.pregen("hedda_ironvow", 3)
	var wizard := TestChars.pregen("silvain_aster", 3)
	var st := _state([cleric, wizard])
	assert_true(_keys(st, cleric).all(func(k: String) -> bool: return k.begins_with("hedda_ironvow/")), "only Hedda's: %s" % [_keys(st, cleric)])
	assert_false(_keys(st, cleric).is_empty())
	cleric.dead = true
	assert_true(_keys(st, cleric).is_empty(), "the dead prepare nothing")
	assert_false(_keys(st).any(func(k: String) -> bool: return k.begins_with("hedda_ironvow/")))


func test_any_number_of_spells_change_at_once_for_a_paladin_too() -> void:
	# After a rest a Paladin changes one spell (test_spell_swaps); with no rest to count from, every pick is free.
	var ch := TestChars.custom("paladin", "human", 5)
	var key := "paladin.prepared"
	var earlier := ch.picks_for(key)
	var st := _state([ch])
	var c := PrepareScreen.preparable(st, PrepareScreen.ANYTIME, ch).filter(func(e: Dictionary) -> bool: return (e["choice"] as Choice).key == key)[0]["choice"] as Choice
	ChoiceOptions.close_swap(c)
	ChoiceOptions.populate(c, ch)
	assert_false(ChoiceOptions.swap_open(c), "no swap limit")
	var fresh := _fresh(c, 3)
	assert_eq(fresh.size(), 3, "other Paladin spells to prepare")
	var swapped: Array = earlier.duplicate()
	swapped[0] = fresh[0]
	swapped[1] = fresh[1]
	swapped[2] = fresh[2]
	_store(ch, key, swapped)
	c = ch.choice(key)
	ChoiceOptions.close_swap(c)
	ChoiceOptions.populate(c, ch)
	assert_eq(ChoiceOptions.errors(c, ch), [] as Array[String], "three spells changed with no rest")
	var known := ch.known_spells().map(func(k: Dictionary) -> String: return str(k["id"]))
	for id in fresh:
		assert_true(id in known, "%s is prepared now" % id)
	assert_false(earlier[0] in known and not earlier[0] in swapped, "%s went" % earlier[0])
	# The rules library still has the Long Rest's one-spell swap for a Paladin; the Prepare Spells screen no longer uses it
	# for spells, after a rest or not (Weapon Mastery and the other rest-only choices keep theirs).
	var rest := PrepareScreen.preparable(st).filter(func(e: Dictionary) -> bool: return (e["choice"] as Choice).key == key)[0]["choice"] as Choice
	assert_true(PrepareScreen.spell_choice(rest), "the Paladin's list is a spell choice on the screen a rest offers too")
	assert_eq(rest.replace_max, 1, "the data still says one after a Long Rest")


func test_what_only_a_rest_changes_keeps_its_swap_limit() -> void:
	var fighter := TestChars.custom("fighter", "human", 3)
	var picks := PrepareScreen.preparable(_state([fighter])).filter(func(e: Dictionary) -> bool: return (e["choice"] as Choice).kind == "weapon_mastery")
	assert_false(picks.is_empty(), "a Fighter swaps a Weapon Mastery after a Long Rest")
	assert_false(PrepareScreen.spell_choice(picks[0]["choice"] as Choice), "and that isn't a spell: its limit stays")
	var druid := TestChars.custom("druid", "human", 3)
	var forms := PrepareScreen.preparable(_state([druid])).filter(func(e: Dictionary) -> bool: return (e["choice"] as Choice).kind == "beast_form")
	assert_false(forms.is_empty(), "a Druid swaps a Wild Shape form after a Long Rest")
	assert_false(PrepareScreen.spell_choice(forms[0]["choice"] as Choice), "and that keeps its limit too")


func test_always_prepared_spells_stay_when_the_list_changes() -> void:
	var ch := TestChars.custom("cleric", "human", 5, {"cleric_subclass": ["life_domain"]})
	var always := ch.known_spells().filter(func(k: Dictionary) -> bool: return str(k["kind"]) == "always").map(
		func(k: Dictionary) -> String: return str(k["id"]))
	assert_true("bless" in always and "revivify" in always, "the Life Domain's spells: %s" % [always])
	var key := "cleric.prepared"
	# Emptying the list leaves them: they are the domain's, not picks.
	_store(ch, key, [])
	var known := ch.known_spells().filter(func(k: Dictionary) -> bool: return str(k["kind"]) == "always").map(
		func(k: Dictionary) -> String: return str(k["id"]))
	assert_eq(known, always, "the domain's spells stay prepared")


func test_changing_spells_refunds_no_slots_and_ends_nothing() -> void:
	var ch := TestChars.custom("cleric", "human", 5)
	var st := _state([ch])
	st.party[0].slots_used[0] = 2
	ch.begin_concentration("bless", "Bless")
	st.active_spells["longstrider"] = {"until": st.total_minutes() + 480, "caster": ch.id}
	var spent := ch.slots_used.duplicate()
	var key := "cleric.prepared"
	var c := ch.choice(key)
	ChoiceOptions.populate(c, ch)
	var picks: Array = c.picks.duplicate()
	picks[0] = _fresh(c, 1)[0]
	_store(ch, key, picks)
	assert_eq(ch.slots_used, spent, "no slot comes back")
	assert_true(ch.concentration != null and ch.concentration.source_id == "bless", "still concentrating on Bless")
	assert_true(st.spell_active("longstrider"), "the spell already cast keeps going")
	# Even with Bless itself taken off the list.
	picks = ch.picks_for(key)
	if "bless" in picks:
		picks.erase("bless")
	_store(ch, key, picks)
	assert_true(ch.concentration != null and ch.concentration.source_id == "bless", "still concentrating after Bless leaves the list")


func test_a_fight_refuses_with_a_reason() -> void:
	assert_true(PrepareScreen.refusal(true).contains("fight"), PrepareScreen.refusal(true))
	assert_eq(PrepareScreen.refusal(false), "")
	assert_false(PrepareScreen.fighting(null))
