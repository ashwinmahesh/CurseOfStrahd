class_name D20Test
extends RefCounted
## Resolves a D20 Test (ability check, saving throw or attack roll) per the 2024 PHB rules glossary:
## - Advantage and Disadvantage don't stack; if you have both, you have neither.
## - A natural 20 on an attack roll is a Critical Hit and hits regardless of modifiers or AC;
##   a natural 1 on an attack roll misses. Checks and saves have no automatic results.
## - Meeting the DC (or AC) succeeds.

enum Kind { ABILITY_CHECK, SAVING_THROW, ATTACK_ROLL }

var kind: Kind
var rolls: Array[int] = []
var kept: int = 0
var modifier: int = 0
var target: int = 0
var advantage: bool = false
var disadvantage: bool = false
var total: int = 0
var success: bool = false
var critical: bool = false
var natural_one: bool = false
var label: String = ""


## `advantage_sources` / `disadvantage_sources` are counts so callers can just add up effects.
static func roll(dice: DiceRoller, kind_: Kind, modifier_: int, target_: int,
		advantage_sources: int = 0, disadvantage_sources: int = 0, label_: String = "") -> D20Test:
	var t := D20Test.new()
	t.kind = kind_
	t.modifier = modifier_
	t.target = target_
	t.label = label_
	var has_adv := advantage_sources > 0
	var has_dis := disadvantage_sources > 0
	t.advantage = has_adv and not has_dis
	t.disadvantage = has_dis and not has_adv
	var reason := label_ if label_ != "" else str(Kind.keys()[kind_])
	if t.advantage or t.disadvantage:
		t.rolls = dice.roll(20, 2, reason)
		t.kept = maxi(t.rolls[0], t.rolls[1]) if t.advantage else mini(t.rolls[0], t.rolls[1])
	else:
		t.rolls = dice.roll(20, 1, reason)
		t.kept = t.rolls[0]
	t._resolve()
	return t


## Resolves an already-known die (for tests and replays).
static func from_natural(kind_: Kind, natural: int, modifier_: int, target_: int) -> D20Test:
	var t := D20Test.new()
	t.kind = kind_
	t.rolls = [natural]
	t.kept = natural
	t.modifier = modifier_
	t.target = target_
	t._resolve()
	return t


func _resolve() -> void:
	total = kept + modifier
	critical = kind == Kind.ATTACK_ROLL and kept == 20
	natural_one = kind == Kind.ATTACK_ROLL and kept == 1
	if critical:
		success = true
	elif natural_one:
		success = false
	else:
		success = total >= target


## Combat-log text, e.g. "Attack: d20 14 + 5 = 19 vs AC 16, hit" (plan §5.3).
func describe() -> String:
	var die := "d20 %d" % kept
	if rolls.size() == 2:
		die = "d20 %s (%d, %d)" % ["adv" if advantage else "dis", rolls[0], rolls[1]]
	var sign := "+" if modifier >= 0 else "-"
	var vs := "AC" if kind == Kind.ATTACK_ROLL else "DC"
	var outcome := "success" if success else "failure"
	if kind == Kind.ATTACK_ROLL:
		outcome = "critical hit" if critical else ("hit" if success else "miss")
	var name: String = label if label != "" else ["Check", "Save", "Attack"][kind]
	return "%s: %s %s %d = %d vs %s %d, %s" % [name, die, sign, absi(modifier), total, vs, target, outcome]
