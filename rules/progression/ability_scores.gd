class_name AbilityScores
extends RefCounted
## The three 2024 ways to generate ability scores (PHB "Step 3: Determine Ability Scores"): the Standard
## Array, 27-point Point Cost, and Random Generation (4d6, drop the lowest, six times).

const STANDARD_ARRAY: Array[int] = [15, 14, 13, 12, 10, 8]
const POINT_COSTS := {8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9}
const POINT_BUDGET := 27
const METHODS: Array[String] = ["standard_array", "point_buy", "roll", "manual"]


static func point_cost(scores: Dictionary) -> int:
	var total := 0
	for ab: StringName in Abilities.ALL:
		var v := int(scores.get(str(ab), 8))
		total += int(POINT_COSTS.get(v, 99))
	return total


## Rolls 4d6 and keeps the highest three, six times, through the seeded dice.
## Returns [{total, rolls, dropped}].
static func roll_set(dice: DiceRoller) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in 6:
		var rolls := dice.roll(6, 4, "Ability score %d (4d6 drop lowest)" % (i + 1))
		var sorted := rolls.duplicate()
		sorted.sort()
		var dropped := int(sorted[0])
		out.append({"total": int(sorted[1]) + int(sorted[2]) + int(sorted[3]), "rolls": rolls, "dropped": dropped})
	return out


## Problems with a set of base scores for a method. `pool` is the rolled totals for "roll".
static func problems(method: String, scores: Dictionary, pool: Array = []) -> Array[String]:
	var out: Array[String] = []
	var values: Array[int] = []
	for ab: StringName in Abilities.ALL:
		if not scores.has(str(ab)):
			out.append("%s has no score yet." % Creature.ABILITY_NAMES[ab])
			continue
		values.append(int(scores[str(ab)]))
	if not out.is_empty():
		return out
	match method:
		"standard_array":
			var want := STANDARD_ARRAY.duplicate()
			want.sort()
			var got := values.duplicate()
			got.sort()
			if got != want:
				out.append("Standard Array: use 15, 14, 13, 12, 10 and 8 once each.")
		"point_buy":
			for v in values:
				if v < 8 or v > 15:
					out.append("Point Cost: every score must be between 8 and 15.")
					break
			if out.is_empty():
				var cost := point_cost(scores)
				if cost > POINT_BUDGET:
					out.append("Point Cost: %d points spent, only %d available." % [cost, POINT_BUDGET])
		"roll":
			var want2: Array[int] = []
			for p: Variant in pool:
				want2.append(int(p))
			want2.sort()
			var got2 := values.duplicate()
			got2.sort()
			if want2.size() != 6:
				out.append("Roll your six scores first.")
			elif got2 != want2:
				out.append("Random Generation: assign each rolled score once.")
		"manual":
			for v in values:
				if v < 3 or v > 18:
					out.append("Scores must be between 3 and 18.")
					break
	return out


## Puts the six values in a class's recommended order (highest where the class's Standard Array suggestion
## is highest). Works for the Standard Array and for rolled sets.
static func recommended(class_data: Dictionary, values: Array[int] = STANDARD_ARRAY) -> Dictionary:
	var rec := (class_data.get("recommended", {}) as Dictionary).get("standard_array", {}) as Dictionary
	if rec.is_empty():
		rec = {"str": 15, "dex": 14, "con": 13, "int": 12, "wis": 10, "cha": 8}
	var order: Array[String] = []
	for ab: String in rec:
		order.append(ab)
	order.sort_custom(func(a: String, b: String) -> bool: return int(rec[a]) > int(rec[b]))
	var sorted := values.duplicate()
	sorted.sort()
	sorted.reverse()
	var out := {}
	for i in order.size():
		out[order[i]] = sorted[i]
	return out
