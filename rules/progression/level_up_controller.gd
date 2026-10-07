class_name LevelUpController
extends RefCounted
## Gaining a level (plan §5.6 "Level up", 2024 PHB "Level Advancement" and "Multiclassing"): choose the
## class to advance (multiclass prerequisites checked and explained), take the fixed Hit Points or roll the
## die, read the new features, make every choice the level grants (subclass, feat, spells, Expertise ...),
## compare before and after, then confirm. The character doesn't change until confirm(). The picks start blank;
## recommend() (the screen's Use Recommended, Q10) fills the ones still blank with sensible ones, which the player
## changes as they like.

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
	_open_swaps(after)
	for c in after.choice_defs:
		ChoiceOptions.populate(c, after)
		if not c.is_complete():
			out.append(c)
	return out


## All choices touched by this level (complete or not), for the level-up screen: also the spell lists the class may
## swap from (a Bard's spell and cantrip every Bard level, even when the count stays).
func level_choices() -> Array[Choice]:
	var before := {}
	for c in character.choice_defs:
		before[c.key] = c.count
	var after := preview()
	var out: Array[Choice] = []
	var offered := _open_swaps(after)
	for c in after.choice_defs:
		if not before.has(c.key) or int(before[c.key]) != c.count or not c.is_complete() or offered.has(c.key):
			ChoiceOptions.populate(c, after)
			out.append(c)
	return out


## 2024: gaining a level lets that class replace one spell and one cantrip on its lists (`replaceable` level_up, Bard,
## Sorcerer, Warlock, Eldritch Knight, Arcane Trickster; every caster's cantrips but a Wizard's); every other earlier
## pick on a class list stays, so a Cleric or Wizard only adds new spells here and reworks the list after a Long Rest.
## Weapon Mastery is the same: a new level adds kinds, and the earlier ones change after a Long Rest. Other choices a
## level up lets that class swap (`replaceable` level_up with a `replace_max`: one Eldritch Invocation, Maneuver,
## Metamagic option, Fighting Style, Blessed or Druidic Warrior cantrip) are offered every level of it too, and a
## choice tied to no class (Magic Initiate) on any level. Choices a rest lets you change (Wild Shape forms) only grow.
func _open_swap(c: Choice) -> void:
	var spell_list := c.class_id != "" and c.key in ["%s.prepared" % c.class_id, "%s.cantrips" % c.class_id]
	if not spell_list and c.replaceable == "":
		return
	ChoiceOptions.open_swap(c, character.picks_for(c.key), "level_up" if c.class_id in ["", chosen_class] else "")


## Opens every choice's swap chance (_open_swap); choices sharing a `replace_group` (a Warlock's Mystic Arcanum
## spells, one Magic Initiate's cantrips and spell) then share one budget, each keeping what the others haven't used.
## Returns the keys offered a swap ({key: true}), so a spent group stays on screen, locked.
func _open_swaps(after: Character) -> Dictionary:
	var offered := {}
	var used := {}
	for c in after.choice_defs:
		_open_swap(c)
		if c.swap_max > 0:
			offered[c.key] = true
		if c.replace_group != "" and ChoiceOptions.swap_open(c):
			used[_group(c)] = int(used.get(_group(c), 0)) + ChoiceOptions.swapped_out(c).size()
	for c in after.choice_defs:
		if c.replace_group != "" and ChoiceOptions.swap_open(c):
			var others := int(used[_group(c)]) - ChoiceOptions.swapped_out(c).size()
			c.swap_max = maxi(0, c.swap_max - others)
	return offered


## A class's group spans its levels (Mystic Arcanum at 11, 13, 15, 17); a feat's is that one feat (Magic Initiate can be
## taken again for another list).
static func _group(c: Choice) -> String:
	return "%s|%s" % [c.replace_group, c.class_id if c.class_id != "" else c.source]


## Q10: fills every pick this level still needs with a recommended one, keeping every pick already made (a subclass
## other than the recommended one stays, and what it asks for is filled for it): the character's own level plan where it
## fits (a companion's data/pregens `level_plan`), else RecommendedPicks. A choice a pick opens (an Ability Score
## Improvement's abilities, a feat's spell) is filled too. Returns what it filled, for the screen:
## [{key, label, names (the picks as the player reads them), plan (true when the level plan gave them)}].
func recommend() -> Array[Dictionary]:
	var plan := RecommendedPicks.plan_step(character, chosen_class).get("choices", {}) as Dictionary
	var before := {}
	var from_plan := {}
	for _i in 60:
		var next: Choice = null
		for c in level_choices():
			if not c.is_complete() and not before.has(c.key):
				next = c
				break
		if next == null:
			break
		before[next.key] = next.picks.duplicate()
		if plan.has(next.key):
			# The plan's picks after the ones already made, never in place of them.
			var planned: Array = next.picks.duplicate()
			for p: Variant in plan[next.key] as Array:
				if planned.size() < next.count and not str(p) in planned:
					planned.append(str(p))
			if choose(next.key, planned).is_empty():
				from_plan[next.key] = true
				continue
			# The plan no longer fits (an earlier pick changed): back to what was there, then the usual picks.
			choose(next.key, next.picks)
		var picks: Array = next.picks.duplicate()
		picks.append_array(RecommendedPicks.pick(next, preview(), chosen_class))
		choose(next.key, picks)
	var out: Array[Dictionary] = []
	for c in level_choices():
		if not before.has(c.key):
			continue
		var names: Array[String] = []
		for p in c.picks:
			if not p in (before[c.key] as Array):
				var o := c.option(p)
				var shown := o.label if o != null else p
				# Ability increases read "Strength +2" or "Strength +1, Charisma +1".
				if c.kind == "ability_increase":
					shown = "%s +%d" % [shown, c.picks.count(p)]
				if not shown in names:
					names.append(shown)
		if not names.is_empty():
			out.append({"key": c.key, "label": c.label if c.label != "" else c.kind.replace("_", " ").capitalize(),
				"names": names, "plan": from_plan.has(c.key)})
	return out



func choose(key: String, picks: Array) -> Array[String]:
	var clean: Array = []
	for p: Variant in picks:
		clean.append(str(p))
	(build["choices"] as Dictionary)[key] = clean
	_refresh()
	_open_swaps(preview())
	for c in preview().choice_defs:
		if c.key == key:
			ChoiceOptions.populate(c, preview())
			return ChoiceOptions.errors(c, preview())
	return ["Unknown choice: %s" % key]


func errors() -> Array[String]:
	var out: Array[String] = []
	if chosen_class == "":
		out.append("Choose a class to advance.")
		return out
	var after := preview()
	_open_swaps(after)
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
	_row(rows, "Spell slots", _slots_text(a.spellcasting_slots()), _slots_text(b.spellcasting_slots()))
	_row(rows, "Pact Magic slots", _pact_text(a.pact_magic()), _pact_text(b.pact_magic()))
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


static func _pact_text(pact: Dictionary) -> String:
	if int(pact["count"]) <= 0:
		return "none"
	return "%d × level %d" % [int(pact["count"]), int(pact["level"])]


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
