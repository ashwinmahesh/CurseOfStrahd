class_name Monster
extends Creature
## A creature built from a 2024-format stat block (data/monsters). Its totals (AC, saves, skills,
## initiative) come from the stat block; spells and conditions still change them through modifiers.

static var _counter: int = 0

var data: Dictionary = {}
var cr: float = 0.0
var hp_max_base: int = 1
var _trait_modifiers: Array[Modifier] = []


## `dice` given = roll the Hit Dice; otherwise use the average (the 2024 default).
static func from_data(entry: Dictionary, dice: DiceRoller = null, compendium_: Compendium = null) -> Monster:
	var m := Monster.new()
	if compendium_ != null:
		m.compendium = compendium_
	_counter += 1
	m.data = entry
	m.id = "%s#%d" % [entry.get("id", "monster"), _counter]
	m.name = str(entry.get("name", "Monster"))
	m.size = StringName(str(entry.get("size", "medium")))
	m.creature_type = StringName(str(entry.get("type", "beast")))
	m.cr = float(entry.get("cr", 0))
	m.base_label = "Stat block"
	m.base_speed = (entry.get("speed", {"walk": 30}) as Dictionary).duplicate()
	m.base_senses = (entry.get("senses", {}) as Dictionary).duplicate()
	for v: Variant in entry.get("resistances", []):
		m.base_resistances.append(str(v))
	for v: Variant in entry.get("vulnerabilities", []):
		m.base_vulnerabilities.append(str(v))
	for v: Variant in entry.get("immunities", []):
		m.base_immunities.append(str(v))
	for v: Variant in entry.get("condition_immunities", []):
		m.base_condition_immunities.append(str(v))
	var hp_data := entry.get("hp", {"average": 1, "dice": "1"}) as Dictionary
	m.hp_max_base = int(hp_data.get("average", 1))
	if dice != null:
		m.hp_max_base = maxi(1, int(dice.roll_expr(str(hp_data.get("dice", "1")), "%s Hit Points" % m.name)["total"]))
	for t: Variant in entry.get("traits", []):
		var tr := t as Dictionary
		for md: Variant in tr.get("modifiers", []):
			m._trait_modifiers.append(Modifier.make(md as Dictionary, str(tr.get("name", "")), &"monster", m.id))
	m.hp = m.max_hp()
	return m


func proficiency_bonus() -> int:
	if data.has("proficiency_bonus"):
		return int(data["proficiency_bonus"])
	return Abilities.proficiency_for_cr(cr)


func base_ability_parts(ab: StringName) -> Array[Dictionary]:
	return [{"label": "Stat block", "value": int((data.get("abilities", {}) as Dictionary).get(str(ab), 10))}]


func intrinsic_modifiers() -> Array[Modifier]:
	return _trait_modifiers


func max_hp_breakdown() -> Breakdown:
	var b := Breakdown.new("Hit Points")
	b.add("Stat block (%s)" % (data.get("hp", {}) as Dictionary).get("dice", ""), hp_max_base)
	_add_hp_modifiers(b)
	return b


func armor_class() -> Breakdown:
	var b := Breakdown.new("AC")
	b.add(str(data.get("ac_note", "Stat block")), int(data.get("ac", 10)))
	_add_ac_modifiers(b, {})
	return b


func fixed_save(ab: StringName) -> Variant:
	var saves := data.get("saves", {}) as Dictionary
	return int(saves[str(ab)]) if saves.has(str(ab)) else null


func fixed_skill(skill: StringName) -> Variant:
	var skills := data.get("skills", {}) as Dictionary
	return int(skills[str(skill)]) if skills.has(str(skill)) else null


func fixed_initiative() -> Variant:
	return int(data["initiative"]) if data.has("initiative") else null


func xp() -> int:
	return int(data.get("xp", 0))


func action(action_id: String) -> Dictionary:
	for list_name: String in ["actions", "bonus_actions", "reactions"]:
		for a: Variant in data.get(list_name, []):
			if str((a as Dictionary).get("id", "")) == action_id:
				return a as Dictionary
	return {}


## Builds an attack profile for a stat-block attack, so AttackResolver can roll it like a weapon.
func attack_profile(action_id: String) -> WeaponProfile:
	var a := action(action_id)
	var p := WeaponProfile.new()
	p.item_id = action_id
	p.name = "%s: %s" % [name, a.get("name", action_id)]
	var atk := a.get("attack", {}) as Dictionary
	p.melee = str(a.get("kind", "melee")) != "ranged"
	p.tags.assign(["melee" if p.melee else "ranged"])
	p.reach = int(atk.get("reach", 5))
	var rng := atk.get("range", []) as Array
	if rng.size() >= 1:
		p.normal_range = int(rng[0])
		p.long_range = int(rng[rng.size() - 1])
	p.attack = Breakdown.new("%s attack" % p.name)
	p.attack.add("Stat block", int(atk.get("bonus", 0)))
	var ctx := formula_context()
	for m in modifiers_for(&"attack"):
		if not m.has_when():
			p.attack.add_nonzero(m.source_name, mod_value(m, ctx))
	for m in modifiers_for(&"d20"):
		p.attack.add_nonzero(m.source_name, mod_value(m, ctx))
	var dmg := _damage_entries(a)
	p.damage_bonus = Breakdown.new("%s damage bonus" % p.name)
	if not dmg.is_empty():
		var first := dmg[0] as Dictionary
		var parsed := DiceRoller.parse_expr(str(first["dice"]))
		p.damage_dice = "%dd%d" % [int(parsed["count"]), int(parsed["sides"])] if int(parsed["count"]) > 0 else "0"
		p.damage_bonus.add("Stat block", int(parsed["modifier"]))
		p.damage_type = StringName(str(first["type"]))
	return p


## Extra damage dice an action deals beyond its first damage entry (Ghoul Bite's Necrotic), for
## AttackResolver's extra_dice option.
func extra_damage_dice(action_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dmg := _damage_entries(action(action_id))
	for i in range(1, dmg.size()):
		var d := dmg[i] as Dictionary
		if d.has("when") and not d.has("if"):
			continue
		out.append({"dice": str(d["dice"]), "type": str(d["type"]), "label": str(d["type"]).capitalize()})
	return out


## The damage entries that apply now: entries marked `if: bloodied` / `not_bloodied` (a swarm's weaker bites once
## it's Bloodied) are kept only when that's true.
func _damage_entries(a: Dictionary) -> Array:
	var out: Array = []
	for d: Variant in a.get("damage", []):
		var dd := d as Dictionary
		match str(dd.get("if", "")):
			"bloodied":
				if not is_bloodied():
					continue
			"not_bloodied":
				if is_bloodied():
					continue
		out.append(dd)
	return out


## Average damage of an action with every damage entry that applies (for the AI's choices).
func average_damage(action_id: String) -> float:
	var total := 0.0
	for d: Variant in _damage_entries(action(action_id)):
		var p := DiceRoller.parse_expr(str((d as Dictionary)["dice"]))
		total += int(p["count"]) * (int(p["sides"]) + 1) / 2.0 + int(p["modifier"])
	return total
