class_name SpellOptions
extends RefCounted
## What a creature can cast in a fight (SpellCaster): its spells and why one can't be cast now (slots, the action
## economy, components, silence, forms), the numbers a cast uses (save DC, attack bonus, free uses), class options when
## casting (Psionic Spells) and Metamagic.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## Every spell `c` knows with whether it can cast it now and why not:
## {id, name, level, class_id, ability, free: bool, casting: action|bonus_action|reaction, legal, reason}
func castable(c: Combatant) -> Array[Dictionary]:
	var spells := sp()
	var out: Array[Dictionary] = []
	if spells.caster_char(c) == null:
		return out
	var ch := spells.caster_char(c)
	var seen := {}
	for k in ch.known_spells():
		var id := str(k["id"])
		if seen.has(id):
			# Prepared and granted both: the granted free casting isn't lost.
			if str(k["kind"]) == "granted" and ch.resource_left("spell:%s" % id) > 0:
				var prev := seen[id] as Dictionary
				prev["free"] = true
				if str(prev["reason"]).begins_with("No spell slots") or str(prev["reason"]).begins_with("Already cast a spell with a slot"):
					prev["legal"] = true
					prev["reason"] = ""
			continue
		var s := _comp().spell_data(id)
		if s.is_empty():
			continue
		var level := int(s.get("level", 0))
		var unit := str((s.get("casting_time", {}) as Dictionary).get("unit", "action"))
		# Mage Hand Legerdemain (Arcane Trickster 3): Mage Hand as a Bonus Action.
		if id == "mage_hand" and CombatFeatures.has_feature(c, "mage_hand_legerdemain"):
			unit = "bonus_action"
		# Spell Breaker (Abjurer 10): Dispel Magic as a Bonus Action.
		if id == "dispel_magic" and CombatFeatures.has_feature(c, "spell_breaker"):
			unit = "bonus_action"
		# Pact of the Chain: Find Familiar as a Magic action without a slot.
		var chain := id == "find_familiar" and ClassFeatures.knows_invocation(c, "pact_of_the_chain")
		if chain:
			unit = "action"
		var entry := {"id": id, "name": str(s["name"]), "level": level, "class_id": str(k.get("class_id", "")),
			"ability": str(k.get("ability", "")), "free": false, "casting": unit, "legal": true, "reason": ""}
		var res_id := "spell:%s" % id
		if str(k["kind"]) == "granted" and ch.resource_left(res_id) > 0:
			entry["free"] = true
			# Genie Magic: the free casting at a higher slot from some character level on.
			entry["free_slot"] = int(k.get("free_slot", 0))
		# Warlock invocations that cast a spell at will (Armor of Shadows, Fiendish Vigor...).
		if ClassFeatures.at_will(c, id) or chain or bool(k.get("at_will", false)):
			entry["free"] = true
			entry["at_will"] = true
		var why := _why_not(c, s, entry)
		if why != "":
			entry["legal"] = false
			entry["reason"] = why
		out.append(entry)
		seen[id] = entry
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["level"]) < int(b["level"]) or (int(a["level"]) == int(b["level"]) and str(a["name"]) < str(b["name"])))
	return out


func _why_not(c: Combatant, s: Dictionary, entry: Dictionary) -> String:
	var spells := sp()
	if str(s.get("automation", "")) == "reference":
		return "Not automated yet"
	if not has_combat_rules(s):
		return "No effect in a fight (%s)" % _out_of_combat_word(s)
	var ch := spells.caster_char(c)
	var unit := str(entry["casting"])
	if unit == "reaction":
		return "Cast as a Reaction when it triggers"
	if unit in ["minute", "hour"]:
		return "Takes too long to cast in combat (cast it before the fight)"
	var why := economy_block(c, unit)
	if why != "":
		return why
	var comp := s.get("components", {}) as Dictionary
	# Enchantment and Illusion Adept: a spell of that school cast with a slot needs no Verbal component.
	var waived := (int(s.get("level", 0)) > 0 and c.creature.has_flag("waive_components:%s" % str(s.get("school", "")))) \
		or enc().faerun.waives_components(c, str(s.get("id", "")))
	if bool(comp.get("v", false)) and not waived and not (str(s.get("school", "")) == "illusion" and CombatFeatures.has_feature(c, "improved_illusions")):
		# Spell-Slinger's Puppet: its holder speaks through the doll.
		var voiced := enc().items.specials.fr.puppet_voice(c)
		if c.creature.has_flag("speechless") and not voiced:
			return "Can't speak"
		for cell in c.footprint():
			if spells.zones.silenced(cell) and not voiced:
				return "Silence: no Verbal spells here"
	if c.creature.has_flag("cant_cast"):
		return "Can't cast spells in this form"
	var armor := ch.equipped("armor")
	if not armor.is_empty() and not ch.trained_for(armor):
		return "Wearing armor without training"
	# A costly material component (2024): carried, since no pouch or focus stands in for it; not when a feature casts the
	# spell without its Material component (Knowledge Domain's Channel Divinity).
	var feature_cast := entry.get("resource_cast", {}) as Dictionary
	if not bool((feature_cast.get("resource_cast", {}) as Dictionary).get("omit_material", false)):
		var need := ch.component_why(s)
		if need != "":
			return need
	var level := int(s.get("level", 0))
	if level > 0 and not bool(entry["free"]):
		if c.cast_slot_spell_this_turn:
			return "Already cast a spell with a slot this turn"
		var any := false
		for l in range(level, 10):
			if ch.slots_left(l) > 0:
				any = true
		if not any:
			return "No spell slots of level %d or higher left" % level
	if str(s["id"]) == "spiritual_weapon" and spells.zones.object_of(c.id, "spiritual_weapon") != null:
		return ""
	return ""


## "" if the action economy lets `c` spend this casting time now.
func economy_block(c: Combatant, unit: String) -> String:
	if unit == "action":
		if not c.action_available:
			return "Action already used"
		if c.magic_action_used:
			return "Only one Magic action this turn (Action Surge's action can't be Magic)"
		if (c.creature.has_flag("slowed") or c.creature.has_flag("action_or_bonus")) and not c.bonus_available:
			return "An action or a Bonus Action this turn, not both"
	if unit == "bonus_action":
		if not c.bonus_available:
			return "Bonus Action already used"
		if (c.creature.has_flag("slowed") or c.creature.has_flag("action_or_bonus")) and not c.action_available and not c.surged:
			return "An action or a Bonus Action this turn, not both"
	return ""


static func _out_of_combat_word(s: Dictionary) -> String:
	var tags := s.get("tags", []) as Array
	for t: String in ["detection", "communication", "social", "utility"]:
		if t in tags:
			return t
	return "exploration"


## True if the spell does something the combat engine can resolve.
func has_combat_rules(s: Dictionary) -> bool:
	if str(s.get("id", "")) in SpellCaster.SPECIAL or str(s.get("id", "")) in SpellCaster.SUMMON_SPELLS or str(s.get("id", "")) in SpellSpecials.HANDLED or str(s.get("id", "")) in HighMagic.HANDLED or str(s.get("id", "")) in MidMagic.HANDLED:
		return true
	for k: String in ["attack", "heal", "damage", "temp_hp", "zone", "object", "sustain", "roll_response"]:
		if s.has(k):
			return true
	for fx: Variant in s.get("effects", []):
		if str((fx as Dictionary).get("effect", "")) in SpellCaster.COMBAT_EFFECTS:
			return true
	return false


## Effects can require a save to complete casting, without spending a spell slot on failure.
## Kept on the effect so the DC, duration and removal survive encounter saves.
func casting_gate(c: Combatant) -> bool:
	for fx: Effect in c.creature.effects.duplicate():
		if not fx.data.has("casting_save"):
			continue
		var rule := fx.data["casting_save"] as Dictionary
		var test := c.creature.roll_save(enc().dice, StringName(str(rule["ability"])), int(rule["dc"]), [], [], "Casting through %s" % fx.name, SpellCaster.spell_save_keys(fx.caster_id))
		enc().log.add("save", test.describe(), c.id)
		if not test.success:
			enc().log.add("spell", "%s's spell dissipates; casting time spent, spell slot preserved" % c.name(), c.id)
			return false
	return true


## A spell cast before the fight (Mage Armor, Find Familiar, Animate Dead): its lowest slot is spent and its effect
## applied, with Concentration if it needs it. With `ritual`, a Ritual spell cast earlier as a Ritual carries over and
## spends nothing (a summoned familiar joining the fight).
func precast(c: Combatant, spell_id: String, ritual: bool = false) -> bool:
	var spells := sp()
	if spells.caster_char(c) == null:
		return false
	var ch := spells.caster_char(c)
	var s := _comp().spell_data(spell_id)
	var entry := spells._entry_any(c, spell_id)
	if s.is_empty() or entry.is_empty():
		return false
	var level := int(s.get("level", 0))
	var slot := 0
	var as_ritual := ritual and bool(s.get("ritual", false))
	# A Ritual spends nothing; Undead Thralls: a free casting of Animate Dead before the fight comes first.
	if as_ritual:
		slot = level
	elif level > 0 and ch.resource_left("spell:%s" % spell_id) > 0:
		ch.spend_resource("spell:%s" % spell_id)
		slot = level
	elif level > 0:
		slot = spells._lowest_slot(ch, level)
		if slot == 0:
			return false
		ch.expend_slot(slot)
	var conc: Concentration = null
	if bool((s.get("duration", {}) as Dictionary).get("concentration", false)):
		conc = c.creature.begin_concentration(spell_id, str(s["name"]))
	enc().log.add("spell", "%s cast %s before the fight%s" % [c.name(), s["name"], " (cast earlier as a Ritual)" if as_ritual else (" (level %d slot)" % slot if slot > 0 else "")], c.id)
	var ctx := {"c": c, "s": s, "slot": slot, "nums": numbers(c, entry), "conc": conc, "opts": {}, "precast": true,
		"choice": str(c.get_meta("chain_form", "imp")) if spell_id == "find_familiar" and ClassFeatures.knows_invocation(c, "pact_of_the_chain") else ""}
	# Necromancy Familiar: the form chosen for it (a Skeleton unless set).
	if spell_id == "find_familiar" and CombatFeatures.has_feature(c, "necromancy_familiar"):
		ctx["choice"] = str(c.get_meta("familiar_form", "skeleton"))
	var r := CombatResult.new()
	match spell_id:
		"find_familiar", "animate_dead":
			spells._summon(ctx, c.cell, r)
		_:
			spells.apply_effect_entries(ctx, c, s.get("effects", []) as Array, "cast", r)
	return true


func _entry(c: Combatant, spell_id: String) -> Dictionary:
	for e in castable(c):
		if str(e["id"]) == spell_id:
			return e
	return {}


## {dc: Breakdown, attack: Breakdown, mod: int}
func numbers(c: Combatant, entry: Dictionary) -> Dictionary:
	var spells := sp()
	var ch := spells.caster_char(c)
	var cid := str(entry.get("class_id", ""))
	if cid != "" and not ch.spellcasting_entry(cid).is_empty():
		var ab := StringName(str(ch.spellcasting_entry(cid)["ability"]))
		return {"dc": ch.spell_save_dc(cid), "attack": ch.spell_attack_bonus(cid), "mod": ch.ability_mod(ab), "ability": ab, "class_id": cid}
	var ab2 := StringName(str(entry.get("ability", "int")))
	if not Creature.ABILITY_NAMES.has(ab2):
		ab2 = &"int"
	var mod := ch.ability_mod(ab2)
	var dc := Breakdown.new("Spell save DC")
	dc.add("Base", 8).add("%s modifier" % Creature.ABILITY_SHORT[ab2], mod).add("Proficiency", ch.proficiency_bonus())
	var atk := Breakdown.new("Spell attack")
	atk.add("%s modifier" % Creature.ABILITY_SHORT[ab2], mod).add("Proficiency", ch.proficiency_bonus())
	return {"dc": dc, "attack": atk, "mod": mod, "ability": ab2}


## Overchannel (Evoker 14): the first use per Long Rest is free; each later one deals 2d12 Necrotic per spell level
## (+1d12 per use) to the caster, ignoring Resistance and Immunity.
func _overchannel_cost(c: Combatant, level: int) -> void:
	var uses := int(c.get_meta("overchannel_uses", 0))
	c.set_meta("overchannel_uses", uses + 1)
	if uses == 0:
		return
	var n := (2 + uses - 1) * level
	var rolled := enc()._roll_damage_dice("%dd12" % n, false, 0, "Overchannel")
	c.creature.hp = maxi(0, c.creature.hp - int(rolled["total"]))
	enc().log.add("hit", "Overchannel burns %s for %d Necrotic" % [c.name(), int(rolled["total"])], c.id, [str(rolled["text"])])


## The class casting options `c` could add to spell `s` now.
func class_cast_options(c: Combatant, s: Dictionary) -> Array[String]:
	var spells := sp()
	var out: Array[String] = []
	if spells.caster_char(c) == null:
		return out
	var classes := s.get("classes", []) as Array
	if CombatFeatures.has_feature(c, "psychic_spells") and "warlock" in classes and (s.has("damage") or str(s.get("school", "")) in ["enchantment", "illusion"]):
		out.append("psychic_spells")
	var lvl := int(s.get("level", 0))
	if CombatFeatures.has_feature(c, "psionic_sorcery") and str(s.get("id", "")) in SpellCaster.PSIONIC_SPELLS and lvl >= 1 \
			and spells.caster_char(c).resource_left("sorcery_points") >= lvl:
		out.append("psionic_sorcery")
	return out


func _metamagic_check(c: Combatant, s: Dictionary, meta: Array) -> String:
	var spells := sp()
	if meta.is_empty():
		return ""
	if spells.caster_char(c) == null:
		return "No Metamagic"
	var ch := spells.caster_char(c)
	var cost := 0
	var main := 0
	for m: String in meta:
		if m in SpellCaster.CLASS_CAST_OPTIONS:
			if not m in class_cast_options(c, s):
				return "Can't use %s on this spell" % m.capitalize().replace("_", " ")
			continue
		if not SpellCaster.METAMAGIC_COST.has(m):
			return "Unknown Metamagic %s" % m
		if not m in metamagic_known(ch):
			return "%s doesn't know %s Spell" % [c.name(), m.capitalize()]
		cost += int(SpellCaster.METAMAGIC_COST[m])
		if not m in ["empowered", "seeking"]:
			main += 1
	# Sorcery Incarnate (Sorcerer 7): two options on one spell while Innate Sorcery is active.
	var allowed := 2 if CombatFeatures.has_feature(c, "sorcery_incarnate") and c.creature.has_flag("innate_sorcery") else 1
	if main > allowed:
		return "Only one Metamagic option per spell (Empowered and Seeking can join another)"
	if "twinned" in meta and int((s.get("upcast", {}) as Dictionary).get("targets", 0)) <= 0:
		return "Twinned Spell needs a spell that can target more creatures at a higher level"
	if "quickened" in meta and str((s.get("casting_time", {}) as Dictionary).get("unit", "")) != "action":
		return "Quickened Spell needs a spell with a casting time of an action"
	if ch.resource_left("sorcery_points") < cost:
		return "Needs %d Sorcery Points" % cost
	return ""


## Metamagic options a character chose (choices of kind "metamagic").
static func metamagic_known(ch: Character) -> Array[String]:
	var out: Array[String] = []
	for c in ch.choice_defs:
		if c.kind == "metamagic":
			for p: Variant in c.picks:
				out.append(str(p).trim_suffix("_spell"))
	return out


func _pay_metamagic(c: Combatant, meta: Array) -> void:
	var spells := sp()
	var cost := 0
	for m: String in meta:
		cost += int(SpellCaster.METAMAGIC_COST.get(m, 0))
	if cost == 0:
		return
	spells.caster_char(c).spend_resource("sorcery_points", cost)
	enc().log.add("info", "%s shapes the spell: %s (%d Sorcery Points)" % [c.name(), ", ".join(meta.map(func(x: String) -> String: return x.capitalize())), cost], c.id)


func resource_cast_entry(c: Combatant, spell: Dictionary, feature_id: String) -> Dictionary:
	var spells := sp()
	var ch := spells.caster_char(c)
	if ch == null:
		return {}
	for feature in ch.resource_casts(str(spell["id"])):
		if str(feature["id"]) != feature_id:
			continue
		var rule := feature["resource_cast"] as Dictionary
		var entry := {"id": str(spell["id"]), "name": str(spell["name"]), "level": int(spell["level"]),
			"class_id": str(feature["class_id"]), "ability": str(feature["ability"]), "free": true,
			"casting": str(rule["casting"]), "resource_cast": feature}
		var reason := _why_not(c, spell, entry)
		if reason == "" and ch.resource_left(str(rule["resource"])) < int(rule["cost"]):
			reason = "No %s uses left" % str((ch.resources.get(str(rule["resource"]), {}) as Dictionary).get("name", rule["resource"]))
		entry["legal"] = reason == ""
		entry["reason"] = reason
		return entry
	return {}
