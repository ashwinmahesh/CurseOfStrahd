extends TestCase
## Auras round figures (world/look/aura_fx.gd, owner 2026-10-09): Strahd's dark aura, which surges when he acts. A
## paladin's Aura of Protection draws nothing (owner, 2026-10-12).

var _made: Array[Node] = []
var _was: ModeController.Mode


func before_each() -> void:
	_was = ModeController.mode


func after_each() -> void:
	ModeController.mode = _was
	for n in _made:
		n.queue_free()
	_made.clear()


func _token(cr: Creature, side: StringName, art: String = "") -> CombatToken:
	var tok := CombatToken.create(Combatant.new(cr, side, Vector2i(3, 3)), art)
	add_child(tok)
	_made.append(tok)
	return tok


func _strahd() -> CombatToken:
	return _token(Monster.from_data(Compendium.shared().monster_data("strahd_von_zarovich")), &"enemy")


func test_strahd_wears_the_dark_aura_and_it_surges_when_he_acts() -> void:
	var tok := _strahd()
	assert_true(tok.aura != null, "Strahd has an aura")
	if tok.aura == null:
		return
	assert_eq(tok.aura.style, AuraFx.Style.DARK)
	assert_true(tok.aura.halo.visible and tok.aura.floor_area.visible, "smoke round him and shadow under him")
	tok.start_attack(Vector2(1, 0))
	assert_eq(float(tok.aura.get("_surge")), 1.0, "an attack swells it")
	tok.aura.call("_process", 0.4)
	assert_true(float(tok.aura.get("_surge")) < 1.0 and float(tok.aura.get("_surge")) > 0.0, "and it dies back")
	tok.combatant.creature.hp = 0
	tok.refresh()
	assert_false(tok.aura.halo.visible, "gone when he drops")


func test_only_strahds_own_sprite_has_it() -> void:
	assert_true(_token(Monster.from_data(Compendium.shared().monster_data("vampire_spawn")), &"enemy").aura == null)
	var staged := _token(Monster.from_data(Compendium.shared().monster_data("commoner")), &"neutral", "strahd")
	assert_true(staged.aura != null, "Strahd staged in a scene (his look on another block) has it too")


func test_a_paladins_aura_of_protection_draws_nothing() -> void:
	# The owner had the paladin's glow and the area on the floor taken off (2026-10-12); the save bonus stays.
	var tok := _token(TestChars.pregen("godrick_pendlebrook", 6), &"party")
	assert_true(ClassFeatures.has(tok.combatant, "aura_of_protection"), "he has the aura")
	assert_true(tok.aura == null, "but no glow round him, and no area on the floor")
	assert_eq(tok.find_children("Aura", "", true, false).size(), 0)


## "Slowed" over a creature whose Speed a spell or effect cut (owner, 2026-10-12): Ray of Frost's minus, the Slow
## spell's half; nothing for an untouched creature.
func test_slowed_shows_over_a_creature_whose_speed_is_cut() -> void:
	var tok := _token(Monster.from_data(Compendium.shared().monster_data("zombie")), &"enemy")
	assert_false(str((tok.get("_status") as Label3D).text).contains("Slowed"), "nothing yet")
	var frost := Effect.new("Ray of Frost", &"spell", "ray_of_frost").with_modifier("speed", {"value": -10})
	tok.combatant.creature.add_effect(frost)
	tok.refresh()
	assert_true(str((tok.get("_status") as Label3D).text).contains("Slowed"), "Ray of Frost's minus 10 ft")
	tok.combatant.creature.remove_effect(frost)
	tok.combatant.creature.add_effect(Effect.new("Slow", &"spell", "slow").with_modifier("speed_percent", {"value": 50}))
	tok.refresh()
	assert_true(str((tok.get("_status") as Label3D).text).contains("Slowed"), "the Slow spell's half")
