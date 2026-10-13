extends FightSeriesCase
## The story's own fights held to the owner's bar where he found them too easy (2026-10-12: the Wizard of Wines at level 6
## on Balanced, where the autopilot won all eight tries losing at most one hero; 2026-10-13 18:05: the test party playing
## as he does wins about 5 in 8 on Balanced): over seeds 1-8 the four pregens win four to six, standing where walking in
## sets the fight off. Their level 5 and 7 versions are held by test_wow_levels.gd.


## Where walking in sets each fight off.
const VINE_LANE: Array[Vector2i] = [Vector2i(22, 25), Vector2i(23, 25), Vector2i(22, 26), Vector2i(23, 26)]
const HALL_DOOR: Array[Vector2i] = [Vector2i(10, 9), Vector2i(9, 9), Vector2i(9, 10), Vector2i(10, 10)]
const DIG_DOOR: Array[Vector2i] = [Vector2i(17, 6), Vector2i(16, 6), Vector2i(15, 6), Vector2i(14, 6)]


func _held(location: String, encounter: String, at: Array[Vector2i]) -> void:
	speakers_step_aside = true   # Kostin, before the press house's fight
	var wins := await _series(location, 12, 6, encounter, [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], at)
	assert_true(wins >= 4, "%s can be won (%d/8)" % [encounter, wins])
	assert_true(wins <= 6, "%s stays hard (%d/8)" % [encounter, wins])


## Up the lane from the road: the vines stand up around them, and an old tree blight with them.
func test_the_vineyard_ambush_at_level_6() -> void:
	await _held("wizard_of_wines", "vineyard_ambush", VINE_LANE)


## Into the fermenting hall from the tasting room: two druids, their blights and a shambling mound.
func test_the_winery_hall_at_level_6() -> void:
	await _held("wizard_of_wines_winery", "winery_occupation", HALL_DOOR)


## Through the cask vaults to the dig: the overseer and two druids ahead, two more and their blights rising from among
## the casks behind.
func test_the_cellar_dig_at_level_6() -> void:
	await _held("wizard_of_wines_cellar", "cellar_dig", DIG_DOOR)


## Kostin at the press with the Mash, three druids and six vine blights; the party just inside the door. 3 in 8, one
## druid lighter than the exact 2: with four, the phase 5 playthrough's party lost the press house on every reload once
## an ally's square stopped slowing them (2026-10-13).
func test_the_press_house_at_level_6() -> void:
	await _held("wizard_of_wines_press_house", "press_house_mash", [])


## From the stair foot to the dig, the way a party walks in (Wiki finding 114): the cask vaults' group waits out of
## view among the casks, so nothing in the vaults hears the party go by; the fight starts at the dig door with the
## overseers ahead and that group rising behind. Then the series again from where the walk set it off.
func test_the_cellar_dig_starts_at_the_dig_from_the_stair() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 6)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "wizard_of_wines_cellar"
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var v := root.get("view") as LocationView
	LocationStealth.refresh_waiting(v)
	for w: Dictionary in v.waiting:
		assert_true((w["foe"] as Combatant).cell.x >= 17, "only the dig's foes stand in view: %s" % (w["foe"] as Combatant).cell)
	assert_true(v.walk_to(Vector2i(17, 6)), "a way to the dig")
	for i in 3000:
		if v.in_combat or (not v.busy and v.leader().cell == Vector2i(17, 6)):
			break
		await get_tree().process_frame
	assert_true(v.in_combat, "the dig's fight starts")
	var at: Array[Vector2i] = []
	for m: Combatant in v.members:
		at.append(m.cell)
		assert_true(m.cell.x >= 13, "%s is at the dig door, not deep in the vaults: %s" % [m.name(), m.cell])
	var e := v.combat_view.e
	var behind := e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy" and c.cell.x <= 10)
	assert_eq(behind.size(), 5, "the vaults' group rises behind")
	root.queue_free()
	root = null
	await _frames(2)
	await _held("wizard_of_wines_cellar", "cellar_dig", at)
