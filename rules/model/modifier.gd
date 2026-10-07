class_name Modifier
extends RefCounted
## One rule change from a feature, feat, species trait, item, spell, condition or effect
## (docs/contracts/modifiers.md). It keeps its source so every breakdown can name it.

var stat: StringName
## The raw data object: value, on, when, ability, skill, kind, dice, base, abilities, at_level ...
var data: Dictionary
## Shown in breakdowns and tooltips: "Defense", "Bless", "Dwarven Toughness".
var source_name: String
## class, subclass, species, background, feat, item, spell, condition, effect, monster.
var source_kind: StringName
var source_id: String
## Class whose level `class_level` refers to (class and subclass features).
var class_id: String = ""


static func make(data_: Dictionary, source_name_: String, source_kind_: StringName = &"feature",
		source_id_: String = "", class_id_: String = "") -> Modifier:
	var m := Modifier.new()
	m.data = data_
	m.stat = StringName(str(data_.get("stat", "")))
	m.source_name = source_name_
	m.source_kind = source_kind_
	m.source_id = source_id_
	m.class_id = class_id_
	return m


## Convenience for code-built modifiers: Modifier.of("ac", {"value": 2}, "Shield of Faith").
static func of(stat_: String, fields: Dictionary, source_name_: String, source_kind_: StringName = &"effect") -> Modifier:
	var d := fields.duplicate()
	d["stat"] = stat_
	return make(d, source_name_, source_kind_)


func value_on(ctx: Dictionary) -> int:
	var v := Formula.evaluate(data.get("value", 0), ctx)
	if data.has("min"):
		v = maxi(v, int(data["min"]))
	if data.has("max") and stat != &"ability":
		v = mini(v, int(data["max"]))
	return v


func text(key: String, default: String = "") -> String:
	return str(data.get(key, default))


func number(key: String, default: int = 0) -> int:
	return int(data.get(key, default))


## `on` may be a string or an array of strings.
func on_keys() -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = data.get("on", [])
	if raw is Array:
		for v: Variant in raw:
			out.append(str(v))
	elif str(raw) != "":
		out.append(str(raw))
	return out


func matches_any(keys: Array[String]) -> bool:
	for excluded: Variant in data.get("except", []):
		if str(excluded) in keys:
			return false
	for k in on_keys():
		if k in keys:
			return true
	return false


func at_level() -> int:
	return int(data.get("at_level", 0))


func has_when() -> bool:
	return data.has("when") and not (data["when"] as Dictionary).is_empty()


## Checks the `when` filter against what the caller knows. A filter key the caller can't answer counts as
## not met, so a ranged-only bonus never leaks into a generic number.
##   situation: {armor: "none|light|medium|heavy", shield: bool, weapon_tags: Array, spell: bool,
##               school: String, spell_id: String, bloodied: bool}
## `armor` may also ask for "any" (some armor) or "not_heavy" (none, light or medium).
func applies_when(situation: Dictionary) -> bool:
	if not has_when():
		return true
	var when := data["when"] as Dictionary
	for key: String in when:
		var want: Variant = when[key]
		match key:
			"armor":
				if not situation.has("armor"):
					return false
				var worn := str(situation["armor"])
				if str(want) == "any":
					if worn == "none":
						return false
				elif str(want) == "not_heavy":
					if worn == "heavy":
						return false
				elif worn != str(want):
					return false
			"weapon":
				var tags: Array = situation.get("weapon_tags", [])
				if not str(want) in tags:
					return false
			_:
				if not situation.has(key) or situation[key] != want:
					return false
	return true


func describe() -> String:
	return "%s: %s" % [source_name, JSON.stringify(data)]
