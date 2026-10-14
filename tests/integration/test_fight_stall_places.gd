extends FightSeriesCase
## The places where fights stalled (Scale up book battles, 2026-10-13): Death House's storage and nursery doors, shut
## with a hero in the doorway, walled off the room once that hero fell; and the lead wolf, left standing in the one gap
## of the Old Svalich Road's narrows when the fight began without its conversation, cut the last wolf off.


## The four in a line through the nursery door (a door the narrator watches); into the storage room past its door.
const NURSERY_DOOR: Array[Vector2i] = [Vector2i(22, 8), Vector2i(22, 7), Vector2i(22, 6), Vector2i(22, 5)]
const STORAGE: Array[Vector2i] = [Vector2i(12, 12), Vector2i(12, 11), Vector2i(12, 10), Vector2i(13, 10)]
const NARROWS: Array[Vector2i] = [Vector2i(22, 15), Vector2i(23, 16), Vector2i(24, 17), Vector2i(25, 17)]


func _boot(location: String, at: Array[Vector2i], flags: Array[String] = []) -> LocationView:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f in flags:
		GameState.story.set_flag(f, true)
	GameState.story.location = location
	GameState.story.positions = at.duplicate()
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return root.get("view") as LocationView


func _member_at(e: Encounter, cell: Vector2i) -> Combatant:
	for c in e.combatants:
		if c.side == &"party" and c.cell == cell:
			return c
	return null


func test_a_hero_in_a_shut_doorway_holds_it_open() -> void:
	var v := await _boot("death_house_third", STORAGE)
	# Set down in the storage room, the party sets off its broom as it arrives.
	assert_eq(str((GameState.story.loc_state("death_house_third")["encounters"] as Dictionary).get("storage_broom", "")), "started")
	await _frames(2)
	var e := v.combat_view.e
	var door := Vector2i(12, 11)
	assert_false(e.grid.has_flag(door, CombatGrid.WALL), "no wall round the hero in the doorway")
	var held: BattleObject = null
	for o in e.objects.list:
		if o.door_id == "third_storage_door":
			held = o
	assert_true(held != null and held.open, "the door stands open")
	var liriel := _member_at(e, door)
	liriel.creature.hp = 0
	liriel.creature.add_condition(&"unconscious", "test")
	assert_true(e.grid.can_see(Vector2i(12, 10), 1, Vector2i(12, 12), 1), "with her down, the others still see past her")


func test_a_hero_in_a_watched_doorway_holds_it_open_too() -> void:
	var v := await _boot("death_house_third", NURSERY_DOOR, ["death_house_armor_destroyed"])
	FightSeriesCase.step_aside(v, "nursery_specter")
	assert_true(v.start_encounter("nursery_specter"))
	await _frames(2)
	var e := v.combat_view.e
	assert_false(e.grid.has_flag(Vector2i(22, 6), CombatGrid.WALL), "the nursery door's square isn't a wall")
	_member_at(e, Vector2i(22, 6)).creature.hp = 0
	assert_true(e.grid.can_see(Vector2i(22, 7), 1, Vector2i(22, 5), 1), "sight runs through the doorway past the fallen")


## A fight a conversation starts: its speakers step aside first, as the conversation has them do.
func test_the_lead_wolf_steps_aside_before_the_pack_attacks() -> void:
	var v := await _boot("into_the_mists_road", NARROWS)
	var gap := Vector2i(21, 15)
	var lead := v.npc_tokens["mists_wolves"] as CombatToken
	assert_true(lead.visible and lead.combatant.cell == gap, "the lead wolf stands in the gap of the narrows")
	FightSeriesCase.step_aside(v, "mists_wolves")
	assert_false(lead.visible, "until it steps aside")
	assert_true(v.start_encounter("mists_wolves"))
	await _frames(2)
	assert_false(v.combat_view.e.grid.has_flag(gap, CombatGrid.LOW), "so the fight's way through the narrows is open")
