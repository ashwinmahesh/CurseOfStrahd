extends TestCase
## Wards and rests (Ashwin's answer to the spell audit, 2026-10-12; story/wards.gd, combat/magic_circle.gd): Leomund's
## Tiny Hut and Guards and Wards shelter a Long Rest from the building's enemies, the wards keep a rest from being
## interrupted (Alarm warns instead), Hallow and Nondetection keep Strahd's visits that can wait away, Heroes' Feast
## hardens the party for a day, and Magic Circle stands around its caster in the next fight.

## A keep: a hall and a cellar indoors, joined by stairs. Rats wait in the cellar (as test_rest_rules).
const KEEP := {
	"test_ward_hall": {"id": "test_ward_hall", "name": "Ward Hall", "region": "test", "summary": "", "rest": "risky",
		"map": {"rows": ["#####", "#...#", "#####"]}, "spawns": {"default": [1, 1]},
		"exits": [{"id": "down", "cell": [3, 1], "to": "test_ward_cellar", "spawn": "default"}]},
	"test_ward_cellar": {"id": "test_ward_cellar", "name": "Ward Cellar", "region": "test", "summary": "", "rest": "risky",
		"map": {"rows": ["#####", "#...#", "#####"]}, "spawns": {"default": [1, 1]},
		"exits": [{"id": "up", "cell": [3, 1], "to": "test_ward_hall", "spawn": "default"}],
		"encounters": [{"id": "rats", "trigger": "enter_area:cellar", "monsters": [{"monster": "zombie", "cell": [2, 1]}]}]},
}


func before_each() -> void:
	for id: String in KEEP:
		Compendium.shared().tables["locations"][id] = (KEEP[id] as Dictionary).duplicate(true)
	StrahdPresence.use({})


func after_each() -> void:
	for id: String in KEEP:
		(Compendium.shared().tables["locations"] as Dictionary).erase(id)
	StrahdPresence.use({})


## A caster at `level` who prepares `spells` and carries their components, at `location`.
func _party(spells: Array, location: String, level: int = 11, cls: String = "wizard") -> StoryState:
	var st := StoryState.new()
	var ch := TestChars.custom(cls, "human", level)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for s: Variant in spells:
		if not str(s) in prepared:
			prepared.append(str(s))
	TestCombat.give_components(ch, spells)
	ch.finish_long_rest()
	st.party.append(ch)
	st.party.append(TestChars.pregen("ilse_varga", 9))
	st.location = location
	st.minute_of_day = 20 * 60
	return st


func _cast(st: StoryState, spell_id: String, ritual: bool = false) -> void:
	var res := FieldCasting.cast_utility(st, st.party[0], spell_id, ritual)
	assert_true(bool(res["ok"]), "%s: %s" % [spell_id, res["text"]])


func test_a_tiny_hut_shelters_a_long_rest_from_the_buildings_enemies() -> void:
	var st := _party(["leomunds_tiny_hut"], "test_ward_hall")
	assert_false(RestRules.long_rest_refusals(st).is_empty(), "rats in the cellar")
	_cast(st, "leomunds_tiny_hut", true)
	assert_eq(RestRules.long_rest_refusals(st), [] as Array[String])
	assert_eq(Wards.keeps_rest(st), "Leomund's Tiny Hut", "and nothing interrupts it")
	st.location = "test_ward_cellar"
	assert_eq(Wards.shelter(st), "", "the hut stands where it was cast")


func test_guards_and_wards_covers_the_whole_building() -> void:
	var st := _party(["guards_and_wards"], "test_ward_cellar")
	_cast(st, "guards_and_wards")
	st.location = "test_ward_hall"
	assert_eq(RestRules.long_rest_refusals(st), [] as Array[String], "another floor of the same building")
	assert_eq(Wards.keeps_rest(st), "Guards and Wards")
	st.advance_minutes(25 * 60)
	assert_false(RestRules.long_rest_refusals(st).is_empty(), "a day later the wards are gone")


func test_alarm_warns_without_sheltering() -> void:
	var st := _party(["alarm"], "test_ward_hall", 3)
	_cast(st, "alarm", true)
	assert_true(Wards.alarmed(st))
	assert_eq(Wards.keeps_rest(st), "", "a warning, not a wall")
	assert_false(RestRules.long_rest_refusals(st).is_empty(), "the rats still stop a Long Rest")


func test_hallow_keeps_strahds_night_visit_away_for_good() -> void:
	var st := _party(["hallow"], "vallaki_blue_water_inn", 11, "cleric")
	st.set_flag("strahd_watcher_seen", true)
	st.day = 4
	var inn := {"location": "vallaki_blue_water_inn", "night": true}
	_cast(st, "hallow")
	assert_true(Wards.active_at(st, "hallow", "vallaki_blue_water_inn"))
	assert_eq(Wards.keeps_rest(st), "Hallow")
	assert_true(StrahdPresence.due(st, "rest", inn).is_empty(), "no night visit on hallowed ground")
	st.advance_minutes(60 * 24 * 60)
	assert_true(Wards.active_at(st, "hallow", "vallaki_blue_water_inn"), "until dispelled")
	st.location = "vallaki"
	assert_eq(Wards.keeps_rest(st), "", "only the place it was cast in")


func test_nondetection_hides_the_party_for_eight_hours() -> void:
	var st := _party(["nondetection"], "vallaki_blue_water_inn", 5)
	st.set_flag("strahd_watcher_seen", true)
	st.day = 4
	var inn := {"location": "vallaki_blue_water_inn", "night": true}
	_cast(st, "nondetection")
	assert_true(StrahdPresence.due(st, "rest", inn).is_empty(), "Strahd's eyes can't find them")
	st.advance_minutes(9 * 60)
	assert_eq(str(StrahdPresence.due(st, "rest", inn).get("id", "")), "night_visit", "once it's run out, he comes")


func test_heroes_feast_hardens_the_party_for_a_day() -> void:
	var st := _party(["heroes_feast"], "vallaki", 11, "cleric")
	st.gold = 1200.0
	var fighter := st.party[1]
	var max_before := fighter.max_hp()
	_cast(st, "heroes_feast")
	assert_eq(roundi(st.gold), 200, "the bowl, from the purse")
	assert_true(fighter.max_hp() >= max_before + 2, "2d10 more Hit Points at most: %d -> %d" % [max_before, fighter.max_hp()])
	assert_true(fighter.is_condition_immune(&"frightened") and fighter.is_condition_immune(&"poisoned"))
	assert_true(fighter.modifiers_for(&"advantage").any(func(m: Modifier) -> bool: return m.text("on") == "save:wis"))
	st.advance_minutes(25 * 60)
	assert_eq(fighter.max_hp(), max_before, "a day later it's over")
	st.gold = 10.0
	assert_false(bool(FieldCasting.cast_utility(st, st.party[0], "heroes_feast", false)["ok"]), "no bowl without the gold")


func test_magic_circle_stands_in_the_next_fight_here() -> void:
	var st := _party(["magic_circle"], "test_ward_hall", 7, "cleric")
	_cast(st, "magic_circle")
	var e := TestCombat.open_field()
	var cleric := e.add(st.party[0], &"party", Vector2i(5, 4))
	var z := TestCombat.foe(e, "zombie", Vector2i(10, 4))
	var b := TestCombat.foe(e, "bandit", Vector2i(10, 2))
	Wards.bring_circle(e, st, "test_ward_hall")
	assert_true(e.spells.zones.live().any(func(o: FieldObject) -> bool: return o.spell_id == "magic_circle"))
	assert_true(MagicCircle.blocks(e, z).has(Vector2i(6, 4)), "the undead can't step in")
	assert_true(MagicCircle.blocks(e, b).is_empty(), "a living bandit can")
	assert_true(MagicCircle.shields(e, z, cleric), "its attacks on those inside are at Disadvantage")
	assert_false(MagicCircle.shields(e, b, cleric))
	var e2 := TestCombat.open_field()
	e2.add(st.party[0], &"party", Vector2i(5, 4))
	Wards.bring_circle(e2, st, "test_ward_cellar")
	assert_false(e2.spells.zones.live().any(func(o: FieldObject) -> bool: return o.spell_id == "magic_circle"), "only where it was cast")
	st.advance_minutes(61)
	var e3 := TestCombat.open_field()
	e3.add(st.party[0], &"party", Vector2i(5, 4))
	Wards.bring_circle(e3, st, "test_ward_hall")
	assert_false(e3.spells.zones.live().any(func(o: FieldObject) -> bool: return o.spell_id == "magic_circle"), "an hour later it's gone")
