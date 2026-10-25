extends TestCase
## The spells the Amber Temple's dark gifts grant can be cast (Ashwin, 2026-10-24: "yes, fix it"). A gift's modifiers join a
## character through intrinsic_modifiers(), not the build's own list, so Character._collect_granted_spells never saw a gift's
## `spell` modifier and no gift's spell (Fekre's Blight, Drizlash's Web, Khirad's Clairvoyance, Vaund's Misty Step, ...) reached
## the spell list; it reads them now, with the gift's own casting ability and its uses a Long Rest.


func _gift_spells() -> Dictionary:
	var out := {}
	for id: String in Compendium.shared().table("dark_gifts") as Dictionary:
		for m: Variant in ((Compendium.shared().get_entry("dark_gifts", id)["benefit"] as Dictionary)["modifiers"] as Array):
			if str((m as Dictionary)["stat"]) == "spell":
				out[id] = m
	return out


func _hero_with(gift: String, level: int = 5) -> Character:
	var ch := TestChars.pregen("hedda_ironvow", level)
	ch.accept_dark_gift(gift)
	return ch


func _granted(ch: Character, spell_id: String) -> Dictionary:
	for g: Dictionary in ch.granted_spells:
		if str(g["id"]) == spell_id:
			return g
	return {}


## Every gift that names a spell in its benefit grants it, with its ability, uses and recharge.
func test_every_gifts_spell_reaches_the_one_who_carries_it() -> void:
	var gifts := _gift_spells()
	assert_true(gifts.size() >= 6, "the gifts that grant spells (%d)" % gifts.size())
	for gift: String in gifts:
		var m := gifts[gift] as Dictionary
		var spell := str(m["value"])
		var ch := _hero_with(gift)
		var g := _granted(ch, spell)
		assert_false(g.is_empty(), "%s grants %s" % [gift, spell])
		if g.is_empty():
			continue
		assert_eq(str(g["ability"]), str(m["ability"]), "%s: cast with its own ability" % gift)
		assert_eq(str(g["recharge"]), "long", "%s: once a Long Rest, as it says" % gift)
		var want := int(m["uses"]["count"]) if (m["uses"] as Dictionary)["count"] is float or (m["uses"] as Dictionary)["count"] is int else ch.proficiency_bonus()
		assert_eq(int(g["uses"]), want, "%s: its uses" % gift)
		assert_eq(ch.resource_left("spell:%s" % spell), want, "%s: a free casting for each" % gift)


## A hero who has not taken the gift has no such spell.
func test_a_hero_without_the_gift_does_not_have_its_spell() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 5)
	for spell: String in ["lightning_bolt", "cone_of_cold", "misty_step", "blight", "web"]:
		assert_true(_granted(ch, spell).is_empty(), "no %s before the gift" % spell)


## In a fight each gift's spell is on the list, free, and a casting spends one of its uses.
func test_a_gifts_spell_is_on_the_list_free_in_a_fight() -> void:
	var gifts := _gift_spells()
	for gift: String in gifts:
		var spell := str((gifts[gift] as Dictionary)["value"])
		var ch := _hero_with(gift, 9)
		var e := TestCombat.open_field()
		var c := e.add(ch, &"party", Vector2i(2, 2))
		TestCombat.foe(e, "zombie", Vector2i(9, 5))
		TestCombat.start_with(e, c)
		var entry := {}
		for k in e.spells.castable(c):
			if str(k["id"]) == spell:
				entry = k
		assert_false(entry.is_empty(), "%s: %s is on the spell list" % [gift, spell])
		assert_true(bool(entry.get("free", false)), "%s: %s needs no slot" % [gift, spell])
		var unit := str(((Compendium.shared().spell_data(spell)["casting_time"]) as Dictionary)["unit"])
		if unit == "action" and not str(entry.get("reason", "")).begins_with("No effect in a fight"):
			assert_true(bool(entry.get("legal", false)), "%s: %s can be cast now (%s)" % [gift, spell, entry.get("reason", "")])


## Drizlash's Web is cast from the gift, and the cast spends one of its uses.
func test_drizlashs_web_is_cast_and_spent() -> void:
	var ch := _hero_with("gift_of_drizlash", 5)
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 5))
	TestCombat.start_with(e, c)
	var before := ch.resource_left("spell:web")
	assert_eq(before, ch.proficiency_bonus(), "as many as the Proficiency Bonus")
	assert_true(e.spells.cast(c, "web", 2, [], Vector2(8.5, 4.5)).ok, "and it casts")
	assert_eq(ch.resource_left("spell:web"), before - 1, "spending one of its uses")
