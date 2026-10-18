extends TestCase
## Ireena keeps out of fights (allies plan E3; her NPC says `guest_fights: false`, LocationFights.sits_out and keep_back):
## she is never in the encounter, so she takes no turn and nobody can target her or catch her in an area; her figure stays
## on the board as a bystander whose square blocks, and she steps aside when the fight starts on a square someone will stand
## on. The Narrator says so the first time and now and then after. Other guests still fight. A save made before this, with
## her in the fight, still has her in that one.

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
	LocationFights.keeps_back_delay = 0.0
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	LocationFights.keeps_back_delay = 7.0
	if root != null:
		root.queue_free()
		root = null
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_den")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


## The party walks the den with `npcs` along as guests.
func _with_guests(npcs: Array[String]) -> LocationView:
	for npc in npcs:
		assert_true(GameState.story.add_guest(npc), "%s joins" % npc)
	_view().place_guests()
	return _view()


func _end_fight(v: LocationView) -> void:
	v.combat_view.finished.emit("victory")
	await _frames(4)


func _her(v: LocationView) -> Combatant:
	for g in v.guest_members:
		if g.id == "guest_ireena":
			return g
	return null


func _figures_of(v: LocationView, id: String) -> int:
	var n := 0
	for tok in v.find_children("*", "CombatToken", true, false):
		if (tok as CombatToken).combatant != null and (tok as CombatToken).combatant.id == id and (tok as Node3D).visible:
			n += 1
	return n


func _variants(key: String) -> Array[String]:
	var out: Array[String] = []
	var df := DialogueFile.load_key("narrator/keeps_back")
	for s: Dictionary in df.nodes.get(key, []):
		if str(s["t"]) == "variant":
			out.append(str(s["text"]))
	return out


# --- The rule -----------------------------------------------------------------------------------------------------

func test_ireena_keeps_out_of_fights_and_no_other_guest_is_told_to() -> void:
	assert_false(StoryState.guest_fights("ireena"), "her NPC says so")
	for npc: String in ["ismark", "ezmerelda", "rictavio", "kasimir_velikov", "emil_toranescu"]:
		assert_true(StoryState.guest_fights(npc), "%s fights as ever" % npc)
	assert_true(StoryState.guest_fights("no_such_person"), "fighting is the default")
	for id: String in Compendium.shared().tables["npcs"]:
		var npc := Compendium.shared().get_entry("npcs", id)
		if npc.get("guest_fights", true) == false:
			assert_true(bool(npc.get("guest", false)), "%s keeps out of fights, so she is a guest" % id)


# --- Her card -----------------------------------------------------------------------------------------------------------

func test_her_guest_card_says_she_keeps_back_and_another_guests_says_guest() -> void:
	_with_guests(["ireena", "ismark"] as Array[String])
	var hud := root.get("hud") as ExploreHud
	hud.refresh()
	await _frames(2)
	var pills: Array[String] = []
	for l in hud.find_children("*", "Label", true, false):
		if (l as Label).text in ["Guest", "Keeps back"]:
			pills.append((l as Label).text)
	assert_eq(pills, ["Keeps back", "Guest"] as Array[String], "Ireena's card, then Ismark's")
	assert_true((hud.find_child("Guest_ireena", true, false) as Button).tooltip_text.contains("keeps out of fights"), "her card says why on hover")
	assert_false((hud.find_child("Guest_ismark", true, false) as Button).tooltip_text.contains("keeps out of fights"), "his doesn't")
	var cards := (hud.get("_party_box") as VBoxContainer).get_children()
	for i: int in [cards.size() - 2, cards.size() - 1]:
		var card := cards[i] as Control
		assert_true(card.get_combined_minimum_size().x <= 252.5, "a guest's card does not grow past the party's: %s" % [card.get_combined_minimum_size()])


# --- A fight without her --------------------------------------------------------------------------------------------

func test_a_fight_starts_without_her_and_her_figure_stays_on_the_board() -> void:
	var v := _with_guests(["ireena"] as Array[String])
	var her := _her(v)
	assert_true(her != null, "she is along")
	assert_true(v.start_encounter("rat"), "a fight starts")
	await _frames(3)
	var e := v.combat_view.e
	assert_true(e.get_c("guest_ireena") == null, "she isn't in the fight")
	for c in e.combatants:
		assert_ne(c.creature, GameState.story.guests[0], "nor is anyone her")
		assert_ne(c.side, &"guest", "nobody on the guest side")
	assert_eq(e.combatants.size(), 3, "two heroes and the rat")
	var tok := v.tokens[her.id] as CombatToken
	assert_true(tok.visible, "her figure is still on the board")
	assert_true(e.grid.is_solid(her.cell), "her square blocks, as a bystander's does")
	assert_true(e.occupant_at(her.cell) == null, "with nobody standing on it")
	var hp := GameState.story.guests[0].hp
	await _end_fight(v)
	assert_false(v.in_combat, "the fight is over")
	assert_true(tok.visible, "she is where she was")
	assert_eq(GameState.story.guests[0].hp, hp, "untouched")
	assert_eq(GameState.story.guest_ids, ["ireena"] as Array[String], "still along: nothing sent her home")
	assert_false(v.grid.is_solid(her.cell), "and her square stopped blocking with the fight")


func test_no_area_of_either_side_can_catch_her() -> void:
	var v := _with_guests(["ireena"] as Array[String])
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	var e := v.combat_view.e
	var wizard := e.get_c(GameState.story.party[0].id)
	var her := _her(v)
	var area := e.spells.area_for(wizard, Compendium.shared().spell_data("fireball"), Vector2(her.cell) + Vector2(0.5, 0.5), Vector2.ZERO)
	assert_true(her.cell in area, "the fireball is centred on her square")
	for c in e.spells.creatures_in(area):
		assert_ne(c.creature, GameState.story.guests[0], "and does not find her")
	await _end_fight(v)


func test_another_guest_still_fights_beside_the_party() -> void:
	var v := _with_guests(["ireena", "ismark"] as Array[String])
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	var e := v.combat_view.e
	assert_true(e.get_c("guest_ismark") != null, "Ismark is in the fight")
	assert_true(e.get_c("guest_ireena") == null, "Ireena isn't")
	assert_true(e.get_c("guest_ismark").is_player_controlled(), "and the player commands him")
	await _end_fight(v)


# --- Stepping aside ---------------------------------------------------------------------------------------------------

func test_she_steps_off_the_square_a_foe_starts_on() -> void:
	var v := _with_guests(["ireena"] as Array[String])
	var her := _her(v)
	her.cell = Vector2i(8, 4)   # where the rat starts
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	var e := v.combat_view.e
	assert_ne(her.cell, Vector2i(8, 4), "she stepped off")
	assert_true(maxi(absi(her.cell.x - 8), absi(her.cell.y - 4)) >= 2, "and away from it: %s" % her.cell)
	assert_true(e.occupant_at(her.cell) == null, "onto a square nobody stands on")
	assert_true(e.grid.is_solid(her.cell), "which blocks")
	assert_true(e.grid.distance_ft(her.cell, 1, Vector2i(8, 4), 1) <= 40, "she did not wander off")
	var stepped := her.cell
	await _end_fight(v)
	assert_eq(her.cell, stepped, "and she stays there afterwards")


func test_she_steps_off_a_square_the_party_stands_on() -> void:
	var v := _with_guests(["ireena"] as Array[String])
	var her := _her(v)
	her.cell = v.members[0].cell   # party members and guests share squares outside a fight
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	var e := v.combat_view.e
	assert_ne(her.cell, v.members[0].cell, "she stepped off the leader's square")
	assert_true(e.occupant_at(her.cell) == null, "onto a free one")
	await _end_fight(v)


# --- What the Narrator says -----------------------------------------------------------------------------------------

func test_the_narrator_says_so_the_first_time_and_now_and_then_after() -> void:
	var first := _variants("combat:keeps_back:ireena:first")
	var later := _variants("combat:keeps_back:ireena")
	assert_eq(first.size(), 1, "one line for the first fight")
	assert_true(later.size() >= 4, "and several for the ones after: %d" % later.size())
	for t in first + later:
		assert_false(t.contains("{"), "lines for voicing carry no placeholders: %s" % t)
	var v := _with_guests(["ireena"] as Array[String])
	var said: Array[String] = []
	v.narration.connect(func(t: String) -> void: said.append(t))
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	assert_true(first[0] in said, "the first fight says why: %s" % [said])
	await _end_fight(v)
	said.clear()
	assert_true(v.start_encounter("rat_again"))
	await _frames(3)
	assert_false(first[0] in said, "the first line plays once")
	assert_eq(said.filter(func(t: String) -> bool: return t in later).size(), 1, "the next fight has one of the others: %s" % [said])
	await _end_fight(v)
	said.clear()
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	assert_false(said.any(func(t: String) -> bool: return t in first or t in later), "but not fight after fight: %s" % [said])
	await _end_fight(v)
	GameState.story.advance_minutes(120)
	said.clear()
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	assert_false(first[0] in said, "the first line plays once")
	assert_eq(said.filter(func(t: String) -> bool: return t in later).size(), 1, "a later fight has one of the others: %s" % [said])
	await _end_fight(v)


func test_a_fight_without_her_says_nothing_of_her() -> void:
	var v := _with_guests(["ismark"] as Array[String])
	var said: Array[String] = []
	v.narration.connect(func(t: String) -> void: said.append(t))
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	var all := _variants("combat:keeps_back:ireena:first") + _variants("combat:keeps_back:ireena")
	assert_false(said.any(func(t: String) -> bool: return t in all), "only the guest who keeps out gets a word")
	await _end_fight(v)


# --- Saves ---------------------------------------------------------------------------------------------------------------

func test_a_round_start_save_leaves_her_square_out_and_a_load_puts_her_aside_again() -> void:
	var v := _with_guests(["ireena"] as Array[String])
	assert_true(v.start_encounter("rat"))
	await _frames(3)
	var her := _her(v)
	var snap := GameState.combat_snapshot.duplicate(true)
	assert_false(snap.is_empty(), "the round-start save")
	var data := snap["data"] as Dictionary
	var row := str((data["rows"] as Array)[her.cell.y])
	assert_ne(row[her.cell.x], "=", "her square is not part of the saved ground: %s" % row)
	assert_true((data["combatants"] as Array).all(func(cd: Variant) -> bool: return str((cd as Dictionary)["id"]) != "guest_ireena"), "nor is she a combatant")
	await _end_fight(v)
	assert_true(LocationFights.resume_encounter(v, snap), "the fight is picked up again")
	await _frames(3)
	var e := v.combat_view.e
	assert_true(e.get_c("guest_ireena") == null, "without her")
	her = _her(v)
	assert_true(e.grid.is_solid(her.cell), "her square blocks again")
	assert_true(e.occupant_at(her.cell) == null, "with nobody on it")
	assert_eq(_figures_of(v, "guest_ireena"), 1, "one figure of her, on the board")
	await _end_fight(v)


func test_a_save_made_with_her_in_the_fight_has_her_in_that_one() -> void:
	var v := _with_guests(["ireena"] as Array[String])
	var st := GameState.story
	var hers := _her(v).cell
	var old := Encounter.new(LocationFights._combat_grid(v), v.dice)
	for m in v.members:
		old.add(m.creature, &"party", m.cell)
	old.add(st.guests[0], &"guest", _her(v).cell).controller = &"player"
	old.add(Monster.from_data(Compendium.shared().monster_data("rat")), &"enemy", Vector2i(8, 4))
	old.start()
	var snap := {"location": v.loc_id, "encounter": "rat", "data": EncounterSnapshot.capture(old)}
	assert_true(LocationFights.resume_encounter(v, snap), "an older save loads")
	await _frames(3)
	var e := v.combat_view.e
	assert_true(e.get_c("guest_ireena") != null, "she fights that one, as she did when it was saved")
	assert_eq(_her(v).cell, hers, "and is not stepped aside")
	assert_true(e.occupant_at(hers) == e.get_c("guest_ireena"), "she stands where the save had her")
	assert_eq(_figures_of(v, "guest_ireena"), 1, "as one figure, not two")
	await _end_fight(v)
	await get_tree().create_timer(0.8).timeout   # the figure a load made for her fades away
	assert_eq(_figures_of(v, "guest_ireena"), 1, "and one afterwards")
