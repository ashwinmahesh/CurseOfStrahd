class_name Abilities
extends RefCounted
## The six abilities and the math every other rule builds on (2024 PHB, "Ability Scores and
## Modifiers" and "Proficiency Bonus").

const STR := &"str"
const DEX := &"dex"
const CON := &"con"
const INT := &"int"
const WIS := &"wis"
const CHA := &"cha"
const ALL: Array[StringName] = [STR, DEX, CON, INT, WIS, CHA]

## 2024 PHB skill list (18 skills) and their default abilities.
const SKILLS := {
	&"acrobatics": DEX, &"animal_handling": WIS, &"arcana": INT, &"athletics": STR,
	&"deception": CHA, &"history": INT, &"insight": WIS, &"intimidation": CHA,
	&"investigation": INT, &"medicine": WIS, &"nature": INT, &"perception": WIS,
	&"performance": CHA, &"persuasion": CHA, &"religion": INT, &"sleight_of_hand": DEX,
	&"stealth": DEX, &"survival": WIS,
}

const MAX_SCORE := 30


## Modifier = (score - 10) / 2, rounded down. Score 1 -> -5, 10 -> +0, 30 -> +10.
static func modifier(score: int) -> int:
	return floori((score - 10) / 2.0)


## Proficiency bonus by total character level (or CR for monsters, via proficiency_for_cr).
static func proficiency_bonus(level: int) -> int:
	assert(level >= 1)
	return 2 + floori((level - 1) / 4.0)


## Monsters: CR 0-4 -> +2, 5-8 -> +3 ... 29-30 -> +9. CR below 1 counts as 1.
static func proficiency_for_cr(cr: float) -> int:
	return proficiency_bonus(maxi(1, ceili(cr)))


## Passive score = 10 + all modifiers that apply to the check, +5 for advantage, -5 for
## disadvantage (2024 PHB "Passive Perception").
static func passive_score(check_bonus: int, advantage: bool = false, disadvantage: bool = false) -> int:
	var bonus := 0
	if advantage and not disadvantage:
		bonus = 5
	elif disadvantage and not advantage:
		bonus = -5
	return 10 + check_bonus + bonus
