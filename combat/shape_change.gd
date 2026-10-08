class_name ShapeChange
extends RefCounted
## A creature taking a Beast's shape in a fight (Polymorph; the Druid's Wild Shape uses it too): its combatant swaps
## to a Monster built from the Beast's stat block, keeping its own Hit Points (2024: the target keeps its Hit Points
## and Hit Point Dice) and, for Wild Shape, its mind (Intelligence, Wisdom, Charisma and Proficiency Bonus). The real
## creature waits here and comes back, with the Hit Points the shape was left with, when the shape ends: when its
## Temporary Hit Points run out (Polymorph), when it drops to 0 Hit Points, or when the spell or feature ends.

var _enc: WeakRef
## Combatant id -> {creature: Creature, ai_profile, ends_without_temp_hp: bool, label}
var originals: Dictionary = {}


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func is_shaped(c: Combatant) -> bool:
	return originals.has(c.id)


func original(c: Combatant) -> Creature:
	return (originals[c.id] as Dictionary)["creature"] as Creature if originals.has(c.id) else c.creature


## Shapechange and Boon of Fluid Forms keep the caster's spellcasting (Wild Shape, Polymorph and the rest don't).
func keeps_spells(c: Combatant) -> bool:
	return originals.has(c.id) and str((originals[c.id] as Dictionary).get("label", "")) in ["Shapechange", "Fluid Forms"] \
		and (originals[c.id] as Dictionary)["creature"] is Character


## Beasts in the bestiary a creature could become: Challenge Rating at most `max_cr` (swarms excluded).
static func beast_forms(max_cr: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var table := Compendium.shared().tables.get("monsters", {}) as Dictionary
	for id: String in table:
		var d := table[id] as Dictionary
		if str(d.get("type", "")) != "beast" or float(d.get("cr", 0)) > max_cr + 0.001 or str(id).begins_with("swarm"):
			continue
		out.append(d)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("cr", 0)) < float(b.get("cr", 0)))
	return out


## Turns `c` into the Beast `beast` (monster data). opts: temp_hp (Temporary Hit Points it gains), keep_mind (Wild
## Shape: keeps Int, Wis, Cha and Proficiency Bonus), ends_without_temp_hp (Polymorph), label (what changed it),
## ac_floor (Circle of the Moon's 13 + Wisdom modifier).
func transform(c: Combatant, beast: Dictionary, opts: Dictionary = {}) -> Monster:
	var e := enc()
	if is_shaped(c):
		revert(c, "it changes shape again")
	var orig := c.creature
	var d := beast.duplicate(true)
	d["hp"] = {"average": orig.max_hp(), "dice": str(orig.max_hp())}
	d["shape_of"] = orig.id
	if bool(opts.get("keep_mind", false)):
		var ab := (d.get("abilities", {}) as Dictionary).duplicate()
		for k: String in ["int", "wis", "cha"]:
			ab[k] = orig.ability_score(StringName(k))
		d["abilities"] = ab
		d["proficiency_bonus"] = orig.proficiency_bonus()
	if opts.has("ac_floor"):
		d["ac"] = maxi(int(d.get("ac", 10)), int(opts["ac_floor"]))
	if c.side in [&"party", &"guest"] or c.is_player_controlled():
		d["ai_profile"] = str(d.get("ai_profile", "brute"))
	var m := Monster.from_data(d)
	m.id = orig.id
	m.name = "%s (%s)" % [orig.name, str(beast.get("name", "Beast"))]
	m.hp = clampi(orig.hp, 0, m.max_hp())
	m.concentration = orig.concentration
	m.d20_before = orig.d20_before
	m.d20_after = orig.d20_after
	m.fear_seen = orig.fear_seen
	var tmp := int(opts.get("temp_hp", 0))
	# Boon of Fluid Forms: 20 more Temporary Hit Points from any change of shape.
	if tmp > 0:
		tmp += FaerunFeatures.shape_temp_bonus(orig)
	if tmp > 0:
		m.temp_hp = tmp
	originals[c.id] = {"creature": orig, "ai_profile": str(c.ai_profile), "ends_without_temp_hp": bool(opts.get("ends_without_temp_hp", false)),
		"label": str(opts.get("label", "Shape"))}
	c.creature = m
	c.ai_profile = StringName(str(d.get("ai_profile", "brute")))
	c.size_cells = CombatGrid.size_cells_for(m.size)
	c.movement_left = mini(c.movement_left, c.speed())
	e.events.append({"type": "resize", "id": c.id})
	e.events.append({"type": "condition", "id": c.id})
	e.log.add("condition", "%s becomes a %s (%s)" % [orig.name, str(beast.get("name", "Beast")), opts.get("label", "Shape")], c.id)
	return m


## Ends the shape: the real creature returns with the Hit Points the shape had (0 Hit Points: Unconscious for a
## character, dead for a monster). Leftover Temporary Hit Points vanish.
func revert(c: Combatant, why: String) -> void:
	if not is_shaped(c):
		return
	var e := enc()
	var info := originals[c.id] as Dictionary
	originals.erase(c.id)
	var orig := info["creature"] as Creature
	var shape := c.creature
	orig.hp = clampi(shape.hp, 0, orig.max_hp())
	if orig.concentration != null and orig.concentration.ended:
		orig.concentration = null
	# A spell begun in the shape (Shapechange's caster can cast) keeps its Concentration after the change back.
	if shape.concentration != null and not shape.concentration.ended and shape.concentration != orig.concentration:
		orig.concentration = shape.concentration
	c.creature = orig
	c.ai_profile = StringName(str(info["ai_profile"]))
	c.size_cells = CombatGrid.size_cells_for(orig.size)
	if orig.hp <= 0:
		if orig is Character:
			orig.add_condition(&"unconscious", "0 Hit Points")
		else:
			orig.dead = true
	e.events.append({"type": "resize", "id": c.id})
	e.events.append({"type": "condition", "id": c.id})
	e.log.add("condition", "%s returns to its true form (%s)" % [orig.name, why], c.id)


## After damage: Polymorph ends when the Temporary Hit Points run out, any shape when the creature drops to 0.
func after_damage(c: Combatant) -> void:
	if not is_shaped(c):
		return
	var info := originals[c.id] as Dictionary
	if c.creature.hp <= 0 or c.creature.dead:
		revert(c, "dropped to 0 Hit Points")
	elif bool(info["ends_without_temp_hp"]) and c.creature.temp_hp <= 0:
		revert(c, "no Temporary Hit Points left")


## Save data: the real creature behind each shape.
func to_dict() -> Dictionary:
	var out := {}
	for id: String in originals:
		var info := originals[id] as Dictionary
		var orig := info["creature"] as Creature
		var cd := {"ai_profile": info["ai_profile"], "ends_without_temp_hp": info["ends_without_temp_hp"], "label": info["label"]}
		if orig is Character:
			cd["character"] = (orig as Character).to_dict()
		else:
			var m := orig as Monster
			cd["monster_data"] = m.data.duplicate(true)
			cd["name"] = m.name
			cd["state"] = m.state_to_dict()
		out[id] = cd
	return out


func from_dict(d: Dictionary, party: Dictionary) -> void:
	for id: String in d:
		var cd := d[id] as Dictionary
		var orig: Creature
		if cd.has("character"):
			var cid := str((cd["character"] as Dictionary).get("id", ""))
			orig = party[cid] as Character if party.has(cid) else Character.from_dict(cd["character"] as Dictionary)
			if party.has(cid):
				orig.state_from_dict((cd["character"] as Dictionary)["state"] as Dictionary)
		else:
			var m := Monster.from_data(cd["monster_data"] as Dictionary)
			m.name = str(cd["name"])
			m.state_from_dict(cd["state"] as Dictionary)
			orig = m
		orig.id = id
		var c := enc().get_c(id)
		if c != null:
			orig.d20_before = c.creature.d20_before
			orig.d20_after = c.creature.d20_after
			orig.fear_seen = c.creature.fear_seen
		originals[id] = {"creature": orig, "ai_profile": str(cd["ai_profile"]), "ends_without_temp_hp": bool(cd["ends_without_temp_hp"]),
			"label": str(cd["label"])}
