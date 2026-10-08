extends TestCase
## A summoned familiar joins its caster's fights in the real game (EncounterSetup.bring_familiars from
## LocationView.start_encounter): it stands in a free square beside its caster, the combat view draws it, it leaves
## the board with the fight, and it comes back for the next one while it's still summoned.

const LOC := {
	"id": "test_den", "name": "Test Den", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"encounters": [
		{"id": "rat", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [8, 4]}]},
		{"id": "rat_again", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [8, 1]}]}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_den"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["silvain_aster", "ilse_varga"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_den"
	Dice.reseed(11)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _familiars(e: Encounter, owner_id: String) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in e.combatants:
		if str(c.get_meta("summoner", "")) == owner_id and c.is_alive():
			out.append(c)
	return out


func _end_fight(v: LocationView) -> void:
	v.combat_view.finished.emit("victory")
	await _frames(4)


func test_a_summoned_familiar_stands_beside_its_caster_and_comes_back_next_fight() -> void:
	var v := _view()
	var wizard := GameState.story.party[0]
	assert_true(wizard.knows_spell("find_familiar"), "Silvain knows Find Familiar")
	wizard.familiar = "here"
	assert_true(v.start_encounter("rat"), "a fight starts")
	await _frames(3)
	var cv := v.combat_view
	var e := cv.e
	var owl := _familiars(e, wizard.id)
	assert_eq(owl.size(), 1, "the familiar is on the board")
	var me := e.get_c(wizard.id)
	var d := owl[0].cell - me.cell
	assert_true(maxi(absi(d.x), absi(d.y)) <= 2, "beside its caster: %s and %s" % [owl[0].cell, me.cell])
	assert_false(e.grid.is_solid(owl[0].cell), "not in a wall")
	for c in e.combatants:
		if c != owl[0]:
			assert_ne(c.cell, owl[0].cell, "a square of its own (not %s's)" % c.name())
	var tok := cv.call("_tok", owl[0].id) as CombatToken
	assert_true(tok != null and tok.is_inside_tree(), "the combat view draws it")
	await _end_fight(v)
	assert_false(v.in_combat, "the fight is over")
	assert_false(v.tokens.has(owl[0].id), "no familiar left standing on the exploration map")
	assert_eq(wizard.familiar, "here", "still summoned after a fight it survived")
	assert_true(v.start_encounter("rat_again"), "the next fight starts")
	await _frames(3)
	assert_eq(_familiars(v.combat_view.e, wizard.id).size(), 1, "and the familiar is back")
	await _end_fight(v)


func test_no_familiar_joins_until_one_is_summoned() -> void:
	var v := _view()
	var wizard := GameState.story.party[0]
	wizard.familiar = ""
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	assert_eq(_familiars(v.combat_view.e, wizard.id).size(), 0, "knowing the spell isn't enough")
	assert_eq(v.combat_view.e.combatants.filter(func(c: Combatant) -> bool: return c.side != &"enemy").size(), 2,
		"just the two heroes")
	await _end_fight(v)


func _walk_until_idle() -> void:
	for i in 400:
		if (_view().get("_queue") as Array).is_empty():
			return
		await get_tree().process_frame


func _world_familiars(v: LocationView) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for g in v.guest_members:
		if g.has_meta("familiar_of"):
			out.append(g)
	return out


## Owner's playtest (2026-10-08): Find Familiar cast while exploring left no familiar in the world.
func test_a_familiar_cast_while_exploring_appears_and_follows_the_party() -> void:
	var v := _view()
	var wizard := GameState.story.party[0]
	wizard.familiar = ""
	TestCombat.give_components(wizard, ["find_familiar"], 2)   # incense for two castings
	assert_eq(_world_familiars(v).size(), 0)
	var res := FieldCasting.cast_utility(GameState.story, wizard, "find_familiar", true)
	assert_true(bool(res["ok"]), str(res["text"]))
	v.apply_spell_effect("find_familiar")
	await _frames(2)
	var fams := _world_familiars(v)
	assert_eq(fams.size(), 1, "the familiar is in the world")
	var owl := fams[0]
	assert_true(v.tokens.has(owl.id) and (v.tokens[owl.id] as Node3D).is_inside_tree(), "drawn on the map")
	var lead := v.leader().cell
	assert_true(maxi(absi(owl.cell.x - lead.x), absi(owl.cell.y - lead.y)) <= 3, "beside the party: %s and %s" % [owl.cell, lead])
	var before := owl.cell
	assert_true(v.walk_to(Vector2i(7, 3)))
	await _walk_until_idle()
	assert_ne(owl.cell, before, "it follows the party")
	FieldCasting.cast_utility(GameState.story, wizard, "find_familiar", true)
	v.apply_spell_effect("find_familiar")
	await _frames(2)
	assert_eq(_world_familiars(v).size(), 1, "casting it again keeps one familiar")
	assert_true(v.start_encounter("rat"), "a fight starts")
	await _frames(3)
	var e := v.combat_view.e
	assert_eq(_familiars(e, wizard.id).size(), 1, "it joins the fight as the wizard's familiar")
	assert_eq(e.combatants.filter(func(c: Combatant) -> bool: return c.side != &"enemy").size(), 3, "two heroes and one familiar, not a second one as a guest")
	await _end_fight(v)
	assert_eq(_world_familiars(v).size(), 1, "back in the line after the fight")
	wizard.familiar = ""
	LocationParty.refresh_familiars(v)
	assert_eq(_world_familiars(v).size(), 0, "a familiar that's gone leaves the line")
