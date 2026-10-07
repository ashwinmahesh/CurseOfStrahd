class_name LocationStealth
extends RefCounted
## Sneaking in a location (LocationView): the party crouches while it sneaks, and a sneaking party whose every
## Stealth check beats a foe's passive Perception surprises it when a fight starts.


## The party crouches while sneaking (CombatToken.sneaking; sprites with the fuller animation set show it).
static func show_crouch(view: LocationView) -> void:
	if view.sneaking == view._shown_sneaking:
		return
	view._shown_sneaking = view.sneaking
	for m: Combatant in view.members + view.guest_members:
		if view.tokens.has(m.id):
			(view.tokens[m.id] as CombatToken).sneaking = view.sneaking
			(view.tokens[m.id] as CombatToken).refresh()




## Surprise: a sneaking party whose every Stealth check beats a foe's passive Perception surprises it.
static func _stealth_surprise(view: LocationView, e: Encounter) -> Array[String]:
	var lowest := 1000
	for m in view.members:
		if m.creature.hp > 0:
			var t := m.creature.roll_check(view.dice, &"stealth", 0, CheckAids.before_check(m.creature, &"stealth"))
			lowest = mini(lowest, t.total)
			view.check_rolled.emit(t.describe())
	var out: Array[String] = []
	for c in e.combatants:
		if c.side == &"enemy" and c.creature.passive_score(&"perception").total() < lowest:
			out.append(c.id)
	return out
