extends TestCase
## Ismark as a companion (Resume packages, Allies item 1: power him up to roughly Ezmerelda's strength; the departures are
## in data/monsters/ismark_kolyanovich.json's source note and docs/story/ismark_companion.md). A story ally fights as the
## block their NPC names (StoryState.make_guest), and the block is fixed: it never grows with the party.


func _round_damage(m: Monster) -> float:
	## What a full Multiattack does if every attack hits: each listed slot at its first option's average damage.
	var total := 0.0
	for entry: Variant in m.action("multiattack").get("multiattack", []):
		var d := entry as Dictionary
		var a := m.action(str(d["action"]))
		var dmg := 0.0
		for part: Variant in a.get("damage", []):
			dmg += float((part as Dictionary).get("average", 0))
		total += dmg * int(d.get("count", 1))
	return total


func _guest(id: String) -> Monster:
	var cr := StoryState.make_guest(id)
	assert_true(cr is Monster, id + " is built from a stat block")
	return cr as Monster


func test_he_fights_as_his_own_block_and_the_towns_veterans_are_unchanged() -> void:
	var npc := Compendium.shared().get_entry("npcs", "ismark")
	assert_eq(str(npc.get("monster", "")), "ismark_kolyanovich")
	assert_eq(str((npc.get("guest_build", {}) as Dictionary).get("monster", "")), "ismark_kolyanovich")
	var m := _guest("ismark")
	assert_eq(str(m.data.get("id", "")), "ismark_kolyanovich")
	assert_eq(m.name, "Ismark Kolyanovich")
	assert_eq(m.id, "guest_ismark", "the party's id for him is unchanged")
	var vet := Compendium.shared().monster_data("warrior_veteran")
	assert_eq(float(vet["cr"]), 3.0, "Vallaki's soldiers are still the CR 3 Warrior Veteran")
	assert_eq(int((vet["hp"] as Dictionary)["average"]), 65)


func test_he_keeps_up_with_ezmerelda() -> void:
	var ismark := _guest("ismark")
	var ez := _guest("ezmerelda")
	assert_between(ismark.cr, ez.cr - 1.0, ez.cr, "within a Challenge Rating of her, and not above")
	assert_between(float(ismark.max_hp()), float(ez.max_hp()) * 0.9, float(ez.max_hp()) * 1.3, "Hit Points")
	assert_between(float(ismark.armor_class().total()), float(ez.armor_class().total()) - 1.0, float(ez.armor_class().total()) + 1.0, "Armor Class")
	assert_between(_round_damage(ismark), _round_damage(ez) * 0.9, _round_damage(ez) * 1.5, "what a full turn of blows does")


func test_his_block_is_the_veterans_made_stronger_not_a_different_man() -> void:
	var m := _guest("ismark")
	var vet := Monster.from_data(Compendium.shared().monster_data("warrior_veteran"))
	assert_true(m.max_hp() > vet.max_hp())
	assert_true(m.cr > vet.cr)
	assert_eq(m.armor_class().total(), vet.armor_class().total(), "the same armour")
	assert_eq(str(m.data["alignment"]), "lawful good")
	var multi := m.action("multiattack").get("multiattack", []) as Array
	var attacks := 0
	for entry: Variant in multi:
		attacks += int((entry as Dictionary).get("count", 1))
	assert_eq(attacks, 3, "three attacks a turn, the Veteran's two and one more")
	assert_false(m.action("parry").is_empty(), "he parries, as the Veteran does")
	assert_eq(int(m.action("parry")["ac_bonus"]), 2)
	assert_true(bool(m.action("greatsword").get("weapon", false)), "a weapon attack, so his Parry has a weapon in hand")


func test_the_block_says_what_it_departs_from() -> void:
	var note := str((Compendium.shared().monster_data("ismark_kolyanovich")["source"] as Dictionary).get("note", ""))
	for words: String in ["Warrior Veteran", "CR 7 for 3", "90 Hit Points for 65", "does not grow with the party"]:
		assert_true(note.contains(words), words)
