extends TestCase
## Armor a caster has no training with shuts every spell (2024 Armor Training). Owner report 2026-10-18: Liriel, in Plate
## Armor +1 she isn't trained for, "can't cast any spells for some reason" and each slot gave the reason only on hover.
## Now the combat Spell tab says it first, naming the armor, and the inventory says it the moment the armor goes on.

const SCENE := preload("res://scenes/combat/arena.tscn")
const PLATE := "armor_plus_1__plate_armor"

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


## The notice over the Spell tab's slots, or null.
func _notice() -> Label:
	for n in _hud().find_children("UntrainedArmorNotice", "Label", true, false):
		if not n.is_queued_for_deletion():
			return n as Label
	return null


func _wear(c: Combatant, id: String) -> void:
	var ch := c.creature as Character
	ch.add_item(id)
	assert_true(ch.equip(id, "armor"), "%s goes on" % id)


func test_the_spell_tab_names_the_armor_that_shuts_every_spell() -> void:
	var e := arena.get("e") as Encounter
	var liriel := e.get_c("liriel_dawnsong")
	var hud := _hud()
	hud.shown = liriel
	hud.set_tab(ActionCatalog.SPELLS)
	await _frames(1)
	assert_true(_notice() == null, "nothing to say while she wears what she is trained in")
	_wear(liriel, PLATE)
	hud.set_tab(ActionCatalog.SPELLS)
	await _frames(1)
	var note := _notice()
	assert_true(note != null, "the Spell tab says why")
	if note == null:
		return
	var armor_name := str(Compendium.shared().item_data(PLATE).get("name", ""))
	assert_true(note.text.contains("Liriel") and note.text.contains(armor_name) and note.text.contains("heavy armor"), note.text)
	assert_true(note.is_visible_in_tree(), "and shows")
	var blocked := 0
	for i in hud.slot_count():
		var a := hud.slot_action(i)
		if str(a["kind"]) == "spell" and str(a["reason"]).begins_with("Wearing "):
			blocked += 1
			assert_false(bool(a["legal"]), "%s is shut" % a["label"])
			assert_eq(str(a["reason"]), "Wearing %s without training" % armor_name, "each slot names the armor too")
	assert_true(blocked >= 3, "her spells are shut, not one of them: %d" % blocked)


func test_the_notice_is_only_for_a_caster_the_armor_stops() -> void:
	var e := arena.get("e") as Encounter
	var hud := _hud()
	var liriel := e.get_c("liriel_dawnsong")
	_wear(liriel, PLATE)
	hud.shown = liriel
	hud.set_tab(CombatHud.ALL)
	await _frames(1)
	assert_true(_notice() == null, "the notice sits on the Spell tab, not on All")
	var godrick := e.get_c("godrick_pendlebrook")   # a Paladin: Heavy armor
	_wear(godrick, PLATE)
	assert_true((godrick.creature as Character).untrained_armor().is_empty(), "Godrick is trained for plate")
	hud.shown = godrick
	hud.set_tab(ActionCatalog.SPELLS)
	await _frames(1)
	assert_true(_notice() == null, "a hero trained for the plate gets none")
	hud.shown = liriel
	hud.set_tab(ActionCatalog.SPELLS)
	await _frames(1)
	assert_true(_notice() != null, "Liriel does")
	(liriel.creature as Character).unequip_item(PLATE)
	hud.set_tab(ActionCatalog.SPELLS)
	await _frames(1)
	assert_true(_notice() == null, "and it goes once the plate is off")
