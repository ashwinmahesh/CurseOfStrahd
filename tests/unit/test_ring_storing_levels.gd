extends TestCase
## A Ring of Spell Storing keeps as many of its 5 levels for a spell as the slot it was cast with (2024 DMG), so the caster
## picks that slot's level, from the spell's own up. A Pact Magic caster's slots are all one level, but the ring is the one
## place they cast below it (owner, 2026-10-19): a level 11 warlock (three 5th-level slots) could store nothing in a ring
## that already held a level, because only level 5 was offered.


func _ring(stored: Array = []) -> Dictionary:
	var entry := {"stored": []}
	for lvl: int in stored:
		(entry["stored"] as Array).append({"spell": "magic_missile", "level": lvl, "dc": 15, "attack": 7, "ability": "int"})
	return entry


func _setup(ch: Character, stored: Array = []) -> Array:
	var st := StoryState.new()
	st.party.append(ch)
	ch.add_item("ring_of_spell_storing")
	var e := ch.entry_of("ring_of_spell_storing")
	e["stored"] = _ring(stored)["stored"]
	return [st, e]


func _store_pick(party: Array[Character], holder: Character) -> Dictionary:
	for o in FieldItems.options(party, holder, "ring_of_spell_storing", DiceRoller.new(3)):
		if str(o["power_id"]) == "store":
			return o
	return {}


func _levels_of(picks: Array, spell: String) -> Array:
	var out := []
	for p: Dictionary in picks:
		if str(p["spell"]) == spell:
			out.append(int(p["level"]))
	return out


func _kip(level: int = 11) -> Character:
	var kip := TestChars.pregen("kip_smudgewick", level)
	kip.finish_long_rest()
	return kip


## The report: a warlock whose slots are all level 5 could store a level 1 spell only when the ring was empty, and then
## only as a level 5 one.
func test_a_warlock_can_store_a_low_spell_in_a_ring_with_little_room() -> void:
	var kip := _kip()
	assert_eq(int(kip.pact_magic()["level"]), 5)
	assert_eq(int(kip.pact_magic()["count"]), 3)
	var setup := _setup(kip, [3])   # three of the ring's five levels taken
	var st := setup[0] as StoryState
	var party: Array[Character] = [kip]
	var store := _store_pick(party, kip)
	assert_true(bool(store["legal"]), "the ring takes a low spell: %s" % store.get("reason", ""))
	var picks := store["store"] as Array
	assert_eq(_levels_of(picks, "hex"), [1, 2], "Hex from its own level up to the room that's left")
	for p: Dictionary in picks:
		assert_true(int(p["level"]) <= 2, "nothing past the two levels of room: %s" % p["label"])
		assert_true(int(p["level"]) >= int(p["base"]), "never below the spell's own level: %s" % p["label"])
		assert_eq(int(p["slot"]), 5, "paid with a pact slot: %s" % p["label"])
	var res := FieldItems.use(st, kip, "ring_of_spell_storing", "store", null, DiceRoller.new(3), {"caster": kip.id, "spell": "hex", "level": 1})
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_true(str(res["text"]).contains("level 5 Pact Magic slot"), str(res["text"]))
	var stored := kip.entry_of("ring_of_spell_storing")["stored"] as Array
	assert_eq(stored.size(), 2)
	assert_eq(str((stored[1] as Dictionary)["spell"]), "hex")
	assert_eq(int((stored[1] as Dictionary)["level"]), 1, "stored at the level chosen, so it is cast from the ring at that level")
	assert_eq(FieldItems.stored_levels(kip.entry_of("ring_of_spell_storing")), 4)
	assert_eq(int(kip.pact_magic()["left"]), 2, "one pact slot spent")


## With the whole ring free, the warlock chooses any level from the spell's own to 5; with none free, nothing fits.
func test_the_whole_range_of_levels_when_the_ring_is_empty_and_none_when_it_is_full() -> void:
	var kip := _kip()
	var setup := _setup(kip)
	var party: Array[Character] = [kip]
	var picks := _store_pick(party, kip)["store"] as Array
	assert_eq(_levels_of(picks, "hex"), [1, 2, 3, 4, 5])
	for p: Dictionary in picks:
		assert_eq(_levels_of(picks, str(p["spell"])).min(), int(p["base"]), "starts at the spell's own level")
	(setup[1] as Dictionary)["stored"] = _ring([5])["stored"]
	var full := _store_pick(party, kip)
	assert_false(bool(full["legal"]), "a full ring takes nothing more")
	assert_true((full["store"] as Array).is_empty())


## A level 5 spell takes the whole ring or nothing: the room, not the slot, decides.
func test_a_spell_cannot_be_stored_below_its_own_level() -> void:
	var kip := _kip()
	var setup := _setup(kip, [4])
	var st := setup[0] as StoryState
	var res := FieldItems.use(st, kip, "ring_of_spell_storing", "store", null, DiceRoller.new(3), {"caster": kip.id, "spell": "hex", "level": 2})
	assert_false(bool(res["ok"]), "level 2 does not fit with one level of room")
	assert_eq(int(kip.pact_magic()["left"]), 3, "nothing is spent when it does not fit")
	var party: Array[Character] = [kip]
	for p: Dictionary in _store_pick(party, kip)["store"]:
		assert_eq(int(p["level"]), 1, "one level of room: %s" % p["label"])
		assert_eq(int(p["base"]), 1, "only level 1 spells: %s" % p["label"])


## No pact slot left, nothing to cast with.
func test_a_warlock_with_no_pact_slots_stores_nothing() -> void:
	var kip := _kip()
	var setup := _setup(kip)
	var st := setup[0] as StoryState
	kip.pact_slots_used = int(kip.pact_magic()["count"])
	var party: Array[Character] = [kip]
	assert_false(bool(_store_pick(party, kip)["legal"]))
	var res := FieldItems.use(st, kip, "ring_of_spell_storing", "store", null, DiceRoller.new(3), {"caster": kip.id, "spell": "hex", "level": 1})
	assert_false(bool(res["ok"]), str(res["text"]))
	assert_true((kip.entry_of("ring_of_spell_storing")["stored"] as Array).is_empty())


## Spellcasting slots keep their own levels: a wizard stores at levels it has a slot for, and the slot of that level is
## the one spent.
func test_a_wizard_stores_at_a_level_it_has_a_slot_for() -> void:
	var wiz := TestChars.pregen("silvain_aster", 5)
	wiz.finish_long_rest()
	var setup := _setup(wiz, [2])
	var st := setup[0] as StoryState
	var party: Array[Character] = [wiz]
	var picks := _store_pick(party, wiz)["store"] as Array
	assert_false(picks.is_empty())
	for p: Dictionary in picks:
		assert_true(int(p["level"]) <= 3, "room for three levels: %s" % p["label"])
		assert_eq(int(p["slot"]), int(p["level"]), "a wizard's slot is the level it stores at: %s" % p["label"])
	var spell := picks[0] as Dictionary
	var lvl := int(spell["level"])
	var before := wiz.slots_left(lvl)
	var res := FieldItems.use(st, wiz, "ring_of_spell_storing", "store", null, DiceRoller.new(3), {"caster": wiz.id, "spell": spell["spell"], "level": lvl})
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_false(str(res["text"]).contains("Pact"), str(res["text"]))
	assert_eq(wiz.slots_left(lvl), before - 1)


## A warlock 5 / sorcerer 1: the sorcerer's level 1 slot pays for a level 1 spell first, then the pact slots do (cast down
## from level 3), and level 2 is always a pact slot cast down.
func test_a_multiclassed_caster_spends_the_slot_of_that_level_first() -> void:
	var ch := TestChars.pregen("kip_smudgewick", 5)
	var up := LevelUpController.new(ch)
	assert_true(up.choose_class("sorcerer"), "Kip can multiclass into Sorcerer")
	up.take_fixed_hit_points()
	assert_eq(TestChars.auto_pick(up.pending_choices, up.choose), [] as Array[String])
	assert_true(up.confirm(), str(up.errors()))
	ch.finish_long_rest()
	assert_eq(ch.storing_levels(1), [1, 2, 3] as Array[int])
	assert_eq(ch.storing_slot_for(1), 1, "the sorcerer slot")
	assert_eq(ch.storing_slot_for(2), 3, "no level 2 slot: a pact slot, cast down")
	assert_eq(ch.storing_slot_for(3), 3)
	assert_true(ch.expend_storing_slot(1))
	assert_eq(int(ch.pact_magic()["left"]), 2, "the pact slots kept")
	ch.slots_used[0] = 2
	assert_eq(ch.storing_slot_for(1), 3, "the sorcerer slots spent: a pact slot")
	assert_true(ch.expend_storing_slot(1))
	assert_eq(int(ch.pact_magic()["left"]), 1)
	assert_eq(ch.storing_levels(4), [] as Array[int], "never above the pact level")
	assert_true(ch.expend_storing_slot(3))
	assert_false(ch.expend_storing_slot(1), "nothing left to cast with")
	assert_eq(ch.storing_levels(1), [] as Array[int])


## The Ioun Stone of Reserve holds 3 levels and stores the same way.
func test_an_ioun_stone_of_reserve_takes_a_pact_casters_spell_at_a_lower_level() -> void:
	var kip := _kip()
	var party: Array[Character] = [kip]
	var stone := {"power": {"params": {"capacity": 3}}, "entry": {"stored": []}}
	assert_eq(_levels_of(FieldItems.store_options(party, stone), "hex"), [1, 2, 3])
	stone["entry"] = {"stored": [{"spell": "magic_missile", "level": 2}]}
	assert_eq(_levels_of(FieldItems.store_options(party, stone), "hex"), [1])
