class_name MagicItems
extends RefCounted
## Magic item rules shared by characters, combat, the UI and treasure (2024 DMG "Magic Items", ADR 0011):
## rarity and price, attunement requirements, where an item has to be worn or held to work, charges, and the
## items built on a base weapon or armor ("+1 Longsword" is the "weapon_plus_1" template on "longsword", id
## "weapon_plus_1__longsword"; Compendium.item_data builds it on first use).

const SEP := "__"
const RARITIES: Array[String] = ["common", "uncommon", "rare", "very_rare", "legendary", "artifact"]
## 2024 DMG "Magic Item Prices" (consumables cost half).
const PRICE := {"common": 100, "uncommon": 400, "rare": 4000, "very_rare": 40000, "legendary": 200000, "artifact": 0}
## Where a worn item goes (2024 DMG "Wearing and Wielding Items": one pair of boots, gloves or bracers, one cloak,
## one item of headwear...). Rings: one per hand. Ioun Stones orbit the head, as many as you like.
const WORN_SLOTS: Array[String] = ["head", "eyes", "neck", "cloak", "robe", "wrists", "hands", "belt", "feet", "ring", "ioun"]
const SLOT_CAPACITY := {"ring": 2, "ioun": 99}
const SLOT_NAMES := {"head": "Head", "eyes": "Eyes", "neck": "Neck", "cloak": "Cloak", "robe": "Robe", "wrists": "Wrists",
	"hands": "Hands", "belt": "Belt", "feet": "Feet", "ring": "Ring", "ioun": "Orbiting the head"}
const CLASSES: Array[String] = ["barbarian", "bard", "cleric", "druid", "fighter", "monk", "paladin", "ranger", "rogue",
	"sorcerer", "warlock", "wizard"]
## Spell Scroll save DC by the spell's level (2024 DMG; the attack bonus is the DC - 8).
const SCROLL_DC: Array[int] = [13, 13, 13, 15, 15, 17, 17, 18, 18, 19]
## Spell Scroll rarity by the spell's level.
const SCROLL_RARITY: Array[String] = ["common", "common", "uncommon", "uncommon", "rare", "rare", "very_rare", "very_rare",
	"very_rare", "legendary"]
const SPECIES: Array[String] = ["aasimar", "dragonborn", "dwarf", "elf", "gnome", "goliath", "halfling", "human", "orc",
	"tiefling"]


static func is_magic(item: Dictionary) -> bool:
	return item.has("magic")


static func rarity(item: Dictionary) -> String:
	return str((item.get("magic", {}) as Dictionary).get("rarity", ""))


static func needs_attunement(item: Dictionary) -> bool:
	var needs: Variant = (item.get("magic", {}) as Dictionary).get("attunement", false)
	return (needs is bool and bool(needs)) or (needs is String and str(needs) != "")


## "by a Wizard", "" when anyone may attune.
static func attunement_text(item: Dictionary) -> String:
	var needs: Variant = (item.get("magic", {}) as Dictionary).get("attunement", false)
	return str(needs) if needs is String else ""


static func is_cursed(item: Dictionary) -> bool:
	return bool((item.get("magic", {}) as Dictionary).get("cursed", false))


## The worn slot an item needs ("" = not a worn item).
static func worn_slot(item: Dictionary) -> String:
	return str(item.get("worn", ""))


## Items that work only while held in a hand: wands, rods and staffs, unless the data says otherwise.
static func is_held(item: Dictionary) -> bool:
	if item.has("held"):
		return bool(item["held"])
	return str(item.get("category", "")) in ["wand", "rod", "staff"]


## The mundane item underneath (a +1 Longsword's "longsword"); the item's own id otherwise.
static func base_id(item: Dictionary) -> String:
	return str(item.get("base_item", item.get("id", "")))


static func is_consumable(item: Dictionary) -> bool:
	if item.has("consumable"):
		return bool(item["consumable"])
	return str(item.get("category", "")) in ["potion", "scroll"]


## Price in gp for a rarity (half for consumables); a spell scroll's level decides its rarity.
static func price_for(rarity_: String, consumable: bool) -> float:
	var p := float(PRICE.get(rarity_, 0))
	return p / 2.0 if consumable else p


# --- Charges ----------------------------------------------------------------------------------------

static func charges(item: Dictionary) -> Dictionary:
	return (item.get("magic", {}) as Dictionary).get("charges", {}) as Dictionary


static func has_charges(item: Dictionary) -> bool:
	return not charges(item).is_empty()


## The charges a new item starts with: a number, or dice rolled once ("1d6+3" beads, "1d8+1" Nine Lives Stealer;
## the average without a roller).
static func starting_charges(item: Dictionary, dice: DiceRoller) -> int:
	var spec := charges(item)
	var start: Variant = spec.get("start", spec.get("max", 0))
	if start is String and str(start).contains("d"):
		if dice == null:
			return floori(Gear.average(str(start)))
		return int(dice.roll_expr(str(start), "%s charges" % item.get("name", ""))["total"])
	return int(start)


static func max_charges(item: Dictionary, entry: Dictionary) -> int:
	var spec := charges(item)
	var m: Variant = spec.get("max", 0)
	if m is String and str(m).contains("d"):
		return int(entry.get("max_charges", entry.get("charges", 0)))
	return int(m)


# --- Items built on a base weapon or armor -----------------------------------------------------------

static func is_template(item: Dictionary) -> bool:
	return item.has("template")


## Whether `base` (a mundane weapon, armor, shield or ammunition) can carry the template `t`.
static func template_fits(t: Dictionary, base: Dictionary) -> bool:
	var spec := t.get("template", {}) as Dictionary
	var on := str(spec.get("on", "weapon"))
	var bid := str(base.get("id", ""))
	if bid in (spec.get("exclude", []) as Array):
		return false
	var items := spec.get("items", []) as Array
	if not items.is_empty():
		return bid in items
	match on:
		"weapon":
			if not Gear.is_weapon(base):
				return false
			var kinds := spec.get("kinds", []) as Array
			if not kinds.is_empty() and not Gear.weapon_kind(base) in kinds:
				return false
			var types := spec.get("damage_types", []) as Array
			if not types.is_empty() and not str((base["weapon"] as Dictionary).get("damage_type", "")) in types:
				return false
			for p: Variant in spec.get("properties", []):
				if not str(p) in Gear.weapon_props(base):
					return false
			return true
		"armor":
			if not Gear.is_armor(base):
				return false
			var akinds := spec.get("kinds", []) as Array
			return akinds.is_empty() or str((base["armor"] as Dictionary).get("kind", "")) in akinds
		"shield":
			return Gear.is_shield(base)
		"ammunition":
			return str(base.get("category", "")) == "ammunition"
		"weapon_or_ammunition":
			return Gear.is_weapon(base) and not Gear.is_ranged_weapon(base) or str(base.get("category", "")) == "ammunition"
	return false


## The bases a template can sit on, from `pool` (every mundane item), sorted by id.
static func bases_for(t: Dictionary, pool: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in pool:
		if template_fits(t, b):
			out.append(str(b["id"]))
	out.sort()
	return out


## The finished item: the base's weapon or armor block (patched), the template's magic, powers and text.
static func combine(t: Dictionary, base: Dictionary, id: String) -> Dictionary:
	var spec := t.get("template", {}) as Dictionary
	var out := base.duplicate(true)
	out["id"] = id
	out["base_item"] = str(base["id"])
	out["template_id"] = str(t["id"])
	var pattern := str(spec.get("name", "{base} (%s)" % t.get("name", "")))
	out["name"] = pattern.replace("{base}", str(base.get("name", base["id"])))
	for k: String in ["source", "magic", "modifiers", "powers", "summary", "text", "worn", "held", "weapon_rules",
			"armor_rules", "light", "consumable", "theme", "treasure", "variant_of"]:
		if t.has(k):
			out[k] = (t[k] as Variant) if not (t[k] is Dictionary or t[k] is Array) else t[k].duplicate(true)
	out["icon"] = str(t.get("icon", base.get("icon", base["id"])))
	if t.has("cost_gp"):
		out["cost_gp"] = float(base.get("cost_gp", 0)) + float(t["cost_gp"])
	if spec.has("weapon_patch") and out.has("weapon"):
		_patch(out["weapon"] as Dictionary, spec["weapon_patch"] as Dictionary)
	if spec.has("armor_patch") and out.has("armor"):
		_patch(out["armor"] as Dictionary, spec["armor_patch"] as Dictionary)
	if spec.has("weight_mult"):
		out["weight_lb"] = float(base.get("weight_lb", 0)) * float(spec["weight_mult"])
	return out


static func _patch(block: Dictionary, patch: Dictionary) -> void:
	for k: String in patch:
		match k:
			"properties_add":
				var props := (block.get("properties", []) as Array).duplicate()
				for p: Variant in patch[k]:
					if not p in props:
						props.append(p)
				block["properties"] = props
			"properties_remove":
				var props2 := (block.get("properties", []) as Array).duplicate()
				for p: Variant in patch[k]:
					props2.erase(p)
				block["properties"] = props2
			_:
				if patch[k] == null:
					block.erase(k)
				else:
					block[k] = patch[k]


# --- Attunement requirements ---------------------------------------------------------------------------

## "" if `ch` meets the item's "by a ..." requirement, else the requirement. Classes, "spellcaster" and species are
## checked; alignment isn't tracked in the game, so alignment requirements always pass (deviations.md).
static func requirement_blocker(item: Dictionary, ch: Character) -> String:
	# Items that need others worn first (Hammer of Thunderbolts: a Belt of Giant Strength and Gauntlets of Ogre Power).
	var needs := item.get("attune_requires", []) as Array
	if not needs.is_empty() and not ch._wearing_all(needs):
		return "Wear %s first" % " and ".join(needs.map(func(x: Variant) -> String: return str(x).replace("_", " ").capitalize()))
	var req := attunement_text(item).to_lower()
	if req == "":
		return ""
	# Dwarven Thrower: "by a Dwarf or a creature attuned to a Belt of Dwarvenkind".
	if req.contains("belt of dwarvenkind") and "belt_of_dwarvenkind" in ch.attuned:
		return ""
	var named_class := false
	for cls in CLASSES:
		if req.contains(cls):
			named_class = true
			if ch.class_level_of(cls) > 0:
				return ""
	var named_species := false
	for sp in SPECIES:
		if req.contains(sp):
			named_species = true
			if str(ch.build.get("species", "")) == sp:
				return ""
	if req.contains("spellcaster"):
		if not ch.spellcasting.is_empty() or not ch.granted_spells.is_empty():
			return ""
		return "Requires attunement %s" % attunement_text(item)
	if named_class or named_species:
		return "Requires attunement %s" % attunement_text(item)
	return ""


# --- Powers and recipes ------------------------------------------------------------------------------

## The item whose recipes a power names: a variant's template ("flame_tongue" for "flame_tongue__longsword").
static func recipe_owner(item_id: String) -> String:
	return item_id.get_slice(SEP, 0)


## The powers an item gives: its own `powers`, or the implicit ones (a potion's Bonus Action drink, a scroll's reading).
static func powers_of(item: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Variant in item.get("powers", []):
		out.append(p as Dictionary)
	if not out.is_empty():
		return out
	var cat := str(item.get("category", ""))
	if cat == "potion" and item.has("effects"):
		out.append({"id": "drink", "name": "Drink", "cost": "bonus", "recipe": "drink", "consume": true, "field": true,
			"text": "Bonus Action: drink it, or give it to a creature within 5 ft."})
	elif item.has("scroll_spell"):
		out.append({"id": "read", "name": "Read", "spell": str(item["scroll_spell"]), "scroll": true, "consume": true,
			"field": true, "requires": "anyone", "text": "Cast the spell written on it, if it's on your class's spell list."})
	return out


## Spell recipes an item defines (`recipes`) plus the implicit potion recipe: drinking applies the potion's `effects` to
## the drinker (or a creature within 5 ft it's given to) for the potion's `duration`.
static func recipes_of(item: Dictionary) -> Dictionary:
	var out := (item.get("recipes", {}) as Dictionary).duplicate(true)
	if str(item.get("category", "")) == "potion" and item.has("effects") and not out.has("drink"):
		var heals := false
		for fx: Variant in item["effects"]:
			if str((fx as Dictionary).get("effect", "")) == "heal":
				heals = true
		out["drink"] = {"name": str(item.get("name", "")), "level": 0, "targets": {"kind": "creature", "count": 1},
			"range": {"kind": "touch"}, "effects": (item["effects"] as Array).duplicate(true),
			"duration": item.get("duration", {"kind": "instantaneous"}), "tags": ["healing"] if heals else ["buff"],
			"components": {}}
	return out


# --- A new item's own state ----------------------------------------------------------------------------

## Prayer bead types (2024 DMG, d20): 1-6 Blessing, 7-12 Curing, 13-16 Favor, 17-18 Smiting, 19 Summons, 20 Wind Walking.
const BEADS: Array[String] = ["blessing", "blessing", "blessing", "blessing", "blessing", "blessing", "curing", "curing", "curing",
	"curing", "curing", "curing", "favor", "favor", "favor", "favor", "smiting", "smiting", "summons", "wind_walking"]
## Robe of Useful Items: the six pairs it always has, then 4d4 rolled on its table (d100 bands, condensed to equal odds).
const ROBE_FIXED: Array[String] = ["dagger", "dagger", "bullseye_lantern", "bullseye_lantern", "mirror", "mirror", "pole", "pole",
	"rope", "rope", "sack", "sack"]
const ROBE_RANDOM: Array[String] = ["bag_of_100_gp", "silver_coffer", "iron_door", "ten_gems", "wooden_ladder", "riding_horse", "pit",
	"potions_of_healing", "rowboat", "spell_scroll", "mastiffs", "window", "portable_ram"]
## Artifact properties (2024 DMG "Artifact Properties", condensed to what the game can play): each is modifiers.
const ARTIFACT_PROPERTIES := {
	"minor_beneficial": [
		{"text": "proficiency in Perception", "modifiers": [{"stat": "proficiency", "kind": "skill", "value": "perception"}]},
		{"text": "Immunity to disease", "modifiers": [{"stat": "flag", "value": "immune_disease"}]},
		{"text": "you can't be Charmed or Frightened", "modifiers": [{"stat": "condition_immunity", "value": "charmed"}, {"stat": "condition_immunity", "value": "frightened"}]},
		{"text": "Resistance to Fire damage", "modifiers": [{"stat": "resistance", "value": "fire"}]},
		{"text": "Resistance to Necrotic damage", "modifiers": [{"stat": "resistance", "value": "necrotic"}]},
		{"text": "Darkvision 60 ft", "modifiers": [{"stat": "darkvision", "value": 60}]},
		{"text": "Advantage on Initiative", "modifiers": [{"stat": "advantage", "on": "initiative"}]},
		{"text": "proficiency in Insight", "modifiers": [{"stat": "proficiency", "kind": "skill", "value": "insight"}]}],
	"major_beneficial": [
		{"text": "+2 Strength (to 24)", "modifiers": [{"stat": "ability", "ability": "str", "value": 2, "max": 24}]},
		{"text": "+2 Constitution (to 24)", "modifiers": [{"stat": "ability", "ability": "con", "value": 2, "max": 24}]},
		{"text": "+2 Wisdom (to 24)", "modifiers": [{"stat": "ability", "ability": "wis", "value": 2, "max": 24}]},
		{"text": "+1 to Armor Class", "modifiers": [{"stat": "ac", "value": 1}]},
		{"text": "regain 1d6 Hit Points at the start of each of your turns", "modifiers": [{"stat": "flag", "value": "artifact_regeneration"}]},
		{"text": "Immunity to Poison damage", "modifiers": [{"stat": "immunity", "value": "poison"}]}],
	"minor_detrimental": [
		{"text": "Disadvantage on Perception checks", "modifiers": [{"stat": "disadvantage", "on": "check:perception"}]},
		{"text": "Vulnerability to Radiant damage", "modifiers": [{"stat": "vulnerability", "value": "radiant"}]},
		{"text": "-5 ft Speed", "modifiers": [{"stat": "speed", "value": -5}]},
		{"text": "Disadvantage on Persuasion checks", "modifiers": [{"stat": "disadvantage", "on": "check:persuasion"}]}],
	"major_detrimental": [
		{"text": "-2 Charisma", "modifiers": [{"stat": "ability", "ability": "cha", "value": -2}]},
		{"text": "Disadvantage on Death Saving Throws", "modifiers": [{"stat": "disadvantage", "on": "death_save"}]},
		{"text": "Vulnerability to Psychic damage", "modifiers": [{"stat": "vulnerability", "value": "psychic"}]}],
}


## The state a newly made item starts with: charges, a Helm of Brilliance's gems, prayer beads, a Robe of Useful Items'
## patches, a Ring of Spell Storing's stored spells, an artifact's random properties.
static func init_state(item: Dictionary, dice: DiceRoller, comp: Compendium = null) -> Dictionary:
	var st := {}
	if has_charges(item):
		st["charges"] = starting_charges(item, dice)
		if str(charges(item).get("max", "")).contains("d"):
			st["max_charges"] = int(st["charges"])
	var tid := str(item.get("template_id", item.get("id", "")))
	match tid:
		"helm_of_brilliance":
			st["gems"] = {"diamond": dice.roll_expr("1d10", "Diamonds")["total"], "ruby": dice.roll_expr("2d10", "Rubies")["total"],
				"fire_opal": dice.roll_expr("3d10", "Fire opals")["total"], "opal": dice.roll_expr("4d10", "Opals")["total"]}
		"necklace_of_prayer_beads":
			var beads: Array = []
			for i in int(dice.roll_expr("1d4+2", "Prayer beads")["total"]):
				beads.append(BEADS[dice.roll_one(20, "Bead type") - 1])
			st["beads"] = beads
		"robe_of_useful_items":
			var patches: Array = ROBE_FIXED.duplicate()
			for i in int(dice.roll_expr("4d4", "Patches")["total"]):
				patches.append(ROBE_RANDOM[dice.roll_one(ROBE_RANDOM.size(), "Patch") - 1])
			st["patches"] = patches
		"ring_of_spell_storing":
			var levels := maxi(0, int(dice.roll_expr("1d6-1", "Stored spell levels")["total"]))
			st["stored"] = _random_stored(levels, dice, comp)
	var art := item.get("artifact", {}) as Dictionary
	if not art.is_empty():
		var props: Array = []
		var counts := art.get("properties", {}) as Dictionary
		for kind: String in counts:
			var table := ARTIFACT_PROPERTIES.get(kind, []) as Array
			for i in int(counts[kind]):
				if not table.is_empty():
					props.append(table[dice.roll_one(table.size(), "Artifact property") - 1])
		st["artifact_properties"] = props
	return st


## Spells someone stored in a ring found as treasure: random level 1-5 spells adding up to `levels` (DC 15, +7).
static func _random_stored(levels: int, dice: DiceRoller, comp: Compendium) -> Array:
	var out: Array = []
	if comp == null or levels <= 0:
		return out
	var left := levels
	var guard := 0
	while left > 0 and guard < 20:
		guard += 1
		var lvl := dice.roll_one(mini(5, left), "Stored spell level")
		var pool := comp.spells_for("", lvl)
		if pool.is_empty():
			break
		var sp := pool[dice.roll_one(pool.size(), "Stored spell") - 1]
		out.append({"spell": str(sp["id"]), "level": lvl, "dc": 15, "attack": 7, "ability": "int"})
		left -= lvl
	return out


# --- Spell Scrolls --------------------------------------------------------------------------------------

## "spell_scroll__fireball": a Spell Scroll holding that spell, its rarity and price by the spell's level.
static func combine_scroll(t: Dictionary, spell: Dictionary, id: String) -> Dictionary:
	var lvl := clampi(int(spell.get("level", 0)), 0, 9)
	var out := t.duplicate(true)
	out.erase("template")
	out["id"] = id
	out["template_id"] = str(t["id"])
	out["name"] = "Spell Scroll (%s)" % spell.get("name", "")
	out["scroll_spell"] = str(spell["id"])
	var rar := SCROLL_RARITY[lvl]
	out["magic"] = {"rarity": rar, "attunement": false}
	out["cost_gp"] = price_for(rar, true)
	out["summary"] = "A level %d spell, %s: read it to cast it if it's on your class's spell list (DC %d, %+d)." % [lvl,
		spell.get("name", ""), SCROLL_DC[lvl], SCROLL_DC[lvl] - 8] if lvl > 0 else "The %s cantrip: read it to cast it if it's on your class's spell list (DC 13, +5)." % spell.get("name", "")
	return out
