class_name CheckAids
extends RefCounted
## What a character can spend after failing an ability check outside a fight (2024 PHB): Heroic Inspiration rerolls
## the d20 and keeps the new roll; Tactical Mind (Fighter 2) spends a use of Second Wind to add 1d10, and the use
## isn't spent if the check still fails. Offered by conversations after a failed check (the player decides).
## Helpful Friend (Familiar Friend) works before a check instead (`before_check`), so it never reopens a failed one.


## [{id, label}] for a failed check `test` by `ch`.
static func options(ch: Character, test: D20Test) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if ch == null or test == null or test.success:
		return out
	if ch.heroic_inspiration:
		out.append({"id": "heroic_inspiration", "label": "Heroic Inspiration: reroll the d20"})
	if _has_feature(ch, "tactical_mind") and ch.resource_left("second_wind") > 0:
		out.append({"id": "tactical_mind", "label": "Tactical Mind: add 1d10 (a Second Wind use, kept if it still fails)"})
	return out


## Applies aid `id` to `test` (in place) and returns it.
static func apply(id: String, ch: Character, test: D20Test, dice: DiceRoller) -> D20Test:
	match id:
		"heroic_inspiration":
			if ch.heroic_inspiration:
				ch.heroic_inspiration = false
				var n := dice.d20("Heroic Inspiration reroll (%s)" % ch.name)
				test.set_natural(n, "Heroic Inspiration")
		"tactical_mind":
			if ch.resource_left("second_wind") > 0:
				var r := int(dice.roll_expr("1d10", "Tactical Mind (%s)" % ch.name)["total"])
				test.add_bonus(r, "Tactical Mind")
				if test.success:
					ch.spend_resource("second_wind")
	return test


## Advantage sources for a check `cr` is about to make outside a fight with `skill`: Helpful Friend (Familiar
## Friend) when the skill is one it's proficient in and a use is left, spending the use; its familiar is taken to be
## at its side.
static func before_check(cr: Creature, skill: StringName) -> Array[String]:
	var out: Array[String] = []
	var ch := cr as Character if cr is Character else null
	if ch == null or ch.resource_left("helpful_friend") <= 0 or not Abilities.SKILLS.has(skill) or ch.skill_rank(skill) < 1:
		return out
	if not ch.feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "familiar_friend"):
		return out
	ch.spend_resource("helpful_friend")
	out.append("Helpful Friend")
	return out


static func _has_feature(ch: Character, feature_id: String) -> bool:
	for f in ch.features:
		if str(f.get("id", "")) == feature_id:
			return true
	return false
