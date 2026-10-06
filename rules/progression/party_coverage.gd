class_name PartyCoverage
extends RefCounted
## The party composition panel (plan §5.6): what the four characters cover between them, and the gaps,
## pointed out in plain words but never enforced.

const DAMAGE_TYPES: Array[String] = ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic",
	"piercing", "poison", "psychic", "radiant", "slashing", "thunder"]
const HEALING_SPELLS: Array[String] = ["cure_wounds", "healing_word", "mass_healing_word", "prayer_of_healing",
	"aura_of_vitality", "goodberry"]
const LIGHT_SPELLS: Array[String] = ["light", "dancing_lights", "produce_flame", "continual_flame", "daylight"]
const LIGHT_ITEMS: Array[String] = ["torch", "lamp", "hooded_lantern", "bullseye_lantern", "candle"]


## Returns {roles: {healing, front_line, arcane, divine}: [names], skills: {skill: {name, bonus}},
## damage_types: {type: [names]}, darkvision: [names], light: [names], gaps: [sentences]}.
static func analyze(party: Array[Character]) -> Dictionary:
	var roles := {"healing": [], "front_line": [], "arcane": [], "divine": []}
	var skills := {}
	var damage := {}
	var darkvision: Array[String] = []
	var light: Array[String] = []
	for ch in party:
		var known := {}
		for s in ch.known_spells():
			known[str(s["id"])] = true
		for h in HEALING_SPELLS:
			if known.has(h):
				(roles["healing"] as Array).append(ch.name)
				break
		if ch.ac_value() >= 16 or ch.has_armor_training("heavy"):
			(roles["front_line"] as Array).append(ch.name)
		for e in ch.spellcasting:
			var list := str(e["list"])
			if list in ["wizard", "sorcerer", "warlock", "bard"] and not ch.name in roles["arcane"]:
				(roles["arcane"] as Array).append(ch.name)
			if list in ["cleric", "paladin", "druid", "ranger"] and not ch.name in roles["divine"]:
				(roles["divine"] as Array).append(ch.name)
		for skill: StringName in Abilities.SKILLS:
			var bonus := ch.skill_bonus(skill).total()
			if not skills.has(str(skill)) or bonus > int((skills[str(skill)] as Dictionary)["bonus"]):
				skills[str(skill)] = {"name": ch.name, "bonus": bonus, "proficient": ch.skill_rank(skill) > 0}
		for a in ch.attacks():
			_add(damage, str(a.damage_type), ch.name)
		for s: String in known:
			var spell := ch.compendium.spell_data(s)
			for d: Variant in spell.get("damage", []):
				var dd := d as Dictionary
				if dd.has("type"):
					_add(damage, str(dd["type"]), ch.name)
				for t: Variant in dd.get("type_choice", []):
					_add(damage, str(t), ch.name)
		if ch.darkvision() > 0:
			darkvision.append(ch.name)
		var has_light := false
		for l in LIGHT_SPELLS:
			if known.has(l):
				has_light = true
		for entry in ch.inventory:
			if str(entry["id"]) in LIGHT_ITEMS:
				has_light = true
		if has_light:
			light.append(ch.name)
	var gaps: Array[String] = []
	if (roles["healing"] as Array).is_empty():
		gaps.append("Nobody can cast healing spells; carry Potions of Healing and a Healer's Kit.")
	if (roles["front_line"] as Array).is_empty():
		gaps.append("Nobody has heavy armor or AC 16+ to hold the front line.")
	if (roles["arcane"] as Array).is_empty() and (roles["divine"] as Array).is_empty():
		gaps.append("Nobody casts spells; magical problems will need items or allies.")
	var unskilled: Array[String] = []
	for skill: String in skills:
		if not bool((skills[skill] as Dictionary)["proficient"]):
			unskilled.append(skill.replace("_", " ").capitalize())
	if not unskilled.is_empty():
		gaps.append("Nobody is proficient in %s." % ", ".join(unskilled))
	if darkvision.size() < party.size():
		gaps.append("%d of %d characters can't see in the dark; Barovia is dark, so bring light." % [party.size() - darkvision.size(), party.size()])
	if light.is_empty():
		gaps.append("Nobody has a light source or a light cantrip.")
	if not damage.has("radiant"):
		gaps.append("No Radiant damage, which many Barovian undead fear.")
	if not damage.has("fire"):
		gaps.append("No Fire damage.")
	return {"roles": roles, "skills": skills, "damage_types": damage, "darkvision": darkvision, "light": light,
		"gaps": gaps}


static func _add(table: Dictionary, key: String, who: String) -> void:
	if not table.has(key):
		table[key] = []
	if not who in (table[key] as Array):
		(table[key] as Array).append(who)
