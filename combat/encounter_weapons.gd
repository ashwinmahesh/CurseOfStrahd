class_name EncounterWeapons
extends RefCounted
## What a creature in a fight can attack with (Encounter): its weapon, thrown and unarmed options and stat-block
## attacks, Soulknife blades, how many attacks an Attack action gives, whether an attack is legal from where it stands
## (range, reach, sight, charm, a monster's weapon knocked from its hand), and ammunition and thrown weapons leaving the
## hand (a thrown one lands by its target, GroundItems).

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## Charmed (2024): a Charmed creature can't attack its charmer or target it with damaging abilities or magic.
## "" if `c` may target `t`.
func charm_blocks(c: Combatant, t: Combatant) -> String:
	if not c.creature.has_condition(&"charmed"):
		return ""
	for fx: Effect in c.creature.effects:
		if StringName("charmed") in fx.conditions and fx.caster_id == t.id:
			return "%s is Charmed by %s and can't attack it" % [c.name(), t.name()]
	if c.has_meta("charmed_by") and str(c.get_meta("charmed_by")) == t.id:
		return "%s is Charmed by %s and can't attack it" % [c.name(), t.name()]
	return ""


## The weapon a Polearm Master reacts with: a Quarterstaff, a Spear, or a Heavy weapon with Reach.
func _polearm_option(p: Combatant) -> Dictionary:
	for o in attack_options(p):
		var pr := o["profile"] as WeaponProfile
		if bool(o["melee"]) and (pr.item_id in ["quarterstaff", "spear"] or ("heavy" in pr.properties and "reach" in pr.properties)):
			return o
	return {}


## Every attack `c` can make: {id, label, kind: weapon|thrown|unarmed|monster, profile: WeaponProfile,
## action_id, melee: bool, range: [normal, long], reach}.
func attack_options(c: Combatant) -> Array[Dictionary]:
	var e := enc()
	var out: Array[Dictionary] = []
	if c.creature is Character:
		for p in (c.creature as Character).attacks():
			out.append({"id": ("thrown:" if p.thrown else "weapon:") + p.item_id + ("@" + p.ammo_id if p.ammo_id != "" else ""), "label": p.name,
				"kind": "thrown" if p.thrown else ("unarmed" if p.item_id == "unarmed_strike" else "weapon"),
				"profile": p, "melee": p.melee, "range": [p.normal_range, p.long_range], "reach": p.reach})
		if CombatFeatures.has_feature(c, "psychic_blades"):
			for thrown: bool in [false, true]:
				var pb := _psychic_blade(c, thrown, c.light_attack_weapon == "psychic_blade")
				out.append({"id": ("blade:thrown" if thrown else "blade:melee"), "label": pb.name, "kind": "blade",
					"profile": pb, "melee": not thrown, "range": [pb.normal_range, pb.long_range], "reach": pb.reach})
		out.append_array(e.ravenloft.attack_options(c))
	elif c.creature is Monster:
		var m := c.creature as Monster
		for a: Variant in m.data.get("actions", []):
			var act := a as Dictionary
			if not act.has("attack"):
				continue
			var p := m.attack_profile(str(act["id"]))
			out.append({"id": "monster:" + str(act["id"]), "label": str(act["name"]), "kind": "monster",
				"profile": p, "action_id": str(act["id"]), "melee": p.melee, "range": [p.normal_range, p.long_range],
				"reach": p.reach})
	return out


## Soulknife's Psychic Blade: a Simple Melee weapon with Finesse and Thrown (60/120 ft), 1d6 Psychic + the
## ability modifier, Vex mastery; the second blade (a Bonus Action after attacking with the first) deals 1d4.
func _psychic_blade(c: Combatant, thrown: bool, second: bool) -> WeaponProfile:
	var item := {"id": "psychic_blade", "name": "Psychic Blade", "weapon": {"kind": "simple_melee", "damage": "1d4" if second else "1d6",
		"damage_type": "psychic", "properties": ["finesse", "thrown", "light"], "range": [60, 120], "mastery": "vex"}}
	var p := WeaponProfile.build(c.creature, item, thrown)
	p.mastery = "vex"
	p.proficient = true
	p._compute(c.creature)
	return p


func option_by_id(c: Combatant, option_id: String) -> Dictionary:
	for o in attack_options(c):
		if str(o["id"]) == option_id:
			return o
	return {}


## The melee attack a creature would use for an Opportunity Attack (best average damage).
func best_melee_option(c: Combatant, _target: Combatant) -> Dictionary:
	var best := {}
	var best_avg := -1.0
	for o in attack_options(c):
		if not bool(o["melee"]) or _weapon_gone(c, o) != "":
			continue
		var avg := (o["profile"] as WeaponProfile).average_damage()
		if avg > best_avg:
			best_avg = avg
			best = o
	return best


## How many attacks one Attack action gives (Extra Attack; the highest source wins, 2024 multiclass rule).
func attacks_per_action(c: Combatant) -> int:
	if c.creature.has_flag("slowed"):
		return 1
	var best := 1
	var ctx := c.creature.formula_context()
	for m in c.creature.modifiers_for(&"attacks_per_action"):
		best = maxi(best, c.creature.mod_value(m, ctx))
	return best


## "" if `c` can attack `target` with `option` from where it stands, otherwise why not.
func attack_legal(c: Combatant, target: Combatant, option: Dictionary) -> String:
	var e := enc()
	if target == null or not target.is_alive():
		return "No target"
	if target == c:
		return "Can't attack yourself"
	if e.spells.specials.sphere_blocks(c, target):
		return "A sphere of force is in the way"
	if e.spells.specials.high.box_between(c, target) or e.spells.specials.mid.wall_between(c, target):
		return "A wall is in the way"
	if bool(option["melee"]) and e.spells.specials.mid.shell_blocks_reach(c, target):
		return "The Antilife Shell keeps you out of reach"
	var item_block := e.items.attack_blocked(c, target, option)
	if item_block != "":
		return item_block
	var dist := e.distance(c, target)
	var p := option["profile"] as WeaponProfile
	if bool(option["melee"]):
		if dist > p.reach:
			return "Out of reach (%d ft, reach %d ft)" % [dist, p.reach]
	else:
		var long := p.long_range if p.long_range > 0 else p.normal_range
		if long > 0 and dist > long:
			return "Out of range (%d ft, range %d/%d)" % [dist, p.normal_range, long]
	if int(e.cover(c, target)["cover"]) == CombatGrid.Cover.TOTAL:
		return "No clear line: Total Cover"
	if target.creature.has_flag("ethereal"):
		return "%s is on the Ethereal Plane" % target.name()
	if c.creature.has_flag("cant_attack"):
		return "%s can't attack in this form" % c.name()
	if bool(option["melee"]) and c.creature.has_flag("levitating") != target.creature.has_flag("levitating") \
			and (option["profile"] as WeaponProfile).reach < 20:
		return "Out of reach: one of you is floating 20 ft up (Levitate)"
	var charm := charm_blocks(c, target)
	if charm != "":
		return charm
	var gone := _weapon_gone(c, option)
	if gone != "":
		return gone
	# A stat-block attack only some targets qualify for (a vampire's Bite: grappled, incapacitated or restrained).
	if c.creature is Monster and option.has("action_id"):
		var needs := ((c.creature as Monster).action(str(option["action_id"])).get("targets", {}) as Dictionary).get("requires", []) as Array
		if not needs.is_empty() and not needs.any(func(n: Variant) -> bool: return Legendary.meets(c, target, str(n))):
			return "%s must be %s" % [target.name(), " or ".join(needs.filter(func(n: Variant) -> bool: return str(n) != "willing").map(func(n: Variant) -> String: return str(n).capitalize()))]
	if c.creature is Character and option["kind"] in ["thrown", "weapon"] and item_count(c, p.item_id) <= 0:
		return "No %s left" % p.name.replace(" (thrown)", "")
	if c.creature is Character and option["kind"] in ["thrown", "weapon"] and not bool(option["melee"]):
		var w := (c.creature as Character).compendium.item_data(p.item_id)
		var ammo := str((w.get("weapon", {}) as Dictionary).get("ammunition", ""))
		if ammo != "" and not _has_ammo(c, ammo, p.ammo_id):
			return "No ammunition"
	return ""


## False if `option` is a ranged weapon whose ammunition has run out.
func has_ammo_for(c: Combatant, option: Dictionary) -> bool:
	if not c.creature is Character or bool(option["melee"]) or str(option["kind"]) != "weapon":
		return true
	var w := (c.creature as Character).compendium.item_data((option["profile"] as WeaponProfile).item_id)
	var ammo := str((w.get("weapon", {}) as Dictionary).get("ammunition", ""))
	return ammo == "" or _has_ammo(c, ammo, (option["profile"] as WeaponProfile).ammo_id)


## How many of an item a character carries.
func item_count(c: Combatant, item_id: String) -> int:
	var n := 0
	if c.creature is Character:
		for e in (c.creature as Character).inventory:
			if str(e["id"]) == item_id:
				n += int(e["qty"])
	return n


## A stat-block attack whose weapon is out of the monster's hands (GroundItems): why it can't be made, else "".
func _weapon_gone(c: Combatant, option: Dictionary) -> String:
	if not c.creature is Monster or not option.has("action_id"):
		return ""
	return enc().ground.weapon_gone(c, (c.creature as Monster).action(str(option["action_id"])))


## One of a consumable used up (a Goodberry).
func _spend_item(c: Combatant, item_id: String) -> void:
	for e in (c.creature as Character).inventory:
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			e["qty"] = int(e["qty"]) - 1
			return


## A thrown weapon leaves the hand and comes down in its target's space (GroundItems), to be picked up again. The last
## of a stack leaves the inventory; a weapon that doesn't stack (a magic one) lies there with its own entry, so a
## charge its power spends as it flies (Hammer of Thunderbolts) still comes off it.
func throw_item(c: Combatant, item_id: String, target: Combatant) -> void:
	var ch := c.creature as Character
	for en in ch.inventory:
		if str(en["id"]) != item_id or int(en["qty"]) <= 0:
			continue
		var slot := str(en.get("slot", ""))
		en["qty"] = int(en["qty"]) - 1
		var state := {}
		if int(en["qty"]) <= 0:
			ch.inventory.erase(en)
			if not bool(Compendium.shared().item_data(item_id).get("stackable", false)):
				state = en
		else:
			slot = ""   # more of the stack is still in hand
		ch.items_changed()
		enc().ground.land(c, item_id, state, slot, target)
		return


## Whether `c` carries ammunition of `ammo`'s kind (`specific`: that magic ammunition, "" = ordinary).
func _has_ammo(c: Combatant, ammo: String, specific: String = "") -> bool:
	var want := specific if specific != "" else str(Gear.AMMO_IDS.get(ammo, ammo))
	for e in (c.creature as Character).inventory:
		if str(e["id"]) == want and int(e["qty"]) > 0:
			return true
	return false


func _spend_ammo(c: Combatant, p: WeaponProfile) -> void:
	var ch := c.creature as Character
	var w := ch.compendium.item_data(p.item_id)
	var ammo := str((w.get("weapon", {}) as Dictionary).get("ammunition", ""))
	if ammo == "":
		return
	var want := p.ammo_id if p.ammo_id != "" else str(Gear.AMMO_IDS.get(ammo, ammo))
	for e in ch.inventory:
		if str(e["id"]) == want and int(e["qty"]) > 0:
			e["qty"] = int(e["qty"]) - 1
			enc().ground.ammo_spent(c, want)
			return
