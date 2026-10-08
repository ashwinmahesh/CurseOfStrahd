extends TestCase
## Mage Armor cast as each Long Rest ends, when the player wants it (story/rest_casts.gd): on by default for a hero who
## can cast it without a spell slot (Armor of Shadows), off for one who'd spend a slot, never in armor.


func _kip() -> Character:
	var ch := TestChars.pregen("kip_smudgewick", 3)
	ch.unequip("armor")
	ch.finish_long_rest()
	return ch


func _wizard() -> Character:
	var ch := TestChars.custom("wizard", "human", 3)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "mage_armor" in prepared:
		prepared.append("mage_armor")
	ch.finish_long_rest()
	return ch


func _armored(ch: Character) -> bool:
	return ch.effects.any(func(fx: Effect) -> bool: return fx.source_id == "mage_armor")


func test_armor_of_shadows_casts_it_free_by_default() -> void:
	var kip := _kip()
	var party: Array[Character] = [kip]
	var dice := DiceRoller.new(1)
	var choices := RestCasts.choices(party, kip, dice)
	assert_eq(choices.size(), 1, str(choices))
	if choices.is_empty():
		return
	assert_true(bool(choices[0]["free"]), "Armor of Shadows: no slot")
	assert_true(bool(choices[0]["on"]), "so it's on until the player turns it off")
	var slots := kip.slots_used.duplicate()
	var pact := kip.pact_slots_used
	var lines := RestCasts.after_long_rest(party, dice)
	assert_true(_armored(kip), "Mage Armor is on him: %s" % str(lines))
	assert_eq(kip.slots_used, slots, "no spell slot")
	assert_eq(kip.pact_slots_used, pact, "no Pact Magic slot either")
	assert_true(lines.size() == 1 and lines[0].contains("free"), str(lines))


func test_a_wizard_spends_the_lowest_slot_only_when_turned_on() -> void:
	var wiz := _wizard()
	var party: Array[Character] = [wiz]
	var dice := DiceRoller.new(1)
	var choices := RestCasts.choices(party, wiz, dice)
	assert_true(not choices.is_empty() and not bool(choices[0]["free"]) and not bool(choices[0]["on"]), "off: it costs a slot")
	assert_true(RestCasts.after_long_rest(party, dice).is_empty(), "nothing cast while it's off")
	assert_false(_armored(wiz))
	RestCasts.set_wanted(wiz, "mage_armor", true)
	var lines := RestCasts.after_long_rest(party, dice)
	assert_true(_armored(wiz), str(lines))
	assert_eq(wiz.slots_used[0], 1, "one level 1 slot")
	assert_true(lines[0].contains("level 1 spell slot"), str(lines))


func test_armor_worn_stops_it_and_says_so() -> void:
	var kip := TestChars.pregen("kip_smudgewick", 3)
	kip.finish_long_rest()
	if kip.equipped("armor").is_empty():
		kip.add_item("leather_armor")
		kip.equip("leather_armor", "armor")
	var party: Array[Character] = [kip]
	var lines := RestCasts.after_long_rest(party, DiceRoller.new(1))
	assert_false(_armored(kip))
	assert_true(lines.size() == 1 and lines[0].contains("wearing armor"), str(lines))


func test_the_choice_is_kept_with_the_hero() -> void:
	var wiz := _wizard()
	RestCasts.set_wanted(wiz, "mage_armor", true)
	var back := Character.from_dict(JSON.parse_string(JSON.stringify(wiz.to_dict())) as Dictionary)
	assert_true(bool(back.rest_casts.get("mage_armor", false)), "saved with the character")
