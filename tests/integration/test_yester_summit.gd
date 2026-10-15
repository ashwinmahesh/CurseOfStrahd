extends FightSeriesCase
## The Yester Hill summit, the Wizard of Wines' climax, held to the owner's bar (2026-10-14: the test party at full
## ability, smites, Spirit Guardians, Fireball, the Radiance of the Dawn, Hunter's Mark..., wins about 3 times in 8 on
## Balanced, timeouts counted as losses), for each way the party can reach the fight, standing where walking in sets it
## off, with Ruxandra stepping aside as her conversation ends. The ways earned with a check are a little easier (4 in 8:
## the druids scared off, the circle broken, struck first from the gully), Kostin's warning a little harder (2); the
## tests allow one win either way of those.
## The owner found it far too easy after driving the druids off with Intimidation (2026-10-12): Wintersplinter came
## alone with six twig blights and fell in two rounds.


## Where Ruxandra speaks first (approach 10): the party up the hill path, or round from the back gully.
const UP_THE_PATH: Array[Vector2i] = [Vector2i(16, 17), Vector2i(16, 18), Vector2i(16, 19), Vector2i(16, 20)]
const FROM_THE_GULLY: Array[Vector2i] = [Vector2i(10, 17), Vector2i(9, 18), Vector2i(8, 19), Vector2i(7, 19)]


## The owner's 3 wins in 8 for the party at full ability (2026-10-14), one either way; `low` and `high` move for the
## ways that earn an edge (4) and for Kostin's warning (2).
func _held(level: int, flags: Array[String], at: Array[Vector2i], low: int = 2, high: int = 4) -> void:
	speakers_step_aside = true
	var wins := await _series("yester_hill_gulthias_tree", 12, level, "summit_ritual", [1, 2, 3, 4, 5, 6, 7, 8], flags, [], [], at)
	assert_true(wins >= low, "the summit can be won at level %d %s (%d/8)" % [level, flags, wins])
	assert_true(wins <= high, "the summit stays hard at level %d %s (%d/8)" % [level, flags, wins])


## Walking up the path or round from the gully, the party is where the series starts when Ruxandra turns to speak.
func test_ruxandra_speaks_where_the_fights_start() -> void:
	for way: Array in [[[Vector2i(16, 21), Vector2i(15, 21), Vector2i(17, 21), Vector2i(16, 22)], UP_THE_PATH],
			[[Vector2i(1, 19), Vector2i(2, 19), Vector2i(1, 20), Vector2i(1, 18)], FROM_THE_GULLY]]:
		GameState.reset()
		for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
			var ch := Pregens.build(id, 6)
			ch.finish_long_rest()
			GameState.story.party.append(ch)
		GameState.story.location = "yester_hill_gulthias_tree"
		GameState.story.positions.assign(way[0] as Array)
		GameState.story.minute_of_day = 12 * 60
		Dice.reseed(1)
		root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
		add_child(root)
		await _frames(3)
		var v := root.get("view") as LocationView
		var heard := [false]
		v.dialogue_requested.connect(func(_ref: String, _npc: String) -> void: heard[0] = true)
		assert_true(v.walk_to(Vector2i(15, 12)), "a way to Ruxandra")
		for i in 3000:
			if heard[0] or (not v.busy and v.leader().cell == Vector2i(15, 12)):
				break
			await get_tree().process_frame
		assert_true(heard[0], "Ruxandra speaks first")
		var at: Array[Vector2i] = []
		for m: Combatant in v.members:
			at.append(m.cell)
		assert_eq(at, way[1] as Array[Vector2i], "where the series starts")
		root.queue_free()
		root = null
		await _frames(2)


## Level 6, as the party arrives.
func test_the_plain_summit_at_level_6() -> void:
	await _held(6, [], UP_THE_PATH)


## The circle frightened off: Wintersplinter and the crown's blights (twig, vine and needle), no druids.
func test_the_druids_fled_at_level_6() -> void:
	await _held(6, ["yester_druids_fate=fled"], UP_THE_PATH, 3, 5)


## Up the gully unseen and in among them: the circle surprised, the tree half-made.
func test_struck_first_at_level_6() -> void:
	await _held(6, ["yester_sneaked", "yester_struck_first"], FROM_THE_GULLY, 3, 5)


## Kostin ran ahead and warned them: Ruxandra, Kostin and two more druids round a tree woken early.
func test_kostin_warned_them_at_level_6() -> void:
	await _held(6, ["kostin_fled"], UP_THE_PATH, 1, 3)


## Level 7 (a party that levelled on side quests first): a warden of the hill with Ruxandra and a bigger tree.
func test_the_plain_summit_at_level_7() -> void:
	await _held(7, [], UP_THE_PATH)


func test_the_druids_fled_at_level_7() -> void:
	await _held(7, ["yester_druids_fate=fled"], UP_THE_PATH, 3, 5)


func test_struck_first_at_level_7() -> void:
	await _held(7, ["yester_sneaked", "yester_struck_first"], FROM_THE_GULLY, 3, 5)


func test_kostin_warned_them_at_level_7() -> void:
	await _held(7, ["kostin_fled"], UP_THE_PATH, 1, 3)


## Level 5 (a party that came early): a smaller tree, fewer druids.
func test_the_plain_summit_at_level_5() -> void:
	await _held(5, [], UP_THE_PATH)


func test_the_druids_fled_at_level_5() -> void:
	await _held(5, ["yester_druids_fate=fled"], UP_THE_PATH, 3, 5)


func test_struck_first_at_level_5() -> void:
	await _held(5, ["yester_sneaked", "yester_struck_first"], FROM_THE_GULLY, 3, 5)


func test_kostin_warned_them_at_level_5() -> void:
	await _held(5, ["kostin_fled"], UP_THE_PATH, 1, 3)


## Religion breaks the circle and only Ruxandra stays: a little easier than the plain fight.
func test_the_circle_broken_at_levels_5_to_7() -> void:
	for level: int in [5, 6, 7]:
		await _held(level, ["yester_circle_broken"], UP_THE_PATH, 3, 5)
