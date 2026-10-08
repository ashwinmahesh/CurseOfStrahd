class_name D20Test
extends RefCounted
## Resolves a D20 Test (ability check, saving throw or attack roll) per the 2024 PHB rules glossary:
## - Advantage and Disadvantage don't stack; if you have both, you have neither.
## - A natural 20 on an attack roll is a Critical Hit and hits regardless of modifiers or AC;
##   a natural 1 on an attack roll misses. Checks and saves have no automatic results.
## - Meeting the DC (or AC) succeeds.
## Creature.roll_* builds these with a Breakdown of the modifier, the named sources of Advantage and
## Disadvantage, and any bonus dice (Bless), so the combat log can explain every roll.

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
## Lowest natural roll that is a Critical Hit (Improved Critical: 19). Attack rolls only.
var crit_range: int = 20
## Bonus or penalty dice already rolled (Bless +1d4, Bane -1d4): total and text like "Bless 3".
var extra: int = 0
var extra_label: String = ""
## Where the modifier came from, and why Advantage / Disadvantage applied.
var breakdown: Breakdown = null
var advantage_sources: Array[String] = []
var disadvantage_sources: Array[String] = []
## Automatic failure (Paralyzed and a Dexterity save): no die is rolled.
var auto_failed: bool = false
var auto_fail_reason: String = ""
## Text for a d20 that was rolled again (Halfling Luck): "Luck: 1 → 14".
var reroll_note: String = ""
## The choices that follow this roll wait for the player's answer (a Concentration save asked once the attack or
## spell that caused it is done): whoever rolled it doesn't act on the result yet.
var awaiting: bool = false


## `advantage_sources` / `disadvantage_sources` are counts so callers can just add up effects.
static func roll(dice: DiceRoller, kind_: Kind, modifier_: int, target_: int,
		advantage_sources_: int = 0, disadvantage_sources_: int = 0, label_: String = "",
		crit_range_: int = 20, extra_: int = 0, extra_label_: String = "") -> D20Test:
	var t := D20Test.new()
	t.kind = kind_
	t.modifier = modifier_
	t.target = target_
	t.label = label_
	t.crit_range = crit_range_
	t.extra = extra_
	t.extra_label = extra_label_
	var has_adv := advantage_sources_ > 0
	var has_dis := disadvantage_sources_ > 0
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
static func from_natural(kind_: Kind, natural: int, modifier_: int, target_: int, crit_range_: int = 20) -> D20Test:
	var t := D20Test.new()
	t.kind = kind_
	t.rolls = [natural]
	t.kept = natural
	t.modifier = modifier_
	t.target = target_
	t.crit_range = crit_range_
	t._resolve()
	return t


## A save or check that fails without a roll (Paralyzed creatures fail Dexterity saves).
static func automatic_failure(kind_: Kind, target_: int, label_: String, reason: String) -> D20Test:
	var t := D20Test.new()
	t.kind = kind_
	t.target = target_
	t.label = label_
	t.auto_failed = true
	t.auto_fail_reason = reason
	t.success = false
	return t


## Halfling Luck (2024): a d20 that shows 1 is rolled again and the new roll must be used.
func reroll_ones(dice: DiceRoller, source: String) -> void:
	var notes: Array[String] = []
	for i in rolls.size():
		if rolls[i] == 1:
			rolls[i] = dice.d20(source)
			notes.append("1 → %d" % rolls[i])
	if notes.is_empty():
		return
	reroll_note = "%s: %s" % [source, ", ".join(notes)]
	if rolls.size() == 2:
		kept = maxi(rolls[0], rolls[1]) if advantage else mini(rolls[0], rolls[1])
	else:
		kept = rolls[0]
	_resolve()


## Adds a bonus after the roll (Precision Attack's die, Guided Strike's +10, Boon of Fate) and re-resolves.
func add_bonus(amount: int, source: String) -> void:
	extra += amount
	extra_label = ("%s %s %s %d" % [extra_label, "+" if amount >= 0 else "-", source, absi(amount)]).strip_edges() if extra_label != "" \
		else "%s %d" % [source, amount]
	_resolve()


## The kept d20 becomes `natural` (Portent replaces the roll; Stroke of Luck turns a failure into a 20).
func set_natural(natural: int, source: String) -> void:
	reroll_note = ("%s; " % reroll_note if reroll_note != "" else "") + "%s: %d → %d" % [source, kept, natural]
	kept = natural
	auto_failed = false
	_resolve()


## A d20 below `floor` counts as `floor` (Reliable Talent: 9 or lower counts as 10).
func floor_natural(floor: int, source: String) -> void:
	if kept < floor:
		set_natural(floor, source)


## One die rolled again (Heroic Inspiration, 2024: "reroll any die ... you must use the new roll"): the die worth
## rolling again is the lower one, so with Advantage the better of the two still counts and with Disadvantage the worse.
func reroll_one(natural: int, source: String) -> void:
	var before := kept
	if rolls.size() == 2 and (advantage or disadvantage):
		var low := 0 if rolls[0] <= rolls[1] else 1
		rolls[low] = natural
		kept = maxi(rolls[0], rolls[1]) if advantage else mini(rolls[0], rolls[1])
	else:
		rolls = [natural]
		kept = natural
	_note_reroll(source, "%d → %d" % [before, kept])


## The whole roll made again (Indomitable, Countercharm, a Luck Blade): its Advantage and Disadvantage as before, plus
## `add_advantage` (Countercharm's new roll has Advantage), and the bonuses already counted (Bless, the save's modifier)
## stay. `luck`: Halfling Luck rerolls a 1 again.
func reroll(dice: DiceRoller, source: String, add_advantage: bool = false, luck: bool = false) -> void:
	var before := kept
	var has_adv := advantage or not advantage_sources.is_empty() or add_advantage
	var has_dis := disadvantage or not disadvantage_sources.is_empty()
	advantage = has_adv and not has_dis
	disadvantage = has_dis and not has_adv
	if add_advantage and not source in advantage_sources:
		advantage_sources.append(source)
	if advantage or disadvantage:
		rolls = dice.roll(20, 2, source)
		kept = maxi(rolls[0], rolls[1]) if advantage else mini(rolls[0], rolls[1])
	else:
		rolls = dice.roll(20, 1, source)
		kept = rolls[0]
	_note_reroll(source, "%d → %s" % [before, str(kept) if rolls.size() == 1 else "%d (%d, %d)" % [kept, rolls[0], rolls[1]]])
	if luck and 1 in rolls:
		var note := reroll_note
		reroll_ones(dice, "Luck")
		reroll_note = "%s; %s" % [note, reroll_note]


func _note_reroll(source: String, what: String) -> void:
	reroll_note = ("%s; " % reroll_note if reroll_note != "" else "") + "%s: %s" % [source, what]
	auto_failed = false
	_resolve()


## Whether the roll would succeed with `natural` on the d20 instead (Restore Balance weighing the straight roll).
func would_succeed_with(natural: int) -> bool:
	if kind == Kind.ATTACK_ROLL and natural >= crit_range:
		return true
	if kind == Kind.ATTACK_ROLL and natural == 1:
		return false
	return natural + modifier + extra >= target


func _resolve() -> void:
	total = kept + modifier + extra
	critical = kind == Kind.ATTACK_ROLL and kept >= crit_range
	natural_one = kind == Kind.ATTACK_ROLL and kept == 1
	if critical:
		success = true
	elif natural_one:
		success = false
	else:
		success = total >= target


## Combat-log text, e.g. "Attack: d20 14 + 5 = 19 vs AC 16, hit" (plan §5.3).
func describe() -> String:
	var name: String = label if label != "" else ["Check", "Save", "Attack"][kind]
	var vs := "AC" if kind == Kind.ATTACK_ROLL else "DC"
	if auto_failed:
		return "%s: automatic failure (%s) vs %s %d" % [name, auto_fail_reason, vs, target]
	var die := "d20 %d" % kept
	if rolls.size() == 2:
		die = "d20 %s (%d, %d)" % ["adv" if advantage else "dis", rolls[0], rolls[1]]
		var why := advantage_sources if advantage else disadvantage_sources
		if not why.is_empty():
			die = "d20 %s [%s] (%d, %d)" % ["adv" if advantage else "dis", ", ".join(why), rolls[0], rolls[1]]
	var sign := "+" if modifier >= 0 else "-"
	var bonus := ""
	if extra != 0 or extra_label != "":
		bonus = " %s %s" % ["+" if extra >= 0 else "-", extra_label if extra_label != "" else str(absi(extra))]
	var outcome := "success" if success else "failure"
	if kind == Kind.ATTACK_ROLL:
		outcome = "critical hit" if critical else ("hit" if success else "miss")
	var text := "%s: %s %s %d%s = %d vs %s %d, %s" % [name, die, sign, absi(modifier), bonus, total, vs, target, outcome]
	if reroll_note != "":
		text += " (%s)" % reroll_note
	return text
