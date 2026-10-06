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
## One entry per Spellcasting feature: {class_id, name, ability, list, progression, cantrips_max,
## prepared_max, spellbook_max, cantrips, prepared, spellbook, always, bonus, ritual}
var spellcasting: Array[Dictionary] = []
## Spells from species and feats: {id, ability, uses, recharge, always_prepared, at_level, source}
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
	return Abilities.proficiency_bonus(maxi(1, character_level()))


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
	return _modifiers


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
		_walk_feat(str(bg["feat"]), "background.feat", src, bg.get("feat_params", {}) as Dictionary)


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
	if f.has("choice"):
		var c := f["choice"] as Dictionary
		var picks := _register_choice(c, key, src, str(f.get("name", "")), scope)
		scope[str(c.get("id", "choice"))] = picks
	for c2: Variant in f.get("choices", []):
		var cd := c2 as Dictionary
		var sub_key := "%s.%s" % [key, cd.get("id", "choice")]
		var picks2 := _register_choice(cd, sub_key, src, str(f.get("name", "")), scope)
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
	elif str(d.get("ability", "")) == "choice":
		d["ability"] = str(scope.get("choice", ""))
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


func _add_increases(picks: Array[String], cap: int, label: String) -> void:
	for p in picks:
		_increases.append({"ability": p, "amount": 1, "max": cap, "label": label})


## Registers a choice, applies its current picks and returns them.
func _register_choice(def: Dictionary, key: String, src: Dictionary, label: String, scope: Dictionary = {}) -> Array[String]:
	var c := Choice.new()
	c.key = key
	c.kind = str(def.get("kind", "option"))
	c.count = int(def.get("count", 1))
	c.label = label if label != "" else c.kind.capitalize()
	c.source = str(src["label"])
	c.source_kind = str(src["kind"])
	c.class_id = str(src.get("class_id", ""))
	c.level = int(src.get("character_level", character_level()))
	c.replaceable = str(def.get("replaceable", ""))
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
	choice_defs.append(c)
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
				_walk_feat(p, "%s/%s" % [c.key, p], src)
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


## Choices whose count follows a class table column (Weapon Mastery 3 -> 4 -> 5 -> 6).
func _fix_dynamic_counts() -> void:
	for c in choice_defs:
		if c.filter.has("_count_column") and c.class_id != "":
			var v: Variant = class_column(c.class_id, str(c.filter["_count_column"]))
			if v != null:
				c.count = int(v)


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
			"fixed_cantrips": fixed_cantrips}
		var cantrip_count := cantrips_max - fixed_cantrips.size()
		if cantrip_count > 0:
			entry["cantrips"] = _register_choice({"kind": "cantrip", "count": cantrip_count,
				"filter": {"list": list, "level": 0}, "replaceable": str(sc.get("swap_cantrip", "level_up"))},
				"%s.cantrips" % cid, src, "%s cantrips" % name_).duplicate()
		var book := sc.get("spellbook", {}) as Dictionary
		if not book.is_empty():
			entry["spellbook_max"] = int(book.get("start", 6)) + int(book.get("per_level", 2)) * (n - 1)
			entry["spellbook"] = _register_choice({"kind": "spellbook", "count": int(entry["spellbook_max"]),
				"filter": {"list": list, "max_level": "slots"}}, "%s.spellbook" % cid, src, "Spellbook").duplicate()
		if prepared_max > 0:
			var filter := {"list": list, "max_level": "slots", "min_level": 1}
			if not book.is_empty():
				filter["from_choice"] = "%s.spellbook" % cid
			entry["prepared"] = _register_choice({"kind": "spell", "count": prepared_max, "filter": filter,
				"replaceable": str(sc.get("swap_prepared", "long_rest"))}, "%s.prepared" % cid, src, "Prepared spells").duplicate()
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
		if c.key.begins_with("%s." % c.class_id) and (c.key.ends_with(".cantrips") or c.key.ends_with(".prepared") or c.key.ends_with(".spellbook")) and c.key.count(".") == 1:
			continue
		for e in spellcasting:
			if str(e["class_id"]) == c.class_id:
				for p in c.picks:
					if c.kind == "spellbook":
						(e["spellbook"] as Array).append(p)
					else:
						(e["bonus"] as Array).append({"id": p, "source": c.label})


func _collect_granted_spells() -> void:
	for m in _modifiers:
		if m.stat != &"spell":
			continue
		var spell_id := m.text("value")
		if spell_id == "":
			continue
		var uses := m.data.get("uses", {}) as Dictionary
		granted_spells.append({"id": spell_id, "ability": m.text("ability"), "uses": int(uses.get("count", 0)),
			"recharge": str(uses.get("recharge", "")), "always_prepared": bool(m.data.get("always_prepared", true)),
			"at_level": m.at_level(), "source": m.source_name})


func spellcasting_entry(class_id: String) -> Dictionary:
	for e in spellcasting:
		if str(e["class_id"]) == class_id:
			return e
	return {}


func spell_slots() -> Array[int]:
	var casters: Array[Dictionary] = []
	for e in spellcasting:
		casters.append({"progression": str(e["progression"]), "level": class_level_of(str(e["class_id"]))})
	return Spellcasting.slots_for(casters)


func slots_left(level: int) -> int:
	return spell_slots()[level - 1] - slots_used[level - 1]


func expend_slot(level: int) -> bool:
	if slots_left(level) <= 0:
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
			out.append({"id": str(g["id"]), "class_id": "", "ability": str(g["ability"]), "kind": "granted",
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
		var situation := {"spell": true, "school": str(s.get("school", ""))}
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
	for inc in _increases:
		if str(inc["ability"]) != str(ab):
			continue
		var gain := mini(int(inc["amount"]), maxi(0, int(inc["max"]) - running))
		running += gain
		var label := str(inc["label"])
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
		var die := str(compendium.class_data(str((lv as Dictionary)["class"])).get("hit_die", 8))
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
	var healed := maxi(1, roll + ability_mod(&"con"))
	return heal(healed, "Hit Point Die")


func finish_long_rest() -> void:
	super.finish_long_rest()
	if dead:
		return
	hit_dice_spent.clear()
	slots_used = [0, 0, 0, 0, 0, 0, 0, 0, 0]
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


func add_item(item_id: String, qty: int = 1) -> void:
	var data := compendium.item_data(item_id)
	if bool(data.get("stackable", false)):
		for entry in inventory:
			if str(entry["id"]) == item_id:
				entry["qty"] = int(entry["qty"]) + qty
				return
		inventory.append({"id": item_id, "qty": qty, "slot": ""})
	else:
		for i in qty:
			inventory.append({"id": item_id, "qty": 1, "slot": ""})


func equipped(slot: String) -> Dictionary:
	for entry in inventory:
		if str(entry["slot"]) == slot:
			return compendium.item_data(str(entry["id"]))
	return {}


func equip(item_id: String, slot: String) -> bool:
	for entry in inventory:
		if str(entry["slot"]) == slot:
			entry["slot"] = ""
	for entry in inventory:
		if str(entry["id"]) == item_id and str(entry["slot"]) == "":
			entry["slot"] = slot
			return true
	return false


func unequip(slot: String) -> void:
	for entry in inventory:
		if str(entry["slot"]) == slot:
			entry["slot"] = ""


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
			if not has_armor_training(str(a["kind"])):
				continue
			var cap: Variant = a.get("dex_cap", null)
			var ac := int(a["base_ac"]) + (dex if cap == null else mini(dex, int(cap)))
			if ac > best_ac:
				best_ac = ac
				best_armor = str(item["id"])
		elif Gear.is_shield(item) and has_armor_training("shield"):
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
		if has_armor_training("shield"):
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
		if not has_armor_training(str(a["kind"])):
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
	if need > 0 and ability_score(&"str") < need:
		b.add("%s (needs Strength %d)" % [armor["name"], need], -10)


func carried_weight() -> float:
	var total := 0.0
	for entry in inventory:
		total += float(compendium.item_data(str(entry["id"])).get("weight_lb", 0.0)) * int(entry["qty"])
	return total


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
		if "thrown" in Gear.weapon_props(item) and not Gear.is_ranged_weapon(item):
			out.append(WeaponProfile.build(self, item, true, false))
	out.append(WeaponProfile.unarmed(self))
	return out


# --- Saving and loading --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"build": build.duplicate(true), "state": state_to_dict(), "inventory": inventory.duplicate(true),
		"currency": currency.duplicate(), "hit_dice_spent": hit_dice_spent.duplicate(),
		"slots_used": slots_used.duplicate(), "heroic_inspiration": heroic_inspiration, "id": id}


static func from_dict(d: Dictionary, compendium_: Compendium = null) -> Character:
	var c := Character.from_build(d.get("build", {}) as Dictionary, compendium_)
	c.id = str(d.get("id", c.id))
	c.state_from_dict(d.get("state", {}) as Dictionary)
	c.inventory.clear()
	for e: Variant in d.get("inventory", []):
		c.inventory.append((e as Dictionary).duplicate())
	c.currency = (d.get("currency", c.currency) as Dictionary).duplicate()
	c.hit_dice_spent = (d.get("hit_dice_spent", {}) as Dictionary).duplicate()
	var used := d.get("slots_used", []) as Array
	for i in mini(9, used.size()):
		c.slots_used[i] = int(used[i])
	c.heroic_inspiration = bool(d.get("heroic_inspiration", false))
	return c
