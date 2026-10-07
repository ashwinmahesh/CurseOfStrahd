class_name FaerunCommon
extends RefCounted
## What FaerunFeatures and its helpers (combat/faerun_*.gd) share: the encounter, feat checks, hotbar entries, the
## log, once-per-turn keys and Heroic Inspiration. Each of them extends this.

var _enc: WeakRef

func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func feat(c: Combatant, feat_id: String) -> bool:
	return c != null and enc().features.has_feat(c, feat_id)


static func _ch(c: Combatant) -> Character:
	return c.creature as Character if c != null and c.creature is Character else null


func _entry(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String, rng: int = 0) -> Dictionary:
	return {"id": "feat:fr:" + id, "label": label, "sub": sub, "cost": cost, "why": why, "targeting": targeting, "help": help, "range": rng}


static func _first(a: String, b: String) -> String:
	return a if a != "" else b


func _res_why(c: Combatant, res: String) -> String:
	var ch := _ch(c)
	return "" if ch != null and ch.resource_left(res) > 0 else "None left"


## A benefit marked `"policy"`: on unless its owner turned it Off.
static func allowed(c: Combatant, id: String) -> bool:
	return str(c.reaction_rules.get(id, "auto")) != "never"


func _turn_key() -> String:
	return "%d:%d" % [enc().round_no, enc().turn_index]


## Once per turn (anyone's turn): true the first time, false after.
func _once_per_turn(c: Combatant, key: String) -> bool:
	if str(c.get_meta(key, "")) == _turn_key():
		return false
	c.set_meta(key, _turn_key())
	return true


func _log(kind: String, text: String, who: Combatant, details: Array = []) -> void:
	enc().log.add(kind, text, who.id if who != null else "", details)


## Heroic Inspiration for `t` from `giver`'s feature; false when it already has some (nothing to give).
func _inspire(giver: Combatant, t: Combatant, label: String) -> bool:
	var ch := _ch(t)
	if ch == null or ch.heroic_inspiration:
		return false
	ch.heroic_inspiration = true
	_log("info", "%s gains Heroic Inspiration (%s, from %s)" % [t.name(), label, giver.name()], t)
	return true


## Allies of `c` (not `c`) within `feet` that perceive it and lack Heroic Inspiration, nearest first.
func _uninspired_allies(c: Combatant, feet: int, perceive: Callable) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for a in e.allies_of(c):
		var ch := _ch(a)
		if a == c or ch == null or ch.heroic_inspiration or not a.is_alive() or a.creature.hp <= 0 or e.distance(c, a) > feet:
			continue
		if perceive.call(a):
			out.append(a)
	out.sort_custom(func(x: Combatant, y: Combatant) -> bool: return e.distance(c, x) < e.distance(c, y))
	return out


## FaerunFeatures, for a helper to reach its state and the other helpers.
func faerun() -> FaerunFeatures:
	return enc().faerun
