class_name ChoiceOptions
extends RefCounted
## Fills a Choice with every option of its kind and explains the ones that can't be picked (plan §5.6:
## unavailable options stay visible with the reason; legal but weak ones get a soft warning). Also checks a
## Choice's picks. Works from the character as it currently stands, so prerequisites see earlier picks.

const LANGUAGE_NAMES := {"common": "Common", "common_sign_language": "Common Sign Language", "draconic": "Draconic",
	"dwarvish": "Dwarvish", "elvish": "Elvish", "giant": "Giant", "gnomish": "Gnomish", "goblin": "Goblin",
	"halfling": "Halfling", "orc": "Orc", "abyssal": "Abyssal", "celestial": "Celestial", "deep_speech": "Deep Speech",
	"druidic": "Druidic", "infernal": "Infernal", "primordial": "Primordial", "sylvan": "Sylvan",
	"thieves_cant": "Thieves' Cant", "undercommon": "Undercommon"}


static func populate(c: Choice, ch: Character) -> void:
	c.options.clear()
	var comp := ch.compendium
	match c.kind:
		"skill":
			_skills(c, ch, comp)
		"expertise":
			_expertise(c, ch)
		"tool":
			_tools(c, ch, comp)
		"language":
			_languages(c, ch)
		"feat", "fighting_style":
			_feats(c, ch, comp)
			# Blessed Warrior / Druidic Warrior: options offered beside the Fighting Style feats.
			for o in c.inline_options:
				c.options.append(ChoiceOption.make(str(o.get("id", "")), str(o.get("name", "")), str(o.get("summary", ""))))
		"invocation":
			_invocations(c, ch)
		"beast_form":
			_beast_forms(c, ch)
		"weapon_mastery":
			_masteries(c, ch, comp)
		"cantrip", "spell", "spellbook":
			_spells(c, ch, comp)
		"subclass":
			for s in comp.subclasses_of(c.class_id):
				c.options.append(ChoiceOption.make(str(s["id"]), str(s["name"]), str(s.get("summary", ""))))
		"ability_increase":
			_abilities(c, ch)
		"option", "maneuver", "metamagic":
			for o in c.inline_options:
				c.options.append(ChoiceOption.make(str(o.get("id", "")), str(o.get("name", "")), str(o.get("summary", ""))))
		"lineage":
			var sp := comp.species_data(str(ch.build.get("species", "")))
			for l: Variant in sp.get("lineages", []):
				var ld := l as Dictionary
				c.options.append(ChoiceOption.make(str(ld["id"]), str(ld["name"]), str(ld.get("summary", ""))))
		"spellcasting_ability":
			for a in c.from:
				c.options.append(ChoiceOption.make(a, str(Creature.ABILITY_NAMES[StringName(a)])))
		_:
			for v in c.from:
				c.options.append(ChoiceOption.make(v, v.replace("_", " ").capitalize()))
	_swap_limits(c)


## Problems with a choice's picks, as sentences the player can act on. Incomplete choices are reported too.
static func errors(c: Choice, ch: Character) -> Array[String]:
	var out: Array[String] = []
	if c.options.is_empty():
		populate(c, ch)
	var counts := {}
	for p in c.picks:
		counts[p] = int(counts.get(p, 0)) + 1
		var o := c.option(p)
		if o == null:
			out.append("%s: '%s' isn't an option (%s)." % [c.label, p, c.source])
		elif not o.legal:
			out.append("%s: %s can't be chosen: %s (%s)." % [c.label, o.label, o.reason, c.source])
	for p: String in counts:
		var limit := c.per_ability if c.kind == "ability_increase" else 1
		if int(counts[p]) > limit:
			out.append("%s: %s picked %d times (limit %d) (%s)." % [c.label, _label(c, p), counts[p], limit, c.source])
	if c.picks.size() < c.count:
		var missing := c.count - c.picks.size()
		out.append("%s: choose %d more (%s)." % [c.label, missing, c.source])
	elif c.picks.size() > c.count:
		out.append("%s: %d chosen but only %d allowed (%s)." % [c.label, c.picks.size(), c.count, c.source])
	if swap_open(c) and swapped_out(c).size() > c.swap_max:
		out.append("%s: %s (%d changed) (%s)." % [c.label, _swap_rule(c), swapped_out(c).size(), c.source])
	return out


# --- Swap chances (2024: changing prepared spells after a Long Rest, a spell and a cantrip at a level up) ---------

## Opens a chance to swap earlier picks: `earlier` is the list it starts from, `occasion` "long_rest" or "level_up".
## On the choice's own occasion up to `replace_max` earlier picks may go (any when -1); on any other occasion they all
## stay and only new picks can be added (a Cleric's list grows at a level up but changes after a Long Rest). What a
## Short Rest lets you change, a Long Rest does too.
static func open_swap(c: Choice, earlier: Array[String], occasion: String) -> void:
	c.swap_from = earlier.duplicate()
	var fits := occasion != "" and (c.replaceable == occasion or (c.replaceable == "short_rest" and occasion == "long_rest"))
	c.swap_max = c.replace_max if fits else 0


## Ends a swap chance: the picks are free again.
static func close_swap(c: Choice) -> void:
	c.swap_from.clear()
	c.swap_max = -1


## True while a swap chance limits the choice (open_swap with a limit).
static func swap_open(c: Choice) -> bool:
	return not c.swap_from.is_empty() and c.swap_max >= 0


## Earlier picks the open chance has let go so far.
static func swapped_out(c: Choice) -> Array[String]:
	var out: Array[String] = []
	for p in c.swap_from:
		if not p in c.picks:
			out.append(p)
	return out


## The picks after the player toggles `id`. Picking past the count drops the oldest pick; inside a limited swap chance it
## drops only a pick made during the chance, so an earlier pick leaves only when the player unpicks it, and a locked pick
## never does.
static func toggled(c: Choice, id: String, on: bool) -> Array:
	var picks: Array = c.picks.duplicate()
	if on and not id in picks:
		picks.append(id)
		while picks.size() > c.count:
			var drop := 0
			if swap_open(c):
				drop = -1
				for i in picks.size():
					if not str(picks[i]) in c.swap_from and str(picks[i]) != id:
						drop = i
						break
			if drop < 0:
				return c.picks.duplicate()
			picks.remove_at(drop)
	elif not on:
		var o := c.option(id)
		if o != null and o.locked:
			return picks
		picks.erase(id)
	return picks


## What the open chance allows, for the line under the choice's title; "" when nothing limits it.
static func swap_note(c: Choice) -> String:
	if not swap_open(c):
		return ""
	var noun := _swap_noun(c)
	if c.swap_max == 0:
		return "Pick the new %ss; the others %s." % [noun, _swap_when(c)]
	return "Replace up to %d %s%s: unpick it, then pick the new one (%d of %d replaced)." % [c.swap_max, noun,
		"" if c.swap_max == 1 else "s", mini(swapped_out(c).size(), c.swap_max), c.swap_max]


## Once the chance's earlier picks are used up the rest stay locked; while the list is full of earlier picks only, new
## options wait until the player unpicks the one they're replacing.
static func _swap_limits(c: Choice) -> void:
	if not swap_open(c):
		return
	var out := swapped_out(c).size()
	var only_earlier := true
	for p in c.picks:
		if not p in c.swap_from:
			only_earlier = false
	var noun := _swap_noun(c)
	for o in c.options:
		var picked := o.id in c.picks
		if picked and o.id in c.swap_from and out >= c.swap_max:
			o.lock(_swap_rule(c))
		elif not picked and o.legal and c.picks.size() >= c.count and only_earlier:
			o.block("Unpick the %s you're replacing first" % noun if out < c.swap_max else _swap_rule(c))


static func _swap_rule(c: Choice) -> String:
	var noun := _swap_noun(c)
	if c.swap_max == 0:
		return "Your earlier %ss %s" % [noun, _swap_when(c)]
	return "Only %d %s%s can change %s" % [c.swap_max, noun, "" if c.swap_max == 1 else "s",
		"after a Long Rest" if c.replaceable == "long_rest" else "at a level up"]


static func _swap_noun(c: Choice) -> String:
	match c.kind:
		"cantrip":
			return "cantrip"
		"spell", "spellbook":
			return "spell"
		"weapon_mastery":
			return "weapon choice"
	return "choice"


static func _swap_when(c: Choice) -> String:
	match c.replaceable:
		"long_rest":
			return "change after a Long Rest"
		"level_up":
			return "change when this class gains a level"
	return "can't change"


static func warnings(c: Choice) -> Array[String]:
	var out: Array[String] = []
	for p in c.picks:
		var o := c.option(p)
		if o != null and o.legal and o.warning != "":
			out.append("%s: %s" % [o.label, o.warning])
	return out


static func _label(c: Choice, id: String) -> String:
	var o := c.option(id)
	return o.label if o != null else id


static func _skills(c: Choice, ch: Character, comp: Compendium) -> void:
	var pool: Array[String] = c.from.duplicate()
	var include := c.filter.get("include", ["skill"]) as Array
	if pool.is_empty():
		for s: StringName in Abilities.SKILLS:
			pool.append(str(s))
		if "tool" in include:
			for t in comp.items_where("tool"):
				pool.append(str(t["id"]))
	var skills := ch.proficiencies["skills"] as Dictionary
	var tools := ch.proficiencies["tools"] as Dictionary
	for id in pool:
		var is_skill := Abilities.SKILLS.has(StringName(id))
		var label := id.replace("_", " ").capitalize() if is_skill else comp.display_name("items", id)
		var o := ChoiceOption.make(id, label)
		if is_skill:
			o.summary = "%s skill" % Creature.ABILITY_NAMES[Abilities.SKILLS[StringName(id)]]
			o.tags.append("skill")
		else:
			o.tags.append("tool")
		var table := skills if is_skill else tools
		if table.has(id) and str(table[id]) != c.source:
			o.warn("Already proficient (%s); picking it again gives nothing extra." % table[id])
		c.options.append(o)


static func _expertise(c: Choice, ch: Character) -> void:
	var pool: Array[String] = c.from.duplicate()
	if pool.is_empty():
		for s: StringName in Abilities.SKILLS:
			pool.append(str(s))
	for id in pool:
		var o := ChoiceOption.make(id, id.replace("_", " ").capitalize())
		if ch.skill_rank(StringName(id)) < 1:
			o.block("Requires proficiency in %s" % o.label)
		elif ch.expertise.has(id) and str(ch.expertise[id]) != c.source:
			o.block("Already have Expertise (%s)" % ch.expertise[id])
		c.options.append(o)


static func _tools(c: Choice, ch: Character, comp: Compendium) -> void:
	var kinds: Array = []
	var raw: Variant = c.filter.get("tool_kind", "")
	if raw is Array:
		kinds = raw as Array
	elif str(raw) != "":
		kinds = [str(raw)]
	var tools := ch.proficiencies["tools"] as Dictionary
	for t in comp.items_where("tool"):
		var tool := t.get("tool", {}) as Dictionary
		if not kinds.is_empty() and not str(tool.get("kind", "")) in kinds:
			continue
		if not c.from.is_empty() and not str(t["id"]) in c.from:
			continue
		var o := ChoiceOption.make(str(t["id"]), str(t["name"]), str(t.get("summary", "")))
		if tools.has(str(t["id"])) and str(tools[str(t["id"])]) != c.source:
			o.warn("Already proficient (%s)." % tools[str(t["id"])])
		c.options.append(o)


static func _languages(c: Choice, ch: Character) -> void:
	var pool: Array[String] = c.from.duplicate()
	if pool.is_empty():
		pool.assign(Character.STANDARD_LANGUAGES + Character.RARE_LANGUAGES)
	var known := ch.proficiencies["languages"] as Dictionary
	for id in pool:
		var o := ChoiceOption.make(id, str(LANGUAGE_NAMES.get(id, id.capitalize())))
		if id in Character.RARE_LANGUAGES:
			o.tags.append("rare")
		if known.has(id) and str(known[id]) != c.source:
			o.block("You already know %s (%s)" % [o.label, known[id]])
		c.options.append(o)


static func _feats(c: Choice, ch: Character, comp: Compendium) -> void:
	var categories: Array = []
	var cat: Variant = c.filter.get("category", "fighting_style" if c.kind == "fighting_style" else "")
	if cat is Array:
		categories = (cat as Array).duplicate()
	elif str(cat) != "":
		categories = [str(cat)]
	# Ravenloft: The Horrors Within: a Dark Gift can be taken whenever an origin feat could be.
	if "origin" in categories and not "dark_gift" in categories:
		categories.append("dark_gift")
	var level := c.level if c.level > 0 else ch.character_level()
	var taken := {}
	for f in ch.feats_taken:
		if not str(f["key"]).begins_with(c.key + "/") and not (c.key == "background.feat_choice" and str(f["key"]) == "background.feat"):
			taken[str(f["id"])] = str(f["source"])
	var gifts: Array[ChoiceOption] = []
	for f in comp.all("feats"):
		# `from` lists feats offered whatever their category (a background's own origin feat beside the Dark Gifts).
		if not categories.is_empty() and not str(f.get("category", "")) in categories and not str(f["id"]) in c.from:
			continue
		var o := ChoiceOption.make(str(f["id"]), str(f["name"]), str(f.get("summary", "")))
		o.tags.append(str(f.get("category", "")))
		var why := prerequisite_problem(f, ch, level)
		if why != "":
			o.block(why)
		elif taken.has(str(f["id"])) and not bool(f.get("repeatable", false)):
			o.block("You already have this feat (%s)" % taken[str(f["id"])])
		if str(f.get("category", "")) == "dark_gift":
			o.warning = "A Ravenloft Dark Gift: its power comes with a drawback."
			gifts.append(o)
		else:
			c.options.append(o)
	# Dark Gifts follow the ordinary feats, so the usual picks (and recommendations) come first.
	c.options.append_array(gifts)


## "" if the character meets the feat's prerequisites at `level`, otherwise the reason.
static func prerequisite_problem(f: Dictionary, ch: Character, level: int) -> String:
	var pre := f.get("prerequisites", {}) as Dictionary
	if pre.is_empty():
		return ""
	if int(pre.get("level", 0)) > level:
		return "Requires level %d" % int(pre["level"])
	var all_of := pre.get("abilities", {}) as Dictionary
	for ab: String in all_of:
		if ch.ability_score(StringName(ab)) < int(all_of[ab]):
			return "Requires %s %d (you have %d)" % [Creature.ABILITY_NAMES[StringName(ab)], int(all_of[ab]), ch.ability_score(StringName(ab))]
	var any_of := pre.get("any_ability", {}) as Dictionary
	if not any_of.is_empty():
		var ok := false
		var names: Array[String] = []
		for ab: String in any_of:
			names.append("%s %d" % [Creature.ABILITY_NAMES[StringName(ab)], int(any_of[ab])])
			if ch.ability_score(StringName(ab)) >= int(any_of[ab]):
				ok = true
		if not ok:
			return "Requires %s" % " or ".join(names)
	if pre.has("feature"):
		var need := str(pre["feature"])
		var found := false
		for feat in ch.features:
			if str(feat["id"]) == need:
				found = true
		if need == "spellcasting" and not ch.spellcasting.is_empty():
			found = true
		if not found:
			return "Requires the %s feature" % need.replace("_", " ").capitalize()
	if bool(pre.get("spellcasting", false)) and ch.spellcasting.is_empty():
		return "Requires the Spellcasting feature"
	if pre.has("proficiency"):
		var p := pre["proficiency"] as Dictionary
		var kind := str(p.get("kind", ""))
		var table := {"armor": "armor", "weapon": "weapons", "tool": "tools", "skill": "skills"}
		if not ch.has_proficiency(str(table.get(kind, kind)), str(p.get("value", ""))):
			return "Requires %s" % str(pre.get("text", "%s training" % str(p.get("value", "")).capitalize()))
	return ""


static func _masteries(c: Choice, ch: Character, comp: Compendium) -> void:
	var kinds := c.filter.get("weapon_kinds", []) as Array
	var need_prof := bool(c.filter.get("proficient", false))
	var melee_only := bool(c.filter.get("melee", false))
	for w in comp.items_where("weapon"):
		var wd := w.get("weapon", {}) as Dictionary
		var kind := str(wd.get("kind", ""))
		if not kinds.is_empty() and not kind.split("_")[0] in kinds:
			continue
		if melee_only and not kind.ends_with("melee"):
			continue
		var o := ChoiceOption.make(str(w["id"]), "%s (%s)" % [w["name"], str(wd.get("mastery", "")).capitalize()],
			"%s %s, %s" % [wd.get("damage", ""), str(wd.get("damage_type", "")).capitalize(), kind.replace("_", " ")])
		if need_prof and not ch.weapon_proficient(w):
			o.block("Not proficient with %s" % w["name"])
		c.options.append(o)


static func _spells(c: Choice, ch: Character, comp: Compendium) -> void:
	var list := str(c.filter.get("list", ""))
	# Several lists at once (Magical Discoveries: Cleric, Druid or Wizard).
	var lists: Array = c.filter.get("lists", []) as Array
	# Pointing at a spell already known (Agonizing Blast) rather than learning one; optionally only damaging ones.
	var known_only := bool(c.filter.get("known_only", false))
	var damaging := bool(c.filter.get("damaging", false))
	var ritual_only := bool(c.filter.get("ritual", false))
	var exact: Variant = c.filter.get("level", null)
	var min_level := int(c.filter.get("min_level", 0 if c.kind == "cantrip" else 1))
	var max_level := 9
	var max_raw: Variant = c.filter.get("max_level", null)
	if c.kind == "cantrip":
		exact = 0
	if max_raw != null:
		if str(max_raw) == "slots":
			max_level = _castable_level(c, ch)
		else:
			max_level = int(max_raw)
	var school: Variant = c.filter.get("school", "")
	var from_choice := str(c.filter.get("from_choice", ""))
	var allowed_ids := {}
	if from_choice != "":
		for p in ch.picks_for(from_choice):
			allowed_ids[p] = true
		var e := ch.spellcasting_entry(c.class_id)
		for s: Variant in e.get("spellbook", []):
			allowed_ids[str(s)] = true
	var known := {}
	var mine := {}
	for s in ch.known_spells():
		known[str(s["id"])] = str(s["source"])
		if str(s.get("class_id", "")) == c.class_id:
			mine[str(s["id"])] = true
	var in_book := {}
	if c.kind == "spellbook":
		var e2 := ch.spellcasting_entry(c.class_id)
		for s: Variant in e2.get("spellbook", []):
			in_book[str(s)] = true
	for s in comp.spells_for("" if not lists.is_empty() else list, -1):
		if not lists.is_empty():
			var on_list := false
			for l: Variant in lists:
				if str(l) in (s.get("classes", []) as Array):
					on_list = true
			if not on_list:
				continue
		if known_only and not mine.has(str(s["id"])):
			continue
		if damaging and (s.get("damage", []) as Array).is_empty():
			continue
		if ritual_only and not bool(s.get("ritual", false)):
			continue
		var level := int(s.get("level", 0))
		if exact != null and level != int(exact):
			continue
		if exact == null and (level < min_level or level > 9):
			continue
		if school is Array and not str(s.get("school", "")) in (school as Array):
			continue
		if school is String and str(school) != "" and str(s.get("school", "")) != str(school):
			continue
		if from_choice != "" and not allowed_ids.has(str(s["id"])):
			continue
		var o := ChoiceOption.make(str(s["id"]), str(s["name"]), str(s.get("summary", "")))
		o.data = {"level": level, "school": str(s.get("school", "")), "ritual": bool(s.get("ritual", false)),
			"concentration": bool((s.get("duration", {}) as Dictionary).get("concentration", false))}
		o.tags.append("level %d" % level)
		if level > max_level:
			o.block("Needs level %d spell slots" % level)
		elif c.kind == "spellbook" and in_book.has(str(s["id"])) and not str(s["id"]) in c.picks:
			o.block("Already in your spellbook")
		elif c.kind != "spellbook" and not known_only and known.has(str(s["id"])) and not str(s["id"]) in c.picks:
			o.warn("You already have this spell from %s; picking it here adds nothing new." % known[str(s["id"])])
		c.options.append(o)


## Highest spell level the choice's class could cast if it were the character's only class (2024 multiclass
## rule: prepare spells for each class as if single-classed).
static func _castable_level(c: Choice, ch: Character) -> int:
	var e := ch.spellcasting_entry(c.class_id)
	if e.is_empty():
		return 1
	if str(e["progression"]) == "pact":
		return maxi(1, int(e.get("pact_level", 1)))
	var slots := Spellcasting.slots_for([{"progression": str(e["progression"]), "level": ch.class_level_of(c.class_id)}])
	return maxi(1, Spellcasting.highest_slot_level(slots))


static func _abilities(c: Choice, ch: Character) -> void:
	var pool: Array[String] = c.from.duplicate()
	if pool.is_empty():
		for a: StringName in Abilities.ALL:
			pool.append(str(a))
	for a in pool:
		var o := ChoiceOption.make(a, str(Creature.ABILITY_NAMES[StringName(a)]))
		var score := ch.ability_score(StringName(a))
		o.summary = "Currently %d" % score
		if score >= c.max_score and not a in c.picks:
			o.block("Already %d, the maximum" % c.max_score)
		c.options.append(o)


## Eldritch Invocations: each option may list prerequisites {level, invocation, cantrip: "damage"|"attack"}; the
## level is the invoking class's level, an invocation counts if picked here or elsewhere.
static func _invocations(c: Choice, ch: Character) -> void:
	for o in c.inline_options:
		var opt := ChoiceOption.make(str(o.get("id", "")), str(o.get("name", "")), str(o.get("summary", "")))
		var why := invocation_problem(o, c, ch)
		if why != "":
			opt.block(why)
		c.options.append(opt)


static func invocation_problem(o: Dictionary, c: Choice, ch: Character) -> String:
	var pre := o.get("prerequisites", {}) as Dictionary
	if pre.is_empty():
		return ""
	var cls_name := ch.compendium.display_name("classes", c.class_id)
	if ch.class_level_of(c.class_id) < int(pre.get("level", 0)):
		return "Requires %s level %d" % [cls_name, int(pre["level"])]
	if pre.has("invocation"):
		var need := str(pre["invocation"])
		if not need in c.picks and not need in ch.invocations:
			var label := need.replace("_", " ").capitalize()
			for other in c.inline_options:
				if str(other.get("id", "")) == need:
					label = str(other.get("name", label))
			return "Requires %s" % label
	if pre.has("cantrip"):
		var want := str(pre["cantrip"])
		var ok := false
		for k in ch.known_spells():
			if str(k.get("class_id", "")) != c.class_id:
				continue
			var s := ch.compendium.spell_data(str(k["id"]))
			if int(s.get("level", -1)) != 0 or (s.get("damage", []) as Array).is_empty():
				continue
			if want == "attack" and not s.has("attack"):
				continue
			ok = true
		if not ok:
			return "Requires a %s cantrip that deals damage%s" % [cls_name, " with an attack roll" if want == "attack" else ""]
	return ""


## Wild Shape forms: Beast stat blocks up to the table's CR; the rest stay visible with the reason.
static func _beast_forms(c: Choice, ch: Character) -> void:
	var ok := {}
	for m in ch.beast_forms_for(c):
		ok[str(m["id"])] = true
	for m in ch.compendium.all("monsters"):
		if str(m.get("type", "")) != "beast":
			continue
		var cr := float(m.get("cr", 0))
		var cr_text := "1/8" if is_equal_approx(cr, 0.125) else ("1/4" if is_equal_approx(cr, 0.25) else ("1/2" if is_equal_approx(cr, 0.5) else str(int(cr))))
		var o := ChoiceOption.make(str(m["id"]), str(m["name"]), "Beast, CR %s" % cr_text)
		if not ok.has(str(m["id"])):
			if int((m.get("speed", {}) as Dictionary).get("fly", 0)) > 0:
				o.block("No forms with a Fly Speed yet")
			else:
				o.block("Challenge Rating %s is too high for now" % cr_text)
		c.options.append(o)
