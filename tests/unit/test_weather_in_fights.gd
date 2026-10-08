extends TestCase
## Weather in fights (F12's fight half): a storm in the open feeds Call Lightning (+1d10) and puts out burning
## creatures; fog and storms Lightly Obscure the field, so a Search has Disadvantage, as dim light out of Darkvision's
## reach does.


const STORM := {"label": "Storm", "obscures": true, "flames_out": true}
const FOG := {"label": "Fog", "obscures": true}


func _weather(e: Encounter, id: String, kind: Dictionary, outdoors: bool = true) -> void:
	e.outdoors = outdoors
	e.weather_id = id
	e.weather = kind.duplicate()


func test_call_lightning_takes_control_of_a_storm() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.high_caster(e, ["call_lightning"], Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	var spell := Compendium.shared().spell_data("call_lightning")
	assert_eq(e.spells.damage._damage_dice({"s": spell, "c": c, "slot": 3}), "3d10", "no storm overhead")
	_weather(e, "storm", STORM, false)
	assert_eq(e.spells.damage._damage_dice({"s": spell, "c": c, "slot": 3}), "3d10", "a storm outside doesn't reach in")
	_weather(e, "storm", STORM)
	assert_eq(e.spells.damage._damage_dice({"s": spell, "c": c, "slot": 4}), "5d10", "upcast, and 1d10 more")
	var r := e.spells.cast(c, "call_lightning", 3, [], e.center_of(bag))
	assert_true(r.ok, r.reason)
	assert_true(e.log.dump().contains("Call Lightning 4d10"), "the bolt rolls 4d10")
	_weather(e, "blizzard", {"label": "Blizzard", "obscures": true, "flames_out": true})
	assert_true(e.stormy(), "a blizzard is a storm too")
	_weather(e, "fog", FOG)
	assert_false(e.stormy())


func test_a_storm_puts_out_a_burning_creature() -> void:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, bag)
	e.monster_actions.set_burning(bag, ilse)
	_weather(e, "storm", STORM)
	var hp := ilse.creature.hp
	while e.current() != ilse:
		e.end_turn()
	assert_eq(ilse.creature.hp, hp, "no Fire damage at the start of its turn")
	assert_false(ilse.creature.effects.any(func(fx: Effect) -> bool: return bool(fx.data.get("douse", false))), "the flames are out")
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("The storm puts out the flames on")))


func test_a_burning_creature_keeps_burning_in_fog_or_indoors() -> void:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, bag)
	e.monster_actions.set_burning(bag, ilse)
	_weather(e, "fog", FOG)
	var hp := ilse.creature.hp
	while e.current() != ilse:
		e.end_turn()
	assert_true(ilse.creature.hp < hp, "fog doesn't put flames out")


func test_fog_storms_and_dim_light_make_a_search_harder() -> void:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var silvain := TestCombat.hero(e, "silvain_aster", Vector2i(2, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, ilse)
	assert_eq(e.actions._hard_to_spot(ilse, foe), "", "open daylight")
	_weather(e, "fog", FOG)
	assert_eq(e.actions._hard_to_spot(ilse, foe), "Fog", "Lightly Obscured by the fog")
	_weather(e, "fog", FOG, false)
	assert_eq(e.actions._hard_to_spot(ilse, foe), "", "the fog stays outside")
	e.ambient_light = "dim"
	assert_eq(e.actions._hard_to_spot(ilse, foe), "Dim light")
	if silvain.creature.darkvision() >= e.distance(silvain, foe):
		assert_eq(e.actions._hard_to_spot(silvain, foe), "", "Darkvision sees dim light as bright")
	foe.hidden = true
	foe.stealth_total = 30
	_weather(e, "storm", STORM)
	assert_true(e.search(ilse).ok)
	var entry := e.log.last(1)[0]
	assert_eq((entry["details"] as Array).size(), 2, "a second roll, with Disadvantage, for the creature in the storm")
	assert_true(str((entry["details"] as Array)[1]).contains("Storm"), str(entry["details"]))
