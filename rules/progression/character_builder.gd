class_name CharacterBuilder
extends RefCounted
## 2024 character creation, step by step (plan §5.1 and §5.6): Class, Origin (background, species,
## languages), Ability Scores, Class Choices, Equipment, Appearance, Identity, Review. The UI asks what is
## available (every option says why it can't be picked), sends picks back and shows preview(); nothing is
## committed until build_character(). Any finished step can be revisited: changing an earlier pick prunes the
## choices that no longer apply and re-checks the rest.

enum Step { CLASS, ORIGIN, ABILITIES, CHOICES, EQUIPMENT, APPEARANCE, IDENTITY, REVIEW }
const STEP_NAMES: Array[String] = ["Class", "Origin", "Ability Scores", "Class Choices", "Equipment",
	"Appearance", "Identity", "Review"]

var compendium: Compendium
var build: Dictionary
## Names the company already has: a character made mid-game can't take one (name_problems).
var taken_names: Array[String] = []
var _preview: Character = null


func _init(compendium_: Compendium = null, existing: Dictionary = {}) -> void:
	compendium = compendium_ if compendium_ != null else Compendium.shared()
	build = existing.duplicate(true) if not existing.is_empty() else Character.empty_build()
	_changed()


# --- Class ---------------------------------------------------------------------------------------

func available_classes() -> Array[ChoiceOption]:
	var out: Array[ChoiceOption] = []
	for c in compendium.all("classes"):
		var o := ChoiceOption.make(str(c["id"]), str(c["name"]), str(c.get("summary", "")))
		o.tags.assign((c.get("role_tags", []) as Array).map(func(t: Variant) -> String: return str(t)))
		o.data = {"complexity": str(c.get("complexity", "")), "hit_die": int(c.get("hit_die", 8))}
		out.append(o)
	return out


func class_id() -> String:
	var levels := build.get("levels", []) as Array
	return str((levels[0] as Dictionary)["class"]) if not levels.is_empty() else ""


func set_class(id: String) -> void:
	if not compendium.has("classes", id) or id == class_id():
		return
	build["levels"] = [{"class": id, "hp": 0}]
	# Untouched scores start at the class's recommended Standard Array, so the live sheet is meaningful.
	var scores := build.get("base_scores", {}) as Dictionary
	var untouched := true
	for ab: StringName in Abilities.ALL:
		if int(scores.get(str(ab), 10)) != 10:
			untouched = false
	if untouched and str(build.get("ability_method", "standard_array")) == "standard_array":
		build["base_scores"] = AbilityScores.recommended(compendium.class_data(id))
	_changed()


## What the Class step shows: core traits, levels 1-5 features and every subclass with its summary.
func class_preview(id: String) -> Dictionary:
	var c := compendium.class_data(id)
	if c.is_empty():
		return {}
	var feats: Array[Dictionary] = []
	for i in 5:
		for f: Variant in ((c["levels"] as Array)[i] as Dictionary).get("features", []):
			var fd := f as Dictionary
			feats.append({"level": i + 1, "name": str(fd["name"]), "summary": str(fd.get("summary", ""))})
	var subs: Array[Dictionary] = []
	for s in compendium.subclasses_of(id):
		subs.append({"id": str(s["id"]), "name": str(s["name"]), "summary": str(s.get("summary", ""))})
	return {"name": c["name"], "summary": c.get("summary", ""), "hit_die": c["hit_die"],
		"primary": c["primary_abilities"], "saves": c["saving_throws"], "proficiencies": c["proficiencies"],
		"complexity": c.get("complexity", ""), "role_tags": c.get("role_tags", []), "features_1_to_5": feats,
		"subclasses": subs, "subclass_level": c.get("subclass_level", 3)}


# --- Origin --------------------------------------------------------------------------------------

func available_backgrounds() -> Array[ChoiceOption]:
	var out: Array[ChoiceOption] = []
	for b in compendium.all_playable("backgrounds"):
		var o := ChoiceOption.make(str(b["id"]), str(b["name"]), str(b.get("summary", "")))
		o.data = {"abilities": b["ability_scores"], "feat": compendium.display_name("feats", str(b["feat"])),
			"skills": b["skills"], "tool": (b.get("tool", {}) as Dictionary).get("id", "")}
		out.append(o)
	return out


func set_background(id: String) -> void:
	if compendium.has("backgrounds", id) and id != str(build.get("background", "")):
		build["background"] = id
		_changed()


func available_species() -> Array[ChoiceOption]:
	var out: Array[ChoiceOption] = []
	for s in compendium.all_playable("species"):
		var o := ChoiceOption.make(str(s["id"]), str(s["name"]), str(s.get("summary", "")))
		o.data = {"speed": s.get("speed", 30), "sizes": s.get("sizes", []), "darkvision": s.get("darkvision", 0)}
		out.append(o)
	return out


func set_species(id: String) -> void:
	if compendium.has("species", id) and id != str(build.get("species", "")):
		build["species"] = id
		_changed()


# --- Ability scores ------------------------------------------------------------------------------

func set_ability_method(method: String) -> void:
	if not method in AbilityScores.METHODS:
		return
	build["ability_method"] = method
	match method:
		"standard_array":
			build["base_scores"] = AbilityScores.recommended(compendium.class_data(class_id()))
		"point_buy":
			build["base_scores"] = {"str": 8, "dex": 8, "con": 8, "int": 8, "wis": 8, "cha": 8}
	_changed()


func set_base_scores(scores: Dictionary) -> Array[String]:
	var clean := {}
	for ab: StringName in Abilities.ALL:
		clean[str(ab)] = int(scores.get(str(ab), 8))
	build["base_scores"] = clean
	_changed()
	return ability_problems()


func set_score(ab: StringName, value: int) -> Array[String]:
	var scores := (build.get("base_scores", {}) as Dictionary).duplicate()
	scores[str(ab)] = value
	return set_base_scores(scores)


## Rolls 4d6-drop-lowest six times with the seeded dice and keeps the results for assignment.
func roll_scores(dice: DiceRoller) -> Array[Dictionary]:
	var rolled := AbilityScores.roll_set(dice)
	var totals: Array = []
	for r in rolled:
		totals.append(int(r["total"]))
	build["ability_method"] = "roll"
	build["rolled"] = rolled
	build["rolled_scores"] = totals
	var values: Array[int] = []
	for t: Variant in totals:
		values.append(int(t))
	build["base_scores"] = AbilityScores.recommended(compendium.class_data(class_id()), values)
	_changed()
	return rolled


## The Recommended button: a sensible spread for the class from the current method's numbers.
func apply_recommended_scores() -> void:
	var values: Array[int] = AbilityScores.STANDARD_ARRAY.duplicate()
	if str(build.get("ability_method", "")) == "roll":
		values.clear()
		for t: Variant in build.get("rolled_scores", []):
			values.append(int(t))
	elif str(build.get("ability_method", "")) == "point_buy":
		build["ability_method"] = "standard_array"
	build["base_scores"] = AbilityScores.recommended(compendium.class_data(class_id()), values)
	_changed()


func point_buy_remaining() -> int:
	return AbilityScores.POINT_BUDGET - AbilityScores.point_cost(build.get("base_scores", {}) as Dictionary)


func ability_problems() -> Array[String]:
	return AbilityScores.problems(str(build.get("ability_method", "standard_array")),
		build.get("base_scores", {}) as Dictionary, build.get("rolled_scores", []) as Array)


# --- Choices -------------------------------------------------------------------------------------

## Every choice the build currently involves, with options and reasons filled in.
func all_choices() -> Array[Choice]:
	var ch := preview()
	for c in ch.choice_defs:
		ChoiceOptions.populate(c, ch)
	return ch.choice_defs


func pending_choices() -> Array[Choice]:
	var out: Array[Choice] = []
	for c in all_choices():
		if not c.is_complete():
			out.append(c)
	return out


## Choices that belong to a step: ORIGIN (background, species, languages), CHOICES (class and its feats).
func choices_for_step(step: Step) -> Array[Choice]:
	var out: Array[Choice] = []
	for c in all_choices():
		var origin := c.key.begins_with("background.") or c.key.begins_with("species.") or c.key.begins_with("origin.")
		if (step == Step.ORIGIN and origin) or (step == Step.CHOICES and not origin):
			out.append(c)
	return out


func get_choice(key: String) -> Choice:
	for c in all_choices():
		if c.key == key:
			return c
	return null


## Stores the picks (even imperfect ones, so the player can fix them later) and returns what's wrong.
func choose(key: String, picks: Array) -> Array[String]:
	var clean: Array = []
	for p: Variant in picks:
		clean.append(str(p))
	(build["choices"] as Dictionary)[key] = clean
	_changed()
	var c := get_choice(key)
	return ChoiceOptions.errors(c, preview()) if c != null else ["Unknown choice: %s" % key]


func clear_choice(key: String) -> void:
	(build["choices"] as Dictionary).erase(key)
	_changed()


# --- Equipment, appearance, identity -------------------------------------------------------------

func equipment_options() -> Dictionary:
	var cls := compendium.class_data(class_id())
	var bg := compendium.background_data(str(build.get("background", "")))
	return {"class": cls.get("starting_equipment", []), "background": bg.get("equipment", [])}


func set_equipment(source: String, option_id: String) -> void:
	(build["equipment"] as Dictionary)[source] = option_id
	_changed()


func set_name(character_name: String) -> void:
	build["name"] = character_name.strip_edges()
	_changed()


func set_identity(identity: Dictionary) -> void:
	build["identity"] = identity.duplicate(true)
	_changed()


func set_appearance(appearance: Dictionary) -> void:
	build["appearance"] = appearance.duplicate(true)
	_changed()


# --- Preview and review --------------------------------------------------------------------------

## The live sheet: a Character built from the current state (complete or not), with starting gear.
func preview() -> Character:
	if _preview == null:
		_preview = Character.from_build(build, compendium)
		_preview.apply_starting_equipment()
	return _preview


func _changed() -> void:
	if not build.has("choices"):
		build["choices"] = {}
	# Drop picks for choices that no longer exist (class or origin changed), until stable.
	for i in 4:
		_preview = Character.from_build(build, compendium)
		var keys := {}
		for c in _preview.choice_defs:
			keys[c.key] = true
		var stale: Array[String] = []
		for k: String in (build["choices"] as Dictionary):
			if not keys.has(k):
				stale.append(k)
		if stale.is_empty():
			break
		for k in stale:
			(build["choices"] as Dictionary).erase(k)
	_preview = null


## Blocking problems, each phrased so the player knows what to do. Review lists these apart from warnings.
func errors() -> Array[String]:
	var out: Array[String] = []
	if class_id() == "":
		out.append("Choose a class.")
	if str(build.get("background", "")) == "":
		out.append("Choose a background.")
	if str(build.get("species", "")) == "":
		out.append("Choose a species.")
	out.append_array(ability_problems())
	var ch := preview()
	for c in all_choices():
		out.append_array(ChoiceOptions.errors(c, ch))
	if str(build.get("name", "")) == "":
		out.append("Give your character a name.")
	out.append_array(name_problems())
	return out


## A custom hero (appearance.custom) can't share a pregenerated companion's name: the story speaks to companions by
## name (`name:` selectors), so a namesake would answer for them.
func name_problems() -> Array[String]:
	var out: Array[String] = []
	var app := build.get("appearance", {}) as Dictionary
	var key := str(build.get("name", "")).to_snake_case()
	if bool(app.get("custom", false)) and key != "" and not compendium.get_entry("pregens", key).is_empty():
		out.append("%s is one of your companions' names; choose another for your hero." % str(build["name"]))
	elif key != "":
		for t in taken_names:
			if t.to_snake_case() == key:
				out.append("Someone in your company is already called %s; choose another name." % t)
				break
	return out


## Soft warnings: legal but probably not what the player wants. Never blocking.
func warnings() -> Array[String]:
	var out: Array[String] = []
	var ch := preview()
	var cls := compendium.class_data(class_id())
	if not cls.is_empty():
		var best := 0
		var names: Array[String] = []
		for ab: Variant in cls.get("primary_abilities", []):
			best = maxi(best, ch.ability_score(StringName(str(ab))))
			names.append(str(Creature.ABILITY_NAMES[StringName(str(ab))]))
		if best < 13:
			out.append("%s relies on %s; yours is %d. It will work, but attacks, spells or saves will suffer." % [cls["name"], " or ".join(names), best])
	if ch.ability_score(&"con") < 10:
		out.append("Constitution below 10 lowers your Hit Points at every level.")
	for c in all_choices():
		out.append_array(ChoiceOptions.warnings(c))
	for entry in ch.inventory:
		var item := compendium.item_data(str(entry["id"]))
		if Gear.is_armor(item) and not ch.has_armor_training(str((item["armor"] as Dictionary)["kind"])):
			out.append("You carry %s but lack training with %s armor: wearing it gives Disadvantage on Strength and Dexterity rolls and stops spellcasting." % [item["name"], (item["armor"] as Dictionary)["kind"]])
		elif Gear.is_weapon(item) and not ch.weapon_proficient(item):
			out.append("You aren't proficient with your %s: no Proficiency Bonus on its attacks." % item["name"])
	return out


func step_status(step: Step) -> Dictionary:
	var errs: Array[String] = []
	match step:
		Step.CLASS:
			if class_id() == "":
				errs.append("Choose a class.")
		Step.ORIGIN:
			if str(build.get("background", "")) == "":
				errs.append("Choose a background.")
			if str(build.get("species", "")) == "":
				errs.append("Choose a species.")
			for c in choices_for_step(Step.ORIGIN):
				errs.append_array(ChoiceOptions.errors(c, preview()))
		Step.ABILITIES:
			errs = ability_problems()
		Step.CHOICES:
			for c in choices_for_step(Step.CHOICES):
				errs.append_array(ChoiceOptions.errors(c, preview()))
		Step.IDENTITY:
			if str(build.get("name", "")) == "":
				errs.append("Give your character a name.")
			errs.append_array(name_problems())
		Step.REVIEW:
			errs = errors()
	return {"step": STEP_NAMES[step], "complete": errs.is_empty(), "errors": errs}


## The finished character, or null while anything blocks. Starting equipment is applied and equipped.
func build_character() -> Character:
	if not errors().is_empty():
		return null
	var ch := Character.from_build(build, compendium)
	ch.apply_starting_equipment()
	ch.hp = ch.max_hp()
	return ch
