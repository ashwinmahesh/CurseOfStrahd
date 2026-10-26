extends TestCase
## Ezmerelda's spells on the combat HUD (Resume packages, Allies item 3): a story ally who casts from a stat block gets a Spells tab on
## the hotbar, its slots say what is left today, and a right-click on one does not offer to Ready it (a stat-block spell has no slot
## and no readied form). The catalog side is tests/unit/test_ezmerelda_spells.gd and, in the core, test_stat_block_spells_tab.gd.

const SCENE := preload("res://scenes/combat/arena.tscn")

var arena: Node3D


func before_each() -> void:
	Dice.reseed(3)
	arena = SCENE.instantiate() as Node3D
	add_child(arena)
	await _frames(5)


func after_each() -> void:
	if arena != null:
		arena.queue_free()
		arena = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hud() -> CombatHud:
	return (arena.get("view") as CombatView).get("hud") as CombatHud


func _menu_texts(hud: CombatHud) -> Array[String]:
	var out: Array[String] = []
	var menu := hud.get("_menu") as PopupMenu
	for i in menu.item_count:
		out.append(menu.get_item_text(i))
	return out


func _ezmerelda(e: Encounter) -> Combatant:
	var ez := e.add(StoryState.make_guest("ezmerelda"), &"guest", Vector2i(1, 1))
	ez.controller = &"player"
	return ez


func test_her_spells_fill_the_spells_tab_and_say_what_is_left() -> void:
	var e := arena.get("e") as Encounter
	var hud := _hud()
	var ez := _ezmerelda(e)
	hud.shown = ez
	hud.set_tab(ActionCatalog.SPELLS)
	await _frames(1)
	var labels: Array[String] = []
	var subs := {}
	for i in hud.slot_count():
		var a := hud.slot_action(i)
		if str(a.get("kind", "")) == "spell":
			labels.append(str(a["label"]))
			subs[str(a["label"])] = str(a["sub"])
	for name_: String in ["Magic Missile", "Lightning Bolt", "Greater Invisibility", "Mirror Image"]:
		assert_true(name_ in labels, "%s is on her Spells tab: %s" % [name_, labels])
	assert_true(str(subs.get("Magic Missile", "")).contains("4 left today"), str(subs.get("Magic Missile", "")))


func test_a_stat_block_spell_does_not_offer_to_ready_and_a_hero_s_spell_does() -> void:
	var e := arena.get("e") as Encounter
	var hud := _hud()
	var ez := _ezmerelda(e)
	hud.shown = ez
	hud.set_tab(ActionCatalog.SPELLS)
	await _frames(1)
	var mm := {}
	for i in hud.slot_count():
		if str(hud.slot_action(i).get("label", "")) == "Magic Missile":
			mm = hud.slot_action(i)
	assert_false(mm.is_empty(), "her Magic Missile is on the bar")
	hud.open_slot_menu(mm, Vector2(100, 100))
	assert_false(_menu_texts(hud).any(func(t: String) -> bool: return t.begins_with("Ready")), "no Ready for a stat-block spell: %s" % [_menu_texts(hud)])
	var liriel := e.get_c("liriel_dawnsong")
	hud.shown = liriel
	hud.set_tab(ActionCatalog.SPELLS)
	await _frames(1)
	var action_spell := {}
	for i in hud.slot_count():
		var a := hud.slot_action(i)
		if str(a.get("kind", "")) == "spell" and str(a.get("cost", "")) == "action" and bool(a.get("legal", false)):
			action_spell = a
			break
	assert_false(action_spell.is_empty(), "Liriel has a spell that takes an action")
	hud.open_slot_menu(action_spell, Vector2(100, 100))
	assert_true(_menu_texts(hud).any(func(t: String) -> bool: return t.begins_with("Ready")), "a hero's still can be readied: %s" % [_menu_texts(hud)])
