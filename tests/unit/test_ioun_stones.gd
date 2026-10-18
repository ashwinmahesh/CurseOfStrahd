extends TestCase
## Ioun Stones (2024 DMG): a Magic action tosses one into orbit round the head, three at most; a Utilize action seizes
## and stows any number; a stone whose attunement ends falls as though dropped. Outside a fight the pack just wears and
## takes off (Wear: orbiting the head), so the fight gets the actions the book names.

const PROT := "ioun_stone_protection"
const AGIL := "ioun_stone_agility"
const FORT := "ioun_stone_fortitude"
const INSI := "ioun_stone_insight"


func after_each() -> void:
	GameSettings.set_unlimited_attunement(false)


## A hero in a fight carrying `stones` (attuned to the first `attuned` of them): [encounter, hero].
func _fight(stones: Array[String], attuned: int = 99) -> Array:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var ch := hero.creature as Character
	ch.attuned.clear()
	for i in stones.size():
		ch.add_item(stones[i])
		if i < attuned:
			assert_true(ch.attune(stones[i]), stones[i])
	TestCombat.punching_bag(e, Vector2i(8, 6))
	TestCombat.start_with(e, hero)
	return [e, hero]


func _ids(e: Encounter, c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for a in e.items.list(c):
		out.append(str(a["id"]))
	return out


func test_a_stone_in_the_pack_offers_the_toss_and_no_stow() -> void:
	var run := _fight([PROT])
	var ids := _ids(run[0], run[1])
	assert_true("item:%s:orbit" % PROT in ids, "Toss into orbit")
	assert_false("item:%s:stow" % PROT in ids, "nothing orbits to stow")


func test_the_toss_costs_the_magic_action_and_the_stone_then_works() -> void:
	var run := _fight([PROT])
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	var ch := c.creature as Character
	var ac := ch.ac_value()
	var r := e.items.use(c, PROT, "orbit")
	assert_true(r.ok, r.reason)
	assert_false(c.action_available, "a Magic action")
	assert_eq(ch.held_id("ioun"), PROT, "orbiting the head")
	assert_eq(ch.ac_value(), ac + 1, "attuned, the stone's +1 Armor Class")
	assert_false("item:%s:orbit" % PROT in _ids(e, c), "no tossing it twice")
	assert_true("item:%s:stow" % PROT in _ids(e, c), "but it can be stowed")


func test_an_unattuned_stone_orbits_and_does_nothing_until_attunement_is_dropped() -> void:
	var run := _fight([PROT], 0)
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	var ch := c.creature as Character
	var ac := ch.ac_value()
	assert_true(e.items.use(c, PROT, "orbit").ok)
	assert_eq(ch.ac_value(), ac, "the book's rule: it gives its benefit to someone attuned")
	GameSettings.set_unlimited_attunement(true)
	assert_eq(ch.ac_value(), ac + 1, "Unlimited: orbiting is enough")


func test_three_stones_orbit_at_most_and_one_stow_takes_them_all() -> void:
	var run := _fight([PROT, AGIL, FORT, INSI], 3)   # attuned to three of the four
	var e := run[0] as Encounter
	var c := run[1] as Combatant
	var ch := c.creature as Character
	for id: String in [PROT, AGIL, FORT]:
		c.action_available = true
		c.magic_action_used = false   # a later turn: one Magic action each
		var r := e.items.use(c, id, "orbit")
		assert_true(r.ok, "%s: %s" % [id, r.reason])
	assert_eq(ch.equipped_all("ioun").size(), 3)
	c.action_available = true
	c.magic_action_used = false
	var fourth := e.items.use(c, INSI, "orbit")
	assert_false(fourth.ok, "a fourth is refused")
	assert_true(fourth.reason.contains("Three"), fourth.reason)
	var stows: Array[String] = []
	for a in e.items.list(c):
		if str(a["id"]).ends_with(":stow"):
			stows.append(str(a["id"]))
	assert_eq(stows.size(), 1, "stowing is listed once, on the first stone orbiting")
	c.action_available = true
	var r2 := e.items.use(c, PROT, "stow")
	assert_true(r2.ok, r2.reason)
	assert_false(c.action_available, "a Utilize action for all of them")
	assert_eq(ch.equipped_all("ioun").size(), 0, "any number")
	c.action_available = true
	c.magic_action_used = false
	assert_true(e.items.use(c, INSI, "orbit").ok, "and there is room again")


func test_a_stone_whose_attunement_ends_falls() -> void:
	var ch := TestChars.pregen("ilse_varga", 5)
	ch.attuned.clear()
	ch.add_item(PROT)
	assert_true(ch.attune(PROT))
	assert_true(ch.equip(PROT, "ioun"))
	assert_true(ch.end_attunement(PROT))
	assert_eq(ch.held_id("ioun"), "", "it falls as though dropped: back in the pack")


func test_wearing_a_fourth_stone_from_the_pack_replaces_the_first() -> void:
	var ch := TestChars.pregen("ilse_varga", 5)
	for id: String in [PROT, AGIL, FORT, INSI]:
		ch.add_item(id)
		ch.equip(id, "ioun")
	assert_eq(ch.equipped_all("ioun").size(), MagicItems.IOUN_MAX, "three at most")
	assert_eq(ch.held_id("ioun") != PROT, true, "the oldest went back in the pack")
