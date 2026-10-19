extends TestCase
## What lies under the cairn on Mount Baratok (narrative/mount_baratok/events.dialogue, `cairn_open`; Ashwin, 2026-10-19:
## "When we find Mordenkainen's spellbook, it gives us 2 level 1 spell scrolls, this is unacceptable. It should give us
## 2 level 6 and 2 level 7 spell scrolls, ones with the best combat utility"): Chain Lightning and Disintegrate, Delayed
## Blast Fireball and Forcecage, each readable from a scroll in a fight by the classes whose lists hold it.

const LEVEL_6: Array[String] = ["chain_lightning", "disintegrate"]
const LEVEL_7: Array[String] = ["delayed_blast_fireball", "forcecage"]


func _count(st: StoryState, id: String) -> int:
	var n := 0
	for ch in st.party:
		for e: Dictionary in ch.inventory:
			if str(e["id"]) == id:
				n += int(e.get("qty", 1))
	for e: Dictionary in st.stash:
		if str(e["id"]) == id:
			n += int(e.get("qty", 1))
	return n


func test_opening_the_cairn_gives_two_level_6_and_two_level_7_scrolls_and_no_level_1_scroll() -> void:
	var st := SideQuestPlay.party(["silvain_aster", "hedda_ironvow"], 9, "mount_baratok", 12)
	var beats := SideQuestPlay.play(st, "mount_baratok/events:cairn", ["Unstack the stones"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("mordenkainen_spellbook_found", false)))
	assert_eq(st.quest_stage("the_mad_mage"), "book_found")
	assert_true(SideQuestPlay.text(beats).contains("two loose scrolls"), "the voiced line about the first two is unchanged")
	assert_true(SideQuestPlay.text(beats).contains("two more scrolls"), "and a new line finds the last two")
	for sp in LEVEL_6 + LEVEL_7:
		assert_eq(_count(st, "spell_scroll__" + sp), 1, "one scroll of %s" % sp)
	assert_eq(_count(st, "spell_scroll_level_1"), 0, "and not the two level 1 scrolls")
	for ch in st.party:
		for e: Dictionary in ch.inventory:
			assert_false(str(e["id"]).begins_with("spell_scroll__") and not str(e["id"]).get_slice("__", 1) in LEVEL_6 + LEVEL_7,
				"no other scroll turns up: %s" % e["id"])
	SideQuestPlay.play(st, "mount_baratok/events:cairn")
	assert_eq(_count(st, "spell_scroll__chain_lightning"), 1, "it opens once")


func test_the_four_are_playable_spells_of_the_right_levels_and_very_rare_scrolls() -> void:
	var comp := Compendium.shared()
	for pair: Array in [[LEVEL_6, 6], [LEVEL_7, 7]]:
		for sp: String in pair[0] as Array:
			var spell := comp.spell_data(sp)
			assert_false(spell.is_empty(), "%s is a spell" % sp)
			assert_true(Compendium.playable(spell), "%s is in play" % sp)
			assert_eq(int(spell["level"]), int(pair[1]), "%s is level %d" % [sp, int(pair[1])])
			var scroll := comp.item_data("spell_scroll__" + sp)
			assert_false(scroll.is_empty(), "the scroll exists")
			assert_eq(MagicItems.rarity(scroll), "very_rare", "%s: levels 6 to 8 are very rare" % sp)
			assert_eq(Character.scroll_spell_of(scroll), sp)
	# Berez's treasure is in the very rare band (docs/story/found_magic_items.md).
	assert_true(Treasure.level_for("mount_baratok") >= 9, "very rare belongs to this mountain")


## A level 7 wizard has no slot above level 4: reading these takes the 2024 DMG's check (DC 10 + the spell's level), and a
## success casts the spell. Run on a few seeds: it works on some and fades on others, and the scroll is gone either way.
func test_a_wizard_reads_each_in_a_fight_with_the_scrolls_check() -> void:
	for sp in LEVEL_6 + LEVEL_7:
		var id := "spell_scroll__" + sp
		var worked := 0
		var faded := 0
		for seed_n in range(1, 41):
			var e := TestCombat.open_field(seed_n)
			var c := TestCombat.high_caster(e, [], Vector2i(2, 3))
			var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 400)
			var ch := c.creature as Character
			ch.add_item(id)
			TestCombat.start_with(e, c)
			var why := e.items.power_why(c, e.items.find_power(c, id, "read"))
			assert_eq(why, "", "%s: a wizard may read it (%s)" % [sp, why])
			var r := e.items.use(c, id, "read", [bag], Vector2(6.5, 3.5), Vector2.ZERO, 0, {"choice": "box"})
			assert_true(ch.entry_of(id).is_empty(), "%s: the scroll is used up either way" % sp)
			if r.ok:
				worked += 1
			else:
				faded += 1
				assert_true("fades from the scroll" in r.reason, "%s: %s" % [sp, r.reason])
		assert_true(worked > 0 and faded > 0, "%s: a DC %d check passes sometimes and fails sometimes (%d / %d)"
			% [sp, 10 + (6 if sp in LEVEL_6 else 7), worked, faded])


func test_a_reader_whose_list_lacks_the_spell_cannot_and_the_lists_cover_four_classes() -> void:
	var classes := {}
	for sp in LEVEL_6 + LEVEL_7:
		for c: Variant in Compendium.shared().spell_data(sp)["classes"] as Array:
			classes[str(c)] = true
	for cls: String in ["wizard", "sorcerer", "warlock", "bard"]:
		assert_true(classes.has(cls), "%s can read at least one of them" % cls)
	var e := TestCombat.open_field()
	var fighter := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3), 9)
	var ch := fighter.creature as Character
	ch.add_item("spell_scroll__chain_lightning")
	assert_eq(CombatItems.scroll_why(ch, Compendium.shared().spell_data("chain_lightning")), "Not on your class's spell list")
