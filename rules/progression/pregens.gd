class_name Pregens
extends RefCounted
## Pregenerated characters (plan §5.6 Start step) built to any level by their level plan, for quick starts, the
## combat arena and tests.


## The pregen `id` levelled to `level`, or null if its data doesn't build (errors go to `errors`).
static func build(id: String, level: int = 1, errors: Array[String] = []) -> Character:
	var comp := Compendium.shared()
	var data := comp.get_entry("pregens", id)
	if data.is_empty():
		errors.append("No pregen '%s'" % id)
		return null
	var builder := CharacterBuilder.new(comp, data["build"] as Dictionary)
	var ch := builder.build_character()
	if ch == null:
		errors.append("%s doesn't build: %s" % [id, builder.errors()])
		return null
	for step: Variant in data.get("level_plan", []):
		var plan := step as Dictionary
		if int(plan["level"]) > level:
			break
		var up := LevelUpController.new(ch)
		up.choose_class(str(plan["class"]))
		if int(plan.get("hp", 0)) > 0:
			((up.build["levels"] as Array).back() as Dictionary)["hp"] = int(plan["hp"])
		var choices := plan.get("choices", {}) as Dictionary
		for key: String in choices:
			up.choose(key, choices[key] as Array)
		if not up.confirm():
			errors.append("%s level %d: %s" % [id, plan["level"], up.errors()])
			return null
	# The level plans reach the campaign's cap (11, ADR 0011); past it the pregen stays at its plan's last level.
	if ch.character_level() < level:
		errors.append("%s's level plan stops at level %d" % [id, ch.character_level()])
	return ch


## The pregens the player chooses the party from (data `roster: true`), in name order.
static func roster_ids() -> Array[String]:
	var out: Array[String] = []
	var names := {}
	for d in Compendium.shared().all("pregens"):
		if bool(d.get("roster", false)):
			out.append(str(d["id"]))
			names[str(d["id"])] = str(d.get("name", d["id"]))
	out.sort_custom(func(a: String, b: String) -> bool: return str(names[a]) < str(names[b]))
	return out


## Brings a pregen who sat out some milestones up to `level` by their level plan (roster members level with the
## party). Returns false for a character without a plan (a custom hero levels up from the sheet instead).
static func catch_up(ch: Character, level: int) -> bool:
	var data := Compendium.shared().get_entry("pregens", ch.id)
	if data.is_empty() or bool((ch.build.get("appearance", {}) as Dictionary).get("custom", false)):
		return false
	for step: Variant in data.get("level_plan", []):
		var plan := step as Dictionary
		var at := int(plan["level"])
		if at <= ch.character_level():
			continue
		if at > level:
			break
		var up := LevelUpController.new(ch)
		up.choose_class(str(plan["class"]))
		if int(plan.get("hp", 0)) > 0:
			((up.build["levels"] as Array).back() as Dictionary)["hp"] = int(plan["hp"])
		var choices := plan.get("choices", {}) as Dictionary
		for key: String in choices:
			up.choose(key, choices[key] as Array)
		if not up.confirm():
			return false
	return true

