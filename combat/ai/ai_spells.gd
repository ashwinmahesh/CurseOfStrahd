class_name AiSpells
extends RefCounted
## Enemy spellcasters at Tactician and Honour (combat/difficulty.gd): each turn the best spell of the stat block's list
## (or the scroll it carries) against the best weapon attack, weighed in the same units as AiBrain's attack scores,
## expected damage. Damage counts by the chance to hit or the chance the save fails (half on a success when the spell
## says so); a condition counts by what it takes away from the target, a creature's whole turn for Paralyzed or
## Unconscious; allies caught in an area count against it. A spell that needs Concentration waits while the caster
## keeps another. Spells that summon, place an object or a wall, teleport, buff or heal are left to the stat block's
## own AI (combat/ai/ai_brain.gd).

## What a condition takes from a creature, as a share of its turn.
const CONDITION_WORTH := {"paralyzed": 2.0, "stunned": 1.8, "unconscious": 1.8, "petrified": 2.0, "incapacitated": 1.5,
	"restrained": 0.7, "blinded": 0.6, "frightened": 0.6, "charmed": 0.5, "poisoned": 0.4, "prone": 0.3, "deafened": 0.1}
## A spell is cast only when it beats the weapon plan by this much (a weapon doesn't spend a daily use).
const OVER_WEAPON := 1.1
const MIN_WORTH := 3.0

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## The scroll a caster carries at Tactician and Honour: the highest-level spell of its daily list that harms or
## hinders ("" when it has none).
static func scroll_pick(m: Monster) -> String:
	var sc := m.data.get("spellcasting", {}) as Dictionary
	var best := ""
	var best_level := -1
	for n: String in (sc.get("per_day", {}) as Dictionary):
		for sid: Variant in (sc["per_day"] as Dictionary)[n]:
			var s := Compendium.shared().spell_data(str(sid))
			if not s.is_empty() and _offensive(s) and int(s.get("level", 0)) > best_level:
				best_level = int(s.get("level", 0))
				best = str(sid)
	return best


## Whether `c` has spells of its own or a scroll to weigh.
static func casts(c: Combatant) -> bool:
	return c.creature is Monster and ((c.creature as Monster).data.has("spellcasting") or scroll_of(c) != "")


## The scroll `c` carries (a spell id), or "".
static func scroll_of(c: Combatant) -> String:
	return str(c.get_meta("scroll", ""))


## The spell `c` would cast this turn, when it's worth more than `weapon` (the weapon plan's expected damage for the
## whole action): {kind: cast, spell, targets, point, direction, score, why, scroll} or {}.
func plan(c: Combatant, weapon: float) -> Dictionary:
	var e := enc()
	if not c.action_available or not c.creature is Monster:
		return {}
	var ids: Array[String] = []
	for sp in e.monster_actions.spells_now(c):
		ids.append(str(sp["id"]))
	var scroll := scroll_of(c)
	if scroll != "" and not scroll in ids and not c.creature.has_flag("cant_cast"):
		ids.append(scroll)
	var best := {}
	var best_s := maxf(MIN_WORTH, weapon * OVER_WEAPON)
	for id in ids:
		var opt := _best_use(c, id)
		if opt.is_empty() or float(opt["score"]) <= best_s:
			continue
		best_s = float(opt["score"])
		best = opt
		best["scroll"] = id == scroll and not _knows(c, id)
	return best


func _knows(c: Combatant, id: String) -> bool:
	for sp in enc().monster_actions.spells_now(c):
		if str(sp["id"]) == id:
			return true
	return false


## The best way to cast `id` now: {kind, spell, targets, point, direction, score, why} or {}.
func _best_use(c: Combatant, id: String) -> Dictionary:
	var e := enc()
	var s := Compendium.shared().spell_data(id)
	if s.is_empty() or not _offensive(s):
		return {}
	if str((s.get("casting_time", {}) as Dictionary).get("unit", "action")) != "action":
		return {}
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)) and c.creature.concentration != null:
		return {}
	var rng := e.spells.range_ft(s, c)
	var foes: Array[Combatant] = []
	for h in e.hostiles_of(c):
		if not h.is_down() and e.can_see(c, h):
			foes.append(h)
	if foes.is_empty():
		return {}
	var self_origin := str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	if s.has("area") and not s.has("attack"):
		var best := {}
		for f in foes:
			var point := e.center_of(f)
			var dir := Vector2.ZERO
			if self_origin:
				dir = (point - e.center_of(c)).normalized()
				point = Vector2.INF
			elif e.distance(c, f) > rng + 5:
				continue
			var cells := e.spells.area_for(c, s, point if point != Vector2.INF else e.center_of(c), dir)
			var score := 0.0
			for v in e.spells.creatures_in(cells):
				if v == c:
					continue
				var w := worth(c, s, v)
				score += -1.5 * w if not c.hostile_to(v) else w
			if not self_origin and str(e.spells._check_targets(c, s, 0, [], point, {})["why"]) != "":
				continue
			if best.is_empty() or score > float(best["score"]):
				best = {"kind": "cast", "spell": id, "targets": [], "point": point, "direction": dir, "score": score,
					"why": "%s at %s" % [s.get("name", id), f.name()]}
		return best
	if str((s.get("targets", {}) as Dictionary).get("kind", "creature")) != "creature":
		return {}
	var levels := (MonsterActions.data_of(c).get("spellcasting", {}) as Dictionary).get("levels", {}) as Dictionary
	var level := int(levels.get(id, s.get("level", 0)))
	var n := maxi(1, e.spells.target_count(s, level))
	var scored: Array[Dictionary] = []
	for f2 in foes:
		if e.distance(c, f2) > rng:
			continue
		if "humanoid" in str((s.get("targets", {}) as Dictionary).get("description", "")).to_lower() and f2.creature.creature_type != &"humanoid":
			continue
		scored.append({"t": f2, "w": worth(c, s, f2)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["w"]) > float(b["w"]))
	var picked: Array = []
	var total := 0.0
	for entry: Dictionary in scored.slice(0, n):
		picked.append(entry["t"])
		total += float(entry["w"])
	if picked.is_empty() or str(e.spells._check_targets(c, s, 0, picked, Vector2.INF, {})["why"]) != "":
		return {}
	return {"kind": "cast", "spell": id, "targets": picked, "point": Vector2.INF, "direction": Vector2.ZERO, "score": total,
		"why": "%s on %s" % [s.get("name", id), ", ".join(picked.map(func(t: Combatant) -> String: return t.name()))]}


## A spell this planner weighs: one that harms or hinders, and that the engine casts in full.
static func _offensive(s: Dictionary) -> bool:
	if str(s.get("automation", "")) == "reference" or s.has("object") or s.has("sustain") or s.has("heal"):
		return false
	var tags := s.get("tags", []) as Array
	return "damage" in tags or "control" in tags or "debuff" in tags


## Expected worth of `s` landing on `t` (damage, plus the turn a condition takes away), by the chance it lands.
func worth(c: Combatant, s: Dictionary, t: Combatant) -> float:
	var e := enc()
	var sc := MonsterActions.data_of(c).get("spellcasting", {}) as Dictionary
	var ab := StringName(str(sc.get("ability", "int")))
	var dmg := 0.0
	for d: Variant in s.get("damage", []):
		var p := DiceRoller.parse_expr(str((d as Dictionary).get("dice", "0")))
		dmg += float(p["count"]) * (float(p["sides"]) + 1.0) / 2.0 + float(p["modifier"])
	var lands := 1.0
	var half := false
	if s.has("attack"):
		var atk := int(sc.get("attack", c.creature.ability_mod(ab) + c.creature.proficiency_bonus())) + _bonus(c, &"spell_attack")
		lands = clampf(float(21 - (t.creature.ac_value() - atk)) / 20.0, 0.05, 0.95)
	elif s.has("save"):
		var dc := int(sc.get("dc", 8 + c.creature.ability_mod(ab) + c.creature.proficiency_bonus())) + _bonus(c, &"spell_dc")
		var bonus := t.creature.save_bonus(StringName(str(s["save"]))).total()
		lands = clampf(float(dc - bonus - 1) / 20.0, 0.0, 1.0)
		half = str(s.get("save_success", "none")) == "half"
	var cond := 0.0
	for cid: Variant in s.get("conditions", []):
		if t.creature.is_condition_immune(StringName(str(cid))):
			continue
		cond = maxf(cond, float(CONDITION_WORTH.get(str(cid), 0.2)))
	var value := lands * (dmg + cond * _threat(t))
	if half:
		value += (1.0 - lands) * dmg / 2.0
	if t.creature.concentration != null and dmg > 0.0:
		value += 1.0
	return value + e.ai.tactics.target_adjust(t, value) * 0.5


## Roughly the damage `t` deals in a turn: what a condition that costs it the turn is worth.
static func _threat(t: Combatant) -> float:
	if t.creature is Character:
		return 4.0 + 1.5 * float((t.creature as Character).character_level())
	return 4.0 + 2.0 * float((t.creature as Monster).data.get("cr", 1))


static func _bonus(c: Combatant, stat: StringName) -> int:
	var total := 0
	var ctx := c.creature.formula_context()
	for m in c.creature.modifiers_for(stat):
		total += c.creature.mod_value(m, ctx)
	return total


## Casts the plan's spell; reading a scroll doesn't spend the stat block's daily use, and the scroll is gone.
func cast(c: Combatant, p: Dictionary) -> CombatResult:
	var e := enc()
	var id := str(p["spell"])
	var key := "cast_%s" % id
	var had: Variant = c.get_meta(key) if c.has_meta(key) else null
	var opts := {}
	if (p.get("direction", Vector2.ZERO) as Vector2) != Vector2.ZERO:
		opts["direction"] = p["direction"]
	if bool(p.get("scroll", false)):
		c.remove_meta("scroll")
		e.log.add("info", "%s reads a Spell Scroll" % c.name(), c.id)
	var r := e.monster_actions.cast(c, id, p["targets"] as Array, p.get("point", Vector2.INF) as Vector2, 0, opts)
	if bool(p.get("scroll", false)):
		if had == null:
			c.remove_meta(key)
		else:
			c.set_meta(key, had)
		if not r.ok and not r.is_paused():
			c.set_meta("scroll", id)   # nothing was cast: the scroll is still whole
	return r
