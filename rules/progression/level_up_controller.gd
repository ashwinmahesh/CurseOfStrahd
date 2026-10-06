class_name LevelUpController
extends RefCounted
## Gaining a level (plan §5.6 "Level up", 2024 PHB "Level Advancement" and "Multiclassing"): choose the
## class to advance (multiclass prerequisites checked and explained), take the fixed Hit Points or roll the
## die, read the new features, make every choice the level grants (subclass, feat, spells, Expertise ...),
## compare before and after, then confirm. The character doesn't change until confirm().

const MAX_LEVEL := 20

var character: Character
var compendium: Compendium
var build: Dictionary
var chosen_class: String = ""
var _after: Character = null


func _init(character_: Character) -> void:
	character = character_
	compendium = character_.compendium
	build = character_.build.duplicate(true)


func can_level_up() -> bool:
	return character.character_level() < MAX_LEVEL


## Every class, with the multiclass reason when it can't be taken.
func available_classes() -> Array[ChoiceOption]:
	var out: Array[ChoiceOption] = []
	for c in compendium.all("classes"):
		var cid := str(c["id"])
		var current := character.class_level_of(cid)
		var o := ChoiceOption.make(cid, str(c["name"]), "Level %d → %d" % [current, current + 1] if current > 0 else "New class (multiclass)")
		if not can_level_up():
			o.block("Already level %d" % MAX_LEVEL)
		elif current == 0:
			var why := multiclass_problem(cid)
			if why != "":
				o.block(why)
		elif current >= MAX_LEVEL:
			o.block("Already level %d in %s" % [MAX_LEVEL, c["name"]])
		out.append(o)
	return out


## 2024 rule: a new class needs 13 in its primary ability AND in the primary ability of every current class.
func multiclass_problem(new_class: String) -> String:
	var problems: Array[String] = []
	var check := [new_class]
	check.append_array(character.class_order)
	for cid: Variant in check:
		var why := _prerequisite(str(cid))
		if why != "":
			var cname := compendium.display_name("classes", str(cid))
			problems.append(("%s needs %s" % [cname, why]) if str(cid) == new_class else ("your %s levels need %s" % [cname, why]))
	if problems.is_empty():
		return ""
	var text := "; ".join(problems)
	return text.left(1).to_upper() + text.substr(1)


func _prerequisite(class_id: String) -> String:
	var mc := compendium.class_data(class_id).get("multiclass", {}) as Dictionary
	var all_of := mc.get("all_of", {}) as Dictionary
	for ab: String in all_of:
		var have := character.ability_score(StringName(ab))
		if have < int(all_of[ab]):
			return "%s %d (you have %d)" % [Creature.ABILITY_NAMES[StringName(ab)], int(all_of[ab]), have]
	var any_of := mc.get("any_of", {}) as Dictionary
	if not any_of.is_empty():
		var parts: Array[String] = []
		for ab: String in any_of:
			if character.ability_score(StringName(ab)) >= int(any_of[ab]):
				return ""
			parts.append("%s %d" % [Creature.ABILITY_NAMES[StringName(ab)], int(any_of[ab])])
		return " or ".join(parts)
	return ""


func choose_class(class_id: String) -> bool:
	var option: ChoiceOption = null
	for o in available_classes():
		if o.id == class_id:
			option = o
	if option == null or not option.legal:
		return false
	build = character.build.duplicate(true)
	(build["levels"] as Array).append({"class": class_id, "hp": 0})
	chosen_class = class_id
	_refresh()
	return true


## {die, fixed, con, rolled}: what the Hit Points step shows.
func hit_point_options() -> Dictionary:
	var die := int(compendium.class_data(chosen_class).get("hit_die", 8))
	var last := (build["levels"] as Array).back() as Dictionary
	return {"die": die, "fixed": die / 2 + 1, "con": character.ability_mod(&"con"), "rolled": int(last.get("hp", 0))}


## Rolls the Hit Point Die with the seeded dice (shown on screen); returns the roll.
func roll_hit_points(dice: DiceRoller) -> int:
	var die := int(hit_point_options()["die"])
	var roll := dice.roll_one(die, "Hit Points for %s level %d" % [compendium.display_name("classes", chosen_class), character.class_level_of(chosen_class) + 1])
	((build["levels"] as Array).back() as Dictionary)["hp"] = roll
	_refresh()
	return roll


func take_fixed_hit_points() -> void:
	((build["levels"] as Array).back() as Dictionary)["hp"] = 0
	_refresh()


func preview() -> Character:
	if _after == null:
		_refresh()
	return _after


func _refresh() -> void:
	for i in 4:
		_after = Character.from_build(build, compendium)
		var keys := {}
		for c in _after.choice_defs:
			keys[c.key] = true
		var stale: Array[String] = []
		for k: String in (build["choices"] as Dictionary):
			if not keys.has(k):
				stale.append(k)
		if stale.is_empty():
			break
		for k in stale:
			(build["choices"] as Dictionary).erase(k)
	_after.inventory = character.inventory.duplicate(true)
	_after.currency = character.currency.duplicate()


## Features gained at this level, with their full text.
func new_features() -> Array[Dictionary]:
	var before := {}
	for f in character.features:
		before[str(f["key"])] = true
	var out: Array[Dictionary] = []
	for f in preview().features:
		if not before.has(str(f["key"])):
			out.append(f)
	return out


## Every choice this level asks for: new ones, and ones whose count grew (more prepared spells, a new cantrip).
func pending_choices() -> Array[Choice]:
	var after := preview()
	var out: Array[Choice] = []
	for c in after.choice_defs:
		ChoiceOptions.populate(c, after)
		if not c.is_complete():
			out.append(c)
	return out


## All choices touched by this level (complete or not), for the level-up screen.
func level_choices() -> Array[Choice]:
	var before := {}
	for c in character.choice_defs:
		before[c.key] = c.count
	var after := preview()
	var out: Array[Choice] = []
	for c in after.choice_defs:
		if not before.has(c.key) or int(before[c.key]) != c.count or not c.is_complete():
			ChoiceOptions.populate(c, after)
			out.append(c)
	return out


func choose(key: String, picks: Array) -> Array[String]:
	var clean: Array = []
	for p: Variant in picks:
		clean.append(str(p))
	(build["choices"] as Dictionary)[key] = clean
	_refresh()
	for c in preview().choice_defs:
		if c.key == key:
			return ChoiceOptions.errors(c, preview())
	return ["Unknown choice: %s" % key]


func errors() -> Array[String]:
	var out: Array[String] = []
	if chosen_class == "":
		out.append("Choose a class to advance.")
		return out
	var after := preview()
	for c in after.choice_defs:
		ChoiceOptions.populate(c, after)
		out.append_array(ChoiceOptions.errors(c, after))
	return out


func warnings() -> Array[String]:
	var out: Array[String] = []
	for c in level_choices():
		out.append_array(ChoiceOptions.warnings(c))
	return out


## Before/after rows for the summary screen: {label, before, after}. Only rows that changed.
func changes() -> Array[Dictionary]:
	var a := character
	var b := preview()
	var rows: Array[Dictionary] = []
	_row(rows, "Level", a.class_summary(), b.class_summary())
	_row(rows, "Hit Point maximum", a.max_hp(), b.max_hp())
	_row(rows, "Proficiency Bonus", a.proficiency_bonus(), b.proficiency_bonus())
	_row(rows, "Armor Class", a.ac_value(), b.ac_value())
	_row(rows, "Initiative", a.initiative_bonus().signed(), b.initiative_bonus().signed())
	for ab: StringName in Abilities.ALL:
		_row(rows, str(Creature.ABILITY_NAMES[ab]), a.ability_score(ab), b.ability_score(ab))
	for ab: StringName in Abilities.ALL:
		_row(rows, "%s save" % Creature.ABILITY_NAMES[ab], a.save_bonus(ab).signed(), b.save_bonus(ab).signed())
	_row(rows, "Spell slots", _slots_text(a.spell_slots()), _slots_text(b.spell_slots()))
	for e in b.spellcasting:
		var cid := str(e["class_id"])
		var before_dc := a.spell_save_dc(cid).total() if not a.spellcasting_entry(cid).is_empty() else 0
		_row(rows, "%s spell save DC" % e["name"], before_dc, b.spell_save_dc(cid).total())
	for res_id: String in b.resources:
		var r := b.resources[res_id] as Dictionary
		_row(rows, str(r["name"]), a.resource_max(res_id), int(r["max"]))
	var atk_a := a.attacks()
	var atk_b := b.attacks()
	for i in mini(atk_a.size(), atk_b.size()):
		_row(rows, atk_b[i].name, atk_a[i].describe().get_slice(": ", 1), atk_b[i].describe().get_slice(": ", 1))
	_row(rows, "Hit Point Dice", _dice_text(a.hit_dice()), _dice_text(b.hit_dice()))
	return rows


static func _row(rows: Array[Dictionary], label: String, before: Variant, after: Variant) -> void:
	if str(before) != str(after):
		rows.append({"label": label, "before": before, "after": after})


static func _slots_text(slots: Array[int]) -> String:
	var parts: Array[String] = []
	for i in slots.size():
		if slots[i] > 0:
			parts.append("L%d×%d" % [i + 1, slots[i]])
	return ", ".join(parts) if not parts.is_empty() else "none"


static func _dice_text(dice: Dictionary) -> String:
	var parts: Array[String] = []
	for d: String in dice:
		parts.append("%dd%s" % [int((dice[d] as Dictionary)["total"]), d])
	return " + ".join(parts)


## Applies the level. Current Hit Points rise by the increase in the maximum (including retroactive
## Constitution changes). Returns false, changing nothing, while errors remain.
func confirm() -> bool:
	if not errors().is_empty():
		return false
	var before_max := character.max_hp()
	character.build = build.duplicate(true)
	character.refresh()
	var gained := character.max_hp() - before_max
	if not character.dead:
		character.hp = clampi(character.hp + maxi(0, gained), 0, character.max_hp())
	character.log_event({"type": "level_up", "creature": character.id, "class": chosen_class,
		"level": character.character_level()})
	return true
