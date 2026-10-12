class_name FightSeriesCase
extends TestCase
## Fights played to the end by the test autopilot with the four pregens, seed by seed, on their own maps
## (test_side_quest_bosses.gd, test_story_fights.gd): every fight finishes, and the party can win but pays for it (hard,
## per the owner's standing rule).

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Boots `location` at `hour` with the four pregens at `level`, starts `encounter` and plays it with the autopilot.
## `at`: where the four stand when it starts (the saved positions a load uses); unset, the location's default spawn.
func _play(location: String, hour: int, level: int, encounter: String, seed_value: int, flags: Array[String] = [],
		guests: Array[String] = [], open_doors: Array[String] = [], at: Array[Vector2i] = []) -> Dictionary:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f in flags:
		GameState.story.set_flag(f, true)
	for g in guests:
		GameState.story.add_guest(g)
	for d in open_doors:
		(GameState.story.loc_state(location)["doors"] as Dictionary)[d] = LocationView.DOOR_OPEN
	GameState.story.location = location
	if at.size() == GameState.story.party.size():
		GameState.story.positions = at.duplicate()
	GameState.story.minute_of_day = hour * 60
	Dice.reseed(seed_value)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var v := root.get("view") as LocationView
	# A party set down inside a fight's trigger area sets it off as it arrives; otherwise it starts here.
	var started := str((GameState.story.loc_state(location)["encounters"] as Dictionary).get(encounter, "")) == "started"
	assert_true(started or v.start_encounter(encounter), "%s starts" % encounter)
	await _frames(2)
	var e := v.combat_view.e
	var res := PartyAutopilot.new(e).run(30)
	res["story_flags"] = e.legendary.story_flags.duplicate()   # what the fight hands back (a withdrawal's flag)
	res["departed"] = e.legendary.departed.values()
	for c in e.combatants:
		assert_true(c.creature.hp >= 0 and c.creature.hp <= c.creature.max_hp(), "%s HP in range" % c.name())
	root.queue_free()
	root = null
	await _frames(2)
	return res


## Plays `encounter` once per seed: every fight finishes and at least one is won. Returns the wins, for a test that
## wants more of them.
func _series(location: String, hour: int, level: int, encounter: String, seeds: Array, flags: Array[String] = [],
		guests: Array[String] = [], open_doors: Array[String] = [], at: Array[Vector2i] = []) -> int:
	var wins := 0
	var downs := 0
	var rounds := 0
	for s: int in seeds:
		var res := await _play(location, hour, level, encounter, s, flags, guests, open_doors, at)
		assert_ne(str(res["outcome"]), "timeout", "%s seed %d finished" % [encounter, s])
		if str(res["outcome"]) == "victory":
			wins += 1
		downs += int(res["downs"])
		rounds += int(res["rounds"])
	print("        %s at level %d: %d/%d won, %.1f rounds, %.1f party members dropped per fight" % [
		encounter, level, wins, seeds.size(), rounds / float(seeds.size()), downs / float(seeds.size())])
	assert_true(wins >= 1, "%s can be won at level %d (%d/%d)" % [encounter, level, wins, seeds.size()])
	return wins
