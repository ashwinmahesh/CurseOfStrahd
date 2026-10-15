extends TestCase
## Preserve Life (Life Domain 3, 2024): one Magic action and one use of Channel Divinity restore 5 x Cleric level Hit
## Points in all, divided as the cleric chooses among Bloodied creatures within 30 ft, none above half its maximum, no
## Undead or Construct. The pool is new with each use (never per turn, never carried over), points left unshared are
## lost, and the hotbar's prompt asks for the division first and spends nothing until it is confirmed.


## A level 5 Life Cleric at (1,3), two allies at (2,3) and (2,4) brought low, and a zombie far off.
func _field(level: int = 5) -> Dictionary:
	var e := TestCombat.open_field()
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 3), level)
	var i := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3), level)
	var t := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 4), level)
	TestCombat.foe(e, "zombie", Vector2i(10, 7))
	TestCombat.start_with(e, h)
	i.creature.hp = 4
	t.creature.hp = 6
	return {"e": e, "h": h, "i": i, "t": t}


## The Hit Points all the Bloodied creatures in reach could take between them.
func room_total(e: Encounter, h: Combatant) -> int:
	var total := 0
	var room := e.features.preserve_life_room(h)
	for id: String in room:
		total += int(room[id])
	return total


func _uses(h: Combatant) -> int:
	return (h.creature as Character).resource_left("channel_divinity")


func test_the_pool_is_five_times_the_cleric_level_for_each_use() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	assert_eq(e.features.preserve_life_pool(h), 25, "5 x level 5")
	var req := e.features.preserve_life_prompt(h).pending
	assert_true(req != null, "the hotbar asks first")
	assert_eq(req.pool, 25)
	assert_eq(req.title, "Preserve Life")
	assert_true(req.shared() <= 25 and req.unspent() == 25 - req.shared(), "the default spread never passes the pool")
	assert_eq(req.shared(), mini(25, int(room_total(e, h))), "and gives as much as the two can take, to a most of 25")


func test_it_is_one_use_of_channel_divinity_not_a_pool_that_comes_back_each_turn() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var i := f["i"] as Combatant
	var t := f["t"] as Combatant
	var uses := _uses(h)
	assert_true(uses >= 2, "a level 5 Cleric has two uses: %d" % uses)
	assert_true(e.features.preserve_life(h).ok)
	assert_eq(_uses(h), uses - 1, "exactly one use spent")
	assert_true(i.creature.hp > 4 and t.creature.hp > 6, "both were healed")
	# The same turn: the Magic action is gone, so no second heal from the same pool.
	var again := e.features.preserve_life(h)
	assert_false(again.ok, "a second use the same turn is refused")
	assert_true(again.reason.contains("already used"), again.reason)
	assert_eq(_uses(h), uses - 1, "and costs nothing")
	# A later turn: a new use, and a whole new pool, not what was left of the first.
	h.action_available = true
	h.magic_action_used = false
	i.creature.hp = 4
	t.creature.hp = 6
	assert_true(e.features.preserve_life(h).ok)
	assert_eq(_uses(h), uses - 2, "the second use is paid for too")
	assert_eq(e.features.preserve_life_pool(h), 25, "the pool is 25 again, whatever the first use gave")
	# With every use gone there is nothing to preserve with.
	h.action_available = true
	h.magic_action_used = false
	(h.creature as Character).spend_resource("channel_divinity", _uses(h))
	assert_false(e.features.preserve_life(h).ok, "no use of Channel Divinity left")
	assert_false(e.features.preserve_life_prompt(h).ok, "the hotbar says so before asking")


func test_the_prompt_spends_nothing_until_it_is_confirmed() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var i := f["i"] as Combatant
	var uses := _uses(h)
	var req := e.features.preserve_life_prompt(h).pending
	assert_eq(_uses(h), uses, "asking costs nothing")
	assert_true(h.action_available and not h.magic_action_used, "and no action")
	assert_eq(i.creature.hp, 4, "and heals nobody")
	# Skip: nothing happens.
	var r := e.answer_reaction(false)
	assert_true(r.ok)
	assert_eq(_uses(h), uses, "Skip keeps the use")
	assert_true(h.action_available and not h.magic_action_used, "and the action")
	assert_eq(i.creature.hp, 4)
	assert_true(e.pending == null)
	assert_true(req != null)


func test_the_cleric_divides_the_pool_and_what_is_left_is_lost() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var i := f["i"] as Combatant
	var t := f["t"] as Combatant
	var uses := _uses(h)
	var req := e.features.preserve_life_prompt(h).pending
	# 7 to Ilse and 3 to Tamsin: 10 of the 25.
	req.amounts[i.id] = 7
	req.amounts[t.id] = 3
	assert_eq(req.shared(), 10)
	assert_eq(req.unspent(), 15, "15 left to share")
	assert_eq(req.selection_error(), "", "that can be confirmed")
	var r := e.answer_reaction(true)
	assert_true(r.ok, r.reason)
	assert_eq(i.creature.hp, 11, "7 more")
	assert_eq(t.creature.hp, 9, "3 more")
	assert_eq(_uses(h), uses - 1, "one use, however few points were given")
	var said := e.log.entries.filter(func(en: Dictionary) -> bool: return str(en.get("text", "")).contains("uses Preserve Life"))
	assert_false(said.is_empty(), "the log has it")
	assert_true(str(said[-1]["text"]).contains("10 of 25"), str(said[-1]["text"]))
	assert_true(str(said[-1]["text"]).contains("15 unspent"), str(said[-1]["text"]))


func test_nobody_rises_above_half_their_maximum() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var i := f["i"] as Combatant
	var room := e.features.preserve_life_room(h)
	assert_eq(int(room[i.id]), i.creature.max_hp() / 2 - 4, "half the maximum, less what they have")
	var req := e.features.preserve_life_prompt(h).pending
	req.amounts[i.id] = int(room[i.id]) + 1
	assert_ne(req.selection_error(), "", "one over is refused: %s" % req.selection_error())
	assert_true(req.selection_error().contains("at most"), req.selection_error())
	var refused := e.answer_reaction(true)
	assert_false(refused.ok, "and can't be confirmed")
	assert_true(e.pending == req, "the prompt stays up for another try")
	assert_eq(i.creature.hp, 4, "nobody healed")
	req.amounts[i.id] = int(room[i.id])
	assert_true(e.answer_reaction(true).ok)
	assert_eq(i.creature.hp, i.creature.max_hp() / 2, "up to half and no more")
	# Direct use of the rule agrees.
	var g := _field(5)
	var e2 := g["e"] as Encounter
	var over := e2.features.preserve_life(g["h"] as Combatant, {(g["i"] as Combatant).id: 99})
	assert_false(over.ok)
	assert_true(over.reason.contains("at most"), over.reason)


func test_the_pool_cannot_be_overspent_or_left_empty() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var i := f["i"] as Combatant
	var t := f["t"] as Combatant
	var req := e.features.preserve_life_prompt(h).pending
	var room := e.features.preserve_life_room(h)
	req.amounts[i.id] = int(room[i.id])
	req.amounts[t.id] = int(room[t.id])
	req.pool = 5   # as if the cleric's pool were smaller than what was handed out
	assert_true(req.selection_error().contains("Only 5"), req.selection_error())
	req.pool = 25
	req.amounts[i.id] = 0
	req.amounts[t.id] = 0
	assert_true(req.selection_error().contains("at least 1"), "nothing given: %s" % req.selection_error())
	var uses := _uses(h)
	assert_false(e.features.preserve_life(h, {i.id: 0}).ok, "an empty division is no use of it")
	assert_eq(_uses(h), uses, "and the use is kept")


func test_only_bloodied_creatures_within_30_feet_are_listed() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var i := f["i"] as Combatant
	var t := f["t"] as Combatant
	t.creature.hp = t.creature.max_hp()   # not Bloodied
	var room := e.features.preserve_life_room(h)
	assert_true(room.has(i.id) and not room.has(t.id), "only the Bloodied: %s" % [room.keys()])
	assert_false(room.has(h.id), "the cleric at full health isn't")
	h.creature.hp = 3
	assert_true(e.features.preserve_life_room(h).has(h.id), "but the cleric can be included when Bloodied")
	# Out of reach.
	var far := _field(5)
	var e2 := far["e"] as Encounter
	var i2 := far["i"] as Combatant
	i2.cell = Vector2i(11, 0)
	assert_false(e2.features.preserve_life_room(far["h"] as Combatant).has(i2.id), "beyond 30 feet")


func test_undead_and_constructs_cannot_be_healed_by_it() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var zombie := e.add(TestCombat.monster("zombie"), &"party", Vector2i(2, 2))
	zombie.creature.hp = 2
	var armor := e.add(TestCombat.monster("animated_armor"), &"party", Vector2i(3, 3))
	armor.creature.hp = 2
	var room := e.features.preserve_life_room(h)
	assert_false(room.has(zombie.id), "an Undead ally is left out")
	assert_false(room.has(armor.id), "so is a Construct")
	assert_true(room.has((f["i"] as Combatant).id), "a hero is not")
	var r := e.features.preserve_life(h, {zombie.id: 5})
	assert_false(r.ok, "and can't be named")


func test_the_hotbar_asks_instead_of_spreading_for_the_player() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var i := f["i"] as Combatant
	var cat := ActionCatalog.new(e)
	var entry := cat.find(h, "preserve_life")
	assert_true(bool(entry["legal"]), "Bloodied allies in reach")
	assert_true(str(entry["sub"]).contains("25"), "the entry says how many Hit Points one use has: %s" % entry["sub"])
	var r := cat.perform(h, entry)
	assert_true(r.is_paused() and e.pending != null and e.pending.kind == "preserve_life", "a prompt, not a heal")
	assert_eq(i.creature.hp, 4, "nothing healed yet")
	var saw_effect := e.events.any(func(ev: Variant) -> bool: return str((ev as Dictionary).get("type", "")) == "ability")
	assert_false(saw_effect, "and the effect waits for the answer")
	assert_true(e.answer_reaction(true).ok, "the default division can be confirmed as it is")
	assert_true(i.creature.hp > 4, "healed once confirmed")
	var after := e.events.any(func(ev: Variant) -> bool: return str((ev as Dictionary).get("type", "")) == "ability" and str((ev as Dictionary).get("key", "")) == "preserve_life")
	assert_true(after, "the effect plays then")


func test_the_default_division_is_the_most_hurt_first() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var h := f["h"] as Combatant
	var i := f["i"] as Combatant
	var t := f["t"] as Combatant
	i.creature.hp = 1
	t.creature.hp = 9
	var room := e.features.preserve_life_room(h)
	var spread := e.features.preserve_life_spread(room, 5)
	assert_eq(int(spread.get(i.id, 0)), 5, "all of a small pool to the one who is worst off")
	assert_false(spread.has(t.id))
	var wide := e.features.preserve_life_spread(room, 100)
	assert_eq(int(wide[i.id]), int(room[i.id]), "up to what they can take")
	assert_true(int(wide.get(t.id, 0)) > 0, "then the next")
