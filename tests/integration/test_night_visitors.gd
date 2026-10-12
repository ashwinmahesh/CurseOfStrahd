extends TestCase
## Night visitors at camp (F16, data/camp/night_visitors.json): an interrupted night in a risky place brings a fight to
## the camp, and every group is played to the end by the test autopilot at the lowest level it comes for, once per
## seed 1-8, with the party as it really is then: a day's adventuring behind it and only the interrupted hour's Short
## Rest benefits. Every fight finishes, and each group is hard but winnable (the owner's standing rule, and his
## 2026-10-12 word on easy fights): won at least twice in eight and lost at least twice.

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
		_tired(ch)
		GameState.story.party.append(ch)
	GameState.story.milestones = level - 1
	GameState.story.location = FIELD
	GameState.story.minute_of_day = 22 * 60
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return LocationCamp.pitch(root.get("view") as LocationView, root, "risky")


## A hero as the night's visitors find them: a day's adventuring behind them (half their Hit Points and half of each
## level's spell slots spent), then the interrupted hour's Short Rest benefits (LongRest.take).
static func _tired(ch: Character) -> void:
	ch.hp = maxi(1, ch.max_hp() / 2)
	var slots := ch.spell_slots()
	for i in slots.size():
		for n in slots[i] / 2:
			ch.expend_slot(i + 1)
	ch.finish_short_rest()


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


## Plays each of `land`'s groups once per seed 1-8: every fight finishes, and each is won at least twice and lost at
## least twice.
func _land(land: String) -> void:
	for g: Variant in CampSite.visitors()["groups"]:
		var group := g as Dictionary
		if str(group["land"]) != land:
			continue
		var level := int((group["levels"] as Array)[0])
		var wins := 0
		var won_downs := 0
		var rounds := 0
		for s in range(1, 9):
			var res := await _play(group, s)
			assert_ne(str(res["outcome"]), "timeout", "%s seed %d finished" % [group["id"], s])
			if str(res["outcome"]) == "victory":
				wins += 1
				won_downs += int(res["downs"])
			rounds += int(res["rounds"])
		print("        %s at level %d: %d/8 won, %.1f rounds, %.1f heroes dropped per win" % [group["id"], level, wins,
			rounds / 8.0, won_downs / float(maxi(1, wins))])
		assert_true(wins >= 2, "%s is won at least twice in 8 at level %d (%d)" % [group["id"], level, wins])
		assert_true(wins <= 6, "%s is lost at least twice in 8 at level %d (%d)" % [group["id"], level, wins])


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
