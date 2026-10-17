extends TestCase
## Letting go of Concentration at will (2024 glossary "Concentration": you can end it at any time, no action needed):
## Encounter.drop_concentration ends the spell with everything it keeps going and spends nothing, and the hotbar offers
## it on the Common tab for as long as a creature holds a spell.


## A level 9 wizard who knows `spells`, and a punching bag in reach: {e, c, bag, cat}.
func _field(spells: Array) -> Dictionary:
	var e := TestCombat.open_field(6)
	var c := TestCombat.caster_with(e, spells, Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 300)
	TestCombat.start_with(e, c)
	return {"e": e, "c": c, "bag": bag, "cat": ActionCatalog.new(e)}


func test_banishment_dropped_brings_the_creature_back_for_nothing() -> void:
	var f := _field(["banishment"])
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	var bag := f["bag"] as Combatant
	TestCombat.next_d20(e, 1)
	assert_true(e.spells.cast(c, "banishment", 4, [bag]).ok)
	assert_true(bag.has_meta("banished"), "it is banished")
	assert_true(c.creature.concentration != null, "and held")
	var slots := (c.creature as Character).slots_left(4)
	var bonus := c.bonus_available
	var reaction := c.reaction_available
	var moved := c.movement_left
	var r := e.drop_concentration(c)
	assert_true(r.ok, r.reason)
	assert_true(c.creature.concentration == null, "Concentration is gone")
	assert_false(bag.has_meta("banished"), "the banished creature is back")
	assert_eq((c.creature as Character).slots_left(4), slots, "no slot comes back")
	assert_eq(c.bonus_available, bonus, "no Bonus Action spent")
	assert_eq(c.reaction_available, reaction, "no Reaction spent")
	assert_eq(c.movement_left, moved, "no movement spent")
	assert_true(e.current() == c, "and it is still their turn")


func test_it_works_with_the_action_spent_and_logs_it() -> void:
	var f := _field(["bless"])
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	assert_true(e.spells.cast(c, "bless", 1, [c]).ok)
	assert_false(c.action_available, "the Action went on the spell")
	var before := e.log.entries.size()
	assert_true(e.drop_concentration(c).ok, "dropping needs no action")
	var said := false
	for i in range(before, e.log.entries.size()):
		said = said or str(e.log.entries[i]["text"]).contains("stops concentrating on")
	assert_true(said, "the log says so")


func test_the_spells_effects_on_allies_end() -> void:
	var f := _field(["bless"])
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	var friend := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	assert_true(e.spells.cast(c, "bless", 1, [c, friend]).ok)
	assert_true(friend.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "bless"), "Bless is on her")
	assert_true(e.drop_concentration(c).ok)
	assert_false(friend.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "bless"), "and gone")


func test_a_cloud_it_keeps_goes() -> void:
	var f := _field(["fog_cloud"])
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	assert_true(e.spells.cast(c, "fog_cloud", 1, [], Vector2(6.5, 5.5)).ok)
	var clouds := e.spells.zones.objects.filter(func(o: FieldObject) -> bool: return o.spell_id == "fog_cloud")
	assert_eq(clouds.size(), 1, "a cloud lies on the field")
	assert_true(e.drop_concentration(c).ok)
	clouds = e.spells.zones.objects.filter(func(o: FieldObject) -> bool: return o.spell_id == "fog_cloud")
	assert_eq(clouds.size(), 0, "it clears")


func test_haste_dropped_leaves_the_target_lethargic() -> void:
	var f := _field(["haste"])
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	var friend := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	assert_true(e.spells.cast(c, "haste", 3, [friend]).ok)
	assert_true(e.drop_concentration(c).ok)
	assert_true(friend.creature.has_condition(&"incapacitated"), "the spell ending is the spell ending, however it ends")


func test_nothing_to_drop() -> void:
	var f := _field(["bless"])
	var e := f["e"] as Encounter
	var r := e.drop_concentration(f["c"] as Combatant)
	assert_false(r.ok)
	assert_true(r.reason.contains("isn't concentrating"), r.reason)


func test_the_hotbar_offers_it_only_while_concentrating() -> void:
	var f := _field(["bless"])
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	var cat := f["cat"] as ActionCatalog
	assert_true(cat.find(c, "drop_concentration").is_empty(), "nothing to drop yet")
	assert_true(e.spells.cast(c, "bless", 1, [c]).ok)
	var a := cat.find(c, "drop_concentration")
	assert_false(a.is_empty(), "the slot appears")
	assert_eq(str(a["tab"]), ActionCatalog.COMMON, "on the Common tab")
	assert_eq(str(a["cost"]), "free", "it costs nothing")
	assert_eq(str(a["targeting"]), "none", "it needs no aim")
	assert_true(bool(a["legal"]), str(a["reason"]))
	assert_true(str(a["sub"]).contains("Bless"), "the slot names the spell: %s" % a["sub"])
	assert_true(Icons.for_action(a) != null, "with a tile of its own")
	assert_true(cat.slots(c, ActionCatalog.COMMON).any(func(s: Dictionary) -> bool: return str(s["id"]) == "drop_concentration"), "and it is a slot")
	var r := cat.perform(c, a)
	assert_true(r.ok, r.reason)
	assert_true(cat.find(c, "drop_concentration").is_empty(), "gone once dropped")
	assert_true(c.creature.concentration == null)


func test_the_slot_waits_for_its_creatures_turn() -> void:
	var f := _field(["bless"])
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	var cat := f["cat"] as ActionCatalog
	assert_true(e.spells.cast(c, "bless", 1, [c]).ok)
	e.end_turn()
	assert_true(e.current() != c)
	var a := cat.find(c, "drop_concentration")
	assert_false(bool(a["legal"]), "not on someone else's turn")
	assert_true(str(a["reason"]).contains("turn"), str(a["reason"]))


func test_the_effects_it_ended_do_not_come_back_on_the_next_turn() -> void:
	var f := _field(["bless"])
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	assert_true(e.spells.cast(c, "bless", 1, [c]).ok)
	assert_true(e.drop_concentration(c).ok)
	for i in e.order.size():
		e.end_turn()
	assert_true(c.creature.concentration == null)
	assert_false(c.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "bless"))
