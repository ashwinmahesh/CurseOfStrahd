class_name Character
extends Creature
## A player character or guest built from rules data (plan §5.1, §5.6). `build` is the serializable record of
## every decision; refresh() walks the data (species, background, each class level, subclass, feats) and
## derives features, modifiers, proficiencies, spells, resources and the list of choices with their picks.
## CharacterBuilder and LevelUpController edit copies of `build` and preview them through this class, so
## the UI never computes rules.
##
## build = {
##   name, species, background, ability_method, base_scores {str..cha},
##   levels: [{class, hp}],            # hp: 0 = fixed value, >0 = the rolled die (level 1 always max)
##   choices: {choice key: [picks]},   # see Choice.key
##   equipment: {class: "a", background: "a"}, identity: {...}, appearance: {...}
## }

const STANDARD_LANGUAGES: Array[String] = ["common_sign_language", "draconic", "dwarvish", "elvish", "giant",
	"gnomish", "goblin", "halfling", "orc"]
const RARE_LANGUAGES: Array[String] = ["abyssal", "celestial", "deep_speech", "druidic", "infernal", "primordial",
	"sylvan", "thieves_cant", "undercommon"]
const EQUIP_SLOTS: Array[String] = ["armor", "main_hand", "off_hand"]

var build: Dictionary = {}

# --- Derived by refresh() ---
## {id, name, summary, text, source, source_kind, class_id, level, action, implemented}
var features: Array[Dictionary] = []
var choice_defs: Array[Choice] = []
## kind -> {value: source}. kinds: armor, weapons, tools, languages, saves, skills.
var proficiencies: Dictionary = {}
var expertise: Dictionary = {}
var weapon_masteries: Array[String] = []
## {id, name, source}
var feats_taken: Array[Dictionary] = []
var class_levels: Dictionary = {}
var class_order: Array[String] = []
var subclasses: Dictionary = {}
var lineage: String = ""
var maneuvers: Array[String] = []
## Eldritch Invocations and Metamagic options picked, by id.
var invocations: Array[String] = []
var metamagic: Array[String] = []
## Beast forms a Druid knows for Wild Shape (monster ids).
var wild_shape_forms: Array[String] = []
## One entry per Spellcasting or Pact Magic feature: {class_id, name, ability, list, progression, cantrips_max,
## prepared_max, spellbook_max, cantrips, prepared, spellbook, always, bonus, ritual, feature}; Pact Magic entries
## also carry pact_slots and pact_level.
var spellcasting: Array[Dictionary] = []
## Spells from species, feats and class features: {id, class_id, ability, uses, recharge, always_prepared,
## at_level, source}
var granted_spells: Array[Dictionary] = []
var _modifiers: Array[Modifier] = []
var _increases: Array[Dictionary] = []
var _resource_defs: Array[Dictionary] = []

# --- Runtime state (saved) ---
## {id, qty, slot}  slot = "" or one of EQUIP_SLOTS
var inventory: Array[Dictionary] = []
var currency: Dictionary = {"cp": 0, "sp": 0, "ep": 0, "gp": 0, "pp": 0}
## die size (as String) -> spent count
var hit_dice_spent: Dictionary = {}
var slots_used: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
## Pact Magic slots spent (Warlock); they come back on a Short or Long Rest.
var pact_slots_used: int = 0
var heroic_inspiration: bool = false


static func from_build(build_: Dictionary, compendium_: Compendium = null) -> Character:
	var c := Character.new()
	if compendium_ != null:
		c.compendium = compendium_
	c.build = build_.duplicate(true)
	c.uses_death_saves = true
	c.refresh()
	c.hp = c.max_hp()
	return c


static func empty_build() -> Dictionary:
	return {"name": "", "species": "", "background": "", "ability_method": "standard_array",
		"base_scores": {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10},
		"levels": [], "choices": {}, "equipment": {"class": "a", "background": "a"}, "identity": {}, "appearance": {}}


# --- Level and proficiency -----------------------------------------------------------------------

func character_level() -> int:
	return (build.get("levels", []) as Array).size()


func class_level_of(class_id: String) -> int:
	return int(class_levels.get(class_id, 0))


func proficiency_bonus() -> int:
	# Ioun Stone of Mastery: +1.
	return Abilities.proficiency_bonus(maxi(1, character_level())) + (1 if has_flag("proficiency_plus_1") else 0)


func class_name_of(class_id: String) -> String:
	return compendium.display_name("classes", class_id)


## "Fighter 3 / Rogue 2"
func class_summary() -> String:
	var parts: Array[String] = []
	for cid in class_order:
		var text := "%s %d" % [class_name_of(cid), class_level_of(cid)]
		if subclasses.has(cid):
			text = "%s (%s) %d" % [class_name_of(cid), compendium.display_name("subclasses", str(subclasses[cid])), class_level_of(cid)]
		parts.append(text)
	return " / ".join(parts)


func choices() -> Dictionary:
	if not build.has("choices"):
		build["choices"] = {}
	return build["choices"] as Dictionary


func picks_for(key: String) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in choices().get(key, []):
		out.append(str(v))
	return out


func choice(key: String) -> Choice:
	for c in choice_defs:
		if c.key == key:
			return c
	return null


func pending_choices() -> Array[Choice]:
	var out: Array[Choice] = []
	for c in choice_defs:
		if not c.is_complete():
			out.append(c)
	return out


func intrinsic_modifiers() -> Array[Modifier]:
	var items := item_modifiers()
	var gifts := gift_modifiers()
	if items.is_empty() and gifts.is_empty():
		return _modifiers
	var out := _modifiers.duplicate()
	out.append_array(items)
	out.append_array(gifts)
	return out


# --- Dark gifts (the Amber Temple, ADR 0011): accepted for good, kept in the build ------------------------------

## The dark gifts this character carries (data/dark_gifts/ ids).
func dark_gifts() -> Array[String]:
	var out: Array[String] = []
	for g: Variant in build.get("dark_gifts", []):
		out.append(str(g))
	return out


## Takes a dark gift for good: its benefit and its cost both apply from now on.
func accept_dark_gift(gift_id: String) -> void:
	if gift_id in dark_gifts():
		return
	var list := build.get("dark_gifts", []) as Array
	list.append(gift_id)
	build["dark_gifts"] = list
	refresh()


## The modifiers of every dark gift carried: the benefit's and the cost's.
func gift_modifiers() -> Array[Modifier]:
	var out: Array[Modifier] = []
	for id in dark_gifts():
		var data := compendium.get_entry("dark_gifts", id)
		for part: String in ["benefit", "cost"]:
			for md: Variant in (data.get(part, {}) as Dictionary).get("modifiers", []):
				out.append(Modifier.make(md as Dictionary, "%s (%s)" % [data.get("name", id), part], &"dark_gift", id, ""))
	return out


# --- Magic items and attunement (2024 DMG "Magic Items", ADR 0012) ----------------------------------

const MAX_ATTUNED := 3
## Item ids this character is attuned to (a creature can't attune to two copies of one item).
var attuned: Array[String] = []
var _item_mods_key := ""
## Inside an Antimagic Field: magic items act as mundane ones (set by the combat engine, not saved).
var magic_suppressed := false
var _item_mods: Array[Modifier] = []


## Whether an inventory entry's item is working for its bearer right now: attuned if it needs it, and worn, held or
## equipped where it has to be (a weapon or armor equipped, a cloak worn, a wand held). Items that work from the
## pack (a Stone of Good Luck "on your person") only need carrying.
func item_active(e: Dictionary) -> bool:
	if int(e.get("qty", 0)) <= 0:
		return false
	var data := compendium.item_data(str(e["id"]))
	if magic_suppressed and MagicItems.is_magic(data):
		return false
	if MagicItems.needs_attunement(data) and not str(e["id"]) in attuned:
		return false
	var slot := str(e.get("slot", ""))
	if Gear.is_weapon(data) or Gear.is_armor(data) or Gear.is_shield(data):
		return slot != ""
	if MagicItems.worn_slot(data) != "":
		return slot == MagicItems.worn_slot(data)
	if MagicItems.is_held(data):
		return slot in ["main_hand", "off_hand"]
	return true


## The modifiers of magic items that work for this character right now (item_active). A weapon's own bonuses
## (`"when": {"item": "@self"}`) apply to attacks with that weapon whenever it's attuned (if it needs it), since
## a carried weapon is drawn as part of an attack (deviations.md, weapon juggling); `@self` becomes the item's id.
func item_modifiers() -> Array[Modifier]:
	var key := ""
	for e in inventory:
		if int(e.get("qty", 0)) > 0:
			key += "%s:%s;" % [e["id"], e.get("slot", "")]
	key += "|" + ",".join(attuned) + ("|suppressed" if magic_suppressed else "")
	if key == _item_mods_key:
		return _item_mods
	_item_mods_key = key
	_item_mods.clear()
	var seen := {}
	for e in inventory:
		if int(e.get("qty", 0)) <= 0:
			continue
		var iid := str(e["id"])
		var data := compendium.item_data(iid)
		if magic_suppressed and MagicItems.is_magic(data):
			continue
		var mods := (data.get("modifiers", []) as Array).duplicate()
		# Properties this one item rolled (an artifact's), always "while attuned".
		for prop: Variant in e.get("artifact_properties", []):
			for pm: Variant in (prop as Dictionary).get("modifiers", []):
				var pmd := (pm as Dictionary).duplicate()
				pmd["attuned_only"] = true
				mods.append(pmd)
		if mods.is_empty():
			continue
		var attuned_ok := not MagicItems.needs_attunement(data) or iid in attuned
		var active := item_active(e)
		for md: Variant in mods:
			var d := md as Dictionary
			var when := d.get("when", {}) as Dictionary
			var scoped := str(when.get("item", "")) == "@self" or str(when.get("ammo", "")) == "@self"
			# "while attuned" (Berserker Axe's Hit Points) and "while on your person" (Luck Blade's saves) need no slot.
			var anywhere := bool(d.get("attuned_only", false)) or bool(d.get("carried", false))
			if not (active or ((scoped or anywhere) and attuned_ok)):
				continue
			# Only alongside other items worn (Hammer of Thunderbolts with a Belt of Giant Strength and Gauntlets of Ogre Power).
			if d.has("requires_worn") and not _wearing_all(d["requires_worn"] as Array):
				continue
			# Only while the item still holds a gem of that kind (Helm of Brilliance's rubies).
			if d.has("requires_gem") and int((e.get("gems", {}) as Dictionary).get(str(d["requires_gem"]), 0)) <= 0:
				continue
			# Two of the same item don't stack (one Ring of Protection counts once).
			var dedupe := "%s|%s" % [iid, JSON.stringify(d)]
			if seen.has(dedupe):
				continue
			seen[dedupe] = true
			if scoped:
				d = d.duplicate(true)
				var w := (d["when"] as Dictionary)
				for k: String in ["item", "ammo"]:
					if str(w.get(k, "")) == "@self":
						w[k] = iid
			_item_mods.append(Modifier.make(d, str(data.get("name", iid)), &"item", iid, ""))
	return _item_mods


## Whether an active item of each named kind (an id, a template or a `variant_of` group) is worn or held.
func _wearing_all(kinds: Array) -> bool:
	for k: Variant in kinds:
		var found := false
		for e in inventory:
			var d := compendium.item_data(str(e["id"]))
			if str(e["id"]) == str(k) or str(d.get("template_id", "")) == str(k) or str(d.get("variant_of", "")) == str(k):
				if item_active(e):
					found = true
		if not found:
			return false
	return true


## Forget cached item modifiers (after equipping or a change to an item's state).
func items_changed() -> void:
	_item_mods_key = ""


## "" if this character can attune to `item_id` now, else why not (not carried, doesn't need it, already three,
## a requirement like "by a Cleric" unmet).
func attune_blocker(item_id: String) -> String:
	var data := compendium.item_data(item_id)
	if not MagicItems.needs_attunement(data):
		return "Doesn't need attunement"
	if item_id in attuned:
		return "Already attuned"
	var carried := false
	for e in inventory:
		if str(e["id"]) == item_id and int(e.get("qty", 0)) > 0:
			carried = true
	if not carried:
		return "Not carried"
	if attuned.size() >= MAX_ATTUNED:
		return "Already attuned to three items"
	return MagicItems.requirement_blocker(data, self)


func attune(item_id: String) -> bool:
	if attune_blocker(item_id) != "":
		return false
	attuned.append(item_id)
	# Attuning to an item teaches its properties (a disguised one shows what it is, and its curse takes hold).
	var e := entry_of(item_id)
	if not e.is_empty():
		e["identified"] = true
	_item_mods_key = ""
	refresh_item_resources()
	return true


## Identifies the carried `item_id` (Identify, or a Short Rest spent studying it): its true name and properties
## show from now on. Returns its name, or "" if it isn't carried. A curse stays hidden until someone attunes to it.
func identify(item_id: String) -> String:
	var e := entry_of(item_id)
	if e.is_empty():
		return ""
	e["identified"] = true
	return str(compendium.item_data(item_id).get("name", item_id))


## "" if attunement to `item_id` can end now; a cursed item holds on until the curse is lifted (Remove Curse).
func end_attunement_blocker(item_id: String) -> String:
	if not item_id in attuned:
		return "Not attuned"
	var e := entry_of(item_id)
	if MagicItems.is_cursed(compendium.item_data(item_id)) and not bool(e.get("curse_lifted", false)):
		return "Cursed: you can't end the attunement until the curse is lifted (Remove Curse)"
	return ""


func end_attunement(item_id: String) -> bool:
	if end_attunement_blocker(item_id) != "":
		return false
	attuned.erase(item_id)
	_item_mods_key = ""
	refresh_item_resources()
	return true


## The first carried inventory entry for `item_id` ({} if none).
func entry_of(item_id: String) -> Dictionary:
	for e in inventory:
		if str(e["id"]) == item_id and int(e.get("qty", 0)) > 0:
			return e
	return {}


## Charges left on a carried item (its first entry).
func charges_left(item_id: String) -> int:
	return int(entry_of(item_id).get("charges", 0))


## Spends `n` charges of a carried item. False if it hasn't that many.
func spend_charges(item_id: String, n: int) -> bool:
	var e := entry_of(item_id)
	if e.is_empty() or int(e.get("charges", 0)) < n:
		return false
	e["charges"] = int(e["charges"]) - n
	return true


## Uses of a limited power (`uses: {count, per}`) spent since it last came back, by "<item>:<power>".
func power_uses_spent(item_id: String, power_id: String) -> int:
	return int((entry_of(item_id).get("uses", {}) as Dictionary).get(power_id, 0))


func spend_power_use(item_id: String, power_id: String) -> void:
	var e := entry_of(item_id)
	if e.is_empty():
		return
	if not e.has("uses"):
		e["uses"] = {}
	var u := e["uses"] as Dictionary
	u[power_id] = int(u.get(power_id, 0)) + 1


## Dawn (2024: most items regain charges and daily uses "daily at dawn"). Charges come back by the item's `regain`
## dice up to its maximum; powers used "per dawn" come back. Returns log lines.
func on_dawn(dice: DiceRoller) -> Array[String]:
	var lines: Array[String] = []
	for e in inventory:
		var data := compendium.item_data(str(e["id"]))
		if data.is_empty():
			continue
		var spec := MagicItems.charges(data)
		if not spec.is_empty() and str(spec.get("when", "dawn")) == "dawn" and spec.has("regain"):
			var cap := MagicItems.max_charges(data, e)
			var have := int(e.get("charges", 0))
			if have < cap:
				var regain: Variant = spec["regain"]
				var n := cap - have if str(regain) == "all" else int(dice.roll_expr(str(regain), "%s regains charges" % data.get("name", ""))["total"])
				e["charges"] = mini(cap, have + n)
				lines.append("%s's %s regains %d charges (%d of %d)" % [name, data.get("name", ""), int(e["charges"]) - have, int(e["charges"]), cap])
		_reset_uses(e, data, ["dawn"])
		e.erase("fan_uses")
		# "Once every N days": a dawn closer.
		var cds := e.get("cooldowns", {}) as Dictionary
		for pid: String in cds.keys():
			cds[pid] = int(cds[pid]) - 1
			if int(cds[pid]) <= 0:
				cds.erase(pid)
				(e.get("uses", {}) as Dictionary).erase(pid)
		_reset_budgets(e, data, "dawn")
		# A Bag of Devouring swallows whatever is inside it each day.
		if bool((data.get("container", {}) as Dictionary).get("devours", false)) and not (e.get("contents", []) as Array).is_empty():
			e["contents"] = []
			lines.append("Everything in %s's bag is gone" % name)
	return lines


## Running time of toggles (Boots of Speed, Winged Boots, Cloak of Invisibility) comes back.
func _reset_budgets(e: Dictionary, data: Dictionary, when: String) -> void:
	if not e.has("budget_used"):
		return
	for p: Variant in data.get("powers", []):
		var pw := p as Dictionary
		var reset := str(pw.get("budget_reset", "long"))
		if reset == "never":
			continue
		if when == "dawn" and reset == "long" and str(data.get("template_id", data.get("id", ""))) == "boots_of_speed":
			continue
		(e["budget_used"] as Dictionary).erase(str(pw.get("id", "")))


## Dusk: items that regain charges at dusk (the Robe of Stars' stars).
func on_dusk(dice: DiceRoller) -> void:
	for e in inventory:
		var data := compendium.item_data(str(e["id"]))
		var spec := MagicItems.charges(data)
		if spec.is_empty() or str(spec.get("when", "")) != "dusk" or not spec.has("regain"):
			continue
		var cap := MagicItems.max_charges(data, e)
		e["charges"] = mini(cap, int(e.get("charges", 0)) + int(dice.roll_expr(str(spec["regain"]), "%s at dusk" % data.get("name", ""))["total"]))


## Time passing with items that heal (Ring of Regeneration: 1d6 every 10 minutes; Ioun Stone of Regeneration: 15 an
## hour), only while the bearer has at least 1 Hit Point.
func items_passage(minutes: int, dice: DiceRoller) -> void:
	if dead or hp < 1:
		return
	if has_flag("regeneration_ring"):
		for i in mini(minutes / 10, 30):
			if hp >= max_hp():
				break
			heal(dice.roll_one(6, "Ring of Regeneration"), "Ring of Regeneration")
	if has_flag("ioun_regeneration"):
		heal(15 * (minutes / 60), "Ioun Stone of Regeneration")


## Long and Short Rests bring back powers used "per long rest" or "per short rest".
func _reset_item_uses(per: Array[String]) -> void:
	for e in inventory:
		var data := compendium.item_data(str(e["id"]))
		if "long" in per:
			_reset_budgets(e, data, "long")
		var spec := MagicItems.charges(data)
		if not spec.is_empty() and str(spec.get("when", "dawn")) in per:
			e["charges"] = MagicItems.max_charges(data, e)
		_reset_uses(e, data, per)


func _reset_uses(e: Dictionary, data: Dictionary, per: Array) -> void:
	if not e.has("uses"):
		return
	var u := e["uses"] as Dictionary
	for p: Variant in data.get("powers", []):
		var pw := p as Dictionary
		var pu := pw.get("uses", {}) as Dictionary
		if str(pu.get("per", "dawn")) in per:
			u.erase(str(pw.get("id", "")))
			if pw.has("bead"):
				u.erase("bead:%s" % pw["bead"])


## Resources some attuned items grant (none yet beyond charges); kept as a hook for refresh().
func refresh_item_resources() -> void:
	_item_mods_key = ""


# --- The walk ------------------------------------------------------------------------------------

func refresh() -> void:
	features.clear()
	choice_defs.clear()
	_modifiers.clear()
	_increases.clear()
	_resource_defs.clear()
	feats_taken.clear()
	weapon_masteries.clear()
	maneuvers.clear()
	invocations.clear()
	metamagic.clear()
	wild_shape_forms.clear()
	spellcasting.clear()
	granted_spells.clear()
	class_levels.clear()
	class_order.clear()
	subclasses.clear()
	expertise.clear()
	lineage = ""
	proficiencies = {"armor": {}, "weapons": {}, "tools": {}, "languages": {}, "saves": {}, "skills": {}}
	name = str(build.get("name", ""))
	if id == "":
		id = name.to_snake_case() if name != "" else "character"
	_walk_species()
	_walk_background()
	_walk_languages()
	_walk_classes()
	_fix_dynamic_counts()
	_build_spellcasting()
	_collect_granted_spells()
	_apply_resources()
	if hp > max_hp():
		hp = max_hp()


func _source(kind: String, source_id: String, label: String, class_id: String = "", level: int = 0) -> Dictionary:
	return {"kind": kind, "id": source_id, "label": label, "class_id": class_id, "level": level}


func _prof(kind: String, value: String, source: String) -> void:
	var table := proficiencies[kind] as Dictionary
	if not table.has(value):
		table[value] = source


func _walk_species() -> void:
	var sp := compendium.species_data(str(build.get("species", "")))
	if sp.is_empty():
		size = &"medium"
		base_speed = {"walk": 30}
		return
	var src := _source("species", str(sp["id"]), "Species: %s" % sp["name"])
	creature_type = StringName(str(sp.get("creature_type", "humanoid")))
	base_speed = {"walk": int(sp.get("speed", 30))}
	base_senses = {"darkvision": int(sp.get("darkvision", 0))}
	var sizes := sp.get("sizes", ["medium"]) as Array
	if sizes.size() > 1:
		var picks := _register_choice({"kind": "size", "count": 1, "from": sizes}, "species.size", src, "Size")
		size = StringName(picks[0]) if not picks.is_empty() else StringName(str(sizes[0]))
	else:
		size = StringName(str(sizes[0]))
	var scope := {}
	if sp.has("spellcasting_ability_choice"):
		var picks := _register_choice({"kind": "spellcasting_ability", "count": 1,
			"from": sp["spellcasting_ability_choice"]}, "species.spellcasting_ability", src, "Spellcasting ability")
		scope["choice"] = picks[0] if not picks.is_empty() else ""
	scope["species"] = sp
	for t: Variant in sp.get("traits", []):
		var tr := t as Dictionary
		_walk_feature(tr, "species.%s" % tr["id"], src, scope)


func _walk_background() -> void:
	var bg := compendium.background_data(str(build.get("background", "")))
	if bg.is_empty():
		return
	var src := _source("background", str(bg["id"]), "Background: %s" % bg["name"])
	var picks := _register_choice({"kind": "ability_increase", "count": 3, "from": bg["ability_scores"],
		"per_ability": 2, "max": 20}, "background.abilities", src, "Ability Score Increases")
	_add_increases(picks, 20, "Background: %s" % bg["name"])
	for s: Variant in bg.get("skills", []):
		_prof("skills", str(s), src["label"])
	var tool := bg.get("tool", {}) as Dictionary
	if tool.has("choice"):
		var tp := _register_choice({"kind": "tool", "count": 1, "filter": {"tool_kind": tool["choice"]}},
			"background.tool", src, "Tool Proficiency")
		if not tp.is_empty():
			_prof("tools", tp[0], src["label"])
	elif tool.has("id"):
		_prof("tools", str(tool["id"]), src["label"])
	if bg.has("feat"):
		# Any origin feat can be swapped for a Ravenloft Dark Gift (Ravenloft: The Horrors Within); the background's
		# own feat stays picked until the player changes it, so older builds need no new pick.
		var own := str(bg["feat"])
		var fp := _register_choice({"kind": "feat", "count": 1, "from": [own], "filter": {"category": "dark_gift"},
			"default": own, "walk": false}, "background.feat_choice", src, "Origin Feat or Ravenloft Dark Gift")
		var pick := fp[0] if not fp.is_empty() else own
		_walk_feat(pick, "background.feat", src, bg.get("feat_params", {}) as Dictionary if pick == own else {})


func _walk_languages() -> void:
	_prof("languages", "common", "Every character")
	var src := _source("origin", "languages", "Languages")
	var picks := _register_choice({"kind": "language", "count": 2, "from": STANDARD_LANGUAGES}, "origin.languages",
		src, "Languages")
	for p in picks:
		_prof("languages", p, str(src["label"]))


func _walk_classes() -> void:
	var levels := build.get("levels", []) as Array
	for i in levels.size():
		var cid := str((levels[i] as Dictionary).get("class", ""))
		var cls := compendium.class_data(cid)
		if cls.is_empty():
			continue
		var n := class_level_of(cid) + 1
		class_levels[cid] = n
		if not cid in class_order:
			class_order.append(cid)
		var src := _source("class", cid, "%s %d" % [cls["name"], n], cid, n)
		src["character_level"] = i + 1
		if n == 1:
			_class_proficiencies(cls, i == 0, src)
		var level_data := (cls["levels"] as Array)[n - 1] as Dictionary
		for f: Variant in level_data.get("features", []):
			var feat := f as Dictionary
			_walk_feature(feat, "%s.%d.%s" % [cid, n, feat["id"]], src, {})
		if subclasses.has(cid):
			var sub := compendium.subclass_data(str(subclasses[cid]))
			var ssrc := _source("subclass", str(sub.get("id", "")), "%s %d" % [sub.get("name", ""), n], cid, n)
			ssrc["character_level"] = i + 1
			for sf: Variant in sub.get("features", []):
				var entry := sf as Dictionary
				if int(entry["level"]) == n:
					var feature := entry["feature"] as Dictionary
					_walk_feature(feature, "%s.%d.%s" % [sub["id"], n, feature["id"]], ssrc, {})


func _class_proficiencies(cls: Dictionary, first: bool, src: Dictionary) -> void:
	var label := str(src["label"])
	var profs := cls.get("proficiencies", {}) as Dictionary
	if first:
		for ab: Variant in cls.get("saving_throws", []):
			_prof("saves", str(ab), label)
		for a: Variant in profs.get("armor", []):
			_prof("armor", str(a), label)
		for w: Variant in profs.get("weapons", []):
			_prof("weapons", str(w), label)
		for t: Variant in profs.get("tools", []):
			_prof("tools", str(t), label)
		var sc := cls.get("skill_choices", {}) as Dictionary
		var picks := _register_choice(sc, "%s.1.skills" % cls["id"], src, "Skill Proficiencies")
		for p in picks:
			_prof("skills", p, label)
		# Tools chosen rather than fixed (Bard: three Musical Instruments; Monk: an Artisan's Tool or instrument).
		if cls.has("tool_choices"):
			_register_choice(cls["tool_choices"] as Dictionary, "%s.1.tools" % cls["id"], src, "Tool Proficiencies")
	else:
		var mc := (cls.get("multiclass", {}) as Dictionary).get("proficiencies", {}) as Dictionary
		for a: Variant in mc.get("armor", []):
			_prof("armor", str(a), label)
		for w: Variant in mc.get("weapons", []):
			_prof("weapons", str(w), label)
		for t: Variant in mc.get("tools", []):
			_prof("tools", str(t), label)
		if int(mc.get("skills", 0)) > 0:
			var sc2 := (cls.get("skill_choices", {}) as Dictionary).duplicate()
			sc2["count"] = int(mc["skills"])
			var picks2 := _register_choice(sc2, "%s.1.skills" % cls["id"], src, "Skill Proficiency")
			for p in picks2:
				_prof("skills", p, label)
		if int(mc.get("tool_choices", 0)) > 0 and cls.has("tool_choices"):
			var tc := (cls["tool_choices"] as Dictionary).duplicate(true)
			tc["count"] = int(mc["tool_choices"])
			_register_choice(tc, "%s.1.tools" % cls["id"], src, "Tool Proficiency")


## Walks one feature: records it, registers its choices (and applies their picks), turns its modifiers into
## Modifier objects and its resource into a resource definition. `scope` resolves "@name" references to
## picks inside one feat or species (Magic Initiate's "@cantrips", Resilient's "@increased").
func _walk_feature(f: Dictionary, key: String, src: Dictionary, scope: Dictionary) -> void:
	var at := int(f.get("at_level", 0))
	if at > 0 and at > character_level():
		return
	features.append({"id": str(f.get("id", "")), "name": str(f.get("name", "")), "summary": str(f.get("summary", "")),
		"text": str(f.get("text", "")), "source": src["label"], "source_kind": src["kind"],
		"class_id": src["class_id"], "level": src["level"], "action": str(f.get("action", "passive")),
		"implemented": str(f.get("implemented", "data")), "key": key})
	for recipe_key: String in ["activation", "roll_response", "summon_effect", "hit_response", "cast_level_boost", "cast_form", "attack_cantrip", "after_cast_attack", "slot_exchange", "on_feature_target", "spell_sequence", "resource_cast", "damage_response"]:
		if f.has(recipe_key):
			features[-1][recipe_key] = (f[recipe_key] as Dictionary).duplicate(true)
	# A benefit that acts on its own unless turned Off (Reactions.configurable_policies).
	for policy_key: String in ["policy", "policy_cost"]:
		if f.has(policy_key):
			features[-1][policy_key] = str(f[policy_key])
	if f.has("choice"):
		var c := f["choice"] as Dictionary
		var picks := _register_choice(c, key, src, str(c.get("label", f.get("name", ""))), scope)
		scope[str(c.get("id", "choice"))] = picks
	for c2: Variant in f.get("choices", []):
		var cd := c2 as Dictionary
		var sub_key := "%s.%s" % [key, cd.get("id", "choice")]
		var picks2 := _register_choice(cd, sub_key, src, str(cd.get("label", f.get("name", ""))), scope)
		scope[str(cd.get("id", "choice"))] = picks2
	for md: Variant in f.get("modifiers", []):
		_add_modifier(md as Dictionary, str(f.get("name", "")), src, scope)
	if f.has("resource"):
		var r := (f["resource"] as Dictionary).duplicate()
		r["class_id"] = src["class_id"]
		r["source"] = src["label"]
		_resource_defs.append(r)


func _add_modifier(md: Dictionary, feature_name: String, src: Dictionary, scope: Dictionary) -> void:
	var d := md.duplicate(true)
	var values: Array = [d.get("value", 0)]
	var raw: Variant = d.get("value", 0)
	if raw is String and (raw as String).begins_with("@"):
		values = _resolve_ref(raw as String, scope)
	if d.has("ability") and str(d["ability"]).begins_with("@"):
		var a := _resolve_ref(str(d["ability"]), scope)
		d["ability"] = a[0] if not a.is_empty() else ""
	if d.has("skill") and str(d["skill"]).begins_with("@"):
		var skills := _resolve_ref(str(d["skill"]), scope)
		d["skill"] = skills[0] if not skills.is_empty() else ""
	if str(d.get("ability", "")) == "choice":
		d["ability"] = str(scope.get("choice", ""))
	# `when` filters can name a pick too (Agonizing Blast: {"spell_id": "@cantrip"}).
	if d.has("when"):
		var when := d["when"] as Dictionary
		for wk: String in when.keys():
			if when[wk] is String and str(when[wk]).begins_with("@"):
				var r := _resolve_ref(str(when[wk]), scope)
				when[wk] = str(r[0]) if not r.is_empty() else ""
	for v: Variant in values:
		var one := d.duplicate(true)
		one["value"] = v
		_modifiers.append(Modifier.make(one, feature_name, StringName(str(src["kind"])), str(src["id"]), str(src["class_id"])))


func _resolve_ref(ref: String, scope: Dictionary) -> Array:
	var name_ := ref.substr(1)
	var v: Variant = scope.get(name_, [])
	if v is Array:
		return v as Array
	return [v]


func _walk_feat(feat_id: String, key: String, parent: Dictionary, params: Dictionary = {}) -> void:
	var feat := compendium.feat_data(feat_id)
	var label := "%s (%s)" % [feat.get("name", feat_id), parent["label"]]
	feats_taken.append({"id": feat_id, "name": str(feat.get("name", feat_id)), "source": parent["label"], "key": key})
	if feat.is_empty():
		return
	var src := _source("feat", feat_id, label, "", int(parent.get("level", 0)))
	var scope := {}
	var fp := feat.get("params", {}) as Dictionary
	if params.has("list"):
		scope["list"] = str(params["list"])
	elif fp.has("lists"):
		var options: Array = []
		for l: Variant in fp["lists"]:
			options.append({"id": str(l), "name": str(l).capitalize(), "summary": "The %s spell list" % str(l).capitalize()})
		var lp := _register_choice({"kind": "option", "count": 1, "options": options}, "%s.list" % key, src,
			"%s: spell list" % feat.get("name", ""), scope)
		scope["list"] = lp[0] if not lp.is_empty() else ""
	if feat.has("ability_increase"):
		var ai := feat["ability_increase"] as Dictionary
		var picks := _register_choice({"kind": "ability_increase", "count": int(ai.get("points", 1)),
			"from": ai.get("from", Abilities.ALL), "per_ability": int(ai.get("per_ability", 1)),
			"max": int(ai.get("max", 20))}, "%s.abilities" % key, src, "%s: ability increase" % feat.get("name", ""))
		_add_increases(picks, int(ai.get("max", 20)), str(feat.get("name", "")))
		scope["increased"] = picks[0] if not picks.is_empty() else ""
	for b: Variant in feat.get("benefits", []):
		var benefit := b as Dictionary
		_walk_feature(benefit, "%s.%s" % [key, benefit.get("id", "benefit")], src, scope)
	if feat.has("drawback"):
		var drawback := feat["drawback"] as Dictionary
		_walk_feature(drawback, "%s.%s" % [key, drawback.get("id", "drawback")], src, scope)


func _add_increases(picks: Array[String], cap: int, label: String) -> void:
	for p in picks:
		_increases.append({"ability": p, "amount": 1, "max": cap, "label": label})


## Registers a choice, applies its current picks and returns them.
func _register_choice(def: Dictionary, key: String, src: Dictionary, label: String, scope: Dictionary = {}) -> Array[String]:
	var c := Choice.new()
	c.key = key
	c.kind = str(def.get("kind", "option"))
	c.count = Formula.evaluate(def.get("count", 1), {"pb": proficiency_bonus(), "level": character_level()}) if def.get("count", 1) is String else int(def.get("count", 1))
	c.label = label if label != "" else c.kind.capitalize()
	c.source = str(src["label"])
	c.source_kind = str(src["kind"])
	c.class_id = str(src.get("class_id", ""))
	c.level = int(src.get("character_level", character_level()))
	c.replaceable = str(def.get("replaceable", ""))
	c.replace_max = int(def.get("replace_max", -1))
	c.replace_group = str(def.get("replace_group", ""))
	c.per_ability = int(def.get("per_ability", 1))
	c.max_score = int(def.get("max", 20))
	for v: Variant in def.get("from", []):
		c.from.append(str(v))
	var filter := (def.get("filter", {}) as Dictionary).duplicate(true)
	for fk: String in filter.keys():
		var fv: Variant = filter[fk]
		if fv is String and (fv as String).begins_with("@"):
			var r := _resolve_ref(fv as String, scope)
			filter[fk] = str(r[0]) if not r.is_empty() else ""
	if def.has("count_column"):
		filter["_count_column"] = def["count_column"]
	c.filter = filter
	for o: Variant in def.get("options", []):
		c.inline_options.append(o as Dictionary)
	c.picks = picks_for(key)
	# A choice with a default counts as made until the player changes it (the background's own origin feat).
	if c.picks.is_empty() and def.has("default"):
		c.picks = [str(def["default"])]
	choice_defs.append(c)
	if bool(def.get("walk", true)):
		_apply_picks(c, src, scope)
	return c.picks


func _apply_picks(c: Choice, src: Dictionary, scope: Dictionary) -> void:
	var label := str(src["label"])
	for p in c.picks:
		match c.kind:
			"skill":
				if Abilities.SKILLS.has(StringName(p)):
					_prof("skills", p, label)
				else:
					_prof("tools", p, label)
			"expertise":
				if not expertise.has(p):
					expertise[p] = label
			"tool":
				_prof("tools", p, label)
			"language":
				_prof("languages", p, label)
			"fighting_style", "feat":
				# Paladin's Blessed Warrior and Ranger's Druidic Warrior sit beside the Fighting Style feats.
				if _has_inline_option(c, p):
					_walk_inline_option(c, p, src, scope)
				else:
					_walk_feat(p, "%s/%s" % [c.key, p], src)
			"invocation":
				if not p in invocations:
					invocations.append(p)
				_walk_inline_option(c, p, src, scope)
			"metamagic":
				if not p in metamagic:
					metamagic.append(p)
				_walk_inline_option(c, p, src, scope)
			"beast_form":
				if not p in wild_shape_forms:
					wild_shape_forms.append(p)
			"weapon_mastery":
				if not p in weapon_masteries:
					weapon_masteries.append(p)
			"subclass":
				if src["class_id"] != "":
					subclasses[str(src["class_id"])] = p
			"maneuver":
				if not p in maneuvers:
					maneuvers.append(p)
				_walk_inline_option(c, p, src, scope)
			"option":
				_walk_inline_option(c, p, src, scope)
			"lineage":
				lineage = p
				var sp := scope.get("species", {}) as Dictionary
				for l: Variant in sp.get("lineages", []):
					var ld := l as Dictionary
					if str(ld["id"]) == p:
						var lsrc := _source("species", p, "Lineage: %s" % ld["name"])
						for t: Variant in ld.get("traits", []):
							var td := t as Dictionary
							_walk_feature(td, "species.lineage.%s" % td["id"], lsrc, scope)
			"cantrip", "spell", "spellbook":
				pass # read by _build_spellcasting / modifiers


func _walk_inline_option(c: Choice, pick: String, src: Dictionary, scope: Dictionary) -> void:
	for o in c.inline_options:
		if str(o.get("id", "")) == pick:
			_walk_feature(o, "%s/%s" % [c.key, pick], src, scope)


func _has_inline_option(c: Choice, pick: String) -> bool:
	for o in c.inline_options:
		if str(o.get("id", "")) == pick:
			return true
	return false


## Choices whose count follows a class table column (Weapon Mastery 3 -> 4 -> 5 -> 6). Wild Shape's known forms
## are also capped by the Beasts the game's bestiary has (deviations.md), so the choice never dead-ends; so is a
## free-cast spell of one exact level (Mystic Arcanum) by the spells of that level the game has.
func _fix_dynamic_counts() -> void:
	for c in choice_defs:
		if c.filter.has("_count_column") and c.class_id != "":
			var v: Variant = class_column(c.class_id, str(c.filter["_count_column"]))
			if v != null:
				c.count = int(v)
		if c.kind == "beast_form":
			c.count = mini(c.count, beast_forms_for(c).size())
		if c.kind == "spell" and bool(c.filter.get("granted", false)) and c.filter.has("level"):
			c.count = mini(c.count, compendium.spells_for(str(c.filter.get("list", "")), int(c.filter["level"])).size())


## Beast stat blocks a Wild Shape choice may pick: Beasts up to the class table's maximum CR (Circle Forms
## raises it to a third of the Druid level), without a Fly Speed until the table allows one.
func beast_forms_for(c: Choice) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var max_cr := 0.0
	var cr_v: Variant = class_column(c.class_id, str(c.filter.get("cr_column", "")))
	if cr_v != null:
		max_cr = float(cr_v)
	if has_flag("circle_forms"):
		max_cr = maxf(max_cr, floorf(class_level_of(c.class_id) / 3.0))
	var fly_v: Variant = class_column(c.class_id, str(c.filter.get("fly_column", "")))
	var fly_ok := fly_v != null and bool(fly_v)
	for m in compendium.all("monsters"):
		if str(m.get("type", "")) != "beast" or float(m.get("cr", 99)) > max_cr:
			continue
		if not fly_ok and int((m.get("speed", {}) as Dictionary).get("fly", 0)) > 0:
			continue
		out.append(m)
	return out


## A class (or its subclass) table value at the character's current level in that class.
func class_column(class_id: String, column: String) -> Variant:
	var n := class_level_of(class_id)
	if n <= 0:
		return null
	var cls := compendium.class_data(class_id)
	var tables: Array[Dictionary] = [cls.get("table", {}) as Dictionary]
	if subclasses.has(class_id):
		tables.append(compendium.subclass_data(str(subclasses[class_id])).get("table", {}) as Dictionary)
	for t in tables:
		if t.has(column):
			return ((t[column] as Dictionary)["values"] as Array)[n - 1]
	return null


# --- Spellcasting --------------------------------------------------------------------------------

func _build_spellcasting() -> void:
	for cid in class_order:
		var cls := compendium.class_data(cid)
		var n := class_level_of(cid)
		var sc := cls.get("spellcasting", {}) as Dictionary
		var cantrips_max := 0
		var prepared_max := 0
		var fixed_cantrips: Array[String] = []
		var name_ := str(cls.get("name", cid))
		if not sc.is_empty() and n >= int(sc.get("from_level", 1)):
			cantrips_max = int(class_column(cid, str(sc.get("cantrips_column", "cantrips"))) if class_column(cid, str(sc.get("cantrips_column", "cantrips"))) != null else 0)
			prepared_max = int(class_column(cid, str(sc.get("prepared_column", "prepared"))) if class_column(cid, str(sc.get("prepared_column", "prepared"))) != null else 0)
		elif subclasses.has(cid):
			var sub := compendium.subclass_data(str(subclasses[cid]))
			if sub.has("spellcasting"):
				sc = sub["spellcasting"] as Dictionary
				name_ = str(sub.get("name", name_))
				cantrips_max = int((sc.get("cantrips", []) as Array)[n - 1]) if (sc.get("cantrips", []) as Array).size() >= n else 0
				prepared_max = int((sc.get("prepared", []) as Array)[n - 1]) if (sc.get("prepared", []) as Array).size() >= n else 0
				for fc: Variant in sc.get("fixed_cantrips", []):
					fixed_cantrips.append(str(fc))
		if sc.is_empty() or (cantrips_max == 0 and prepared_max == 0):
			continue
		var list := str(sc.get("list", cid))
		var src := _source("class", cid, "%s spellcasting" % name_, cid, n)
		var entry := {"class_id": cid, "name": name_, "ability": str(sc["ability"]), "list": list,
			"progression": str(sc.get("progression", "full")), "cantrips_max": cantrips_max,
			"prepared_max": prepared_max, "spellbook_max": 0, "ritual": str(sc.get("ritual", "prepared")),
			"cantrips": [], "prepared": [], "spellbook": [], "always": [], "bonus": [],
			"fixed_cantrips": fixed_cantrips, "pact_slots": 0, "pact_level": 0}
		# The class feature the entry belongs to: Spellcasting, or Pact Magic (Warlock), whose slots are kept apart.
		entry["feature"] = "pact_magic" if str(entry["progression"]) == "pact" else "spellcasting"
		if str(entry["progression"]) == "pact":
			var count_v: Variant = class_column(cid, str(sc.get("pact_slots_column", "pact_slots")))
			var level_v: Variant = class_column(cid, str(sc.get("pact_level_column", "slot_level")))
			entry["pact_slots"] = int(count_v) if count_v != null else 0
			entry["pact_level"] = int(level_v) if level_v != null else 0
		var cantrip_count := cantrips_max - fixed_cantrips.size()
		if cantrip_count > 0:
			# 2024: every class swaps one cantrip at a time (a level up, or a Wizard's Long Rest).
			entry["cantrips"] = _register_choice({"kind": "cantrip", "count": cantrip_count,
				"filter": {"list": list, "level": 0}, "replaceable": str(sc.get("swap_cantrip", "level_up")),
				"replace_max": 1},
				"%s.cantrips" % cid, src, "%s cantrips" % name_).duplicate()
		var book := sc.get("spellbook", {}) as Dictionary
		if not book.is_empty():
			entry["spellbook_max"] = int(book.get("start", 6)) + int(book.get("per_level", 2)) * (n - 1)
			entry["spellbook"] = _register_choice({"kind": "spellbook", "count": int(entry["spellbook_max"]),
				"filter": {"list": list, "max_level": "slots"}}, "%s.spellbook" % cid, src, "Spellbook").duplicate()
			# Spells copied in from books found on the road (copy_spell): more than the level's picks, never counted.
			for cs: Variant in build.get("copied_spells", []):
				if not str(cs) in (entry["spellbook"] as Array):
					(entry["spellbook"] as Array).append(str(cs))
		if prepared_max > 0:
			var filter := {"list": list, "max_level": "slots", "min_level": 1}
			# Magical Secrets (Bard 10): the class's `spell_list` modifiers open more lists to its prepared spells.
			var extra := extra_spell_lists(cid)
			if not extra.is_empty():
				var lists: Array = [list]
				lists.append_array(extra)
				filter["lists"] = lists
			if not book.is_empty():
				filter["from_choice"] = "%s.spellbook" % cid
			# One spell per level up (Bard, Sorcerer, Warlock); after a Long Rest any number, or `swap_prepared_max`
			# (Paladin and Ranger replace one).
			var swap := str(sc.get("swap_prepared", "long_rest"))
			entry["prepared"] = _register_choice({"kind": "spell", "count": prepared_max, "filter": filter,
				"replaceable": swap, "replace_max": int(sc.get("swap_prepared_max", 1 if swap == "level_up" else -1))},
				"%s.prepared" % cid, src, "Prepared spells").duplicate()
		# Domain spells and similar: always prepared, not counted against the limit.
		if subclasses.has(cid):
			var sub2 := compendium.subclass_data(str(subclasses[cid]))
			var always := sub2.get("always_prepared", {}) as Dictionary
			for lv: String in always:
				if int(lv) <= n:
					for s: Variant in always[lv]:
						(entry["always"] as Array).append({"id": str(s), "source": str(sub2.get("name", ""))})
		spellcasting.append(entry)
	# Cantrips and spells granted by class or subclass features (Thaumaturge, Evocation Savant) join the list.
	for c in choice_defs:
		if c.class_id == "" or not c.kind in ["cantrip", "spell", "spellbook"]:
			continue
		# A choice that only points at a spell you already know (Agonizing Blast's cantrip) grants nothing; a free-cast
		# pick (Mystic Arcanum) is cast through its feature's own `spell` modifier, never with a slot.
		if bool(c.filter.get("known_only", false)) or bool(c.filter.get("granted", false)):
			continue
		if c.key.begins_with("%s." % c.class_id) and (c.key.ends_with(".cantrips") or c.key.ends_with(".prepared") or c.key.ends_with(".spellbook")) and c.key.count(".") == 1:
			continue
		for e in spellcasting:
			if str(e["class_id"]) == c.class_id:
				for p in c.picks:
					if c.kind == "spellbook":
						(e["spellbook"] as Array).append(p)
					else:
						(e["bonus"] as Array).append({"id": p, "source": c.label})


## Spells from modifiers. Class and subclass features keep their class (so the spell uses that class's save DC
## and attack bonus) and default to its spellcasting ability. Free uses are a number, a formula ("mod:wis",
## with `min`) or a class table column (`count_column`: Favored Enemy).
func _collect_granted_spells() -> void:
	var ctx := formula_context()
	var highest_slot := 0
	var slots := spell_slots()
	for i in slots.size():
		if slots[i] > 0:
			highest_slot = i + 1
	for m in _modifiers:
		if m.stat != &"spell" or highest_slot < m.number("at_slot_level", 0):
			continue
		var spell_id := m.text("value")
		if spell_id == "":
			continue
		if m.class_id != "" and class_level_of(m.class_id) < m.number("at_class_level", 0):
			continue
		if bool(m.data.get("prepared_for_classes", false)):
			for casting in spellcasting:
				granted_spells.append({"id": spell_id, "class_id": str(casting["class_id"]), "ability": str(casting["ability"]),
					"uses": 0, "recharge": "", "always_prepared": true, "at_level": m.at_level(), "source": m.source_name})
			continue
		var ability := m.text("ability")
		if ability == "" and m.class_id != "":
			ability = str((compendium.class_data(m.class_id).get("spellcasting", {}) as Dictionary).get("ability", ""))
		var uses := m.data.get("uses", {}) as Dictionary
		var count := 0
		if uses.has("count_column") and m.class_id != "":
			var v: Variant = class_column(m.class_id, str(uses["count_column"]))
			count = int(v) if v != null else 0
		elif uses.has("count"):
			var c := ctx.duplicate()
			c["class_level"] = class_level_of(m.class_id)
			c["pb"] = proficiency_bonus()
			c["level"] = character_level()
			var n_uses: Variant = uses["count"]
			count = Formula.evaluate(n_uses, c) if n_uses is String else int(n_uses)
			if uses.has("min"):
				count = maxi(count, int(uses["min"]))
		granted_spells.append({"id": spell_id, "class_id": m.class_id, "ability": ability, "uses": count,
			"recharge": str(uses.get("recharge", "")), "always_prepared": bool(m.data.get("always_prepared", true)),
			"at_level": m.at_level(), "source": m.source_name})


func spellcasting_entry(class_id: String) -> Dictionary:
	for e in spellcasting:
		if str(e["class_id"]) == class_id:
			return e
	return {}


## Spell lists beyond its own that a class may prepare from: the `spell_list` modifiers of its features (Magical
## Secrets: Cleric, Druid and Wizard). The picks count as that class's spells.
func extra_spell_lists(class_id: String) -> Array[String]:
	var out: Array[String] = []
	for m in _modifiers:
		if m.stat != &"spell_list" or m.class_id != class_id or m.at_level() > character_level():
			continue
		if class_level_of(class_id) < m.number("at_class_level", 0) or m.text("value") in out:
			continue
		out.append(m.text("value"))
	return out


# --- Copying found spells into a spellbook ----------------------------------------------------------------------

## 2024 Wizard (Expanding the Book): a found Wizard spell of 1st level or higher, of a level the Wizard can prepare,
## goes into the spellbook for 2 hours and 50 GP of inks per spell level. The UI pays the time and the gold.
const COPY_MINUTES_PER_LEVEL := 120
const COPY_GP_PER_LEVEL := 50


## The class that keeps a spellbook ("" for none: only a Wizard copies spells).
func spellbook_class() -> String:
	for e in spellcasting:
		if int(e.get("spellbook_max", 0)) > 0:
			return str(e["class_id"])
	return ""


## Why `spell_id` can't go into this character's spellbook now, or "" if it can.
func copy_spell_problem(spell_id: String) -> String:
	var cid := spellbook_class()
	if cid == "":
		return "Only a Wizard can copy spells into a spellbook"
	var s := compendium.spell_data(spell_id)
	if s.is_empty():
		return "Unknown spell"
	var e := spellcasting_entry(cid)
	if not str(e.get("list", cid)) in (s.get("classes", []) as Array):
		return "Not a %s spell" % str(e.get("name", cid))
	var lv := int(s.get("level", 0))
	if lv == 0:
		return "Cantrips aren't copied into a spellbook"
	if spell_id in (e.get("spellbook", []) as Array):
		return "Already in the spellbook"
	var slots := Spellcasting.slots_for([{"progression": str(e["progression"]), "level": class_level_of(cid)}])
	if lv > Spellcasting.highest_slot_level(slots):
		return "Level %d: too high to prepare yet" % lv
	return ""


## Copies `spell_id` into the spellbook (it can then be prepared like any other). False if copy_spell_problem says no.
func copy_spell(spell_id: String) -> bool:
	if copy_spell_problem(spell_id) != "":
		return false
	var copied := (build.get("copied_spells", []) as Array).duplicate()
	copied.append(spell_id)
	build["copied_spells"] = copied
	refresh()
	return true


## Every slot this character can cast with, by spell level: the Spellcasting slots (Multiclass Spellcaster table)
## plus the Pact Magic slots at their slot level. Casting code reads this, slots_left() and expend_slot(), so a
## Warlock's spells work like anyone's; spellcasting_slots() and pact_magic() keep the two pools apart.
func spell_slots() -> Array[int]:
	var out := spellcasting_slots()
	var pact := pact_magic()
	var pl := int(pact["level"])
	if pl > 0:
		out[pl - 1] += int(pact["count"])
	return out


## Slots from Spellcasting features only (Pact Magic is never added to the multiclass caster level).
func spellcasting_slots() -> Array[int]:
	var casters: Array[Dictionary] = []
	for e in spellcasting:
		casters.append({"progression": str(e["progression"]), "level": class_level_of(str(e["class_id"]))})
	return Spellcasting.slots_for(casters)


## Pact Magic (Warlock table): {count, level, used, left}. All the slots share one level and come back on a
## Short or Long Rest.
func pact_magic() -> Dictionary:
	var count := 0
	var level := 0
	for e in spellcasting:
		if str(e["progression"]) == "pact":
			count += int(e.get("pact_slots", 0))
			level = maxi(level, int(e.get("pact_level", 0)))
	var used := mini(pact_slots_used, count)
	return {"count": count, "level": level, "used": used, "left": count - used}


func slots_left(level: int) -> int:
	var left := spellcasting_slots()[level - 1] - slots_used[level - 1]
	var pact := pact_magic()
	if int(pact["level"]) == level:
		left += int(pact["left"])
	return left


## Spends a slot of that level: a Pact Magic slot first (they return on a Short Rest), else a Spellcasting slot.
## Expended slots of either pool at this level; used by effects that restore spell slots without a pool restriction.
func expended_slots(level: int) -> int:
	if level < 1 or level > 9:
		return 0
	var pact := pact_magic()
	return slots_used[level - 1] + (int(pact["used"]) if int(pact["level"]) == level else 0)


## Restore a Spellcasting slot first, then a Pact Magic slot at the same level.
func recover_slot(level: int) -> bool:
	if expended_slots(level) <= 0:
		return false
	if slots_used[level - 1] > 0:
		slots_used[level - 1] -= 1
	else:
		pact_slots_used -= 1
	return true


func expend_slot(level: int) -> bool:
	var pact := pact_magic()
	if int(pact["level"]) == level and int(pact["left"]) > 0:
		pact_slots_used = int(pact["used"]) + 1
		return true
	if spellcasting_slots()[level - 1] - slots_used[level - 1] <= 0:
		return false
	slots_used[level - 1] += 1
	return true


func spell_save_dc(class_id: String) -> Breakdown:
	var e := spellcasting_entry(class_id)
	var ab := StringName(str(e.get("ability", "int")))
	var b := Breakdown.new("Spell save DC")
	b.add("Base", 8)
	b.add("%s modifier" % ABILITY_SHORT[ab], ability_mod(ab))
	b.add("Proficiency", proficiency_bonus())
	var ctx := formula_context()
	for m in modifiers_for(&"spell_dc"):
		if m.applies_when({"spell": true, "spell_class": class_id}):
			b.add_nonzero(m.source_name, mod_value(m, ctx))
	return b


func spell_attack_bonus(class_id: String) -> Breakdown:
	var e := spellcasting_entry(class_id)
	var ab := StringName(str(e.get("ability", "int")))
	var b := Breakdown.new("Spell attack")
	b.add("%s modifier" % ABILITY_SHORT[ab], ability_mod(ab))
	b.add("Proficiency", proficiency_bonus())
	var ctx := formula_context()
	for m in modifiers_for(&"spell_attack"):
		if m.applies_when({"spell": true, "spell_class": class_id}):
			b.add_nonzero(m.source_name, mod_value(m, ctx))
	return b


## Every spell this character can cast right now, with where it comes from:
## {id, class_id, ability, kind: cantrip|prepared|always|bonus|granted, source}
func known_spells() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in spellcasting:
		var cid := str(e["class_id"])
		var ab := str(e["ability"])
		for s: Variant in e["fixed_cantrips"]:
			out.append({"id": str(s), "class_id": cid, "ability": ab, "kind": "cantrip", "source": str(e["name"])})
		for s: Variant in e["cantrips"]:
			out.append({"id": str(s), "class_id": cid, "ability": ab, "kind": "cantrip", "source": str(e["name"])})
		for s: Variant in e["prepared"]:
			out.append({"id": str(s), "class_id": cid, "ability": ab, "kind": "prepared", "source": str(e["name"])})
		for s: Variant in e["always"]:
			var a := s as Dictionary
			out.append({"id": str(a["id"]), "class_id": cid, "ability": ab, "kind": "always", "source": str(a["source"])})
		for s: Variant in e["bonus"]:
			var b := s as Dictionary
			out.append({"id": str(b["id"]), "class_id": cid, "ability": ab, "kind": "bonus", "source": str(b["source"])})
	for g in granted_spells:
		if int(g["at_level"]) <= character_level():
			# Only a class that casts can lend its DC; a Barbarian's ritual-only spells keep their own ability.
			var gcid := str(g.get("class_id", ""))
			if spellcasting_entry(gcid).is_empty():
				gcid = ""
			out.append({"id": str(g["id"]), "class_id": gcid, "ability": str(g["ability"]), "kind": "granted",
				"source": str(g["source"]), "uses": int(g["uses"]), "recharge": str(g["recharge"])})
	return out


## What a spell does when this character casts it at `slot_level` (0 = its own level): damage and healing
## dice with every bonus named, plus the attack bonus or save DC. Used by spell cards and the combat log.
## {name, level, slot, ability, damage_dice, damage_type, damage_bonus: Breakdown, heal_dice,
##  heal_bonus: Breakdown, attack: Breakdown, save_dc: Breakdown, save}
func spell_preview(spell_id: String, slot_level: int = 0) -> Dictionary:
	var s := compendium.spell_data(spell_id)
	if s.is_empty():
		return {}
	var level := int(s.get("level", 0))
	var slot := 0 if level == 0 else maxi(level, slot_level)
	var source := {}
	for k in known_spells():
		if str(k["id"]) == spell_id:
			source = k
			break
	var class_id := str(source.get("class_id", ""))
	var ab := StringName(str(source.get("ability", "")))
	if not Creature.ABILITY_NAMES.has(ab):
		ab = &"int"
		for e in spellcasting:
			if str(s.get("classes", [])).contains(str(e["list"])):
				ab = StringName(str(e["ability"]))
				class_id = str(e["class_id"])
	var mod := ability_mod(ab)
	var ctx := formula_context(slot)
	var out := {"name": str(s["name"]), "level": level, "slot": slot, "ability": str(ab), "class_id": class_id}
	var damage := s.get("damage", []) as Array
	if not damage.is_empty():
		var first := damage[0] as Dictionary
		out["damage_dice"] = Spellcasting.damage_dice(s, character_level(), slot)
		out["damage_type"] = str(first.get("type", ""))
		var bonus := Breakdown.new("%s damage bonus" % s["name"])
		if bool(first.get("add_mod", false)):
			bonus.add("%s modifier" % ABILITY_SHORT[ab], mod)
		var situation := {"spell": true, "school": str(s.get("school", "")), "spell_class": class_id, "spell_id": spell_id,
			"damage_type": str(first.get("type", ""))}
		if level == 0:
			for m in modifiers_for(&"cantrip_damage"):
				if m.applies_when(situation):
					bonus.add_nonzero(m.source_name, mod_value(m, ctx))
		for m in modifiers_for(&"spell_damage"):
			if m.applies_when(situation):
				bonus.add_nonzero(m.source_name, mod_value(m, ctx))
		out["damage_bonus"] = bonus
	var heal := s.get("heal", {}) as Dictionary
	if heal.has("dice"):
		out["heal_dice"] = Spellcasting.heal_dice(s, slot)
		var hb := Breakdown.new("%s healing bonus" % s["name"])
		if bool(heal.get("add_mod", false)):
			hb.add("%s modifier" % ABILITY_SHORT[ab], mod)
		if slot >= 1:
			for m in modifiers_for(&"healing_bonus"):
				hb.add_nonzero(m.source_name, mod_value(m, ctx))
		out["heal_bonus"] = hb
	if s.has("attack") and class_id != "":
		out["attack"] = spell_attack_bonus(class_id)
	if s.has("save") and class_id != "":
		out["save"] = str(s["save"])
		out["save_dc"] = spell_save_dc(class_id)
	return out


func knows_spell(spell_id: String) -> bool:
	for s in known_spells():
		if str(s["id"]) == spell_id:
			return true
	return false


# --- Resources -----------------------------------------------------------------------------------

func _apply_resources() -> void:
	var keep := {}
	var ctx := formula_context()
	for cid in class_order:
		var cls := compendium.class_data(cid)
		var lists: Array[Dictionary] = [{"defs": cls.get("resources", []), "label": str(cls.get("name", cid))}]
		if subclasses.has(cid):
			var sub := compendium.subclass_data(str(subclasses[cid]))
			lists.append({"defs": sub.get("resources", []), "label": str(sub.get("name", ""))})
		for l in lists:
			for r: Variant in l["defs"]:
				var rd := r as Dictionary
				if class_level_of(cid) < int(rd.get("from_level", 1)):
					continue
				var maximum := 0
				if rd.has("table"):
					var v: Variant = class_column(cid, str(rd["table"]))
					maximum = int(v) if v != null else 0
				elif rd.has("max"):
					var c := ctx.duplicate()
					c["class_level"] = class_level_of(cid)
					maximum = Formula.evaluate(rd["max"], c)
				if rd.has("min"):
					maximum = maxi(maximum, int(rd["min"]))
				if maximum > 0:
					set_resource(str(rd["id"]), str(rd["name"]), maximum, str(rd["recharge"]), str(l["label"]))
					keep[str(rd["id"])] = true
	for rd in _resource_defs:
		var c2 := ctx.duplicate()
		c2["class_level"] = class_level_of(str(rd.get("class_id", "")))
		var maximum2 := Formula.evaluate(rd.get("max", 1), c2)
		if rd.has("min"):
			maximum2 = maxi(maximum2, int(rd["min"]))
		if maximum2 > 0:
			set_resource(str(rd["id"]), str(rd["name"]), maximum2, str(rd.get("recharge", "long")), str(rd["source"]))
			keep[str(rd["id"])] = true
	# Spells from species and feats that can be cast without a slot a number of times per rest.
	for g in granted_spells:
		if int(g["uses"]) > 0 and int(g["at_level"]) <= character_level():
			var gid := "spell:%s" % g["id"]
			set_resource(gid, compendium.display_name("spells", str(g["id"])), int(g["uses"]),
				str(g["recharge"]) if str(g["recharge"]) != "" else "long", str(g["source"]))
			keep[gid] = true
	for k: String in resources.keys():
		if not keep.has(k):
			resources.erase(k)


# --- Ability scores ------------------------------------------------------------------------------

func base_ability_parts(ab: StringName) -> Array[Dictionary]:
	var scores := build.get("base_scores", {}) as Dictionary
	var base := int(scores.get(str(ab), 10))
	var method := str(build.get("ability_method", "standard_array")).replace("_", " ").capitalize()
	var parts: Array[Dictionary] = [{"label": "Base (%s)" % method, "value": base}]
	var running := base
	var grouped := {}
	var order: Array[String] = []
	# Manuals and tomes (2024 DMG): +2 to a score and to its maximum, for good.
	var raise := 0
	var boons: Array[Dictionary] = []
	for bv: Variant in build.get("item_boons", []):
		var bd := bv as Dictionary
		if str(bd.get("ability", "")) == str(ab):
			raise += int(bd.get("max_raise", 0))
			boons.append(bd)
	var all_incs: Array = _increases.duplicate()
	for bd2 in boons:
		all_incs.append({"ability": str(ab), "amount": int(bd2.get("value", 2)), "max": 20, "label": str(bd2.get("source", "Magic book"))})
	for inc: Variant in all_incs:
		var incd := inc as Dictionary
		if str(incd["ability"]) != str(ab):
			continue
		var gain := mini(int(incd["amount"]), maxi(0, int(incd["max"]) + raise - running))
		running += gain
		var label := str(incd["label"])
		if not grouped.has(label):
			grouped[label] = 0
			order.append(label)
		grouped[label] = int(grouped[label]) + gain
	for label in order:
		if int(grouped[label]) != 0:
			parts.append({"label": label, "value": int(grouped[label])})
	return parts


# --- Proficiencies -------------------------------------------------------------------------------

func save_proficiency(ab: StringName) -> String:
	var t := proficiencies["saves"] as Dictionary
	if t.has(str(ab)):
		return str(t[str(ab)])
	return proficiency_source("save", ab)


func skill_rank(skill: StringName) -> int:
	var proficient := (proficiencies["skills"] as Dictionary).has(str(skill)) or proficiency_source("skill", skill) != ""
	if expertise.has(str(skill)) or _modifier_expertise(skill):
		return 2
	return 1 if proficient else 0


func _modifier_expertise(skill: StringName) -> bool:
	for m in modifiers_for(&"expertise"):
		if m.text("value") == skill:
			return true
	return false


func has_proficiency(kind: String, value: String) -> bool:
	if (proficiencies.get(kind, {}) as Dictionary).has(value):
		return true
	var singular := {"armor": "armor", "weapons": "weapon", "tools": "tool", "languages": "language",
		"saves": "save", "skills": "skill"}
	return proficiency_source(str(singular.get(kind, kind)), value) != ""


func proficiency_list(kind: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in (proficiencies.get(kind, {}) as Dictionary):
		out.append(k)
	var singular := {"armor": "armor", "weapons": "weapon", "tools": "tool", "languages": "language",
		"saves": "save", "skills": "skill"}
	for m in modifiers_for(&"proficiency"):
		if m.text("kind") == str(singular.get(kind, kind)) and not m.text("value") in out:
			out.append(m.text("value"))
	return out


func has_armor_training(kind: String) -> bool:
	return has_proficiency("armor", "shields" if kind == "shield" else kind)


func weapon_proficient(item: Dictionary) -> bool:
	return Gear.weapon_proficient(proficiency_list("weapons"), item)


## Whether the character is trained to wear this armor or Shield: its kind's training, or armor that needs none
## (Elven Chain: `armor_rules.no_training`).
func trained_for(armor_item: Dictionary) -> bool:
	if bool((armor_item.get("armor_rules", {}) as Dictionary).get("no_training", false)):
		return true
	return has_armor_training(str((armor_item.get("armor", {}) as Dictionary).get("kind", "")))


# --- Hit Points ----------------------------------------------------------------------------------

func max_hp_breakdown() -> Breakdown:
	var b := Breakdown.new("Hit Points")
	var levels := build.get("levels", []) as Array
	if levels.is_empty():
		b.add("No class yet", 0)
		return b
	var con := ability_mod(&"con")
	var fixed_total := 0
	var fixed_count := 0
	var rolled_total := 0
	var rolled_count := 0
	var minimum_fix := 0
	for i in levels.size():
		var lv := levels[i] as Dictionary
		var die := int(compendium.class_data(str(lv["class"])).get("hit_die", 8))
		var gain := 0
		if i == 0:
			b.add("Level 1 (%s d%d maximum)" % [class_name_of(str(lv["class"])), die], die)
			continue
		var roll := int(lv.get("hp", 0))
		if roll <= 0:
			gain = die / 2 + 1
			fixed_total += gain
			fixed_count += 1
		else:
			gain = clampi(roll, 1, die)
			rolled_total += gain
			rolled_count += 1
		if gain + con < 1:
			minimum_fix += 1 - (gain + con)
	if fixed_count > 0:
		b.add("%d level%s at the fixed value" % [fixed_count, "" if fixed_count == 1 else "s"], fixed_total)
	if rolled_count > 0:
		b.add("%d rolled level%s" % [rolled_count, "" if rolled_count == 1 else "s"], rolled_total)
	b.add("Con modifier %s × %d" % ["%+d" % con, levels.size()], con * levels.size())
	b.add_nonzero("Minimum 1 per level", minimum_fix)
	_add_hp_modifiers(b)
	return b


## Hit Point Dice by die size: {"10": {total, spent}}.
func hit_dice() -> Dictionary:
	var out := {}
	for lv: Variant in build.get("levels", []):
		var die := str(int(compendium.class_data(str((lv as Dictionary)["class"])).get("hit_die", 8)))
		if not out.has(die):
			out[die] = {"total": 0, "spent": int(hit_dice_spent.get(die, 0))}
		(out[die] as Dictionary)["total"] = int((out[die] as Dictionary)["total"]) + 1
	return out


## Spends one Hit Point Die during a Short Rest: roll + Con modifier, minimum 1 (2024 glossary).
func spend_hit_die(dice: DiceRoller, die: int) -> int:
	var pool := hit_dice()
	var key := str(die)
	if not pool.has(key):
		return 0
	var entry := pool[key] as Dictionary
	if int(entry["spent"]) >= int(entry["total"]):
		return 0
	hit_dice_spent[key] = int(entry["spent"]) + 1
	var roll := dice.roll_one(die, "Hit Point Die (%s)" % name)
	# Potion of Vitality, Periapt of Wound Closure: the die heals its maximum (or twice what it rolls).
	if has_flag("max_hit_dice"):
		roll = die
	var healed := maxi(1, roll + ability_mod(&"con"))
	if has_flag("double_hit_dice"):
		healed *= 2
	return heal(healed, "Hit Point Die")


## Mist Walker's drawback (a Ravenloft Dark Gift): until the character has travelled 10 miles since its last Long
## Rest, a Short Rest calls for a Constitution save (DC 13 + PB); on a failure the rest gives nothing. True if the
## Mists deny this rest.
func mists_deny_short_rest(dice: DiceRoller, miles_since_long_rest: float) -> bool:
	if miles_since_long_rest >= 10.0 or not feats_taken.any(func(f: Dictionary) -> bool: return str(f["id"]) == "mist_walker"):
		return false
	var sv := roll_save(dice, &"con", 13 + proficiency_bonus(), [], [], "Constitution save vs the Mists (%s)" % name)
	return not sv.success


## Short Rest: resources (Creature) and every Pact Magic slot come back. Hit Point Dice are spent separately.
## Tireless (Ranger 10) also takes away a level of Exhaustion.
func finish_short_rest() -> void:
	super.finish_short_rest()
	open_slot_recovery("short_rest")
	pact_slots_used = 0
	_reset_item_uses(["short"])
	if has_flag("tireless") and exhaustion > 0 and not dead:
		exhaustion -= 1
		log_event({"type": "exhaustion", "creature": id, "level": exhaustion})
	_rest_temp_hp()


## Celestial Resilience (Celestial Warlock 10): after a Short or Long Rest, Temporary Hit Points equal to the Warlock
## level + Charisma modifier. (Sharing some with up to five others is the rest screen's part.)
func _rest_temp_hp() -> void:
	if dead:
		return
	for m in modifiers_for(&"flag"):
		if m.text("value") == "celestial_resilience":
			add_temp_hp(maxi(0, class_level_of(m.class_id) + ability_mod(&"cha")), m.source_name)


func finish_long_rest() -> void:
	super.finish_long_rest()
	close_slot_recovery()
	if dead:
		return
	hit_dice_spent.clear()
	slots_used = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	pact_slots_used = 0
	_reset_item_uses(["short", "long"])
	_rest_temp_hp()
	if has_flag("resourceful"):
		heroic_inspiration = true


# --- Equipment -----------------------------------------------------------------------------------

## Fills the inventory from the chosen class and background equipment options and equips the best gear.
func apply_starting_equipment() -> void:
	inventory.clear()
	currency = {"cp": 0, "sp": 0, "ep": 0, "gp": 0, "pp": 0}
	var eq := build.get("equipment", {}) as Dictionary
	if not class_order.is_empty():
		var first := compendium.class_data(class_order[0])
		_take_option(first.get("starting_equipment", []) as Array, str(eq.get("class", "a")))
	var bg := compendium.background_data(str(build.get("background", "")))
	if not bg.is_empty():
		_take_option(bg.get("equipment", []) as Array, str(eq.get("background", "a")))
	auto_equip()


func _take_option(options: Array, pick: String) -> void:
	for o: Variant in options:
		var opt := o as Dictionary
		if str(opt.get("id", "")) != pick:
			continue
		for it: Variant in opt.get("items", []):
			var item := it as Dictionary
			add_item(str(item["id"]), int(item.get("qty", 1)))
		currency["gp"] = int(currency["gp"]) + int(opt.get("gp", 0))


## Adds `qty` of an item. `state` carries an item's own state when it moves (charges, uses, a lifted curse, what a
## Bag of Holding holds); a new magic item with charges starts with its full count (MagicItems.starting_charges).
func add_item(item_id: String, qty: int = 1, state: Dictionary = {}) -> void:
	# A scroll that only says its level becomes a particular spell (each one picked on its own).
	if MagicItems.GENERIC_SCROLLS.has(item_id):
		for i in qty:
			add_item(MagicItems.specific_scroll(item_id, "%s:%s:%d:%d" % [id, name, inventory.size(), i], compendium), 1, state)
		return
	var data := compendium.item_data(item_id)
	if bool(data.get("stackable", false)):
		for entry in inventory:
			if str(entry["id"]) == item_id:
				entry["qty"] = int(entry["qty"]) + qty
				return
		inventory.append({"id": item_id, "qty": qty, "slot": ""})
	else:
		for i in qty:
			var entry := {"id": item_id, "qty": 1, "slot": ""}
			for k: String in state:
				if not k in ["id", "qty", "slot"]:
					entry[k] = (state[k] as Variant) if not (state[k] is Dictionary or state[k] is Array) else state[k].duplicate(true)
			# A new item: its charges, gems, beads, patches or artifact properties (rolled with a roller seeded by what it is,
			# so the same item found the same way starts the same; treasure passes its own rolled state).
			if MagicItems.is_magic(data) and not entry.has("made"):
				var fresh := MagicItems.init_state(data, DiceRoller.new(hash("%s:%d:%s" % [item_id, inventory.size(), name])), compendium)
				for k2: String in fresh:
					if not entry.has(k2):
						entry[k2] = fresh[k2]
				entry["made"] = true
			inventory.append(entry)
	_item_mods_key = ""


## An inventory entry's own state worth keeping when the item changes hands (everything but id, qty and slot).
static func entry_state(entry: Dictionary) -> Dictionary:
	var out := {}
	for k: String in entry:
		if not k in ["id", "qty", "slot"]:
			out[k] = entry[k]
	return out.duplicate(true)


## Removes one `item_id` from the pack and returns its entry state (for giving it to someone else); {} if not carried.
func remove_one(item_id: String) -> Dictionary:
	for e: Dictionary in inventory.duplicate():
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			var state := entry_state(e)
			if str(e.get("slot", "")) != "" and int(e["qty"]) <= 1:
				e["slot"] = ""
			e["qty"] = int(e["qty"]) - 1
			if int(e["qty"]) <= 0:
				inventory.erase(e)
			if item_id in attuned and entry_of(item_id).is_empty():
				attuned.erase(item_id)
			_item_mods_key = ""
			return state
	return {}


func equipped(slot: String) -> Dictionary:
	for entry in inventory:
		if str(entry["slot"]) == slot:
			return compendium.item_data(str(entry["id"]))
	return {}


## Every item in a slot (rings: two; Ioun Stones: any number).
func equipped_all(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in inventory:
		if str(entry["slot"]) == slot:
			out.append(compendium.item_data(str(entry["id"])))
	return out


## Puts `item_id` in `slot`. Slots hold one item (rings two, Ioun Stones any number); the oldest one in a full slot
## comes off.
func equip(item_id: String, slot: String) -> bool:
	var cap := int(MagicItems.SLOT_CAPACITY.get(slot, 1))
	var holding: Array[Dictionary] = []
	for entry in inventory:
		if str(entry["slot"]) == slot:
			holding.append(entry)
	for entry in inventory:
		if str(entry["id"]) == item_id and str(entry["slot"]) == "":
			if holding.size() >= cap:
				holding[0]["slot"] = ""
			entry["slot"] = slot
			_item_mods_key = ""
			var situation := armor_situation()
			if str(situation["armor"]) != "none" or bool(situation["shield"]):
				for fx: Effect in effects.duplicate():
					if bool(fx.data.get("ends_when_armored", false)):
						remove_effect(fx)
			return true
	return false


## Wears a worn magic item in its slot (a cloak on the shoulders, a ring on a finger).
func wear(item_id: String) -> bool:
	var slot := MagicItems.worn_slot(compendium.item_data(item_id))
	return slot != "" and equip(item_id, slot)


func unequip(slot: String) -> void:
	for entry in inventory:
		if str(entry["slot"]) == slot:
			entry["slot"] = ""
	_item_mods_key = ""


## Takes off one particular item wherever it's worn or held.
func unequip_item(item_id: String) -> void:
	for entry in inventory:
		if str(entry["id"]) == item_id and str(entry["slot"]) != "":
			entry["slot"] = ""
			_item_mods_key = ""
			return


## Picks armor the character is trained in (best AC), a Shield if trained and one-handed fighting suits, and
## the best melee weapon. The player can change all of it; this just gives a sensible start.
func auto_equip() -> void:
	for slot in EQUIP_SLOTS:
		unequip(slot)
	var best_armor := ""
	var best_ac := -1
	var dex := ability_mod(&"dex")
	var shield_id := ""
	for entry in inventory:
		var item := compendium.item_data(str(entry["id"]))
		if Gear.is_armor(item):
			var a := item["armor"] as Dictionary
			if not trained_for(item):
				continue
			var cap: Variant = a.get("dex_cap", null)
			if cap != null and int(cap) == 2 and has_flag("dexterous_wearer") and ability_score(&"dex") >= 16:
				cap = 3
			var ac := int(a["base_ac"]) + (dex if cap == null else mini(dex, int(cap)))
			if ac > best_ac:
				best_ac = ac
				best_armor = str(item["id"])
		elif Gear.is_shield(item) and trained_for(item):
			shield_id = str(item["id"])
	if best_armor != "" and best_ac > 10 + dex:
		equip(best_armor, "armor")
	var best_weapon := ""
	var best_avg := -1.0
	for entry in inventory:
		var w := compendium.item_data(str(entry["id"]))
		if not Gear.is_weapon(w) or Gear.is_ranged_weapon(w):
			continue
		if shield_id != "" and "two_handed" in Gear.weapon_props(w):
			continue
		var avg := Gear.average(str((w["weapon"] as Dictionary)["damage"])) + (2.0 if weapon_proficient(w) else 0.0)
		if avg > best_avg:
			best_avg = avg
			best_weapon = str(w["id"])
	if best_weapon != "":
		equip(best_weapon, "main_hand")
	if shield_id != "":
		equip(shield_id, "off_hand")


## Martial Arts (a feature with the `martial_arts` flag): the class table's die for Unarmed Strikes and Monk weapons
## while wearing no armor and no Shield, else "".
func martial_arts_die() -> String:
	for m in modifiers_for(&"flag"):
		if m.text("value") != "martial_arts" or m.class_id == "":
			continue
		var situation := armor_situation()
		if str(situation["armor"]) != "none" or bool(situation["shield"]):
			return ""
		var v: Variant = class_column(m.class_id, "martial_arts")
		return str(v) if v != null else ""
	return ""


func armor_situation() -> Dictionary:
	var armor := equipped("armor")
	var off := equipped("off_hand")
	var kind := "none"
	if not armor.is_empty():
		kind = str((armor["armor"] as Dictionary)["kind"])
	return {"armor": kind, "shield": Gear.is_shield(off)}


func armor_class() -> Breakdown:
	var situation := armor_situation()
	var armor := equipped("armor")
	var dex := ability_mod(&"dex")
	var candidates: Array[Breakdown] = []
	var base := Breakdown.new("AC")
	if armor.is_empty():
		base.add("Unarmored", 10)
		base.add("Dex modifier", dex)
	else:
		var a := armor["armor"] as Dictionary
		base.add(str(armor["name"]), int(a["base_ac"]))
		var cap: Variant = a.get("dex_cap", null)
		# Medium Armor Master: the Dexterity cap rises to 3 with Dexterity 16 or higher.
		if cap != null and int(cap) == 2 and has_flag("dexterous_wearer") and ability_score(&"dex") >= 16:
			cap = 3
		if cap == null:
			base.add("Dex modifier", dex)
		elif int(cap) > 0:
			base.add("Dex modifier (max %d)" % int(cap), mini(dex, int(cap)))
	candidates.append(base)
	for m in modifiers_for(&"ac_formula"):
		if not m.applies_when(situation):
			continue
		var alt := Breakdown.new("AC")
		alt.add(m.source_name, m.number("base", 10))
		for ab: Variant in m.data.get("abilities", []):
			alt.add("%s modifier" % ABILITY_SHORT[StringName(str(ab))], ability_mod(StringName(str(ab))))
		candidates.append(alt)
	var best := candidates[0]
	for c in candidates:
		if c.total() > best.total():
			best = c
	var off := equipped("off_hand")
	if Gear.is_shield(off):
		if trained_for(off):
			best.add(str(off["name"]), int((off["armor"] as Dictionary)["base_ac"]))
		else:
			best.note("%s gives no AC without Shield training" % off["name"])
	_add_ac_modifiers(best, situation)
	return best


func gear_d20_sources(keys: Array[String]) -> Dictionary:
	var adv: Array[String] = []
	var dis: Array[String] = []
	var armor := equipped("armor")
	if not armor.is_empty():
		var a := armor["armor"] as Dictionary
		if not trained_for(armor):
			for k in keys:
				if k in ["save:str", "save:dex", "check:str", "check:dex", "attack", "initiative"]:
					dis.append("%s without training" % armor["name"])
					break
		if bool(a.get("stealth_disadvantage", false)) and "check:stealth" in keys:
			dis.append(str(armor["name"]))
	return {"advantage": adv, "disadvantage": dis}


func _speed_adjustments(b: Breakdown) -> void:
	var armor := equipped("armor")
	if armor.is_empty():
		return
	var need := int((armor["armor"] as Dictionary).get("strength", 0))
	if need > 0 and ability_score(&"str") < need and not has_flag("speed_not_reduced"):
		b.add("%s (needs Strength %d)" % [armor["name"], need], -10)


func carried_weight() -> float:
	var total := 0.0
	for entry in inventory:
		var data := compendium.item_data(str(entry["id"]))
		total += float(data.get("weight_lb", 0.0)) * int(entry["qty"])
		# What's inside a container counts, unless it's extradimensional (a Bag of Holding always weighs 5 lb).
		if not bool((data.get("container", {}) as Dictionary).get("weightless", false)):
			total += _contents_weight(entry)
	return total


# --- Containers (Bag of Holding, Heward's Handy Haversack, Portable Hole, Efficient Quiver) ---------------

const FOOD: Array[String] = ["ration", "dream_pastry", "goodberry", "bead_of_nourishment"]


func _contents_weight(entry: Dictionary) -> float:
	var w := 0.0
	for c: Variant in entry.get("contents", []):
		var cd := c as Dictionary
		w += float(compendium.item_data(str(cd["id"])).get("weight_lb", 0.0)) * int(cd.get("qty", 1))
	return w


## The first carried container entry with this id ({} if none).
func container_entry(container_id: String) -> Dictionary:
	var e := entry_of(container_id)
	return e if not e.is_empty() and compendium.item_data(container_id).has("container") else {}


## What a container holds: [{id, qty, ...state}].
func contents_of(container_id: String) -> Array:
	return container_entry(container_id).get("contents", []) as Array


## Puts one `item_id` from the pack into the container. "" on success, else why not (too heavy, the wrong kind of
## thing). Putting one extradimensional space in another tears both open: both are destroyed with all they held.
## A Bag of Devouring eats food.
func put_in(container_id: String, item_id: String) -> String:
	var ce := container_entry(container_id)
	if ce.is_empty():
		return "No such container"
	if container_id == item_id and entry_of(item_id) == ce:
		return "It can't hold itself"
	var spec := compendium.item_data(container_id).get("container", {}) as Dictionary
	var data := compendium.item_data(item_id)
	var only := spec.get("only", []) as Array
	if not only.is_empty() and not str(data.get("category", "")) in only:
		return "It only holds %s" % " and ".join(only)
	var weight := _contents_weight(ce) + float(data.get("weight_lb", 0.0))
	if weight > float(spec.get("capacity_lb", 0)):
		return "Too heavy: it holds %d lb" % int(spec.get("capacity_lb", 0))
	if bool(spec.get("extradimensional", false)) and bool((data.get("container", {}) as Dictionary).get("extradimensional", false)):
		remove_one(item_id)
		ce["contents"] = []
		remove_one(container_id)
		return "rift"
	var st := remove_one(item_id)
	if bool(spec.get("devours", false)) and (item_id in FOOD or str(data.get("category", "")) == "consumable"):
		ce["identified"] = true
		return "devoured"
	if not ce.has("contents"):
		ce["contents"] = []
	var stored := st.duplicate()
	stored["id"] = item_id
	stored["qty"] = 1
	(ce["contents"] as Array).append(stored)
	return ""


func _was_stackable(item_id: String) -> bool:
	return bool(compendium.item_data(item_id).get("stackable", false))


## Takes the item at `index` out of the container and back into the pack.
func take_out(container_id: String, index: int) -> bool:
	var ce := container_entry(container_id)
	var items := ce.get("contents", []) as Array
	if index < 0 or index >= items.size():
		return false
	var st := (items[index] as Dictionary).duplicate()
	items.remove_at(index)
	add_item(str(st["id"]), int(st.get("qty", 1)), st)
	return true


## Whether the character carries `item_id`, in the pack or inside a container.
func carries(item_id: String) -> bool:
	if not entry_of(item_id).is_empty():
		return true
	for e in inventory:
		for c: Variant in e.get("contents", []):
			if str((c as Dictionary)["id"]) == item_id:
				return true
	return false


## Attack options for the sheet: every weapon carried plus an Unarmed Strike.
func attacks() -> Array[WeaponProfile]:
	var out: Array[WeaponProfile] = []
	var seen := {}
	for entry in inventory:
		var item := compendium.item_data(str(entry["id"]))
		if not Gear.is_weapon(item) or seen.has(str(item["id"])):
			continue
		seen[str(item["id"])] = true
		out.append(WeaponProfile.build(self, item, false, true))
		# Magic ammunition: one profile per kind carried, with the ammunition's own bonuses.
		var kind := str((item["weapon"] as Dictionary).get("ammunition", ""))
		if kind != "":
			var shot := {}
			for a in inventory:
				var ad := compendium.item_data(str(a["id"]))
				if int(a["qty"]) > 0 and MagicItems.is_magic(ad) and Gear.ammo_matches(ad, kind) and not shot.has(str(ad["id"])):
					shot[str(ad["id"])] = true
					out.append(WeaponProfile.build(self, item, false, true, ad))
		if "thrown" in Gear.weapon_props(item) and not Gear.is_ranged_weapon(item):
			out.append(WeaponProfile.build(self, item, true, false))
	out.append(WeaponProfile.unarmed(self))
	return out


# --- Saving and loading --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"build": build.duplicate(true), "state": state_to_dict(), "inventory": inventory.duplicate(true),
		"currency": currency.duplicate(), "hit_dice_spent": hit_dice_spent.duplicate(),
		"slots_used": slots_used.duplicate(), "pact_slots_used": pact_slots_used,
		"heroic_inspiration": heroic_inspiration, "id": id, "attuned": attuned.duplicate()}


static func from_dict(d: Dictionary, compendium_: Compendium = null) -> Character:
	var c := Character.from_build(d.get("build", {}) as Dictionary, compendium_)
	c.id = str(d.get("id", c.id))
	c.state_from_dict(d.get("state", {}) as Dictionary)
	c.inventory.clear()
	for e: Variant in d.get("inventory", []):
		var ed := (e as Dictionary).duplicate()
		# Saves from before magic items: generic scrolls become particular ones.
		if MagicItems.GENERIC_SCROLLS.has(str(ed.get("id", ""))):
			c.add_item(str(ed["id"]), int(ed.get("qty", 1)))
			continue
		c.inventory.append(ed)
	c.currency = (d.get("currency", c.currency) as Dictionary).duplicate()
	c.hit_dice_spent = (d.get("hit_dice_spent", {}) as Dictionary).duplicate()
	var used := d.get("slots_used", []) as Array
	for i in mini(9, used.size()):
		c.slots_used[i] = int(used[i])
	c.pact_slots_used = int(d.get("pact_slots_used", 0))
	c.heroic_inspiration = bool(d.get("heroic_inspiration", false))
	for a: Variant in d.get("attuned", []):
		c.attuned.append(str(a))
	return c


func spend_resource(res_id: String, amount: int = 1) -> bool:
	if not super.spend_resource(res_id, amount):
		return false
	if amount > 0:
		for modifier in modifiers_for(&"resource_restore"):
			if modifier.text("when_spent") == res_id:
				var ctx := formula_context()
				ctx["class_level"] = class_level_of(modifier.class_id)
				restore_resource(modifier.text("resource"), maxi(0, modifier.value_on(ctx)))
	return true


## Transient choices belong to the just-finished rest or feature event, never to a saved build.
var _slot_recovery_windows: Dictionary = {}

func open_slot_recovery(trigger: String) -> void:
	for feature in features:
		var rule := feature.get("slot_exchange", {}) as Dictionary
		if trigger in (rule.get("recover_on", []) as Array):
			_slot_recovery_windows[str(feature["id"])] = true

func close_slot_recovery() -> void:
	_slot_recovery_windows.clear()

## All values and level gates come from a feature's exchange table; no subclass names here.
func slot_recovery_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	for feature in features:
		var rule := feature.get("slot_exchange", {}) as Dictionary
		if rule.is_empty() or not _slot_recovery_windows.has(str(feature["id"])):
			continue
		for tier: Dictionary in rule.get("recover", []):
			var slot := int(tier["slot"])
			if class_level_of(str(feature["class_id"])) < int(tier["at_level"]) or resource_left(str(rule["resource"])) < int(tier["cost"]) or expended_slots(slot) <= 0:
				continue
			out.append({"feature": str(feature["id"]), "label": str(feature["name"]), "slot": slot,
				"resource": str(rule["resource"]), "cost": int(tier["cost"])})
	return out

func recover_slot_with_resource(feature_id: String, slot: int) -> bool:
	for option in slot_recovery_options():
		if str(option["feature"]) != feature_id or int(option["slot"]) != slot:
			continue
		if not spend_resource(str(option["resource"]), int(option["cost"])):
			return false
		recover_slot(slot)
		_slot_recovery_windows.erase(feature_id)
		return true
	return false

func slot_conversion_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	for feature in features:
		var rule := feature.get("slot_exchange", {}) as Dictionary
		if rule.is_empty() or not bool(rule.get("slot_to_resource", false)):
			continue
		var resource := str(rule["resource"])
		if resource_left(resource) >= resource_max(resource):
			continue
		for slot in range(1, 10):
			if slots_left(slot) > 0:
				out.append({"feature": str(feature["id"]), "label": str(feature["name"]), "resource": resource, "slot": slot})
	return out

func convert_slot_to_resource(feature_id: String, slot: int) -> bool:
	for option in slot_conversion_options():
		if str(option["feature"]) == feature_id and int(option["slot"]) == slot:
			if not expend_slot(slot):
				return false
			restore_resource(str(option["resource"]), slot)
			return true
	return false


## Alternate casting payments are feature data. Eligibility uses the prepared source, not a spell's class list.
## These options remain visible when exhausted so callers can explain the unavailable resource.
func resource_casts(spell_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var spell := compendium.spell_data(spell_id)
	if spell.is_empty():
		return out
	for feature in features:
		var rule := feature.get("resource_cast", {}) as Dictionary
		if rule.is_empty():
			continue
		# One named spell (Spellfire Spark's Sacred Flame), or any prepared spell of a school (Mind Magic).
		if rule.has("spell"):
			if str(rule["spell"]) != spell_id:
				continue
		elif str(spell.get("school", "")) != str(rule.get("school", "")):
			continue
		var cid := str(feature["class_id"])
		var sub := compendium.subclass_data(str(subclasses.get(cid, "")))
		var on_table := false
		for tier: Variant in (sub.get("always_prepared", {}) as Dictionary).values():
			if spell_id in (tier as Array):
				on_table = true
		if bool(rule.get("subclass_spells", false)) and not on_table:
			continue
		for known in known_spells():
			if str(known["id"]) == spell_id and str(known["class_id"]) == cid and str(known["kind"]) in ["prepared", "always", "granted"]:
				var option := feature.duplicate(true)
				option["ability"] = str(known["ability"])
				out.append(option)
				break
	return out
