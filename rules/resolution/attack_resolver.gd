class_name AttackResolver
extends RefCounted
## Resolves one weapon attack (2024 PHB): Advantage and Disadvantage from both creatures, Critical Hits
## (all damage dice rolled twice), automatic Critical Hits against Paralyzed or Unconscious targets within
## 5 feet, Prone targets, long range, damage dice minimums (Great Weapon Fighting), then the target's
## Resistance, Vulnerability and Immunity through Creature.take_damage().

class AttackResult:
	extends RefCounted
	var test: D20Test
	var hit: bool = false
	var critical: bool = false
	var damage_rolls: Array[int] = []
	var damage_total: int = 0
	var damage: DamageResult = null
	var lines: Array[String] = []

	func describe() -> String:
		return "\n".join(lines)


## opts: distance_ft (5), advantage / disadvantage (Array[String] of extra sources), extra_dice
## ([{dice, type, label}] such as Sneak Attack), enemy_adjacent (ranged attacks get Disadvantage),
## apply_damage (true).
static func weapon_attack(dice: DiceRoller, attacker: Creature, profile: WeaponProfile, target: Creature,
		opts: Dictionary = {}) -> AttackResult:
	var r := AttackResult.new()
	var distance := int(opts.get("distance_ft", 5))
	var adv: Array[String] = []
	var dis: Array[String] = []
	for s: Variant in opts.get("advantage", []):
		adv.append(str(s))
	for s: Variant in opts.get("disadvantage", []):
		dis.append(str(s))
	for m in target.modifiers_for(&"attacked_with"):
		if m.text("value") == "advantage":
			adv.append("%s (target)" % m.source_name)
		elif m.text("value") == "disadvantage":
			dis.append("%s (target)" % m.source_name)
	if target.has_flag("prone"):
		if distance <= 5:
			adv.append("target Prone within 5 ft")
		else:
			dis.append("target Prone beyond 5 ft")
	if not profile.melee:
		if profile.normal_range > 0 and distance > profile.normal_range:
			dis.append("long range")
		if bool(opts.get("enemy_adjacent", false)):
			dis.append("enemy within 5 ft")
	var keys: Array[String] = ["attack", "attack:melee" if profile.melee else "attack:ranged"]
	var label := "%s → %s" % [profile.name, target.name]
	r.test = attacker.roll_d20(dice, D20Test.Kind.ATTACK_ROLL, profile.attack, target.ac_value(), keys, adv, dis,
		label, profile.crit_range)
	r.hit = r.test.success
	r.critical = r.test.critical
	if r.hit and not r.critical and distance <= 5 and target.has_flag("auto_crit_within_5ft"):
		r.critical = true
		r.lines.append("Automatic Critical Hit: target can't defend itself within 5 ft")
	r.lines.push_front(r.test.describe())
	if not r.hit:
		return r
	var total := 0
	var by_type := {}
	var text_parts: Array[String] = []
	var dice_list: Array[Dictionary] = [{"dice": profile.damage_dice, "label": profile.name, "type": str(profile.damage_type)}]
	for e: Variant in opts.get("extra_dice", []):
		dice_list.append(e as Dictionary)
	for entry in dice_list:
		var parsed := DiceRoller.parse_expr(str(entry["dice"]))
		var count := int(parsed["count"]) * (2 if r.critical else 1)
		var rolls: Array[int] = []
		if count > 0:
			rolls = dice.roll(int(parsed["sides"]), count, "%s damage" % entry["label"])
		var sub := int(parsed["modifier"])
		var shown: Array[String] = []
		for roll in rolls:
			var v := roll
			if profile.die_minimum > 0 and entry == dice_list[0] and v < profile.die_minimum:
				v = profile.die_minimum
			sub += v
			r.damage_rolls.append(v)
			shown.append(str(v) if v == roll else "%d→%d" % [roll, v])
		total += sub
		var t := str(entry.get("type", str(profile.damage_type)))
		by_type[t] = int(by_type.get(t, 0)) + sub
		text_parts.append("%s %s [%s]" % [entry["label"], entry["dice"], ", ".join(shown)] if not shown.is_empty() else "%s %s" % [entry["label"], entry["dice"]])
	total += profile.damage_bonus.total()
	var primary := str(profile.damage_type)
	by_type[primary] = maxi(0, int(by_type.get(primary, 0)) + profile.damage_bonus.total())
	r.damage_total = maxi(0, total)
	r.lines.append("Damage: %s %+d = %d%s" % [" + ".join(text_parts), profile.damage_bonus.total(), r.damage_total,
		" (Critical Hit: dice doubled)" if r.critical else ""])
	if bool(opts.get("apply_damage", true)):
		var parts: Array = []
		for t2: String in by_type:
			parts.append({"amount": int(by_type[t2]), "type": t2})
		r.damage = target.take_damage_parts(parts, r.critical, dice, profile.name)
		r.lines.append(r.damage.describe(target.name))
	return r
