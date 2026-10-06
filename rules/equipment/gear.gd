class_name Gear
extends RefCounted
## Equipment rules shared by characters and the UI (2024 PHB "Equipment"): weapon and armor proficiency,
## weapon tags for `when` filters, and how a weapon is wielded.

const ARMOR_KINDS: Array[String] = ["light", "medium", "heavy"]
const COIN_GP := {"cp": 0.01, "sp": 0.1, "ep": 0.5, "gp": 1.0, "pp": 10.0}


static func is_weapon(item: Dictionary) -> bool:
	return item.has("weapon")


static func is_armor(item: Dictionary) -> bool:
	return item.has("armor") and str((item["armor"] as Dictionary).get("kind", "")) != "shield"


static func is_shield(item: Dictionary) -> bool:
	return item.has("armor") and str((item["armor"] as Dictionary).get("kind", "")) == "shield"


static func weapon_props(item: Dictionary) -> Array:
	if not is_weapon(item):
		return []
	return (item["weapon"] as Dictionary).get("properties", []) as Array


static func weapon_kind(item: Dictionary) -> String:
	return str((item.get("weapon", {}) as Dictionary).get("kind", ""))


static func is_ranged_weapon(item: Dictionary) -> bool:
	return weapon_kind(item).ends_with("ranged")


static func is_martial(item: Dictionary) -> bool:
	return weapon_kind(item).begins_with("martial")


## Does a list of weapon proficiencies ("simple", "martial", "martial_finesse_or_light", "martial_light", weapon ids) cover
## this weapon?
static func weapon_proficient(profs: Array, item: Dictionary) -> bool:
	if not is_weapon(item):
		return false
	var item_id := str(item.get("id", ""))
	if item_id in profs:
		return true
	var kind := weapon_kind(item)
	if kind.begins_with("simple") and "simple" in profs:
		return true
	if kind.begins_with("martial"):
		if "martial" in profs:
			return true
		var props := weapon_props(item)
		if "martial_finesse_or_light" in profs and ("finesse" in props or "light" in props):
			return true
		if "martial_light" in profs and "light" in props:
			return true
	return false


## Monk weapons (2024): Simple Melee weapons and Martial Melee weapons with the Light property.
static func is_monk_weapon(item: Dictionary) -> bool:
	var kind := weapon_kind(item)
	if kind == "simple_melee":
		return true
	return kind == "martial_melee" and "light" in weapon_props(item)


## Average of a dice expression, for picking the best weapon to hold.
static func average(expr: String) -> float:
	var p := DiceRoller.parse_expr(expr)
	return int(p["count"]) * (int(p["sides"]) + 1) / 2.0 + int(p["modifier"])


## Coins to gold value.
static func gp_value(coins: Dictionary) -> float:
	var total := 0.0
	for k: String in COIN_GP:
		total += int(coins.get(k, 0)) * float(COIN_GP[k])
	return total
