extends TestCase
## Ezmerelda's Spells tab (Resume packages, Allies item 3: "she is a spellcaster but I don't see her spells list"). A story ally runs as
## her stat block, and the block's Spellcasting (data/monsters/ezmerelda_davenir.json: Magic Missile, Shield, Mirror Image, Lightning
## Bolt, Greater Invisibility and the rest, so many a day) only reached the AI. The core now gives a stat-block caster the player runs a
## Spells tab (ActionCatalog.has_block_spells; tests/unit/test_stat_block_spells_tab.gd in the core); this checks it for her and for
## every other story ally whose block casts, with her own numbers.


func _fight() -> Dictionary:
	var e := TestCombat.open_field(5)
	var ez := e.add(StoryState.make_guest("ezmerelda"), &"guest", Vector2i(3, 3))
	ez.controller = &"player"
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var foe := TestCombat.foe(e, "ghoul", Vector2i(7, 3))
	TestCombat.start_with(e, ez)
	return {"e": e, "ez": ez, "hero": hero, "foe": foe, "cat": ActionCatalog.new(e)}


func _spells(cat: ActionCatalog, c: Combatant) -> Dictionary:
	var out := {}
	for a in cat.actions_for(c):
		if str(a["tab"]) == ActionCatalog.SPELLS:
			out[str(a["id"]).substr(6)] = a
	return out


func test_she_has_a_spells_tab_with_the_block_s_spells_and_how_many_are_left_today() -> void:
	var f := _fight()
	var cat := f["cat"] as ActionCatalog
	var ez := f["ez"] as Combatant
	assert_true(ActionCatalog.SPELLS in cat.tabs_for(ez), "the Spells tab")
	var sp := _spells(cat, ez)
	for id: String in ["magic_missile", "shield", "mirror_image", "lightning_bolt", "magic_circle", "greater_invisibility", "protection_from_evil_and_good"]:
		assert_true(sp.has(id), "%s is on her tab: %s" % [id, sp.keys()])
	assert_true(str((sp["magic_missile"] as Dictionary)["sub"]).contains("4 left today"), "Magic Missile, 4 a day")
	assert_true(str((sp["lightning_bolt"] as Dictionary)["sub"]).contains("3 left today"))
	assert_true(str((sp["greater_invisibility"] as Dictionary)["sub"]).contains("1 left today"))
	assert_true(bool((sp["magic_missile"] as Dictionary)["legal"]), str((sp["magic_missile"] as Dictionary)["reason"]))
	assert_eq(int((sp["magic_missile"] as Dictionary)["slot"]), 1, "at its own level")
	assert_false(bool((sp["shield"] as Dictionary)["legal"]), "Shield is a Reaction, cast when it triggers")


func test_she_casts_magic_missile_and_lightning_bolt_with_her_own_dc() -> void:
	var f := _fight()
	var cat := f["cat"] as ActionCatalog
	var ez := f["ez"] as Combatant
	var foe := f["foe"] as Combatant
	var lb := _spells(cat, ez)["lightning_bolt"] as Dictionary
	assert_eq((cat.cast_preview(ez, lb, 3)["save_dc"] as Breakdown).total(), 14, "her Spell save DC 14")
	var hp := foe.creature.hp
	var r := cat.perform(ez, lb, [], Vector2.INF, Vector2(1, 0))
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.hp < hp, "the bolt struck the ghoul")
	assert_eq(int(ez.get_meta("cast_lightning_bolt", 0)), 1, "one of her three is gone")
	assert_false(ez.action_available)
	# Next turn, a bolt fewer and Magic Missile still four.
	var e := f["e"] as Encounter
	while e.current() != ez:
		e.end_turn()
	e.end_turn()
	while e.current() != ez:
		e.end_turn()
	var sp := _spells(cat, ez)
	assert_true(str((sp["lightning_bolt"] as Dictionary)["sub"]).contains("2 left today"), str((sp["lightning_bolt"] as Dictionary)["sub"]))
	var mm := cat.perform(ez, sp["magic_missile"] as Dictionary, [foe])
	assert_true(mm.ok, mm.reason)
	assert_eq(int(ez.get_meta("cast_magic_missile", 0)), 1)


func test_every_story_ally_whose_block_casts_has_the_tab_and_a_fighter_does_not() -> void:
	var e := TestCombat.open_field(6)
	var casters := 0
	for id: String in Compendium.shared().tables["npcs"]:
		var npc := Compendium.shared().get_entry("npcs", id)
		if not bool(npc.get("guest", false)) or npc.get("guest_build", {}).has("pregen"):
			continue
		var cr := StoryState.make_guest(id)
		if not cr is Monster:
			continue
		var c := e.add(cr, &"guest", Vector2i(1 + casters % 10, 1))
		var has_block := not ((cr as Monster).data.get("spellcasting", {}) as Dictionary).is_empty()
		assert_eq(ActionCatalog.new(e).has_block_spells(c), has_block and not e.monster_actions.block_spells(c).is_empty(), "%s: the tab follows the block" % id)
		if has_block:
			casters += 1
	assert_true(casters >= 2, "Ezmerelda and at least one more ally cast from a block: %d" % casters)
	var ismark := e.add(StoryState.make_guest("ismark"), &"guest", Vector2i(10, 6))
	assert_false(ActionCatalog.new(e).has_block_spells(ismark), "Ismark has no spells to list")
