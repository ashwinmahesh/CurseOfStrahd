class_name EncounterGrapples
extends RefCounted
## Grapple and Shove in a fight (Encounter, 2024): the Unarmed Strike's special modes, escaping a grapple, and
## letting go when the grappler can't hold on.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## Grapple or Shove with an Unarmed Strike as one attack of the Attack action (2024): the target makes a Strength
## or Dexterity save (its choice: the better one) against 8 + Str modifier + PB; it can be at most one size larger.
func unarmed_special(c: Combatant, target: Combatant, mode: String) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	if target == null or e.distance(c, target) > 5:
		return CombatResult.fail("Target must be within 5 ft")
	if Creature.SIZES.find(target.creature.size) > Creature.SIZES.find(c.creature.size) + 1:
		return CombatResult.fail("Target is more than one size larger")
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		e.spend_action(c)
		c.took_attack_action = true
		c.attacks_left = e.attacks_per_action(c) - 1
	else:
		return CombatResult.fail("No attacks left this turn")
	var dc := 8 + c.creature.ability_mod(&"str") + c.creature.proficiency_bonus()
	var ab := &"str" if target.creature.save_bonus(&"str").total() >= target.creature.save_bonus(&"dex").total() else &"dex"
	var s := target.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], mode.capitalize(), target.name()])
	var r := CombatResult.new()
	if s.success:
		e.log.add("info", "%s resists %s's %s" % [target.name(), c.name(), mode], c.id, [s.describe()])
		return r
	match mode:
		"grapple":
			target.creature.add_condition(&"grappled", c.name())
			e.grapples[target.id] = c.id
			e.log.add("condition", "%s grapples %s (escape DC %d)" % [c.name(), target.name(), dc], c.id, [s.describe()])
		"shove_prone":
			target.creature.add_condition(&"prone", "Shove")
			e.log.add("condition", "%s shoves %s Prone" % [c.name(), target.name()], c.id, [s.describe()])
		_:
			var moved := e.forced_move(target, e.center_of(c), 5)
			e.log.add("info", "%s shoves %s %d ft" % [c.name(), target.name(), moved * 5], c.id, [s.describe()])
	return r


## Escaping a grapple (2024): an action and a Strength (Athletics) or Dexterity (Acrobatics) check against the
## escape DC.
func escape_grapple(c: Combatant) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not e.grapples.has(c.id):
		return CombatResult.fail("Not grappled")
	e.spend_action(c)
	var grappler := e.get_c(str(e.grapples[c.id]))
	var dc := 8 + grappler.creature.ability_mod(&"str") + grappler.creature.proficiency_bonus() if grappler != null else 10
	if c.has_meta("escape_dc"):
		dc = int(c.get_meta("escape_dc"))
	var skill := &"athletics" if c.creature.skill_bonus(&"athletics").total() >= c.creature.skill_bonus(&"acrobatics").total() else &"acrobatics"
	var t := c.creature.roll_check(e.dice, skill, dc)
	if t.success:
		e.grapples.erase(c.id)
		c.creature.remove_condition(&"grappled")
		c.remove_meta("escape_dc")
		e.monster_actions.release_engulf(c)
		e.log.add("info", "%s breaks free" % c.name(), c.id, [t.describe()])
	else:
		e.log.add("info", "%s struggles but stays Grappled" % c.name(), c.id, [t.describe()])
	return CombatResult.new()


func _release_grapples_by(grappler: Combatant) -> void:
	var e := enc()
	for k: String in e.grapples.keys():
		if str(e.grapples[k]) == grappler.id:
			e.grapples.erase(k)
			var t := e.get_c(k)
			if t != null:
				t.creature.remove_condition(&"grappled")
				if t.has_meta("escape_dc"):
					t.remove_meta("escape_dc")
				e.monster_actions.release_engulf(t)
