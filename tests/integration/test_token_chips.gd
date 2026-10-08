extends TestCase
## The conditions over a figure (CombatToken's chips), owner report 2026-10-07: a sleeper reads "Asleep" rather than
## the Unconscious and Incapacitated its sleep carries, and the chips sit just above a figure lying down instead of
## floating at standing height.

var tok: CombatToken


func before_each() -> void:
	var m := Monster.from_data(Compendium.shared().monster_data("night_hag"))
	tok = CombatToken.create(Combatant.new(m, &"neutral", Vector2i(2, 2)), "offalia_wormwiggle")
	add_child(tok)


func after_each() -> void:
	tok.queue_free()


func _chips() -> String:
	return (tok.get("_status") as Label3D).text


func _chip_height() -> float:
	return (tok.get("_status") as Label3D).position.y


func test_a_sleeper_reads_asleep_and_its_chips_come_down_with_it() -> void:
	var standing := _chip_height()
	var cr := tok.combatant.creature
	var nap := Effect.new("Sleep", &"spell", "sleep").with_condition(&"unconscious")
	nap.data = {"wakeable": true}
	cr.add_effect(nap)
	tok.refresh()
	assert_eq(_chips(), "Asleep · Prone", "one Asleep chip, not Unconscious · Incapacitated")
	assert_true(_chip_height() < standing - 0.4, "the chips sit over the figure lying down (%s vs %s)" % [_chip_height(), standing])
	cr.remove_effect(nap)
	cr.add_condition(&"prone", "woke on the floor")
	tok.refresh()
	assert_eq(_chips(), "Prone")
	cr.remove_condition(&"prone")
	tok.refresh()
	assert_eq(_chips(), "")
	assert_eq(_chip_height(), standing, "standing again, the chips go back up")


func test_an_entranced_creature_is_not_called_asleep() -> void:
	var cr := tok.combatant.creature
	var trance := Effect.new("Hypnotic Pattern", &"spell", "hypnotic_pattern").with_condition(&"charmed").with_condition(&"incapacitated")
	trance.data = {"wakeable": true}
	cr.add_effect(trance)
	tok.refresh()
	assert_false(_chips().contains("Asleep"), _chips())
	assert_true(_chips().contains("Incapacitated"), _chips())
