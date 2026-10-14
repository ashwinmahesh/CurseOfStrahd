extends TestCase
## A creature changing shape is seen and heard (owner ask, 2026-10-14): whatever changes it (Polymorph, Wild Shape, a
## vampire's bat and mist, a lycanthrope's hybrid), the figure gathers, flares and is swapped for the new one in a flash
## with a sound (FxShapeshift, CombatSfx.shapeshift; CombatView._swap_form_art), and Emil, who is drawn as a man, takes
## the werewolf's figure for his hybrid form and is a man again when he changes back.

var e: Encounter
var view: CombatView
var _root: Node3D
var _shown: Array = []


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _field() -> void:
	var rows: Array = []
	for z in 12:
		rows.append("................")
	e = TestCombat.encounter(rows)
	_shown.clear()


func _guest(npc_id: String, cell: Vector2i) -> Combatant:
	return e.add(StoryState.make_guest(npc_id), &"guest", cell)


## The fight on a board with its tokens, `first` to act. What the view shows of each change is gathered in `_shown`.
func _show(first: Combatant) -> void:
	TestCombat.start_with(e, first)
	_root = Node3D.new()
	add_child(_root)
	var board := ArenaBoard.build(e.grid)
	_root.add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c)
		token.position = board.cell_center(c.cell, c.size_cells)
		_root.add_child(token)
		tokens[c.id] = token
	var rig := CameraRig.new()
	_root.add_child(rig)
	view = CombatView.new()
	view.input_locked = true
	_root.add_child(view)
	view.begin(e, board, rig, tokens)
	view.fx.shape_shown.connect(func(id: String, kind: String) -> void: _shown.append([id, kind]))
	await _frames(2)
	var waited := 0.0
	while view._opening and waited < 4.0:   # the opening beat: the first turn waits for it
		await get_tree().process_frame
		waited += get_process_delta_time()
	await view._play_events()
	_shown.clear()


## The board goes once the effects have played out.
func _done() -> void:
	await get_tree().create_timer(0.7).timeout
	_root.queue_free()
	await _frames(1)


func _wears(tok: CombatToken, art: String) -> bool:
	return tok != null and tok.sprite != null and tok.sprite.sprite_frames == DirectionalSprite.frames_for(art)


func _kinds_of(type: String, id: String) -> Array:
	var out: Array = []
	for ev: Dictionary in e.events:
		if str(ev.get("type", "")) == type and str(ev.get("id", "")) == id:
			out.append(str(ev.get("kind", "")))
	return out


# --- Looks and sounds ------------------------------------------------------------------------------------------

func test_every_kind_of_change_has_a_look_and_a_sound_and_an_unknown_one_gets_the_default() -> void:
	var flavours := SpellFx.data()["flavours"] as Dictionary
	for kind: String in FxShapeshift.LOOKS:
		var l := FxShapeshift.look(kind)
		assert_true(flavours.has(str(l["flavour"])), "%s is drawn in a flavour effects.json has" % kind)
		Look.color(str(l["tint"]))   # asserts the palette has it
		var ids := CombatSfx.shapeshift_ids(kind)
		assert_false(ids.is_empty(), "%s has a sound" % kind)
		for entry in ids:
			assert_false(Audio.files("sfx", entry.get_slice("@", 0)).is_empty(), "%s: %s has a recording" % [kind, entry])
	for kind: String in (CombatSfx.data()["shapeshift"] as Dictionary):
		assert_true(FxShapeshift.LOOKS.has(kind), "%s sounds but has no look" % kind)
	assert_eq(FxShapeshift.look("something_new"), FxShapeshift.LOOKS["default"], "a new kind of change still shows")
	assert_eq(CombatSfx.shapeshift_ids("something_new"), CombatSfx.shapeshift_ids("default"), "and sounds")
	# The sounds play on the SFX bus, so the player's sound slider (Audio.set_volumes) is what sets how loud they are.
	for p in Audio._sfx:
		assert_eq(p.bus, &"SFX")


func test_each_shapeshifter_says_how_its_change_looks() -> void:
	_field()
	var s := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(3, 3))
	e.events.clear()
	e.legendary._set_form(s, "bat")
	assert_eq(_kinds_of("form", s.id), ["bat"], "Strahd's bat")
	e.legendary._set_form(s, "mist")
	e.events.clear()
	e.legendary._set_form(s, e.legendary.base_form(s))
	assert_eq(_kinds_of("form", s.id), ["mist"], "back from mist, he leaves the mist")
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 3))
	var rat: Dictionary = ShapeChange.beast_forms(1.0)[0]
	e.events.clear()
	e.shapes.transform(hero, rat, {"temp_hp": 5, "label": "Polymorph", "ends_without_temp_hp": true})
	e.shapes.revert(hero, "test")
	assert_eq(_kinds_of("shape", hero.id), ["polymorph", "polymorph"], "a spell's change, both ways")
	e.events.clear()
	e.shapes.transform(hero, rat, {"temp_hp": 5, "label": "Wild Shape", "keep_mind": true})
	e.shapes.revert(hero, "test")
	assert_eq(_kinds_of("shape", hero.id), ["wild_shape", "wild_shape"], "a Druid's, both ways")
	var raven := _guest("davian_martikov", Vector2i(7, 3))
	e.events.clear()
	e.monster_actions.shift(raven)
	assert_eq(_kinds_of("form", raven.id), ["wereraven"], "a wereraven's feathers, not a wolf's fur")


# --- On the board -----------------------------------------------------------------------------------------------

func test_emil_changes_with_an_effect_and_a_sound_and_back() -> void:
	_field()
	var emil := _guest("emil_toranescu", Vector2i(3, 6))
	TestCombat.foe(e, "zombie", Vector2i(9, 6))
	await _show(emil)
	var own := view.tokens[emil.id] as CombatToken
	assert_true(_wears(own, "emil_toranescu"), "Emil as a man")
	var before := view.fx.get_child_count()
	assert_true(e.feature_actions.perform(emil, "creature:shape_shift", null, Vector2.INF).ok)
	await view._play_events()
	var wolf := view.tokens[emil.id] as CombatToken
	assert_true(wolf != own and _wears(wolf, "werewolf"), "his token is the werewolf's")
	assert_false(own.visible, "his own figure waits, hidden")
	assert_eq(_shown, [[emil.id, "werewolf"]], "the change was shown, as a werewolf's")
	assert_true(view.fx.get_child_count() > before, "with its motes, flash and smoke")
	assert_true(view.fx.find_children("*", "Control", true, false).is_empty(), "nothing that takes the focus")
	await get_tree().create_timer(FxShapeshift.SETTLE + 0.2).timeout
	assert_true(wolf.visible and is_equal_approx(wolf._fade, 1.0), "and the werewolf has come into view")
	emil.bonus_available = true
	assert_true(e.feature_actions.perform(emil, "creature:shape_shift", null, Vector2.INF).ok)
	await view._play_events()
	assert_eq(view.tokens[emil.id], own, "his own figure is back")
	assert_true(own.visible, "and shown")
	assert_eq(_shown, [[emil.id, "werewolf"], [emil.id, "werewolf"]], "that change was shown too")
	await _done()


func test_a_change_is_a_short_beat_that_holds_nothing_up() -> void:
	_field()
	var emil := _guest("emil_toranescu", Vector2i(3, 6))
	TestCombat.foe(e, "zombie", Vector2i(9, 6))
	await _show(emil)
	assert_true(e.feature_actions.perform(emil, "creature:shape_shift", null, Vector2.INF).ok)
	var start := Time.get_ticks_msec()
	await view._play_events()
	var took := float(Time.get_ticks_msec() - start) / 1000.0
	assert_between(took, FxShapeshift.GATHER * 0.8, 1.2, "the figure gathers for a beat, then is swapped")
	await _done()


func test_a_fight_with_its_effects_off_swaps_the_figure_at_once() -> void:
	_field()
	var emil := _guest("emil_toranescu", Vector2i(3, 6))
	TestCombat.foe(e, "zombie", Vector2i(9, 6))
	await _show(emil)
	SpellFx.enabled = false
	assert_true(e.feature_actions.perform(emil, "creature:shape_shift", null, Vector2.INF).ok)
	var start := Time.get_ticks_msec()
	await view._play_events()
	var took := Time.get_ticks_msec() - start
	SpellFx.enabled = true
	assert_true(_wears(view.tokens[emil.id] as CombatToken, "werewolf"), "still the werewolf")
	assert_true(_shown.is_empty(), "no effect was shown")
	assert_true(took < 200, "and there was no beat (%d ms)" % took)
	await _done()


func test_a_figure_nobody_can_see_changes_without_showing_where_it_stands() -> void:
	_field()
	var emil := _guest("emil_toranescu", Vector2i(3, 6))
	TestCombat.foe(e, "zombie", Vector2i(9, 6))
	await _show(emil)
	(view.tokens[emil.id] as CombatToken).visible = false
	assert_true(e.feature_actions.perform(emil, "creature:shape_shift", null, Vector2.INF).ok)
	await view._play_events()
	assert_true(_wears(view.tokens[emil.id] as CombatToken, "werewolf"), "it changed")
	assert_true(_shown.is_empty(), "with no effect or sound to give it away")
	await _done()


func test_kiril_as_a_foe_changes_in_front_of_the_party() -> void:
	_field()
	var kiril := TestCombat.foe(e, "kiril_stoyanovich", Vector2i(9, 6))
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 6))
	await _show(hedda)
	assert_true(_wears(view.tokens[kiril.id] as CombatToken, "kiril_stoyanovich"), "Kiril as a man")
	kiril.bonus_available = true
	e.monster_actions.bonus_action(kiril, "shift")
	await view._play_events()
	assert_true(_wears(view.tokens[kiril.id] as CombatToken, "werewolf"), "the werewolf")
	assert_eq(_shown, [[kiril.id, "werewolf"]])
	await _done()


func test_polymorph_and_a_vampires_bat_use_the_same_effect() -> void:
	_field()
	var wizard := TestCombat.high_caster(e, ["polymorph"], Vector2i(3, 6))
	var scout := TestCombat.foe(e, "scout", Vector2i(8, 6))
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(12, 3))
	await _show(wizard)
	TestCombat.next_d20(e, 1)
	assert_true(e.spells.cast(wizard, "polymorph", 4, [scout], Vector2.INF, Vector2.ZERO, {"choice": "rat"}).ok)
	await view._play_events()
	assert_true(_wears(view.tokens[scout.id] as CombatToken, "rat"), "the scout is a rat")
	assert_true([scout.id, "polymorph"] in _shown, "shown as a spell's change")
	e.shapes.revert(scout, "test")
	await view._play_events()
	assert_true(_wears(view.tokens[scout.id] as CombatToken, CombatToken.art_id(scout)), "and a scout again")
	assert_eq(_shown.count([scout.id, "polymorph"]), 2, "both ways")
	e.legendary._set_form(strahd, "bat")
	await view._play_events()
	assert_true(_wears(view.tokens[strahd.id] as CombatToken, "bat"), "Strahd is a bat")
	assert_true([strahd.id, "bat"] in _shown, "shown as a bat's")
	e.legendary._set_form(strahd, e.legendary.base_form(strahd))
	await view._play_events()
	assert_true(_wears(view.tokens[strahd.id] as CombatToken, CombatToken.art_id(strahd)), "and himself again")
	assert_true([strahd.id, "bat"] in _shown and _shown.count([strahd.id, "bat"]) == 2, "which is shown too")
	await _done()
