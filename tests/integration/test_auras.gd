extends TestCase
## Auras round figures (world/look/aura_fx.gd, owner 2026-10-09): Strahd's dark aura, which surges when he acts, and a
## paladin's Aura of Protection: the area it covers on the floor in fights only, with no glow round the figure (owner,
## 2026-10-12).

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


func test_a_paladins_aura_shows_on_the_floor_once_they_have_aura_of_protection() -> void:
	assert_true(_token(TestChars.pregen("godrick_pendlebrook", 5), &"party").aura == null, "no aura before level 6")
	assert_true(_token(TestChars.pregen("ilse_varga", 6), &"party").aura == null, "a fighter has none")
	var tok := _token(TestChars.pregen("godrick_pendlebrook", 6), &"party")
	assert_true(tok.aura != null)
	if tok.aura == null:
		return
	assert_eq(tok.aura.style, AuraFx.Style.HOLY)
	assert_eq(tok.aura.reach, 2, "10 ft is two squares")
	var plane := tok.aura.floor_area.mesh as PlaneMesh
	assert_eq(plane.size, Vector2(5, 5), "his square and two more every way")
	var corner := float((tok.aura.floor_area.material_override as ShaderMaterial).get_shader_parameter("corner"))
	assert_between(corner, 0.799, 0.801, "rounded by the whole reach: round, not a square")


func test_no_glow_round_the_paladin_himself() -> void:
	# The owner wanted the glow round the paladin's sprite gone, not the area on the floor (2026-10-12).
	var tok := _token(TestChars.pregen("godrick_pendlebrook", 6), &"party")
	assert_true(tok.aura.halo == null, "no glow round the figure")
	assert_eq(tok.aura.find_children("*", "MeshInstance3D", false, false).size(), 1, "only the area on the floor")


func test_the_paladins_area_shows_in_fights_only() -> void:
	var tok := _token(TestChars.pregen("godrick_pendlebrook", 6), &"party")
	ModeController.mode = ModeController.Mode.EXPLORATION
	tok.call("_process", 0.016)
	assert_false(tok.aura.is_showing_area(), "nothing while exploring")
	ModeController.mode = ModeController.Mode.COMBAT
	tok.call("_process", 0.016)
	assert_true(tok.aura.is_showing_area(), "in a fight the floor shows who it covers")
	tok.combatant.creature.add_condition(&"incapacitated", "test")
	tok.refresh()
	assert_false(tok.aura.is_showing_area(), "an Incapacitated paladin's aura is down")


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
