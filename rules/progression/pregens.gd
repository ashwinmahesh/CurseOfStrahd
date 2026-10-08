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
	give_component_kit(ch)
	return ch


## A pregen's starter kit of costly components (2026-10-08): what the spells it knows or has in its spellbook keep
## (Chromatic Orb's diamond, Identify's pearl), enough for the dearest spell of each kind, and two blocks of incense for
## Find Familiar. What a spell uses up (Revivify's diamonds) is bought.
static func give_component_kit(ch: Character) -> void:
	var comp := Compendium.shared()
	var ids: Array[String] = []
	for k in ch.known_spells():
		ids.append(str(k["id"]))
	for sc: Variant in ch.spellcasting:
		for sid: Variant in (sc as Dictionary).get("spellbook", []):
			ids.append(str(sid))
	var need := {}
	for sid in ids:
		var cc := Character.costly_component(comp.spell_data(sid))
		if cc.is_empty() or bool(cc["consumed"]):
			continue
		need[str(cc["material"])] = maxf(float(need.get(str(cc["material"]), 0.0)), float(cc["cost_gp"]))
	for material: String in need:
		var unit := maxf(0.01, float(comp.item_data(material).get("cost_gp", 1.0)))
		var have := ch.material_worth(material)
		if have < float(need[material]):
			ch.add_item(material, ceili((float(need[material]) - have) / unit))
	if "find_familiar" in ids:
		ch.add_item("incense", 2)


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
