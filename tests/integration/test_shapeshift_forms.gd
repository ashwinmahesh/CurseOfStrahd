extends TestCase
## The forms the audit left open (owner ask, 2026-10-14: every shapeshifter has a figure for each shape and the effect
## applies): a werewolf's wolf and a wereraven's raven (2024 Monster Manual: Shape-Shift into the hybrid or the
## animal), Baba Lysaga's swarm of insects, a Night Hag's disguise as the person the story showed, and the effects
## for the appearance changes that swap no figure (Starry Form, Celestial Revelation, Disguise Self, Seeming).

var e: Encounter
var view: CombatView
var _root: Node3D
var _shown: Array = []


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _forms(c: Combatant) -> Array:
	return e.events.filter(func(ev: Dictionary) -> bool: return str(ev.get("type", "")) == "form" and str(ev.get("id", "")) == c.id)


func _ally(npc_id: String) -> Combatant:
	var c := e.add(StoryState.make_guest(npc_id), &"guest", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, c)
	e.events.clear()
	return c


# --- A lycanthrope's animal ---------------------------------------------------------------------------------------

func test_emil_takes_the_wolf_form_and_is_a_man_again() -> void:
	e = TestCombat.open_field()
	var c := _ally("emil_toranescu")
	assert_eq(c.speed(), 30, "a man's pace")
	assert_true(e.feature_actions.list(c).any(func(x: Dictionary) -> bool: return str(x["id"]) == "feat:creature:shape_shift:wolf"), "the hotbar offers the wolf")
	assert_true(e.feature_actions.perform(c, "creature:shape_shift:wolf", null, Vector2.INF).ok)
	assert_eq(str(c.get_meta("form", "")), "wolf", "he is a wolf")
	assert_false(c.bonus_available, "for a Bonus Action")
	assert_eq(c.speed(), 40, "a wolf's pace")
	assert_eq(c.size_cells, 1, "Medium")
	var forms := _forms(c)
	assert_eq(forms.size(), 1)
	if forms.size() == 1:
		assert_eq(str((forms[0] as Dictionary).get("art", "")), "wolf", "wearing the wolf")
		assert_eq(str((forms[0] as Dictionary).get("kind", "")), "werewolf", "a werewolf's change, not a vampire's")
	var bite := (c.creature as Monster).action("bite")
	var bow := (c.creature as Monster).action("longbow")
	assert_eq(e.monster_actions.why_not(c, bite), "", "the Bite in wolf form")
	assert_ne(e.monster_actions.why_not(c, bow), "", "but no bow")
	var ids := e.feature_actions.list(c).map(func(x: Dictionary) -> String: return str(x["id"]))
	assert_false("feat:creature:shape_shift:wolf" in ids, "no second animal form from this one")
	# And back to a man, on a later turn.
	c.bonus_available = true
	e.events.clear()
	assert_true(e.feature_actions.perform(c, "creature:shape_shift", null, Vector2.INF).ok)
	assert_eq(str(c.get_meta("form", "")), "humanoid", "a man again")
	assert_eq(c.speed(), 30)
	forms = _forms(c)
	assert_true(forms.size() == 1 and str((forms[0] as Dictionary).get("art", "x")) == "" and str((forms[0] as Dictionary).get("kind", "")) == "werewolf", "his own figure, as a werewolf's change")


func test_a_wereraven_ally_takes_the_raven() -> void:
	e = TestCombat.open_field()
	var c := _ally("davian_martikov")
	assert_true(e.feature_actions.perform(c, "creature:shape_shift:raven", null, Vector2.INF).ok)
	assert_eq(str(c.get_meta("form", "")), "raven")
	assert_eq(c.size_cells, 1, "Small")
	var forms := _forms(c)
	assert_true(forms.size() == 1 and str((forms[0] as Dictionary).get("art", "")) == "raven" and str((forms[0] as Dictionary).get("kind", "")) == "wereraven")
	assert_eq(e.monster_actions.why_not(c, (c.creature as Monster).action("beak")), "", "the Beak in raven form")
	assert_ne(e.monster_actions.why_not(c, (c.creature as Monster).action("shortbow")), "", "no bow")


func test_a_hybrid_can_go_straight_to_the_wolf_and_a_foe_werewolf_wears_the_wolf() -> void:
	e = TestCombat.open_field()
	var w := TestCombat.foe(e, "werewolf", Vector2i(3, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	TestCombat.start_with(e, w)
	w.bonus_available = true
	e.events.clear()
	e.monster_actions.bonus_action(w, "shift")
	assert_eq(str(w.get_meta("form", "")), "hybrid", "the AI goes into the hybrid, as before")
	assert_true(_forms(w).is_empty(), "which it already looks")
	e.monster_actions.shift(w, "wolf")
	var forms := _forms(w)
	assert_true(forms.size() == 1 and str((forms[0] as Dictionary).get("art", "")) == "wolf", "and a wolf it can be")
	e.monster_actions.shift(w)
	assert_eq(str(w.get_meta("form", "")), "humanoid", "back from the wolf")


func test_moonbeam_puts_a_wolf_back_with_its_pace_and_a_save_keeps_the_form() -> void:
	e = TestCombat.open_field(3)
	var caster := TestCombat.caster_with(e, ["moonbeam"], Vector2i(2, 3), 5)
	var emil := TestCombat.foe(e, "emil_toranescu", Vector2i(7, 3))
	TestCombat.start_with(e, emil)
	e.monster_actions.shift(emil, "wolf")
	assert_eq(emil.speed(), 40)
	# A fight picked up from a save: still a wolf, still quick.
	var back := EncounterSnapshot.restore(EncounterSnapshot.capture(e), DiceRoller.new(5), [] as Array[Character])
	var emil2 := back.get_c(emil.id)
	assert_eq(str(emil2.get_meta("form", "")), "wolf", "the saved fight keeps the wolf")
	assert_eq(emil2.speed(), 40, "and its pace")
	assert_eq(back.legendary.form_art(emil2), "wolf", "and the figure to draw")
	e.end_turn()
	e.events.clear()
	TestCombat.next_d20(e, 1)
	caster.action_available = true
	assert_true(e.spells.cast(caster, "moonbeam", 2, [], Vector2(7.5, 3.5)).ok)
	assert_eq(str(emil.get_meta("form", "")), "humanoid", "forced back")
	assert_eq(emil.speed(), 30, "to a man's pace")
	var forms := _forms(emil)
	assert_true(forms.size() == 1 and str((forms[0] as Dictionary).get("art", "x")) == "", "and a man's figure")


func test_only_a_lycanthrope_shifts_on_its_own() -> void:
	e = TestCombat.open_field()
	var hag := TestCombat.foe(e, "night_hag", Vector2i(3, 3))
	var mimic := TestCombat.foe(e, "mimic", Vector2i(6, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	TestCombat.start_with(e, hag)
	for c: Combatant in [hag, mimic]:
		c.bonus_available = true
		e.monster_actions.bonus_action(c, "shift")
		assert_true(c.bonus_available, "%s keeps its Bonus Action: nothing for it to shift into" % c.name())
		assert_false(c.has_meta("form"))


# --- Lysaga's swarm and the hag's disguise -------------------------------------------------------------------------

func test_baba_lysaga_can_be_a_swarm_of_insects() -> void:
	e = TestCombat.open_field()
	var l := TestCombat.foe(e, "baba_lysaga", Vector2i(3, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	TestCombat.start_with(e, l)
	e.events.clear()
	assert_true(e.legendary.change_form(l, "swarm").ok, "with her action")
	assert_eq(str(l.get_meta("form", "")), "swarm")
	var forms := _forms(l)
	assert_true(forms.size() == 1 and str((forms[0] as Dictionary).get("art", "")) == "swarm_of_insects" and str((forms[0] as Dictionary).get("kind", "")) == "swarm")
	assert_eq(int(((l.creature as Monster).base_speed as Dictionary).get("fly", 0)), 30, "flying")
	assert_eq(int(((l.creature as Monster).base_speed as Dictionary).get("walk", 0)), 5, "and barely walking")
	assert_eq(e.legendary.form_art(l), "swarm_of_insects", "the figure a saved fight draws")


func test_a_named_hag_disguises_as_her_own_npc_and_a_nameless_one_has_no_figure() -> void:
	e = TestCombat.open_field()
	var hag := TestCombat.foe(e, "night_hag", Vector2i(3, 3))
	hag.creature.name = "Offalia Wormwiggle"
	var other := TestCombat.foe(e, "night_hag", Vector2i(6, 3))
	TestCombat.hero(e, "silvain_aster", Vector2i(1, 3))
	TestCombat.start_with(e, hag)
	e.events.clear()
	e.legendary._set_form(hag, "disguise")
	e.legendary._set_form(other, "disguise")
	var mine := _forms(hag)
	assert_true(mine.size() == 1 and str((mine[0] as Dictionary).get("art", "")) == "offalia_wormwiggle", "in her apron")
	assert_eq(str((mine[0] as Dictionary).get("kind", "")), "disguise")
	var theirs := _forms(other)
	assert_true(theirs.size() == 1 and str((theirs[0] as Dictionary).get("art", "x")) == "", "a hag no story person plays has no disguise to wear")


# --- On the board --------------------------------------------------------------------------------------------------

func _show() -> void:
	_root = Node3D.new()
	add_child(_root)
	var board := ArenaBoard.build(e.grid)
	_root.add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token := CombatToken.create(c) if c.side != &"guest" else LocationFights._combat_token(c)
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
	while view._opening and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await view._play_events()
	_shown.clear()


func _wears(tok: CombatToken, art: String) -> bool:
	return tok != null and tok.sprite != null and tok.sprite.sprite_frames == DirectionalSprite.frames_for(art)


func test_the_board_shows_the_wolf_the_swarm_and_the_disguise_with_the_effect() -> void:
	e = TestCombat.open_field()
	_shown.clear()
	var emil := _ally("emil_toranescu")
	var l := TestCombat.foe(e, "baba_lysaga", Vector2i(9, 4))
	var hag := TestCombat.foe(e, "night_hag", Vector2i(9, 6))
	hag.creature.name = "Morgantha"
	await _show()
	assert_true(e.feature_actions.perform(emil, "creature:shape_shift:wolf", null, Vector2.INF).ok)
	e.legendary._set_form(l, "swarm")
	e.legendary._set_form(hag, "disguise")
	await view._play_events()
	assert_true(_wears(view.tokens[emil.id] as CombatToken, "wolf"), "Emil is a wolf")
	assert_true(_wears(view.tokens[l.id] as CombatToken, "swarm_of_insects"), "Lysaga is a swarm")
	assert_true(_wears(view.tokens[hag.id] as CombatToken, "morgantha"), "Morgantha is the old woman")
	assert_true([emil.id, "werewolf"] in _shown and [l.id, "swarm"] in _shown and [hag.id, "disguise"] in _shown, "each change was shown: %s" % [_shown])
	# And the wolf, the swarm and the disguise come off again.
	emil.bonus_available = true
	assert_true(e.feature_actions.perform(emil, "creature:shape_shift", null, Vector2.INF).ok)
	e.legendary._set_form(l, e.legendary.base_form(l))
	e.legendary._set_form(hag, e.legendary.base_form(hag))
	await view._play_events()
	assert_true(_wears(view.tokens[emil.id] as CombatToken, "emil_toranescu"), "Emil is a man")
	assert_true(_wears(view.tokens[l.id] as CombatToken, CombatToken.art_id(l)), "Lysaga herself")
	assert_true(_wears(view.tokens[hag.id] as CombatToken, CombatToken.art_id(hag)), "the hag herself")
	assert_eq(_shown.size(), 6, "both ways")
	await get_tree().create_timer(0.7).timeout
	_root.queue_free()
	await _frames(1)


# --- The appearance changes that swap no figure ---------------------------------------------------------------------

func test_starry_form_celestial_revelation_and_the_disguise_spells_show_and_sound() -> void:
	e = TestCombat.open_field()
	var c := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	for key: String in ["starry_form:archer", "starry_form:dragon", "celestial_revelation:heavenly_wings", "celestial_revelation:inner_radiance"]:
		var cue := SpellFx.ability_cue("feature", key, c)
		assert_eq(str(cue.get("family", "")), "transform", "%s shows as a change" % key)
		assert_false(CombatSfx.ids_for(cue, "cast").is_empty(), "and sounds")
	assert_eq(str(SpellFx.ability_cue("feature", "starry_form:archer", c)["flavour"]), "moon")
	assert_eq(str(SpellFx.ability_cue("feature", "celestial_revelation:heavenly_wings", c)["flavour"]), "radiant")
	assert_eq(str(SpellFx.ability_cue("feature", "celestial_revelation:necrotic_shroud", c)["flavour"]), "necrotic", "a Necrotic Shroud is a dark one")
	for spell: String in ["disguise_self", "seeming", "alter_self", "gaseous_form", "enlarge_reduce"]:
		assert_eq(str(SpellFx.spell_cue(spell).get("family", "")), "transform", "%s changes how someone looks" % spell)
	assert_true(CombatSfx.own("celestial_revelation:heavenly_wings").has("cast"), "its own sound")
