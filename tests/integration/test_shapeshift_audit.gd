extends TestCase
## The shapeshift audit (owner ask, 2026-10-14: every creature and character that changes shape has a figure for each
## shape, and the effect applies on every route): the data names a figure for every shape, a fight picked up from a save
## draws whoever was mid-shape in the shape they were in, the lycanthropy curse and a story reveal (a hag turning out to
## be one) show the change, and a shape with no figure still shows as a change.

var e: Encounter
var view: CombatView
var _root: Node3D
var _shown: Array = []
var game: Node


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func after_each() -> void:
	if game != null:
		game.queue_free()
		game = null


func _field() -> void:
	var rows: Array = []
	for z in 12:
		rows.append("................")
	e = TestCombat.encounter(rows)
	_shown.clear()


## The fight on a board with its tokens as a fight picked up from a save builds them (LocationFights._fight_tokens): the
## party and guests in the figures they walked in with, a foe's built from its creature.
func _show(own_figures: Dictionary = {}) -> void:
	_root = Node3D.new()
	add_child(_root)
	var board := ArenaBoard.build(e.grid)
	_root.add_child(board)
	var tokens := {}
	for c in e.combatants:
		var token: CombatToken
		if own_figures.has(c.id):
			token = CombatToken.create(c, str(own_figures[c.id]))
		elif c.side == &"guest":
			token = LocationFights._combat_token(c)
		else:
			token = CombatToken.create(c)
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


func _done() -> void:
	await get_tree().create_timer(0.7).timeout
	_root.queue_free()
	await _frames(1)


func _wears(tok: CombatToken, art: String) -> bool:
	return tok != null and tok.sprite != null and tok.sprite.sprite_frames == DirectionalSprite.frames_for(art)


# --- The data -----------------------------------------------------------------------------------------------

func test_every_shape_a_creature_can_take_has_a_figure_and_every_change_a_look() -> void:
	var c := Compendium.shared()
	var checked := 0
	for id: String in c.table("monsters"):
		var d := c.monster_data(id)
		for sh: Variant in ((d.get("forms", {}) as Dictionary).get("shapes", []) as Array):
			var shape := sh as Dictionary
			var art := str(shape.get("art", ""))
			checked += 1
			if bool(shape.get("art_from_npc", false)):
				# A figure the story's person has: every NPC a stat block is named for has one.
				for npc_id: String in c.table("npcs"):
					var npc := c.table("npcs")[npc_id] as Dictionary
					if str(npc.get("monster", "")) == id:
						assert_true(DirectionalSprite.frames_for(str(npc.get("sprite", npc_id))) != null, "%s's disguise as %s has a figure" % [id, npc_id])
			else:
				assert_true(art != "" and DirectionalSprite.frames_for(art) != null, "%s's %s form has a figure (%s)" % [id, shape.get("id", ""), art])
			assert_true(FxShapeshift.LOOKS.has(str(shape.get("kind", shape.get("id", "")))) or not shape.has("kind"), "%s's %s change has a look" % [id, shape.get("id", "")])
		if d.has("hybrid_art"):
			assert_true(DirectionalSprite.frames_for(str(d["hybrid_art"])) != null, "%s's hybrid has a figure" % id)
		if d.has("reveal"):
			assert_true(FxShapeshift.LOOKS.has(str(d["reveal"])), "%s's reveal has a look (%s)" % [id, d["reveal"]])
			assert_false(CombatSfx.shapeshift_ids(str(d["reveal"])).is_empty())
	assert_true(checked >= 10, "every shape of Strahd, the vampires, the lycanthropes, Lysaga and the hag was checked (%d)" % checked)
	# Polymorph, Wild Shape and the high spells: every creature one can become wears its own sprite.
	var forms: Array[Dictionary] = []
	forms.append_array(ShapeChange.beast_forms(30.0))
	forms.append_array(HighMagic.forms(30.0))
	for f in forms:
		var art := str(f.get("art", f.get("id", "")))
		assert_true(DirectionalSprite.frames_for(art) != null, "%s has a figure to be turned into" % f.get("id", ""))


func test_a_mimic_or_hags_shape_shift_is_not_a_snarling_hybrid() -> void:
	_field()
	var hag := TestCombat.foe(e, "night_hag", Vector2i(3, 3))
	var mimic := TestCombat.foe(e, "mimic", Vector2i(6, 3))
	var wolf := TestCombat.foe(e, "werewolf", Vector2i(9, 3))
	e.monster_actions.shift(hag)
	e.monster_actions.shift(mimic)
	e.monster_actions.shift(wolf)
	var log := "\n".join(e.log.texts())
	assert_true(log.contains("Night Hag changes shape"), "the hag changes shape")
	assert_true(log.contains("Mimic changes shape"), "so does the mimic")
	assert_true(log.contains("Werewolf twists into a snarling hybrid form"), "a werewolf's other form is the hybrid")
	assert_false(log.contains("Hag twists") or log.contains("Mimic twists"), "nobody else is a snarling hybrid")


func test_a_vampires_bat_and_mist_wear_the_bat_and_the_mist() -> void:
	_field()
	var v := TestCombat.foe(e, "vampire", Vector2i(8, 6))
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 6))
	TestCombat.start_with(e, hedda)
	await _show()
	e.legendary._set_form(v, "bat")
	await view._play_events()
	assert_true(_wears(view.tokens[v.id] as CombatToken, "bat"), "the vampire is a bat")
	assert_eq(_shown, [[v.id, "bat"]], "shown as a bat's change")
	e.legendary._set_form(v, "mist")
	await view._play_events()
	assert_true(_wears(view.tokens[v.id] as CombatToken, "strahd_mist"), "and mist")
	e.legendary._set_form(v, e.legendary.base_form(v))
	await view._play_events()
	assert_true(_wears(view.tokens[v.id] as CombatToken, CombatToken.art_id(v)), "and a vampire again")
	await _done()


# --- A fight picked up from a save -------------------------------------------------------------------------------

func test_a_fight_picked_up_from_a_save_draws_everyone_in_the_shape_they_were_in() -> void:
	_field()
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 6))
	var emil := e.add(StoryState.make_guest("emil_toranescu"), &"guest", Vector2i(3, 3))
	var ireena := e.add(StoryState.make_guest("ireena"), &"guest", Vector2i(3, 9))
	var strahd := TestCombat.foe(e, "strahd_von_zarovich", Vector2i(12, 6))
	var scout := TestCombat.foe(e, "scout", Vector2i(10, 3))
	TestCombat.start_with(e, hedda)
	var rat: Dictionary = ShapeChange.beast_forms(1.0)[0]
	var rat_art := str(rat.get("art", rat.get("id", "")))
	e.shapes.transform(hedda, rat, {"temp_hp": 5, "label": "Polymorph"})
	e.shapes.transform(ireena, rat, {"temp_hp": 5, "label": "Polymorph"})
	e.shapes.transform(scout, rat, {"temp_hp": 5, "label": "Polymorph"})
	e.monster_actions.shift(emil)
	e.legendary._set_form(strahd, "bat")
	var saved := EncounterSnapshot.capture(e)
	var own_look := CombatToken.art_for(e.shapes.original(hedda))
	# Picked up from the save: new combatants, no events to play, the tokens as a resumed fight builds them.
	var party_back: Array[Character] = []
	party_back.append(e.shapes.original(hedda) as Character)
	e = EncounterSnapshot.restore(saved, DiceRoller.new(3), party_back)
	e.events.clear()
	var c_hedda := e.get_c(hedda.id)
	var c_emil := e.get_c(emil.id)
	var c_ireena := e.get_c(ireena.id)
	var c_strahd := e.get_c(strahd.id)
	var c_scout := e.get_c(scout.id)
	assert_true(c_hedda != null and e.shapes.is_shaped(c_hedda), "Hedda is still the rat in the saved fight")
	assert_true(str(c_emil.get_meta("form", "")) == "hybrid" and e.legendary.form(c_strahd) == "bat", "Emil's hybrid and Strahd's bat kept too")
	await _show({c_hedda.id: own_look})
	assert_true(_wears(view.tokens[c_emil.id] as CombatToken, "werewolf"), "Emil is the werewolf")
	assert_true(_wears(view.tokens[c_strahd.id] as CombatToken, "bat"), "Strahd is a bat")
	assert_true(_wears(view.tokens[c_scout.id] as CombatToken, rat_art), "the scout is a %s" % rat_art)
	assert_true(_wears(view.tokens[c_ireena.id] as CombatToken, rat_art), "Ireena is the beast, not her own figure under its stat block")
	assert_true(_wears(view.tokens[c_hedda.id] as CombatToken, rat_art), "and Hedda")
	assert_true(is_instance_valid(view._own_tokens[c_hedda.id]) and not (view._own_tokens[c_hedda.id] as Node3D).visible, "her own figure waits, hidden")
	# The shapes end: each is itself again, the party's own figures back (not the beasts').
	e.shapes.revert(c_hedda, "test")
	e.shapes.revert(c_ireena, "test")
	e.shapes.revert(c_scout, "test")
	e.monster_actions.shift(c_emil)
	e.legendary._set_form(c_strahd, e.legendary.base_form(c_strahd))
	await view._play_events()
	assert_eq(view.tokens[c_hedda.id], view._own_tokens[c_hedda.id], "Hedda's own token is hers again")
	assert_true(_wears(view.tokens[c_hedda.id] as CombatToken, own_look), "wearing her own look")
	assert_true(_wears(view.tokens[c_ireena.id] as CombatToken, "ireena"), "Ireena in her own")
	assert_true(_wears(view.tokens[c_scout.id] as CombatToken, CombatToken.art_id(c_scout)), "the scout as a scout")
	assert_true(_wears(view.tokens[c_emil.id] as CombatToken, "emil_toranescu"), "Emil as a man")
	assert_true(_wears(view.tokens[c_strahd.id] as CombatToken, CombatToken.art_id(c_strahd)), "Strahd as himself")
	await _done()


# --- Routes that changed a figure with no effect ------------------------------------------------------------------

func test_a_cursed_creature_changes_into_the_werewolf_it_becomes() -> void:
	_field()
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 6))
	var victim := TestCombat.hero(e, "ilse_varga", Vector2i(6, 6))
	TestCombat.foe(e, "werewolf", Vector2i(10, 6))
	TestCombat.start_with(e, hedda)
	await _show()
	var fx := Effect.new("Cursed: Lycanthropy", &"monster", "lycanthropy").with_modifier("flag", {"value": "curse:lycanthropy"})
	fx.ends = Effect.Ends.NEVER
	victim.creature.add_effect(fx)
	e.events.clear()
	assert_true(e.monster_actions.lycanthrope(victim))
	await view._play_events()
	assert_eq(_shown, [[victim.id, "werewolf"]], "the victim changes first")
	var raised := e.combatants.filter(func(c: Combatant) -> bool: return c.creature.name.contains("werewolf"))
	assert_true(not raised.is_empty() and view.tokens.has((raised[-1] as Combatant).id), "and the werewolf stands in their place")
	assert_false((view.tokens[victim.id] as CombatToken).visible, "the victim's figure has gone")
	await _done()


func test_a_shape_with_no_figure_still_shows_as_a_change() -> void:
	_field()
	var scout := TestCombat.foe(e, "scout", Vector2i(8, 6))
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 6))
	await _show()
	var before: Variant = view.tokens[scout.id]
	await view._swap_shape_art(scout.id, "a_creature_nobody_drew", "polymorph")
	assert_eq(_shown, [[scout.id, "polymorph"]], "it showed")
	assert_eq(view.tokens[scout.id], before, "on the figure it has")
	await _done()


# --- Story scenes: a person turns out to be something else -----------------------------------------------------------

func test_a_foe_of_the_same_name_as_someone_who_stepped_aside_is_that_person_revealed() -> void:
	assert_true(LocationFights._same_person("Offalia Wormwiggle", "Offalia Wormwiggle"))
	assert_true(LocationFights._same_person("Vosk", "Vosk, unmasked"), "unmasked is still Vosk")
	assert_true(LocationFights._same_person("Abbot", "The Abbot"))
	assert_true(LocationFights._same_person("Zuleika Toranescu", "Zuleika"))
	assert_false(LocationFights._same_person("Kostin", "Mother Ruxandra"))
	assert_false(LocationFights._same_person("", ""))
	_field()
	var hag := TestCombat.foe(e, "night_hag", Vector2i(5, 5))
	hag.creature.name = "Offalia Wormwiggle"
	var other := TestCombat.foe(e, "night_hag", Vector2i(7, 5))
	other.creature.name = "Morgantha"
	var v := LocationView.new()
	v._stepped_aside.append({"name": "Offalia Wormwiggle", "art": "offalia_wormwiggle"})
	var reveal := LocationFights._reveal_of(v, hag)
	assert_eq(str(reveal.get("art", "")), "offalia_wormwiggle", "Offalia was a woman in an apron a moment ago")
	assert_eq(str(reveal.get("kind", "")), "hag")
	assert_true(v._stepped_aside.is_empty(), "each person changes once")
	assert_true(LocationFights._reveal_of(v, hag).is_empty())
	v._stepped_aside.append({"name": "Offalia Wormwiggle", "art": "offalia_wormwiggle"})
	assert_true(LocationFights._reveal_of(v, other).is_empty(), "Morgantha is someone else")
	var fed := TestCombat.foe(e, "scout", Vector2i(9, 5))
	fed.creature.name = "Offalia Wormwiggle"
	assert_true(LocationFights._reveal_of(v, fed).is_empty(), "a scout is no reveal: its stat block names none")
	v.free()


func test_offalia_turns_into_the_hag_in_front_of_the_party() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]:
		var ch := Pregens.build(id, 7)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "old_bonegrinder"
	GameState.story.minute_of_day = 14 * 60
	Dice.reseed(7)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _frames(3)
	var v := game.get("view") as LocationView
	v._stepped_aside.append({"name": "Offalia Wormwiggle", "art": "offalia_wormwiggle"})
	assert_true(v.start_encounter("bakery_offalia"), "the fight starts")
	await _frames(2)
	var hag_tok: CombatToken = null
	var stand_in: CombatToken = null
	for t: Variant in v.combat_view.tokens.values():
		var tok := t as CombatToken
		if tok.combatant.name() == "Offalia Wormwiggle":
			hag_tok = tok
	for child in v.get_children():
		if child is CombatToken and child != hag_tok and (child as CombatToken).combatant == hag_tok.combatant:
			stand_in = child as CombatToken
	assert_true(hag_tok != null and stand_in != null, "the hag, and Offalia as she was, stand in the same place")
	assert_false(hag_tok.visible, "the hag isn't there yet")
	assert_true(_wears(stand_in, "offalia_wormwiggle"), "in her apron")
	assert_true(v._stepped_aside.is_empty())
	await get_tree().create_timer(FxShapeshift.GATHER + 0.5).timeout
	assert_true(hag_tok.visible, "then she is the hag")
	assert_false(is_instance_valid(stand_in) and stand_in.is_inside_tree(), "and the woman in the apron has gone")
