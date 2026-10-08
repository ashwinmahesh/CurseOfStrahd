extends TestCase
## The target box's outline (owner request, 2026-10-08): when the player is about to attack, the box beside the
## target is outlined green if the attack would roll with Advantage, red with Disadvantage, and stays gilt with
## neither or both. It reads the same situation the attack roll uses (Encounter.attack_situation).

const SCENE := preload("res://scenes/combat/arena.tscn")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _attack(catalog: ActionCatalog, c: Combatant) -> Dictionary:
	for a in catalog.actions_for(c):
		if str(a["kind"]) == "attack":
			return a
	return {}


func test_the_preview_reads_the_rolls_edge() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2))
	var foe := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	TestCombat.start_with(e, hero)
	var catalog := ActionCatalog.new(e)
	var attack := _attack(catalog, hero)
	assert_false(attack.is_empty(), "the hero has an attack")
	var edge := func() -> String: return str(catalog.attack_preview(hero, attack, foe).get("edge", ""))
	assert_eq(edge.call(), "", "a plain attack")
	foe.creature.add_condition(&"restrained")
	assert_eq(edge.call(), "advantage", "against a Restrained foe")
	var sit := e.attack_situation(hero, foe, e.option_by_id(hero, str(attack["option_id"])))
	assert_false((sit["advantage"] as Array).is_empty(), "as the roll has it")
	hero.creature.add_condition(&"poisoned")
	assert_eq(edge.call(), "", "Advantage and Disadvantage cancel")
	foe.creature.remove_condition(&"restrained")
	assert_eq(edge.call(), "disadvantage", "a Poisoned hero")


func test_the_box_is_outlined_by_the_edge() -> void:
	var arena := SCENE.instantiate() as Node3D
	add_child(arena)
	await _frames(5)
	var view := arena.get("view") as CombatView
	var e := view.e
	for i in 20:
		if e.current().is_player_controlled():
			break
		e.end_turn()
		await _frames(1)
	var c := e.current()
	var foe: Combatant = null
	for o in e.combatants:
		if c.hostile_to(o) and o.is_alive():
			foe = o
			break
	var tokens := arena.get("tokens") as Dictionary
	var box := (view.hud.get("_tooltip") as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	var hover := func(attack: Dictionary) -> void:
		view.set("selected", attack)
		view.set("mode", CombatView.Mode.TARGET)
		view.set("hover_token", tokens[foe.id])
		view.call("_update_hover")
	var attack := _attack(view.catalog, c)
	hover.call(attack)
	assert_eq(box.border_color, Look.color("gilt"), "neither: the gilt edge")
	foe.creature.add_condition(&"restrained")
	hover.call(attack)
	assert_eq(box.border_color, Look.color("bile"), "Advantage: green")
	foe.creature.remove_condition(&"restrained")
	c.creature.add_condition(&"poisoned")
	hover.call(attack)
	assert_eq(box.border_color, Look.color("vampire_red"), "Disadvantage: red")
	c.creature.remove_condition(&"poisoned")
	view.set("mode", CombatView.Mode.IDLE)
	arena.queue_free()
	await _frames(1)
