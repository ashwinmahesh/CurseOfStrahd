extends TestCase
## A free casting stays reachable in a fight once its level's slots are spent (2026-10-13): it's offered beside the slot
## levels, first, instead of the pip going to the next slot up and spending that.


func test_a_free_casting_is_offered_once_its_levels_slots_are_spent() -> void:
	var e := TestCombat.open_field(5)
	var liriel := TestCombat.hero(e, "liriel_dawnsong", Vector2i(2, 2), 5)
	TestCombat.foe(e, "ogre", Vector2i(9, 2))
	TestCombat.start_with(e, liriel)
	var ch := liriel.creature as Character
	assert_true(ch.resource_left("spell:sanctuary") > 0, "Magic Initiate's free Sanctuary")
	var cat := ActionCatalog.new(e)
	assert_eq(cat.level_choices(liriel, cat.find(liriel, "spell:sanctuary")), [1, 2, 3] as Array[int], "level 1 slots left")
	ch.slots_used[0] = ch.spellcasting_slots()[0]   # every level 1 slot spent
	var sanctuary := cat.find(liriel, "spell:sanctuary")
	var levels := cat.level_choices(liriel, sanctuary)
	assert_eq(levels, [1, 2, 3] as Array[int], "the free casting beside the slots, first")
	var level2 := ch.slots_left(2)
	var r := cat.perform(liriel, sanctuary, [liriel], Vector2.INF, Vector2.ZERO, levels[0])
	assert_true(r.ok, r.reason)
	assert_eq(ch.resource_left("spell:sanctuary"), 0, "the free casting spent")
	assert_eq(ch.slots_left(2), level2, "no level 2 slot spent")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Sanctuary (free casting)")), "\n".join(e.log.texts().slice(-3)))
	assert_eq(cat.level_choices(liriel, cat.find(liriel, "spell:sanctuary")), [2, 3] as Array[int], "spent: the slots alone")
