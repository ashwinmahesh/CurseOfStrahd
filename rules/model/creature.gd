class_name Creature
extends RefCounted
## Anything with Hit Points the rules act on: characters, monsters, NPCs (plan §4.3). Pure rules state with
## no nodes. Every number comes back as a Breakdown so the UI can explain it (plan §5.6). Character and
## Monster fill in where scores, Hit Points, AC and proficiencies come from; everything else (conditions,
## effects, damage, healing, death saves, Concentration, rests) is shared here. 2024 PHB throughout.

const ABILITY_NAMES := {&"str": "Strength", &"dex": "Dexterity", &"con": "Constitution",
	&"int": "Intelligence", &"wis": "Wisdom", &"cha": "Charisma"}
const ABILITY_SHORT := {&"str": "Str", &"dex": "Dex", &"con": "Con", &"int": "Int", &"wis": "Wis", &"cha": "Cha"}
const SIZES: Array[StringName] = [&"tiny", &"small", &"medium", &"large", &"huge", &"gargantuan"]
## Carrying capacity multiplier on Strength by size (2024 glossary "Carrying Capacity").
const CARRY_MULTIPLIER := {&"tiny": 7.5, &"small": 15.0, &"medium": 15.0, &"large": 30.0, &"huge": 60.0, &"gargantuan": 120.0}
const MAX_EVENTS := 200

static var _condition_mods: Dictionary = {}

var id: String = ""
var name: String = ""
var size: StringName = &"medium"
var creature_type: StringName = &"humanoid"
var compendium: Compendium = null

var hp: int = 1
var temp_hp: int = 0
## Hit Points of a ward that soaks damage first (Abjurer's Arcane Ward).
var ward_hp: int = 0
var exhaustion: int = 0
var death_successes: int = 0
var death_failures: int = 0
var stable: bool = false
var dead: bool = false
## Hit Points lost to a Sword of Wounding: healing other than a rest can't bring them back (cleared by a rest).
var unhealable: int = 0
## Player characters (and story NPCs) make Death Saving Throws; monsters die at 0 Hit Points.
var uses_death_saves: bool = false

## Conditions applied directly (not through an Effect): condition -> Array of source names.
var conditions: Dictionary = {}
var effects: Array[Effect] = []
var concentration: Concentration = null
## id -> {name, max, used, recharge, source}
var resources: Dictionary = {}

var base_speed: Dictionary = {"walk": 30}
var base_resistances: Array[String] = []
var base_vulnerabilities: Array[String] = []
var base_immunities: Array[String] = []
var base_condition_immunities: Array[String] = []
var base_senses: Dictionary = {}
## Label for the base defenses above in breakdowns ("Stat block" for monsters).
var base_label: String = "Base"

## Rules events since the caller last drained them (plan §4.3: the engine returns events).
var events: Array[Dictionary] = []
## Hooks the combat engine installs (features that change D20 Tests: Lucky, Portent, Indomitable, Reliable
## Talent...). before(creature, kind, keys, target) -> {advantage: [], disadvantage: [], natural: int};
## after(creature, test, keys) changes the finished test in place.
var d20_before: Callable = Callable()
var d20_after: Callable = Callable()


func _init() -> void:
	compendium = Compendium.shared()


## Clears static caches (tests and shutdown).
static func clear_caches() -> void:
	_condition_mods.clear()


# --- What subclasses provide ---------------------------------------------------------------------

func proficiency_bonus() -> int:
	return 2


## Total character level (0 for monsters).
func character_level() -> int:
	return 0


func class_level_of(_class_id: String) -> int:
	return 0


## Where an ability score comes from before modifiers: [{label, value}].
func base_ability_parts(_ability: StringName) -> Array[Dictionary]:
	return [{"label": "Score", "value": 10}]


## Modifiers from features, traits, feats and items (not conditions or effects).
func intrinsic_modifiers() -> Array[Modifier]:
	return []


func max_hp_breakdown() -> Breakdown:
	var b := Breakdown.new("Hit Points")
	b.add("Base", 1)
	_add_hp_modifiers(b)
	return b


func armor_class() -> Breakdown:
	var b := Breakdown.new("AC")
	b.add("Unarmored", 10)
	b.add("Dex modifier", ability_mod(&"dex"))
	_add_ac_modifiers(b, {"armor": "none", "shield": false})
	return b


## Stat-block totals override the computed save/skill bonus (monsters). null = compute.
func fixed_save(_ability: StringName) -> Variant:
	return null


func fixed_skill(_skill: StringName) -> Variant:
	return null


func fixed_initiative() -> Variant:
	return null


## What this creature wears, for `when` filters: {armor: none|light|medium|heavy, shield: bool}.
func armor_situation() -> Dictionary:
	return {"armor": "none", "shield": false}


## Extra Advantage/Disadvantage that comes from gear rather than modifiers (armor without training,
## Stealth in heavy armor). Returns {advantage: [...], disadvantage: [...]}.
func gear_d20_sources(_keys: Array[String]) -> Dictionary:
	return {"advantage": [], "disadvantage": []}


# --- Modifiers -----------------------------------------------------------------------------------

func all_modifiers() -> Array[Modifier]:
	var out: Array[Modifier] = []
	var level := character_level()
	for m in intrinsic_modifiers():
		if m.at_level() <= level and (m.class_id == "" or class_level_of(m.class_id) >= m.number("at_class_level", 0)):
			out.append(m)
	for c in active_conditions():
		out.append_array(_modifiers_of_condition(c))
	var best := {}
	for e in effects:
		var k := e.key()
		if not best.has(k):
			best[k] = e
			continue
		var other := best[k] as Effect
		if e.potency() > other.potency() or (e.potency() == other.potency() and e.order > other.order):
			best[k] = e
	for e: Effect in best.values():
		out.append_array(e.modifiers)
	return out


func modifiers_for(stat: StringName) -> Array[Modifier]:
	var out: Array[Modifier] = []
	for m in all_modifiers():
		if m.stat == stat:
			out.append(m)
	return out


func has_flag(flag: String) -> bool:
	for m in modifiers_for(&"flag"):
		if m.text("value") == flag:
			return true
	return false


## Values formulas can use, without ability terms (used while computing ability scores).
func _base_ctx() -> Dictionary:
	return {"pb": proficiency_bonus(), "level": character_level(), "class_level": 0, "slot_level": 0,
		"exhaustion": exhaustion}


func formula_context(slot_level: int = 0) -> Dictionary:
	var ctx := _base_ctx()
	ctx["slot_level"] = slot_level
	for ab: StringName in Abilities.ALL:
		var score := ability_score(ab)
		ctx["score:%s" % ab] = score
		ctx["mod:%s" % ab] = Abilities.modifier(score)
	return ctx


## A modifier's value, with class_level resolved for the class that granted it.
func mod_value(m: Modifier, ctx: Dictionary) -> int:
	if m.class_id != "":
		var c := ctx.duplicate()
		c["class_level"] = class_level_of(m.class_id)
		return m.value_on(c)
	return m.value_on(ctx)


# --- Abilities, saves, checks --------------------------------------------------------------------

func ability_breakdown(ab: StringName) -> Breakdown:
	var b := Breakdown.new(str(ABILITY_NAMES[ab]))
	for p in base_ability_parts(ab):
		b.add(str(p["label"]), int(p["value"]))
	var ctx := _base_ctx()
	for m in modifiers_for(&"ability"):
		if m.text("ability") == ab:
			var cap := m.number("max", 20)
			var gain := mini(mod_value(m, ctx), maxi(0, cap - b.sum()))
			b.add_nonzero(m.source_name, gain)
	for m in modifiers_for(&"ability_min"):
		if m.text("ability") == ab:
			b.set_floor(mod_value(m, ctx), m.source_name)
	return b


func ability_score(ab: StringName) -> int:
	return ability_breakdown(ab).total()


func ability_mod(ab: StringName) -> int:
	return Abilities.modifier(ability_score(ab))


func check_keys(skill_or_ability: StringName) -> Array[String]:
	var keys: Array[String] = ["check:all", "check:%s" % skill_or_ability]
	if Abilities.SKILLS.has(skill_or_ability):
		keys.append("check:%s" % Abilities.SKILLS[skill_or_ability])
	return keys


func save_keys(ab: StringName) -> Array[String]:
	return ["save:all", "save:%s" % ab]


func initiative_keys() -> Array[String]:
	return ["initiative", "check:all", "check:dex"]


## Proficiency from modifiers (feats, species, items): returns the source name or "".
func proficiency_source(kind: String, value: String) -> String:
	for m in modifiers_for(&"proficiency"):
		if m.text("kind") == kind and m.text("value") == value:
			return m.source_name
	return ""


func save_proficiency(ab: StringName) -> String:
	return proficiency_source("save", ab)


## 0 = none, 1 = proficient, 2 = Expertise.
func skill_rank(skill: StringName) -> int:
	for m in modifiers_for(&"expertise"):
		if m.text("value") == skill:
			return 2
	return 1 if proficiency_source("skill", skill) != "" else 0


func save_bonus(ab: StringName) -> Breakdown:
	var b := Breakdown.new("%s save" % ABILITY_NAMES[ab])
	var mod := ability_mod(ab)
	b.add("%s modifier" % ABILITY_SHORT[ab], mod)
	var fixed: Variant = fixed_save(ab)
	if fixed != null:
		var rest := int(fixed) - mod
		if rest == proficiency_bonus():
			b.add("Proficiency", rest)
		else:
			b.add_nonzero("Stat block", rest)
	elif save_proficiency(ab) != "":
		b.add("Proficiency", proficiency_bonus())
	var ctx := formula_context()
	for m in modifiers_for(&"save"):
		var a := m.text("ability", "all")
		if a == "all" or a == ab:
			b.add_nonzero(m.source_name, mod_value(m, ctx))
	_add_d20_modifiers(b, ctx)
	_note_advantage(b, save_keys(ab))
	return b


func skill_bonus(skill: StringName) -> Breakdown:
	var ab: StringName = Abilities.SKILLS[skill]
	var b := Breakdown.new(str(skill).capitalize())
	var mod := ability_mod(ab)
	b.add("%s modifier" % ABILITY_SHORT[ab], mod)
	var fixed: Variant = fixed_skill(skill)
	if fixed != null:
		var rest := int(fixed) - mod
		if rest == proficiency_bonus():
			b.add("Proficiency", rest)
		elif rest == 2 * proficiency_bonus():
			b.add("Expertise", rest)
		else:
			b.add_nonzero("Stat block", rest)
	else:
		match skill_rank(skill):
			2:
				b.add("Expertise", 2 * proficiency_bonus())
			1:
				b.add("Proficiency", proficiency_bonus())
			_:
				# Jack of All Trades (Bard 2): half the Proficiency Bonus, rounded down, to skills you lack.
				if has_flag("jack_of_all_trades"):
					b.add("Jack of All Trades", floori(proficiency_bonus() / 2.0))
	_add_check_modifiers(b, check_keys(skill), skill, ab)
	_note_advantage(b, check_keys(skill))
	return b


## A plain ability check (no skill), e.g. a Strength check to force a door.
func ability_check_bonus(ab: StringName) -> Breakdown:
	var b := Breakdown.new("%s check" % ABILITY_NAMES[ab])
	b.add("%s modifier" % ABILITY_SHORT[ab], ability_mod(ab))
	_add_check_modifiers(b, check_keys(ab), &"", ab)
	_note_advantage(b, check_keys(ab))
	return b


func initiative_bonus() -> Breakdown:
	var b := Breakdown.new("Initiative")
	var mod := ability_mod(&"dex")
	b.add("Dex modifier", mod)
	var fixed: Variant = fixed_initiative()
	if fixed != null:
		b.add_nonzero("Stat block", int(fixed) - mod)
	var ctx := formula_context()
	for m in modifiers_for(&"initiative"):
		b.add_nonzero(m.source_name, mod_value(m, ctx))
	_add_check_modifiers(b, ["check:all", "check:dex"], &"", &"dex", false)
	_note_advantage(b, initiative_keys())
	return b


## Passive score: 10 + the check's bonus, +5 with Advantage, -5 with Disadvantage (2024 glossary).
func passive_score(skill: StringName) -> Breakdown:
	var check := skill_bonus(skill)
	var b := Breakdown.new("Passive %s" % str(skill).capitalize())
	b.add("Base", 10)
	for p in check.parts:
		b.add(str(p["label"]), int(p["value"]))
	var src := d20_sources(check_keys(skill))
	var adv := (src["advantage"] as Array).size() > 0
	var dis := (src["disadvantage"] as Array).size() > 0
	if adv and not dis:
		b.add("Advantage", 5)
	elif dis and not adv:
		b.add("Disadvantage", -5)
	var ctx := formula_context()
	for m in modifiers_for(&"passive"):
		if m.text("skill") == skill:
			b.add_nonzero(m.source_name, mod_value(m, ctx))
	return b


func _add_check_modifiers(b: Breakdown, keys: Array[String], skill: StringName, ab: StringName,
		with_d20: bool = true) -> void:
	var ctx := formula_context()
	for m in modifiers_for(&"check"):
		var target := m.text("skill", m.text("ability", "all"))
		if target == "all" or target == skill or target == ab or ("check:%s" % target) in keys:
			b.add_nonzero(m.source_name, mod_value(m, ctx))
	if with_d20:
		_add_d20_modifiers(b, ctx)
	else:
		_add_d20_modifiers(b, ctx)


func _add_d20_modifiers(b: Breakdown, ctx: Dictionary) -> void:
	for m in modifiers_for(&"d20"):
		b.add_nonzero(m.source_name, mod_value(m, ctx))


func _note_advantage(b: Breakdown, keys: Array[String]) -> void:
	var src := d20_sources(keys)
	for s: String in src["advantage"]:
		b.note("Advantage (%s)" % s)
	for s: String in src["disadvantage"]:
		b.note("Disadvantage (%s)" % s)
	for m in modifiers_for(&"auto_fail"):
		if m.matches_any(keys):
			b.note("Automatic failure (%s)" % m.source_name)


## Named sources of Advantage and Disadvantage for a D20 Test with these keys. A `when` filter can ask about the
## armor worn or {"incapacitated": false} (Danger Sense).
func d20_sources(keys: Array[String]) -> Dictionary:
	var adv: Array[String] = []
	var dis: Array[String] = []
	var situation := armor_situation()
	situation["incapacitated"] = has_condition(&"incapacitated")
	for m in modifiers_for(&"advantage"):
		if m.matches_any(keys) and not m.source_name in adv and m.applies_when(situation):
			adv.append(m.source_name)
	for m in modifiers_for(&"disadvantage"):
		if m.matches_any(keys) and not m.source_name in dis and m.applies_when(situation):
			dis.append(m.source_name)
	var gear := gear_d20_sources(keys)
	for s: String in gear["advantage"]:
		adv.append(s)
	for s: String in gear["disadvantage"]:
		dis.append(s)
	return {"advantage": adv, "disadvantage": dis}


# --- Rolling D20 Tests ---------------------------------------------------------------------------

## `extra_keys` name the action the check belongs to ("search", "study") for features that care (Sharp Eye, Watchers).
func roll_check(dice: DiceRoller, skill_or_ability: StringName, dc: int, extra_adv: Array[String] = [],
		extra_dis: Array[String] = [], label: String = "", extra_keys: Array[String] = []) -> D20Test:
	var bonus := skill_bonus(skill_or_ability) if Abilities.SKILLS.has(skill_or_ability) else ability_check_bonus(skill_or_ability)
	var text := label if label != "" else "%s (%s)" % [bonus.label, name]
	var keys := check_keys(skill_or_ability)
	keys.append_array(extra_keys)
	return roll_d20(dice, D20Test.Kind.ABILITY_CHECK, bonus, dc, keys, extra_adv, extra_dis, text)


func roll_save(dice: DiceRoller, ab: StringName, dc: int, extra_adv: Array[String] = [],
		extra_dis: Array[String] = [], label: String = "", extra_keys: Array[String] = []) -> D20Test:
	var keys := save_keys(ab)
	keys.append_array(extra_keys)
	var text := label if label != "" else "%s save (%s)" % [ABILITY_NAMES[ab], name]
	return roll_d20(dice, D20Test.Kind.SAVING_THROW, save_bonus(ab), dc, keys, extra_adv, extra_dis, text)


func roll_initiative(dice: DiceRoller) -> D20Test:
	return roll_d20(dice, D20Test.Kind.ABILITY_CHECK, initiative_bonus(), 0, initiative_keys(), [], [],
		"Initiative (%s)" % name)


## The one place a creature rolls a d20: automatic failures, Advantage/Disadvantage sources, bonus and
## penalty dice (Bless, Bane) and the explanation all come together here.
func roll_d20(dice: DiceRoller, kind: D20Test.Kind, bonus: Breakdown, target: int, keys: Array[String],
		extra_adv: Array[String] = [], extra_dis: Array[String] = [], label: String = "",
		crit_range: int = 20, extra_dice: Array = []) -> D20Test:
	for m in modifiers_for(&"auto_fail"):
		if m.matches_any(keys):
			var failed := D20Test.automatic_failure(kind, target, label, m.source_name)
			failed.breakdown = bonus
			return failed
	var src := d20_sources(keys)
	var adv: Array[String] = []
	var dis: Array[String] = []
	adv.assign(src["advantage"])
	dis.assign(src["disadvantage"])
	adv.append_array(extra_adv)
	dis.append_array(extra_dis)
	var forced := 0
	if d20_before.is_valid():
		var pre := d20_before.call(self, kind, keys, target) as Dictionary
		for x: Variant in pre.get("advantage", []):
			adv.append(str(x))
		for x: Variant in pre.get("disadvantage", []):
			dis.append(str(x))
		forced = int(pre.get("natural", 0))
	var extra := 0
	var extra_text := ""
	for m in modifiers_for(&"bonus_die"):
		if m.matches_any(keys):
			var r := int(dice.roll_expr(m.text("dice", "1d4"), m.source_name)["total"])
			extra += r
			extra_text += " + %s %d" % [m.source_name, r]
	for m in modifiers_for(&"penalty_die"):
		if m.matches_any(keys):
			var r := int(dice.roll_expr(m.text("dice", "1d4"), m.source_name)["total"])
			extra -= r
			extra_text += " - %s %d" % [m.source_name, r]
	# Dice from someone else's effect (Blade Ward: attack rolls against its caster subtract 1d4).
	for xd: Variant in extra_dice:
		var x := xd as Dictionary
		var r2 := int(dice.roll_expr(str(x.get("dice", "1d4")), str(x.get("source", "")))["total"])
		var sgn := int(x.get("sign", 1))
		extra += r2 * sgn
		extra_text += " %s %s %d" % ["+" if sgn > 0 else "-", x.get("source", ""), r2]
	var t := D20Test.roll(dice, kind, bonus.total(), target, adv.size(), dis.size(), label, crit_range,
		extra, extra_text.strip_edges())
	if has_flag("luck"):
		t.reroll_ones(dice, "Luck")
	if forced > 0:
		t.set_natural(forced, "Portent")
	t.breakdown = bonus
	t.advantage_sources = adv
	t.disadvantage_sources = dis
	if d20_after.is_valid():
		d20_after.call(self, t, keys)
	log_event({"type": "d20", "creature": id, "text": t.describe()})
	consume_effects(keys)
	return t


## Removes effects that last only until the creature's next D20 Test with one of `keys` (Mind Sliver).
func consume_effects(keys: Array[String]) -> void:
	for e: Effect in effects.duplicate():
		for k in e.consume_on:
			if k in keys:
				remove_effect(e)
				break


## Removes effects that last only until the next attack roll against this creature (Guiding Bolt).
func consume_attacked() -> void:
	for e: Effect in effects.duplicate():
		if e.consume_when_attacked:
			remove_effect(e)


# --- Hit Points, damage and healing --------------------------------------------------------------

func max_hp() -> int:
	return maxi(0, max_hp_breakdown().total())


func _add_hp_modifiers(b: Breakdown) -> void:
	var ctx := formula_context()
	for m in modifiers_for(&"hp_max"):
		b.add_nonzero(m.source_name, mod_value(m, ctx))


func is_bloodied() -> bool:
	return hp <= floori(max_hp() / 2.0)


func is_conscious() -> bool:
	return not dead and hp > 0 and not has_condition(&"unconscious")


func defense_source(stat: StringName, base: Array[String], damage_type: StringName) -> String:
	if str(damage_type) in base or "all" in base:
		return base_label
	for m in modifiers_for(stat):
		var v := m.text("value")
		if v == damage_type or v == "all":
			return m.source_name
	return ""


func resistance_source(damage_type: StringName) -> String:
	return defense_source(&"resistance", base_resistances, damage_type)


func vulnerability_source(damage_type: StringName) -> String:
	return defense_source(&"vulnerability", base_vulnerabilities, damage_type)


func immunity_source(damage_type: StringName) -> String:
	return defense_source(&"immunity", base_immunities, damage_type)


## Deals damage of one type that has already been rolled and had its bonuses added (2024 order:
## bonuses and penalties first, then Resistance, then Vulnerability; Immunity means none). Temporary Hit
## Points absorb first. Handles dropping to 0, Massive Damage, damage at 0 HP and the Concentration save
## (rolled here when `dice` is given, otherwise reported as concentration_dc for the caller).
func take_damage(amount: int, damage_type: StringName, critical: bool = false, dice: DiceRoller = null,
		source: String = "") -> DamageResult:
	return take_damage_parts([{"amount": amount, "type": damage_type}], critical, dice, source)


## One instance of damage made of several types (a Ghoul's Bite: Piercing plus Necrotic). Each type meets
## the target's defenses on its own; the total is lost at once and forces one Concentration save.
func take_damage_parts(parts: Array, critical: bool = false, dice: DiceRoller = null,
		source: String = "") -> DamageResult:
	var r := DamageResult.new()
	r.critical = critical
	r.source = source
	if dead:
		return r
	var dmg := 0
	for part: Variant in parts:
		var pd := part as Dictionary
		var damage_type := StringName(str(pd["type"]))
		var amount := maxi(0, int(pd["amount"]))
		r.raw += amount
		if r.type == &"":
			r.type = damage_type
		var imm := immunity_source(damage_type)
		if imm != "":
			if amount > 0:
				r.notes.append("Immunity to %s: %s" % [damage_type, imm])
			continue
		var res := resistance_source(damage_type)
		# Resistance that only covers this damage's source (Shield of Missile Attraction: Ranged weapons).
		if res == "" and str(pd.get("resisted_by", "")) != "":
			res = str(pd["resisted_by"])
		if res != "" and bool(pd.get("ignore_resistance", false)):
			r.notes.append("%s ignores Resistance" % pd.get("ignore_source", "The attack"))
			res = ""
		if res != "" and amount > 0:
			amount = floori(amount / 2.0)
			r.notes.append("Resistance to %s: %s" % [damage_type, res])
		var vul := vulnerability_source(damage_type)
		if vul != "" and amount > 0:
			amount *= 2
			r.notes.append("Vulnerability to %s: %s" % [damage_type, vul])
		dmg += amount
	r.final = dmg
	if dmg <= 0:
		_log_damage(r)
		return r
	# A magical ward (the Abjurer's Arcane Ward) takes damage before anything else.
	var warded := mini(ward_hp, dmg)
	if warded > 0:
		ward_hp -= warded
		dmg -= warded
		r.notes.append("Arcane Ward absorbs %d (%d left)" % [warded, ward_hp])
		r.final = dmg
		if dmg <= 0:
			_log_damage(r)
			return r
	var absorbed := mini(temp_hp, dmg)
	temp_hp -= absorbed
	r.absorbed_by_temp = absorbed
	var remaining := dmg - absorbed
	var maximum := max_hp()
	if remaining > 0 and hp == 0:
		if remaining >= maximum:
			r.instant_death = true
			_die("Massive Damage")
		elif uses_death_saves:
			stable = false
			var fails := 2 if critical else 1
			death_failures += fails
			r.death_save_failures = fails
			if death_failures >= 3:
				_die("three Death Saving Throw failures")
		r.died = dead
	elif remaining > 0:
		var before := hp
		hp -= remaining
		r.hp_lost = mini(before, remaining)
		if hp <= 0:
			var overflow := -hp
			hp = 0
			r.dropped_to_zero = true
			if uses_death_saves:
				if overflow >= maximum:
					r.instant_death = true
					_die("Massive Damage")
				else:
					_fall_unconscious()
			else:
				_die("0 Hit Points")
			r.died = dead
	if concentration != null and not dead and hp > 0:
		r.concentration_dc = Concentration.save_dc(r.final)
		if dice != null:
			var t := roll_save(dice, &"con", r.concentration_dc, [], [], "Concentration (%s)" % name, ["concentration"])
			r.concentration_save = t
			if not t.success:
				r.concentration_broken = true
				concentration.end("failed a Concentration save")
	_log_damage(r)
	return r


func _log_damage(r: DamageResult) -> void:
	log_event({"type": "damage", "creature": id, "amount": r.final, "damage_type": str(r.type),
		"text": r.describe(name)})


## Regains Hit Points (never above the maximum). Healing a creature at 0 HP wakes it; it stays Prone.
func heal(amount: int, source: String = "") -> int:
	if dead or amount <= 0:
		return 0
	var before := hp
	# Hit Points a Sword of Wounding took come back only with a Short or Long Rest.
	var cap := maxi(0, max_hp() - (0 if source in ["Short Rest", "Long Rest", "Hit Point Die"] else unhealable))
	hp = maxi(before, mini(cap, hp + amount))
	if before == 0 and hp > 0:
		_wake_from_zero()
	log_event({"type": "healed", "creature": id, "amount": hp - before, "source": source})
	return hp - before


## Temporary Hit Points don't stack: the higher amount is kept (the player may choose in the UI).
func add_temp_hp(amount: int, source: String = "") -> bool:
	if amount <= temp_hp:
		return false
	temp_hp = amount
	log_event({"type": "temp_hp", "creature": id, "amount": amount, "source": source})
	return true


func _fall_unconscious() -> void:
	death_successes = 0
	death_failures = 0
	stable = false
	add_condition(&"unconscious", "0 Hit Points")


func _wake_from_zero() -> void:
	death_successes = 0
	death_failures = 0
	stable = false
	if conditions.has(&"unconscious"):
		remove_condition(&"unconscious", "0 Hit Points")
		add_condition(&"prone", "Unconscious")


func _die(reason: String) -> void:
	if dead:
		return
	dead = true
	hp = 0
	if concentration != null:
		concentration.end("died")
	log_event({"type": "died", "creature": id, "reason": reason})


## Death Saving Throw (2024): 10+ succeeds; three successes = Stable, three failures = death; a natural 1
## counts as two failures, a natural 20 restores 1 Hit Point. Bonuses to saving throws apply.
func roll_death_save(dice: DiceRoller) -> D20Test:
	if dead or hp > 0 or stable:
		return null
	var bonus := Breakdown.new("Death save")
	var ctx := formula_context()
	for m in modifiers_for(&"save"):
		if m.text("ability", "all") == "all":
			bonus.add_nonzero(m.source_name, mod_value(m, ctx))
	_add_d20_modifiers(bonus, ctx)
	var keys: Array[String] = ["save:all", "death_save"]
	var t := roll_d20(dice, D20Test.Kind.SAVING_THROW, bonus, 10, keys, [], [], "Death save (%s)" % name)
	if t.kept == 20 or (t.kept >= 18 and has_flag("survivor")):
		heal(1, "natural 20 on a Death Saving Throw" if t.kept == 20 else "Survivor: %d counts as a 20" % t.kept)
	elif t.kept == 1:
		death_failures += 2
	elif t.success:
		death_successes += 1
	else:
		death_failures += 1
	if death_failures >= 3:
		_die("three Death Saving Throw failures")
	elif death_successes >= 3:
		stabilize()
	return t


func stabilize() -> void:
	if dead or hp > 0:
		return
	stable = true
	death_successes = 0
	death_failures = 0
	log_event({"type": "stable", "creature": id})


# --- Conditions ----------------------------------------------------------------------------------

func condition_immunity_source(c: StringName) -> String:
	if str(c) in base_condition_immunities:
		return base_label
	for m in modifiers_for(&"condition_immunity"):
		if m.text("value") == c:
			return m.source_name
	return ""


func is_condition_immune(c: StringName) -> bool:
	return condition_immunity_source(c) != ""


func add_condition(c: StringName, source: String = "") -> bool:
	if c == &"exhaustion":
		return add_exhaustion(1)
	if is_condition_immune(c):
		log_event({"type": "condition_immune", "creature": id, "condition": str(c)})
		return false
	var sources: Array = conditions.get(c, [])
	if not source in sources:
		sources.append(source)
	conditions[c] = sources
	log_event({"type": "condition_applied", "creature": id, "condition": str(c), "source": source})
	_after_conditions_changed()
	return true


## Removes one source of a condition, or every source when `source` is empty.
func remove_condition(c: StringName, source: String = "") -> void:
	if not conditions.has(c):
		return
	if source == "":
		conditions.erase(c)
	else:
		var sources := conditions[c] as Array
		sources.erase(source)
		if sources.is_empty():
			conditions.erase(c)
	log_event({"type": "condition_removed", "creature": id, "condition": str(c)})


func add_exhaustion(levels: int = 1) -> bool:
	if is_condition_immune(&"exhaustion"):
		return false
	exhaustion = clampi(exhaustion + levels, 0, 6)
	log_event({"type": "exhaustion", "creature": id, "level": exhaustion})
	if exhaustion >= 6:
		_die("Exhaustion level 6")
	return true


## Every condition in force, including those from effects and the ones they imply
## (Unconscious -> Incapacitated, Prone).
func active_conditions() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: StringName in conditions:
		if not c in out:
			out.append(c)
	for e in effects:
		for c in e.conditions:
			if not c in out:
				out.append(c)
	if exhaustion > 0 and not &"exhaustion" in out:
		out.append(&"exhaustion")
	var i := 0
	while i < out.size():
		var data := compendium.condition_data(out[i])
		for implied: Variant in data.get("implies", []):
			var ic := StringName(str(implied))
			if not ic in out:
				out.append(ic)
		i += 1
	return out


func has_condition(c: StringName) -> bool:
	return c in active_conditions()


func condition_sources(c: StringName) -> Array[String]:
	var out: Array[String] = []
	for s: Variant in conditions.get(c, []):
		out.append(str(s))
	for e in effects:
		if c in e.conditions:
			out.append(e.name)
	return out


func _modifiers_of_condition(c: StringName) -> Array[Modifier]:
	if not _condition_mods.has(c):
		var list: Array[Modifier] = []
		var data := compendium.condition_data(c)
		for d: Variant in data.get("modifiers", []):
			list.append(Modifier.make(d as Dictionary, str(data.get("name", str(c).capitalize())), &"condition", str(c)))
		_condition_mods[c] = list
	return _condition_mods[c] as Array[Modifier]


func _after_conditions_changed() -> void:
	if not has_flag("no_concentration"):
		return
	if concentration != null:
		concentration.end("Incapacitated")
	for e: Effect in effects.duplicate():
		if e.ends_when_incapacitated:
			remove_effect(e)


# --- Effects and Concentration -------------------------------------------------------------------

func add_effect(e: Effect) -> bool:
	var kept: Array[StringName] = []
	var had_conditions := not e.conditions.is_empty()
	for c in e.conditions:
		if is_condition_immune(c):
			log_event({"type": "condition_immune", "creature": id, "condition": str(c), "source": e.name})
		else:
			kept.append(c)
	e.conditions = kept
	if had_conditions and kept.is_empty() and e.modifiers.is_empty():
		return false
	effects.append(e)
	log_event({"type": "effect_added", "creature": id, "effect": e.name})
	_after_conditions_changed()
	return true


func remove_effect(e: Effect) -> void:
	if e in effects:
		effects.erase(e)
		log_event({"type": "effect_removed", "creature": id, "effect": e.name})
		if e.on_end.is_valid():
			var f := e.on_end
			e.on_end = Callable()
			f.call()


func remove_effects_named(effect_name: String) -> void:
	for e: Effect in effects.duplicate():
		if (e as Effect).name == effect_name:
			remove_effect(e as Effect)


## Starts Concentration on something new, ending any previous Concentration first.
func begin_concentration(source_id: String, label: String) -> Concentration:
	if concentration != null:
		concentration.end("started concentrating on %s" % label)
	concentration = Concentration.new(self, source_id, label)
	log_event({"type": "concentration_started", "creature": id, "source": source_id})
	return concentration


## Turn bookkeeping: call for every creature when anyone's turn starts or ends.
func on_turn_start(active_creature_id: String) -> void:
	for e: Effect in effects.duplicate():
		if (e as Effect).on_turn_start(active_creature_id):
			remove_effect(e as Effect)


func on_turn_end(active_creature_id: String) -> void:
	for e: Effect in effects.duplicate():
		if (e as Effect).on_turn_end(active_creature_id):
			remove_effect(e as Effect)


func advance_minutes(minutes: int) -> void:
	for e: Effect in effects.duplicate():
		if (e as Effect).advance_minutes(minutes):
			remove_effect(e as Effect)


# --- Resources and rests -------------------------------------------------------------------------

func set_resource(res_id: String, res_name: String, maximum: int, recharge: String, source: String = "") -> void:
	var used := 0
	if resources.has(res_id):
		used = int((resources[res_id] as Dictionary)["used"])
	resources[res_id] = {"name": res_name, "max": maximum, "used": mini(used, maximum), "recharge": recharge,
		"source": source}


func resource_max(res_id: String) -> int:
	return int((resources.get(res_id, {"max": 0}) as Dictionary)["max"])


func resource_left(res_id: String) -> int:
	if not resources.has(res_id):
		return 0
	var r := resources[res_id] as Dictionary
	return int(r["max"]) - int(r["used"])


func spend_resource(res_id: String, amount: int = 1) -> bool:
	if resource_left(res_id) < amount:
		return false
	var r := resources[res_id] as Dictionary
	r["used"] = int(r["used"]) + amount
	return true


func restore_resource(res_id: String, amount: int = 1) -> void:
	if resources.has(res_id):
		var r := resources[res_id] as Dictionary
		r["used"] = maxi(0, int(r["used"]) - amount)


## Short Rest benefits that aren't Hit Point Dice (Character adds those): "short" resources refill,
## "short_one" resources get one use back.
func finish_short_rest() -> void:
	for res_id: String in resources:
		var r := resources[res_id] as Dictionary
		match str(r["recharge"]):
			"short":
				r["used"] = 0
			"short_one":
				r["used"] = maxi(0, int(r["used"]) - 1)
	for e: Effect in effects.duplicate():
		if (e as Effect).ends == Effect.Ends.SHORT_REST:
			remove_effect(e as Effect)
	unhealable = 0
	log_event({"type": "short_rest", "creature": id})


## Long Rest (2024 glossary): all HP back, Temporary HP gone, Exhaustion -1, every resource refilled.
func finish_long_rest() -> void:
	if dead:
		return
	for res_id: String in resources:
		(resources[res_id] as Dictionary)["used"] = 0
	for e: Effect in effects.duplicate():
		var ends := (e as Effect).ends
		if ends == Effect.Ends.SHORT_REST or ends == Effect.Ends.LONG_REST:
			remove_effect(e as Effect)
	if exhaustion > 0:
		exhaustion -= 1
	temp_hp = 0
	unhealable = 0
	var was_zero := hp == 0
	hp = max_hp()
	if was_zero:
		_wake_from_zero()
	death_successes = 0
	death_failures = 0
	stable = false
	log_event({"type": "long_rest", "creature": id})


# --- Speed, senses, carrying ---------------------------------------------------------------------

func speed(kind: String = "walk") -> Breakdown:
	var b := Breakdown.new("%s Speed" % kind.capitalize() if kind != "walk" else "Speed")
	var base := int(base_speed.get(kind, 0))
	var ctx := formula_context()
	for m in modifiers_for(&"speed_set"):
		var v := _speed_set_value(m, ctx, kind)
		if v > 0 and m.text("kind", "walk") == kind and v > base:
			base = v
	if base <= 0:
		b.add("No %s speed" % kind, 0)
		return b
	b.add(base_label if base_label != "Base" else "Base", base)
	var situation := armor_situation()
	for m in modifiers_for(&"speed"):
		var k := m.text("kind", "walk")
		if (k == "walk" or k == kind) and m.applies_when(situation):
			b.add_nonzero(m.source_name, mod_value(m, ctx))
	_speed_adjustments(b)
	for m in modifiers_for(&"speed_percent"):
		var pct := mod_value(m, ctx)
		var now := b.sum()
		b.add(m.source_name, now * pct / 100 - now)
	for m in modifiers_for(&"speed_set"):
		if m.text("kind", "walk") == kind and _speed_set_value(m, ctx, kind) == 0:
			b.set_override(0, m.source_name)
	if b.sum() < 0:
		b.set_floor(0, "minimum 0")
	return b


## Character adds the heavy-armor Strength penalty here.
## A speed_set value: a number, or "walk" for a speed equal to the creature's walking Speed (Potion of Flying).
func _speed_set_value(m: Modifier, ctx: Dictionary, kind: String) -> int:
	if m.text("value") == "walk":
		return int(base_speed.get("walk", 0)) if kind == "walk" else speed("walk").total()
	return mod_value(m, ctx)


func _speed_adjustments(_b: Breakdown) -> void:
	pass


func darkvision() -> int:
	var best := int(base_senses.get("darkvision", 0))
	var ctx := formula_context()
	for m in modifiers_for(&"darkvision"):
		best = maxi(best, mod_value(m, ctx))
	return best


## Range in feet of a special sense (blindsight, tremorsense, truesight), from the stat block or modifiers.
func sense_range(kind: String) -> int:
	var best := int(base_senses.get(kind, 0))
	var ctx := formula_context()
	for m in modifiers_for(&"sense"):
		if m.text("kind") == kind:
			best = maxi(best, mod_value(m, ctx))
	return best


func carrying_capacity() -> Breakdown:
	var b := Breakdown.new("Carrying capacity (lb)")
	var step := 0
	var ctx := formula_context()
	for m in modifiers_for(&"carry_size_step"):
		step += mod_value(m, ctx)
	var idx := clampi(SIZES.find(size) + step, 0, SIZES.size() - 1)
	var mult := float(CARRY_MULTIPLIER[SIZES[idx]])
	b.add("Strength %d × %s" % [ability_score(&"str"), str(mult)], int(ability_score(&"str") * mult))
	return b


func ac_value() -> int:
	return armor_class().total()


func _add_ac_modifiers(b: Breakdown, situation: Dictionary) -> void:
	var ctx := formula_context()
	for m in modifiers_for(&"ac"):
		if m.applies_when(situation):
			b.add_nonzero(m.source_name, mod_value(m, ctx))
	for m in modifiers_for(&"ac_min"):
		b.set_floor(mod_value(m, ctx), m.source_name)


# --- Events --------------------------------------------------------------------------------------

func log_event(e: Dictionary) -> void:
	events.append(e)
	if events.size() > MAX_EVENTS:
		events.pop_front()


func drain_events() -> Array[Dictionary]:
	var out := events.duplicate()
	events.clear()
	return out


## Runtime state that changes in play (not the build): saved with the game.
func state_to_dict() -> Dictionary:
	var conds := {}
	for c: StringName in conditions:
		conds[str(c)] = (conditions[c] as Array).duplicate()
	var res := {}
	for k: String in resources:
		res[k] = int((resources[k] as Dictionary)["used"])
	var fx: Array = []
	for e in effects:
		fx.append(e.to_dict())
	return {"hp": hp, "temp_hp": temp_hp, "ward_hp": ward_hp, "exhaustion": exhaustion, "death_successes": death_successes,
		"death_failures": death_failures, "stable": stable, "dead": dead, "conditions": conds,
		"resources_used": res, "effects": fx, "unhealable": unhealable,
		"concentration": {"source": concentration.source_id, "name": concentration.name} if concentration != null else {}}


func state_from_dict(d: Dictionary) -> void:
	hp = int(d.get("hp", hp))
	temp_hp = int(d.get("temp_hp", 0))
	ward_hp = int(d.get("ward_hp", 0))
	unhealable = int(d.get("unhealable", 0))
	exhaustion = int(d.get("exhaustion", 0))
	death_successes = int(d.get("death_successes", 0))
	death_failures = int(d.get("death_failures", 0))
	stable = bool(d.get("stable", false))
	dead = bool(d.get("dead", false))
	conditions.clear()
	var conds := d.get("conditions", {}) as Dictionary
	for c: String in conds:
		conditions[StringName(c)] = (conds[c] as Array).duplicate()
	var used := d.get("resources_used", {}) as Dictionary
	for k: String in used:
		if resources.has(k):
			(resources[k] as Dictionary)["used"] = int(used[k])
	effects.clear()
	for ed: Variant in d.get("effects", []):
		effects.append(Effect.from_dict(ed as Dictionary))
	var conc := d.get("concentration", {}) as Dictionary
	concentration = Concentration.new(self, str(conc["source"]), str(conc["name"])) if not conc.is_empty() else null


## After loading several creatures: reattaches Concentration links (effects on anyone, cast by these casters).
static func relink_concentration(creatures: Array[Creature], saved: Dictionary) -> void:
	var by_id := {}
	for c in creatures:
		by_id[c.id] = c
	for c in creatures:
		var effs := (saved.get(c.id, {}) as Dictionary).get("effects", []) as Array
		for i in mini(effs.size(), c.effects.size()):
			var info := ((effs[i] as Dictionary).get("concentration", {}) as Dictionary)
			var caster_id := str(info.get("caster", ""))
			if caster_id == "" or not by_id.has(caster_id):
				continue
			var caster := by_id[caster_id] as Creature
			if caster.concentration != null and caster.concentration.source_id == str(info.get("source", "")):
				caster.concentration.relink(c, c.effects[i])
