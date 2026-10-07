extends TestCase
## Owner report (2026-10-07): a Potion of Healing restored 1 Hit Point. Every healing potion heals its dice (2d4 + 2,
## 4d4 + 4, 8d4 + 8, 10d4 + 20) whichever way it's drunk: in a fight (a Bonus Action), from the inventory outside
## one, or given to a fallen friend from the right-click menu.

const TIERS := {"potion_of_healing": [4, 10], "potion_of_healing_greater": [8, 20], "potion_of_healing_superior": [16, 40],
	"potion_of_healing_supreme": [30, 60]}


func _hurt(level: int = 11) -> Character:
	var ch := TestChars.pregen("hedda_ironvow", level)
	ch.finish_long_rest()
	ch.hp = 1
	return ch


func test_drunk_in_a_fight() -> void:
	for id: String in TIERS:
		var e := TestCombat.open_field()
		var c := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2), 11)
		c.creature.hp = 1
		(c.creature as Character).add_item(id)
		TestCombat.punching_bag(e, Vector2i(8, 8))
		TestCombat.start_with(e, c)
		var r := e.items.use(c, id, "drink", [c])
		assert_true(r.ok, "%s: %s" % [id, r.reason])
		var healed := c.creature.hp - 1
		assert_true(healed >= int(TIERS[id][0]) and healed <= int(TIERS[id][1]), "%s in a fight healed %d" % [id, healed])


func test_drunk_from_the_inventory() -> void:
	for id: String in TIERS:
		var st := StoryState.new()
		var ch := _hurt()
		st.party.append(ch)
		ch.add_item(id)
		var res := FieldItems.use(st, ch, id, "drink", ch, DiceRoller.new(3))
		assert_true(bool(res.get("ok", false)), "%s: %s" % [id, res])
		var healed := ch.hp - 1
		assert_true(healed >= int(TIERS[id][0]) and healed <= int(TIERS[id][1]), "%s outside a fight healed %d" % [id, healed])


func test_a_near_full_drinker_is_told_the_roll() -> void:
	var st := StoryState.new()
	var ch := _hurt()
	ch.hp = ch.max_hp() - 1
	st.party.append(ch)
	ch.add_item("potion_of_healing")
	var res := FieldItems.use(st, ch, "potion_of_healing", "drink", ch, DiceRoller.new(3))
	assert_eq(ch.hp, ch.max_hp(), "one short of full: one Hit Point is all there's room for")
	assert_true(str(res.get("text", "")).contains("now at full"), "and it says so: '%s'" % res.get("text", ""))
