extends TestCase
## The plan §5.6 screens open and work on a real party: sheet, inventory, journal, party and formation, rests, the
## pause menu, level up through LevelUpController, and character creation clicked through for every class.

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_hall"] = {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	# A fixture, not real content (test_set_dressing checks every location).
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_crypt")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The button with `text` on `screen` (not one on its way out), or null.
func _button(screen: Node, text: String) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b.is_queued_for_deletion():
			return b as Button
	return null


## Whether a label on `screen` says `text`.
func _says(screen: Node, text: String) -> bool:
	return screen.find_children("*", "Label", true, false).any(func(l: Node) -> bool:
		return (l as Label).text.contains(text) and not l.is_queued_for_deletion())


## A Long Rest waits until no enemies remain in the building, on any floor, and 16 hours after the last one (owner rules,
## 2026-10-09): its card says why in words, read the same with the pad as with the mouse, and the Short Rest stays open.
func test_a_long_rest_waits_for_a_clear_building_and_sixteen_hours() -> void:
	(Compendium.shared().tables["locations"] as Dictionary)["test_crypt"] = {"id": "test_crypt", "name": "Test Crypt",
		"region": "test", "summary": "", "map": {"rows": ["#####", "#...#", "#####"]}, "spawns": {"default": [1, 1]},
		"rest": "safe", "encounters": [{"id": "ghouls", "trigger": "enter_area:crypt", "monsters": [{"monster": "ghoul", "cell": [2, 1]}]}]}
	GameState.story.location = "test_crypt"
	var ilse := GameState.story.party[0]
	ilse.hp = 1
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	assert_true(_button(rest, "Take a Long Rest (8 hours)").disabled, "no Long Rest with ghouls in the crypt")
	assert_false(_button(rest, "Finish the Short Rest (1 hour)").disabled, "the Short Rest is still on")
	assert_true(_says(rest, "Enemies still prowl this place"), "the card says why")
	rest.call("_long_rest", "safe")
	assert_eq(ilse.hp, 1, "nothing slept away")
	(GameState.story.loc_state("test_crypt")["encounters"] as Dictionary)["ghouls"] = true
	rest.call("_refresh_long")
	await _frames(1)
	var take := _button(rest, "Take a Long Rest (8 hours)")
	assert_false(take.disabled, "the crypt is clear")
	take.pressed.emit()
	await _frames(1)
	assert_eq(ilse.hp, ilse.max_hp(), "rested")
	assert_true(_button(rest, "Take a Long Rest (8 hours)").disabled, "not again so soon")
	assert_true(_says(rest, "the next can start in 16 hours"), "and how long until the next")


func test_every_screen_opens() -> void:
	for kind: String in ["sheet", "inventory", "journal", "party", "rest", "menu", "level_up"]:
		root.call("open_screen", kind, 0)
		await _frames(2)
		assert_true(root.get("screen") != null, "%s opened" % kind)
		root.call("close_screen")
		await _frames(1)
	assert_true(root.get("screen") == null)


func test_inventory_equips_and_gives() -> void:
	root.call("open_screen", "inventory", 0)
	await _frames(1)
	var inv := root.get("screen") as InventoryScreen
	var ilse := GameState.story.party[0]
	inv.selected = "flail"
	inv.call("_draw")
	ilse.equip("flail", "main_hand")
	assert_eq(str(ilse.equipped("main_hand").get("id", "")), "flail")
	inv.selected = "javelin"
	var before := 0
	for e in GameState.story.party[1].inventory:
		if str(e["id"]) == "javelin":
			before += int(e["qty"])
	inv.call("_give", GameState.story.party[1])
	var after := 0
	for e in GameState.story.party[1].inventory:
		if str(e["id"]) == "javelin":
			after += int(e["qty"])
	assert_eq(after, before + 1)


func test_short_rest_spends_hit_dice() -> void:
	var ilse := GameState.story.party[0]
	ilse.hp = 3
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	rest.call("_spend", ilse, 10)
	assert_true(ilse.hp > 3, "hp %d, dice %s, log %s" % [ilse.hp, ilse.hit_dice(), rest.get("_log").text])
	var minute := GameState.story.minute_of_day
	rest.call("_finish_short")
	assert_eq(GameState.story.minute_of_day, (minute + 60) % (24 * 60))


## A feat list shows the highlighted feat's full text in a panel beside it (owner, 2026-10-07), and follows the mouse.
func test_feat_list_has_a_description_panel() -> void:
	var c := Choice.new()
	c.key = "test.feat"
	c.kind = "feat"
	c.count = 1
	c.label = "Feat"
	c.filter = {"category": "general"}
	ChoiceOptions.populate(c, GameState.story.party[0])
	var w := ChoiceWidget.create(c)
	add_child(w)
	await _frames(1)
	var shown := w.get("_shown") as String
	assert_ne(shown, "", "a feat is described from the start")
	w.show_detail("great_weapon_master")
	await _frames(1)
	var texts: Array[String] = []
	for l in w.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_true(texts.has("Great Weapon Master"), "its name heads the panel")
	assert_true(texts.has("Hew"), "each benefit is listed by name")
	w.queue_free()


## Heal up (docs/plans/ui_polish.md): one click spends Hit Point Dice for everyone hurt, never for someone at full.
func test_heal_up_spends_dice_for_the_hurt() -> void:
	var ilse := GameState.story.party[0]
	var tamsin := GameState.story.party[1]
	ilse.hp = 1
	tamsin.hp = tamsin.max_hp()
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	rest.heal_up()
	assert_true(ilse.hp > 1, "the hurt one healed")
	var spent := 0
	for die: String in ilse.hit_dice():
		spent += int((ilse.hit_dice()[die] as Dictionary)["spent"])
	assert_true(spent >= 1)
	for die: String in tamsin.hit_dice():
		assert_eq(int((tamsin.hit_dice()[die] as Dictionary)["spent"]), 0, "nobody at full spends a die")


func test_level_up_with_a_milestone() -> void:
	GameState.story.milestones = 1
	var ilse := GameState.story.party[0]
	root.call("open_screen", "level_up", 0)
	await _frames(1)
	var lu := root.get("screen") as LevelUpScreen
	assert_true(lu.ctl != null)
	for c in lu.ctl.pending_choices():
		var picks: Array = []
		for o in c.options:
			if o.legal and picks.size() < c.count:
				picks.append(o.id)
		lu.ctl.choose(c.key, picks)
	lu.call("_confirm")
	assert_eq(ilse.character_level(), 2)
	assert_false(GameState.story.can_level_up(ilse))


func test_creation_for_every_class() -> void:
	for cid: String in ["barbarian", "bard", "cleric", "druid", "fighter", "monk", "paladin", "ranger", "rogue",
			"sorcerer", "warlock", "wizard"]:
		var cs := CreationScreen.new()
		add_child(cs)
		var empty: Array[Dictionary] = []
		cs.open_with(empty)
		var b := cs.b()
		b.set_class(cid)
		b.set_background("acolyte")
		b.set_species("human")
		var missing := TestChars.auto_pick(func() -> Array[Choice]: return b.pending_choices(),
			func(key: String, picks: Array) -> void: b.choose(key, picks))
		assert_true(missing.is_empty(), "%s: %s" % [cid, missing])
		b.set_name("Test %s" % cid)
		cs.step = CharacterBuilder.Step.REVIEW
		cs.call("_draw")
		assert_true(b.errors().is_empty(), "%s: %s" % [cid, b.errors()])
		for step in CharacterBuilder.STEP_NAMES.size():
			cs.step = step
			cs.call("_draw")
		cs.queue_free()
		await _frames(1)


func test_healing_and_mage_armor_outside_combat() -> void:
	var hedda := GameState.story.party[2]
	var silvain := GameState.story.party[3]
	var ilse := GameState.story.party[0]
	ilse.hp = 2
	var opts := FieldCasting.options(GameState.story.party, hedda, DiceRoller.new(3))
	var ids: Array = opts.map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_true("healing_word" in ids, str(ids))
	assert_false("guiding_bolt" in ids, "harmful spells wait for a fight")
	var slots := hedda.slots_left(1)
	var target: Array[Character] = [ilse]
	var res := FieldCasting.cast(GameState.story.party, hedda, "healing_word", 1, target, DiceRoller.new(3))
	assert_true(bool(res["ok"]), str(res))
	assert_true(ilse.hp > 2)
	assert_eq(hedda.slots_left(1), slots - 1)
	if "mage_armor" in silvain.known_spells().map(func(k: Dictionary) -> String: return str(k["id"])):
		var ac := silvain.ac_value()
		var me: Array[Character] = [silvain]
		res = FieldCasting.cast(GameState.story.party, silvain, "mage_armor", 1, me, DiceRoller.new(3))
		assert_true(bool(res["ok"]), str(res))
		assert_true(silvain.ac_value() > ac, "Mage Armor lasts after the cast")
	root.call("open_screen", "sheet", 2)
	await _frames(1)
	var sheet := root.get("screen") as CharacterSheetScreen
	sheet.call("_draw")


## Ally spells outside fights (owner report 2026-10-09: Protection from Evil and Good had no Cast button there): they go
## on anyone in the party, the caster too. Its Holy Water is still needed, with the reason a fight gives, and used up;
## Lesser Restoration ends a poison; Warding Bond goes only on another; Light stays on the exploring list.
func test_ally_spells_outside_combat() -> void:
	var cleric := Pregens.build("hedda_ironvow", 3)
	cleric.finish_long_rest()
	var ilse := GameState.story.party[0]
	var party: Array[Character] = [cleric, ilse]
	((cleric.spellcasting[0] as Dictionary)["prepared"] as Array).append_array(["protection_from_evil_and_good",
		"lesser_restoration", "warding_bond"])
	for e: Dictionary in cleric.inventory.duplicate():
		if str(e["id"]) == "holy_water":
			while int(e.get("qty", 0)) > 0:
				cleric.remove_one("holy_water", e)
	var opts := {}
	for o in FieldCasting.options(party, cleric, DiceRoller.new(3)):
		opts[str(o["id"])] = o
	assert_true(opts.has("protection_from_evil_and_good") and opts.has("lesser_restoration"), str(opts.keys()))
	assert_false(bool((opts["protection_from_evil_and_good"] as Dictionary)["legal"]))
	assert_eq(str((opts["protection_from_evil_and_good"] as Dictionary)["reason"]), "Needs Holy Water worth 25 gp", "as in a fight")
	cleric.add_item("holy_water")
	var me: Array[Character] = [cleric]
	var res := FieldCasting.cast(party, cleric, "protection_from_evil_and_good", 1, me, DiceRoller.new(3))
	assert_true(bool(res["ok"]), str(res))
	assert_true(cleric.effects.any(func(fx: Effect) -> bool: return fx.source_id == "protection_from_evil_and_good"), "on the caster")
	assert_eq(cleric.material_worth("holy_water"), 0.0, "the flask is used up")
	ilse.add_condition(&"poisoned", "Test")
	var her: Array[Character] = [ilse]
	res = FieldCasting.cast(party, cleric, "lesser_restoration", 2, her, DiceRoller.new(3))
	assert_true(bool(res["ok"]), str(res))
	assert_false(ilse.has_condition(&"poisoned"), "Lesser Restoration ends the poison")
	assert_true(bool((opts["warding_bond"] as Dictionary)["others_only"]))
	res = FieldCasting.cast(party, cleric, "warding_bond", 2, me, DiceRoller.new(3))
	assert_false(bool(res["ok"]), "Warding Bond goes on another creature")
	assert_false(opts.has("light"), "Light is cast from the exploring list")


func test_the_stash_at_a_safe_place() -> void:
	var ilse := GameState.story.party[0]
	assert_true(GameState.story.stash_put("javelin", ilse))
	assert_true(GameState.story.party_has_item("javelin"))
	var before := ilse.inventory.filter(func(e: Dictionary) -> bool: return str(e["id"]) == "javelin").size()
	assert_true(GameState.story.stash_take("javelin", ilse))
	assert_false(GameState.story.stash_take("javelin", ilse), "only the one we put there")
	root.call("open_screen", "inventory", 0)
	await _frames(1)
	var inv := root.get("screen") as InventoryScreen
	assert_true(inv.call("_stash_open"), "the test hall is a safe place")
	assert_true(before >= 0)


func test_arcane_recovery_after_a_short_rest() -> void:
	var silvain := GameState.story.party[3]
	silvain.slots_used[0] = 2
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	rest.call("_finish_short")
	await _frames(1)
	var buttons := rest.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text.begins_with("Recover a level 1"))
	assert_eq(buttons.size(), 1, "level 1 wizard: one slot level to recover")
	(buttons[0] as Button).pressed.emit()
	assert_eq(silvain.slots_used[0], 1)
	assert_eq(silvain.resource_left("arcane_recovery"), 0, "once per Long Rest")


func test_preparing_spells_after_a_long_rest() -> void:
	var hedda := GameState.story.party[2]
	var list := PrepareScreen.preparable(GameState.story)
	var keys: Array = list.map(func(e: Dictionary) -> String: return (e["choice"] as Choice).key)
	assert_true("cleric.prepared" in keys, str(keys))
	var c := hedda.choice("cleric.prepared")
	ChoiceOptions.populate(c, hedda)
	var current: Array = c.picks.duplicate()
	var other := ""
	for o in c.options:
		if o.legal and not o.id in current:
			other = o.id
			break
	assert_true(other != "", "another cleric spell to prepare")
	var picks: Array = current.duplicate()
	picks[0] = other
	(hedda.build["choices"] as Dictionary)["cleric.prepared"] = picks
	hedda.refresh()
	var known: Array = hedda.known_spells().map(func(k: Dictionary) -> String: return str(k["id"]))
	assert_true(other in known, "now prepared")
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	rest.call("_long_rest", "safe")
	await _frames(1)
	var btn := rest.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "Change prepared spells")
	assert_eq(btn.size(), 1)
	(btn[0] as Button).pressed.emit()
	await _frames(2)
	assert_eq(rest.find_children("*", "PrepareScreen", true, false).size(), 1)


## The Prepare Spells widget for `key` inside the rest screen's open PrepareScreen (opened with its button).
func _prepare_widget(rest: RestScreen, key: String) -> ChoiceWidget:
	for ps in rest.find_children("*", "PrepareScreen", true, false):
		ps.free()
	var btn := rest.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "Change prepared spells")
	(btn[0] as Button).pressed.emit()
	await _frames(2)
	for w in rest.find_children("*", "ChoiceWidget", true, false):
		if (w as ChoiceWidget).choice.key == key:
			return w as ChoiceWidget
	return null


func test_a_wizard_swaps_one_cantrip_per_long_rest_even_after_reopening() -> void:
	var silvain := GameState.story.party[3]
	var keys: Array = PrepareScreen.preparable(GameState.story).map(func(e: Dictionary) -> String: return (e["choice"] as Choice).key)
	assert_true("wizard.cantrips" in keys, "a Wizard swaps a cantrip after a Long Rest: %s" % [keys])
	var earlier := silvain.picks_for("wizard.cantrips")
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	rest.call("_long_rest", "safe")
	await _frames(1)
	var w := await _prepare_widget(rest, "wizard.cantrips")
	assert_true(w != null, "the Wizard's cantrips are on the Prepare Spells screen")
	w.call("_toggle", earlier[0], false)
	await _frames(2)
	assert_false(earlier[0] in silvain.picks_for("wizard.cantrips"), "unpicked")
	w = null
	for w2 in rest.find_children("*", "ChoiceWidget", true, false):
		if (w2 as ChoiceWidget).choice.key == "wizard.cantrips" and not (w2 as Node).is_queued_for_deletion():
			w = w2 as ChoiceWidget
	var fresh := ""
	for o in w.choice.options:
		if o.legal and not o.id in earlier:
			fresh = o.id
			break
	w.call("_toggle", fresh, true)
	await _frames(2)
	assert_true(fresh in silvain.picks_for("wizard.cantrips"), "the new cantrip is in")
	# Done, then the button again: the swap still counts from the list the rest ended with.
	w = await _prepare_widget(rest, "wizard.cantrips")
	assert_true(w.choice.option(earlier[1]).locked, "the Long Rest's one cantrip swap is used")
	assert_true(ChoiceOptions.swap_note(w.choice).contains("1 of 1 replaced"), ChoiceOptions.swap_note(w.choice))
	# Closing the screen ends the chance: the character's own choice has no limit left on it.
	for ps in rest.find_children("*", "PrepareScreen", true, false):
		ps.free()
	assert_false(ChoiceOptions.swap_open(silvain.choice("wizard.cantrips")), "the swap chance closed with the screen")


func test_an_items_long_rest_offers_prepared_spells_too() -> void:
	# Daern's Instant Fortress gives the party a Long Rest from the inventory: the same chance follows it.
	var ilse := GameState.story.party[0]
	ilse.add_item("daerns_instant_fortress")
	root.call("open_screen", "inventory", 0)
	await _frames(1)
	var inv := root.get("screen") as InventoryScreen
	var prep := func() -> Array: return inv.find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
		return (b as Button).text == "Change prepared spells" and not b.is_queued_for_deletion())
	assert_eq((prep.call() as Array).size(), 0, "no rest yet")
	inv.selected = "daerns_instant_fortress"
	inv.call("_use_power", "fortress", {})
	await _frames(1)
	var btn := prep.call() as Array
	assert_eq(btn.size(), 1, "offered after the item's Long Rest")
	(btn[0] as Button).pressed.emit()
	await _frames(2)
	var keys: Array = inv.find_children("*", "ChoiceWidget", true, false).map(func(w: Node) -> String: return (w as ChoiceWidget).choice.key)
	assert_true("wizard.cantrips" in keys and "cleric.prepared" in keys, str(keys))


func test_quicksave_from_the_pause_menu() -> void:
	# A new game has no slot: the first quicksave makes one, and later ones go over it.
	SaveSystem.current_slot = ""
	root.call("open_screen", "menu", 0)
	await _frames(1)
	var menu := root.get("screen") as PauseMenu
	var quick := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text.begins_with("Quicksave"))
	assert_eq(quick.size(), 1, "a Quicksave button")
	(quick[0] as Button).pressed.emit()
	var slot := SaveSystem.current_slot
	assert_true(slot != "" and SaveSystem.has_slot(slot), "the first quicksave made the game's slot")
	var count := SaveSystem.list_slots().size()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F5
	ev.pressed = true
	menu.call("_unhandled_input", ev)
	assert_eq(SaveSystem.current_slot, slot, "F5 saves over the same slot")
	assert_eq(SaveSystem.list_slots().size(), count, "no new slot")
	# A loaded game quicksaves over the slot it came from.
	assert_eq(SaveSystem.save("test_loaded"), OK)
	SaveSystem.current_slot = ""
	assert_eq(SaveSystem.load_slot("test_loaded"), OK)
	assert_eq(SaveSystem.current_slot, "test_loaded")
	assert_eq(SaveSystem.quick_save(), OK)
	assert_eq(SaveSystem.current_slot, "test_loaded")
	SaveSystem.delete_slot("test_loaded")
	SaveSystem.delete_slot(slot)
	SaveSystem.current_slot = ""
	root.call("close_screen")


func test_pause_menu_voices_slider() -> void:
	root.call("open_screen", "menu", 0)
	await _frames(1)
	var menu := root.get("screen") as PauseMenu
	var names: Array = menu.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is PauseMenu.ConceptSlider).map(func(n: Node) -> String: return str(n.name))
	assert_eq(names, ["Music", "Effects", "Voices"], "three volume sliders")
	var voices := menu.find_children("Voices", "", true, false)[0] as PauseMenu.ConceptSlider
	var was := VoiceOver.volume()
	assert_eq(voices.value, was, "the slider starts at the voice volume")
	voices.changed.emit(0.35)
	assert_eq(VoiceOver.volume(), 0.35, "moving it sets the voice volume")
	VoiceOver.set_volume(was)
	root.call("close_screen")
