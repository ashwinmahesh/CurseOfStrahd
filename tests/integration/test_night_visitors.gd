extends TestCase
## Night visitors at camp (F16, data/camp/night_visitors.json): an interrupted night in a risky place brings a fight to
## the camp, and every group is played to the end by the test autopilot at the lowest level it comes for, once per
## seed 1-8: every fight finishes, and the party can win, but pays for it (the owner's standing rule for fights).

var root: Node
const FIELD := "test_night_field"


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
		await _frames(3)
	(Compendium.shared().tables["locations"] as Dictionary).erase(FIELD)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## An open field in `region`, the four at `level`, a camp made in it at night.
func _camp(region: String, level: int) -> LocationCamp:
	var rows: Array = []
	for z in 20:
		rows.append("#".repeat(26) if z == 0 or z == 19 else "#" + ".".repeat(24) + "#")
	Compendium.shared().tables["locations"][FIELD] = {"id": FIELD, "name": "Test Field", "region": region, "summary": "",
		"map": {"rows": rows, "outdoors": true, "theme": "wilderness"}, "spawns": {"default": [12, 10]}, "rest": "risky"}
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.milestones = level - 1
	GameState.story.location = FIELD
	GameState.story.minute_of_day = 22 * 60
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return LocationCamp.pitch(root.get("view") as LocationView, root, "risky")


## A region whose land is `land`.
func _region_of(land: String) -> String:
	var lands := CampSite.visitors()["lands"] as Dictionary
	for region: String in lands:
		if str(lands[region]) == land:
			return region
	return ""


func _group(id: String) -> Dictionary:
	for g: Variant in CampSite.visitors()["groups"]:
		if str((g as Dictionary)["id"]) == id:
			return g as Dictionary
	return {}


## Plays `group` at camp at the lowest level it comes for, with the dice at `seed_value`.
func _play(group: Dictionary, seed_value: int) -> Dictionary:
	var camp := await _camp(_region_of(str(group["land"])), int((group["levels"] as Array)[0]))
	var view := root.get("view") as LocationView
	var taken := {}
	for m: Combatant in view.members:
		taken[m.cell] = true
	var spec := CampSite.fight_for(group, view.grid, camp.center, taken)
	assert_eq((spec.get("monsters", []) as Array).size(), (group["monsters"] as Array).size(), "%s: all of them come" % group["id"])
	Dice.reseed(seed_value)
	assert_true(view.start_custom_encounter(spec), "%s starts" % group["id"])
	await _frames(2)
	var e := view.combat_view.e
	var res := PartyAutopilot.new(e).run(30)
	root.queue_free()
	root = null
	await _frames(2)
	return res


## Plays each of `land`'s groups once per seed 1-8: every fight finishes, and the party wins at least half of them.
func _land(land: String) -> void:
	for g: Variant in CampSite.visitors()["groups"]:
		var group := g as Dictionary
		if str(group["land"]) != land:
			continue
		var wins := 0
		var downs := 0
		var rounds := 0
		for s in range(1, 9):
			var res := await _play(group, s)
			assert_ne(str(res["outcome"]), "timeout", "%s seed %d finished" % [group["id"], s])
			wins += 1 if str(res["outcome"]) == "victory" else 0
			downs += int(res["downs"])
			rounds += int(res["rounds"])
		print("        %s at level %d: %d/8 won, %.1f rounds, %.1f party members dropped per fight" % [group["id"],
			int((group["levels"] as Array)[0]), wins, rounds / 8.0, downs / 8.0])
		assert_true(wins >= 4, "%s can be won at level %d, most nights (%d/8)" % [group["id"], int((group["levels"] as Array)[0]), wins])


func test_an_interrupted_night_at_camp_brings_its_visitors() -> void:
	var camp := await _camp("svalich_road", 2)
	var view := root.get("view") as LocationView
	# A seed whose first d6 (the night's interruption) shows a 1.
	var s := 1
	while DiceRoller.new(s).roll_one(6) != 1:
		s += 1
	Dice.reseed(s)
	camp.sleep()
	await _frames(2)
	assert_true(view.in_combat, "something comes out of the dark")
	assert_false(camp.slept, "nobody slept the night")
	var foes := view.combat_view.e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy")
	assert_eq(foes.size(), (_group("forest_wolves")["monsters"] as Array).size(), "the wolves of the Svalich Woods")
	for c: Combatant in foes:
		assert_true(view.grid.distance_ft(c.cell, 1, camp.center, 1) >= CampSite.DARK_NEAR * 5, "%s comes from the dark" % c.name())


func test_every_land_has_a_group_for_every_level() -> void:
	for land: String in ["forest", "marsh", "mountain", "castle"]:
		for level in range(1, StoryState.LEVEL_CAP + 1):
			assert_false(CampSite.groups_for(_region_of(land), level).is_empty(), "something comes for a level %d camp in the %s" % [level, land])
	assert_eq(CampSite.land_of("nowhere_at_all"), str(CampSite.visitors()["default_land"]), "a region not listed")


func test_the_forests_visitors_are_hard_but_winnable() -> void:
	await _land("forest")


func test_the_marshes_visitors_are_hard_but_winnable() -> void:
	await _land("marsh")


func test_the_mountains_visitors_are_hard_but_winnable() -> void:
	await _land("mountain")


func test_the_castles_visitors_are_hard_but_winnable() -> void:
	await _land("castle")
