extends TestCase
## What enemies say and creatures sound like in a fight (narrative/combat/barks.json, world/combat/combat_barks.gd):
## every kind names real monsters, each monster once, with takes for every moment and a cast speaker; a kind gives its
## battle cry once a fight, waits its turn after another, and the party never barks.


func _barks() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CombatBarks.DATA)) as Dictionary


func test_every_kind_names_real_monsters_once_with_every_moment() -> void:
	var seen := {}
	var casting := JSON.parse_string(FileAccess.get_file_as_string("res://audio/voice/casting.json")) as Dictionary
	for section: String in ["voices", "noises"]:
		for kind: String in _barks()[section] as Dictionary:
			var v := (_barks()[section] as Dictionary)[kind] as Dictionary
			var speaker := ("bark_" if section == "voices" else "noise_") + kind
			assert_true((casting["voices"] as Dictionary).has(speaker), "%s is cast in audio/voice/casting.json" % speaker)
			for m: Variant in v["monsters"] as Array:
				assert_false(Compendium.shared().get_entry("monsters", str(m)).is_empty(), "%s: %s is a monster" % [kind, m])
				assert_false(seen.has(m), "%s barks for %s and %s" % [m, seen.get(m, ""), kind])
				seen[m] = kind
			for moment in CombatBarks.MOMENTS:
				assert_true(CombatBarks.takes_for(str((v["monsters"] as Array)[0]), moment).size() >= 2, "%s has two takes for %s" % [kind, moment])


func test_a_kind_cries_once_a_fight_and_waits_its_turn() -> void:
	var e := TestCombat.open_field()
	var bandit := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	var tough := TestCombat.foe(e, "tough", Vector2i(4, 3))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(5, 3))
	var hero := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(1, 1))
	assert_eq(CombatBarks.speaker_for("bandit"), "bark_bandit")
	assert_eq(CombatBarks.speaker_for("wolf"), "noise_wolf")
	var b := CombatBarks.new()
	var cry := b.pick(bandit, "battle", 0)
	assert_true(cry in CombatBarks.takes_for("bandit", "battle"), "the first bandit to act cries out: " + cry)
	assert_eq(b.pick(wolf, "battle", 100), "", "nothing else while it speaks and just after")
	assert_eq(b.pick(tough, "battle", 60000), "", "a tough is a bandit: the kind has cried already")
	assert_true(b.pick(wolf, "battle", 60000) != "", "a wolf pack's snarl is another kind's")
	assert_eq(b.pick(hero, "death", 120000), "", "the party never barks")
	assert_true(b.pick(bandit, "death", 120000) != "", "a death is always heard when it's quiet")
	b.reset()
	assert_true(b.pick(tough, "battle", 0) != "", "a new fight, a new battle cry")
	b.free()
