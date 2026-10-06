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
	return ch
