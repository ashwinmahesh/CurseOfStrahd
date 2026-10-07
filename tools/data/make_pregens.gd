extends SceneTree
## Writes data/pregens/<id>.json for the pregens in tools/data/pregen_specs.json: a level 1 build and a level plan to
## the campaign's cap (11, ADR 0011), built through CharacterBuilder and LevelUpController so every pick is legal.
## A spec names its preferred picks by choice key (the longest key that ends the choice's key wins: "prepared" covers
## "cleric.prepared", "4.ability_score_improvement" covers "paladin.4.ability_score_improvement"), with per-level
## overrides under "levels"; anything left open is filled with the first legal options, the way TestChars.auto_pick
## does. The spec also sets `roster`, the look (`appearance`, e.g. a borrowed `art` id) and an `art_todo` note.
##
##   make pregens [ONLY="id …"] [VERBOSE=1]

const SPECS := "res://tools/data/pregen_specs.json"
const OUT := "res://data/pregens/%s.json"
const CAP := 11

var verbose := false


func _init() -> void:
	var only: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			for id in a.trim_prefix("--only=").split(" ", false):
				only.append(id)
		elif a == "--verbose":
			verbose = true
	var specs := JSON.parse_string(FileAccess.get_file_as_string(SPECS)) as Dictionary
	var failed := false
	for id: String in specs:
		if not only.is_empty() and not id in only:
			continue
		if not _write(id, specs[id] as Dictionary):
			failed = true
	quit(1 if failed else 0)


func _write(id: String, spec: Dictionary) -> bool:
	var b := CharacterBuilder.new()
	b.set_class(str(spec["class"]))
	b.set_background(str(spec["background"]))
	b.set_species(str(spec["species"]))
	b.set_name(str(spec["name"]))
	b.set_base_scores(spec["scores"] as Dictionary)
	var equipment := spec.get("equipment", {"class": "a", "background": "a"}) as Dictionary
	for source: String in equipment:
		b.set_equipment(source, str(equipment[source]))
	b.set_identity({"pronouns": str(spec["pronouns"]), "tags": spec.get("tags", [])})
	var prefs := _prefs(spec, 1)
	_fill(1, b.pending_choices, b.choose, prefs)
	var ch := b.build_character()
	if ch == null:
		printerr("%s doesn't build: %s" % [id, b.errors()])
		return false
	var build := b.build.duplicate(true)
	var plan: Array = []
	var class_id := str(spec["class"])
	for level in range(2, CAP + 1):
		var up := LevelUpController.new(ch)
		up.choose_class(class_id)
		up.take_fixed_hit_points()
		var picked := _fill(level, up.pending_choices, up.choose, _prefs(spec, level))
		if not up.confirm():
			printerr("%s level %d: %s" % [id, level, up.errors()])
			return false
		plan.append({"level": level, "class": class_id, "hp": 0, "choices": picked})
	var path := OUT % id
	var data := {}
	if FileAccess.file_exists(path):
		data = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	data["id"] = id
	data["name"] = str(spec["name"])
	data["pronouns"] = str(spec["pronouns"])
	data["summary"] = str(spec["summary"])
	data["hook"] = str(spec["hook"])
	data["roster"] = bool(spec.get("roster", data.get("roster", false)))
	if spec.has("art_todo"):
		data["art_todo"] = str(spec["art_todo"])
	else:
		data.erase("art_todo")
	build["appearance"] = (spec.get("appearance", {}) as Dictionary).duplicate()
	data["build"] = build
	data["level_plan"] = plan
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ", false) + "\n")
	f.close()
	var check: Array[String] = []
	var built := _rebuild(data, check)
	print("%s: level %d %s, AC %d, HP %d %s" % [id, built.character_level() if built else 0,
		ch.class_summary(), ch.armor_class().total(), ch.max_hp(), check])
	return check.is_empty()


## The spec's preferences with the overrides for `level` on top.
func _prefs(spec: Dictionary, level: int) -> Dictionary:
	var out := (spec.get("prefs", {}) as Dictionary).duplicate(true)
	var by_level := spec.get("levels", {}) as Dictionary
	if by_level.has(str(level)):
		out.merge(by_level[str(level)] as Dictionary, true)
	return out


## Fills every open choice (preferred picks first, then the first legal options without warnings), re-reading the
## choices after each pick. Returns the picks made, by key.
func _fill(level: int, get_pending: Callable, choose: Callable, prefs: Dictionary) -> Dictionary:
	var made := {}
	var tried := {}
	for guard in 200:
		var c: Choice = null
		for p in get_pending.call() as Array[Choice]:
			if not tried.has(p.key):
				c = p
				break
		if c == null:
			break
		tried[c.key] = true
		var picks: Array = c.picks.duplicate()
		var legal: Array[String] = []
		var good: Array[String] = []
		var weak: Array[String] = []
		for o in c.options:
			if o.legal:
				legal.append(o.id)
				if not o.id in picks:
					if o.warning == "":
						good.append(o.id)
					else:
						weak.append(o.id)
		var want := _pref_for(c.key, prefs)
		if c.kind == "ability_increase":
			for ab: String in want:
				if picks.size() < c.count and ab in legal and picks.count(ab) < c.per_ability:
					picks.append(ab)
		else:
			for p: String in want:
				if picks.size() < c.count and p in legal and not p in picks:
					picks.append(p)
		var pool: Array[String] = good + weak
		while picks.size() < c.count and not pool.is_empty():
			var next := pool.pop_front() as String
			if c.kind == "ability_increase":
				while picks.size() < c.count and picks.count(next) < c.per_ability:
					picks.append(next)
			elif not next in picks:
				picks.append(next)
		if verbose:
			print("  L%d %s [%d %s] %s%s" % [level, c.key, c.count, c.kind, picks,
				"" if want.size() > 0 or c.kind in ["spell", "cantrip", "spellbook"] else "  (auto; legal: %s)" % ", ".join(legal.slice(0, 16))])
		if picks.size() < c.count:
			printerr("  L%d %s: only %d of %d" % [level, c.key, picks.size(), c.count])
		var problems := choose.call(c.key, picks) as Array[String]
		if not problems.is_empty():
			printerr("  L%d %s %s: %s" % [level, c.key, picks, problems])
		made[c.key] = picks
	return made


func _pref_for(key: String, prefs: Dictionary) -> Array:
	if prefs.has(key):
		return prefs[key] as Array
	var best := ""
	for k: String in prefs:
		if (key.ends_with("." + k) or key.ends_with("/" + k)) and k.length() > best.length():
			best = k
	return prefs[best] as Array if best != "" else []


func _rebuild(data: Dictionary, errors: Array[String]) -> Character:
	# Pregens.build reads the compendium, which loaded before this file was written; rebuild from the dict instead.
	var builder := CharacterBuilder.new(null, data["build"] as Dictionary)
	var ch := builder.build_character()
	if ch == null:
		errors.append("doesn't rebuild: %s" % [builder.errors()])
		return null
	for step: Variant in data["level_plan"]:
		var plan := step as Dictionary
		var up := LevelUpController.new(ch)
		up.choose_class(str(plan["class"]))
		var choices := plan["choices"] as Dictionary
		for key: String in choices:
			up.choose(key, choices[key] as Array)
		if not up.confirm():
			errors.append("level %d doesn't replay: %s" % [plan["level"], up.errors()])
			return null
	return ch
