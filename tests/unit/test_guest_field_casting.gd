extends TestCase
## Spells on story allies outside a fight (owner, 2026-10-12: "If we have a companion, we should be able to cast spells
## on them out of combat"): a guest travelling with the party (StoryState.guests, a monster stat block) takes the same
## healing and help from the character sheet as a hero, and a spell that lasts until the next Long Rest ends at the
## party's rest for them too.


func _party(st: StoryState, ids: Array[String]) -> void:
	for id in ids:
		var ch := TestChars.pregen(id, 5)
		ch.finish_long_rest()
		st.party.append(ch)


func _effect_of(cr: Creature, spell_id: String) -> Effect:
	for fx in cr.effects:
		if fx.source_id == spell_id:
			return fx
	return null


func test_cure_wounds_heals_a_guest() -> void:
	var st := StoryState.new()
	_party(st, ["liriel_dawnsong"])
	assert_true(st.add_guest("adrian_martikov"))
	var adrian := st.guests[0]
	adrian.hp = 3
	var liriel := st.party[0]
	var slots := liriel.slots_left(1)
	var res := FieldCasting.cast(st.party, liriel, "cure_wounds", 1, [adrian], DiceRoller.new(4), st)
	assert_true(bool(res["ok"]), str(res))
	assert_true(adrian.hp > 3, "Adrian healed")
	assert_eq(liriel.slots_left(1), slots - 1)


func test_aid_on_a_hero_and_a_guest_lasts_until_the_long_rest() -> void:
	var st := StoryState.new()
	_party(st, ["liriel_dawnsong"])
	st.add_guest("adrian_martikov")
	var adrian := st.guests[0]
	var liriel := st.party[0]
	((liriel.spellcasting[0] as Dictionary)["prepared"] as Array).append("aid")
	var before := adrian.max_hp()
	var res := FieldCasting.cast(st.party, liriel, "aid", 2, [liriel, adrian], DiceRoller.new(4), st)
	assert_true(bool(res["ok"]), str(res))
	assert_eq(adrian.max_hp(), before + 5, "Aid raises the guest's Hit Point maximum")
	st.advance_minutes(10 * 60)
	assert_true(_effect_of(adrian, "aid") != null, "still on after 10 hours")
	adrian.finish_long_rest()
	assert_true(_effect_of(adrian, "aid") == null, "gone at the Long Rest (the rest screen rests guests too)")


func test_without_the_story_a_guest_isnt_on_hand() -> void:
	var st := StoryState.new()
	_party(st, ["liriel_dawnsong"])
	st.add_guest("adrian_martikov")
	var adrian := st.guests[0]
	adrian.hp = 3
	FieldCasting.cast(st.party, st.party[0], "cure_wounds", 1, [adrian], DiceRoller.new(4))
	assert_eq(adrian.hp, 3, "only the party is on the board without the story state")
