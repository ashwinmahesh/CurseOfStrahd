class_name ActionCatalog
extends RefCounted
## The hotbar (combat view spec, cb_01): every option a creature has this turn, with what it costs, whether it can
## be used now and why not, how it's aimed, and the numbers to show. The HUD lists these and calls perform(); it
## never computes rules itself. Previews (hit chances, area templates, movement paths) come from here too.
##
## An action: {id, tab, label, sub, cost: action|attack|bonus|reaction|free|movement, legal, reason, targeting,
##   count, repeat, range, spell_id, slot, option_id, kind, help}
## targeting: none (at once), enemy, ally, creature, dying (a creature at 0 HP), multi (up to `count` creatures,
##   repeats allowed when `repeat`), point (a grid point in range), direction (aimed from the caster).

const COMMON := "Common"
const SPELLS := "Spells"
const ITEMS := "Items"
const PASSIVES := "Passives"

var e: Encounter


func _init(encounter: Encounter) -> void:
	e = encounter


func tabs_for(c: Combatant) -> Array[String]:
	var out: Array[String] = [COMMON, class_tab(c)]
	if c.creature is Character and not (c.creature as Character).spellcasting.is_empty():
		out.append(SPELLS)
	out.append(ITEMS)
	out.append(PASSIVES)
	return out


func class_tab(c: Combatant) -> String:
	if c.creature is Character:
		var ch := c.creature as Character
		if not ch.class_order.is_empty():
			return ch.class_name_of(ch.class_order[0])
	return "Abilities"


func actions_for(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_attacks(c, out)
	_standard(c, out)
	_class_actions(c, out)
	_spells(c, out)
	_items(c, out)
	_passives(c, out)
	return out


func find(c: Combatant, action_id: String) -> Dictionary:
	for a in actions_for(c):
		if str(a["id"]) == action_id:
			return a
	return {}


func _entry(id: String, tab: String, label: String, sub: String, cost: String, why: String, targeting: String,
		help: String = "") -> Dictionary:
	return {"id": id, "tab": tab, "label": label, "sub": sub, "cost": cost, "legal": why == "", "reason": why,
		"targeting": targeting, "count": 1, "repeat": false, "range": 0, "spell_id": "", "slot": 0, "option_id": "",
		"kind": id.get_slice(":", 0), "help": help}


## "" if `c` could start or continue the Attack action now.
func _attack_why(c: Combatant) -> String:
	var why := e._turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "Can't act"
	if c.attacks_left <= 0 and not c.action_available:
		return "Action already used"
	return ""


func _attacks(c: Combatant, out: Array[Dictionary]) -> void:
	var why := _attack_why(c)
	var cost := "attack" if c.attacks_left > 0 else "action"
	var per := e.attacks_per_action(c)
	for o in e.attack_options(c):
		var p := o["profile"] as WeaponProfile
		if str(o["kind"]) == "unarmed":
			continue
		var w := why
		if w == "" and not e.has_ammo_for(c, o):
			w = "No ammunition"
		var dmg := "%s%s" % [p.damage_dice, ("%+d" % p.damage_bonus.total()) if p.damage_bonus.total() != 0 else ""]
		var a := _entry("attack:" + str(o["id"]), COMMON, p.name, "%+d · %s" % [p.attack.total(), dmg], cost, w, "enemy",
			"Attack%s. %s" % [(" (%d attacks per Attack action)" % per) if per > 1 else "", p.describe()])
		a["option_id"] = str(o["id"])
		a["range"] = p.reach if bool(o["melee"]) else (p.long_range if p.long_range > 0 else p.normal_range)
		out.append(a)
		# The Light property's extra attack.
		if "light" in p.properties and c.light_attack_weapon != "" and p.item_id != c.light_attack_weapon:
			var nick := p.mastery == "nick"
			for o2 in e.attack_options(c):
				if (o2["profile"] as WeaponProfile).item_id == c.light_attack_weapon and (o2["profile"] as WeaponProfile).mastery == "nick":
					nick = true
			var w2 := e._turn_check(c)
			if w2 == "" and c.nick_used:
				w2 = "Extra Light attack already made"
			elif w2 == "" and not nick and not c.bonus_available:
				w2 = "Bonus Action used"
			var thrown := str(o["kind"]) == "thrown"
			var off := _entry("offhand:" + str(o["id"]), COMMON, "Off-hand " + p.name.replace(" (thrown)", ""),
				"Light%s%s" % [" · Nick" if nick else "", " · thrown" if thrown else ""],
				"free" if nick else "bonus", w2, "enemy", "The Light property's extra attack, without your ability modifier to damage.")
			off["option_id"] = str(o["id"])
			off["range"] = a["range"]
			out.append(off)
	var dc := 8 + c.creature.ability_mod(&"str") + c.creature.proficiency_bonus()
	var g := _entry("grapple", COMMON, "Grapple", "DC %d" % dc, cost, why, "enemy", "Unarmed Strike: the target makes a Str or Dex save or is Grappled.")
	g["range"] = 5
	out.append(g)
	var sp := _entry("shove_prone", COMMON, "Shove: Prone", "DC %d" % dc, cost, why, "enemy", "Unarmed Strike: the target makes a Str or Dex save or falls Prone.")
	sp["range"] = 5
	out.append(sp)
	var sh := _entry("shove_push", COMMON, "Shove: Push", "DC %d · 5 ft" % dc, cost, why, "enemy", "Unarmed Strike: the target makes a Str or Dex save or is pushed 5 ft.")
	sh["range"] = 5
	out.append(sh)


func _standard(c: Combatant, out: Array[Dictionary]) -> void:
	var why := e._action_check(c)
	out.append(_entry("dash", COMMON, "Dash", "+%d ft" % c.speed(), "action", why, "none", "Gain extra movement equal to your Speed."))
	out.append(_entry("disengage", COMMON, "Disengage", "no Opp. Attacks", "action", why, "none", "Your movement doesn't provoke Opportunity Attacks this turn."))
	out.append(_entry("dodge", COMMON, "Dodge", "until your turn", "action", why, "none", "Attacks against you have Disadvantage; Advantage on Dex saves."))
	var help := _entry("help", COMMON, "Help", "ally Advantage", "action", why, "enemy", "Distract an enemy within 5 ft: the next ally attack against it has Advantage.")
	help["range"] = 5
	out.append(help)
	var hide_why := why
	if hide_why == "":
		hide_why = e.hide_blocker(c)
	out.append(_entry("hide", COMMON, "Hide", "DC 15 Stealth", "action", hide_why, "none", "Needs Three-Quarters or Total Cover from every enemy."))
	out.append(_entry("search", COMMON, "Search", "Perception", "action", why, "none", "Look for hidden creatures."))
	var study := _entry("study", COMMON, "Study", "recall lore", "action", why, "creature", "An Intelligence check to recall what a creature is and what it can do.")
	study["range"] = 120
	out.append(study)
	var ready_why := why
	var best := e.best_melee_option(c, null)
	if ready_why == "" and best.is_empty():
		ready_why = "No attack to ready"
	var rd := _entry("ready", COMMON, "Ready", "attack on approach", "action", ready_why, "none",
		"Hold an attack (%s) for your Reaction when an enemy comes within reach." % (best.get("label", "") if not best.is_empty() else ""))
	rd["option_id"] = str(best.get("id", ""))
	out.append(rd)
	var stab := _entry("stabilize", COMMON, "Stabilize", "DC 10 Medicine", "action", why, "dying", "Help a dying creature within 5 ft: a DC 10 Wisdom (Medicine) check makes it Stable.")
	stab["range"] = 5
	out.append(stab)
	if e.grapples.has(c.id):
		out.append(_entry("escape", COMMON, "Escape Grapple", "Athletics or Acrobatics", "action", why, "none"))
	if c.creature.has_condition(&"prone"):
		var stand_why := e._turn_check(c)
		if stand_why == "" and c.movement_left < c.speed() / 2:
			stand_why = "Needs %d ft of movement" % (c.speed() / 2)
		out.append(_entry("stand", COMMON, "Stand Up", "%d ft" % (c.speed() / 2), "movement", stand_why, "none"))
	else:
		out.append(_entry("drop_prone", COMMON, "Drop Prone", "free", "movement", e._turn_check(c), "none"))
	out.append(_entry("influence", COMMON, "Influence", "talk", "action", "Wolves and the walking dead can't be reasoned with", "none"))
	out.append(_entry("utilize", COMMON, "Utilize", "use an object", "action", "Nothing to use here (Healer's Kit is on Items)", "none"))


func _class_actions(c: Combatant, out: Array[Dictionary]) -> void:
	if not c.creature is Character:
		return
	var ch := c.creature as Character
	var tab := class_tab(c)
	var bwhy := e._bonus_check(c)
	if CombatFeatures.has_feature(c, "second_wind"):
		var w := bwhy if bwhy != "" else ("No uses left" if ch.resource_left("second_wind") <= 0 else "")
		out.append(_entry("second_wind", tab, "Second Wind", "%d left · 1d10+%d" % [ch.resource_left("second_wind"), ch.class_level_of("fighter")], "bonus", w, "none"))
	if CombatFeatures.has_feature(c, "action_surge"):
		var w2 := e._turn_check(c)
		if w2 == "":
			w2 = "No uses left" if ch.resource_left("action_surge") <= 0 else ("Used this turn" if c.surged else "")
		out.append(_entry("action_surge", tab, "Action Surge", "%d left" % ch.resource_left("action_surge"), "free", w2, "none", "One more action this turn (not Magic)."))
	if CombatFeatures.has_feature(c, "cunning_action"):
		out.append(_entry("cunning_dash", tab, "Cunning: Dash", "+%d ft" % c.speed(), "bonus", bwhy, "none"))
		out.append(_entry("cunning_disengage", tab, "Cunning: Disengage", "no Opp. Attacks", "bonus", bwhy, "none"))
		var hw := bwhy if bwhy != "" else e.hide_blocker(c)
		out.append(_entry("cunning_hide", tab, "Cunning: Hide", "DC 15 Stealth", "bonus", hw, "none"))
	if CombatFeatures.has_feature(c, "steady_aim"):
		var sw := bwhy if bwhy != "" else ("You've moved this turn" if c.moved else "")
		out.append(_entry("steady_aim", tab, "Steady Aim", "Advantage, Speed 0", "bonus", sw, "none"))
	if CombatFeatures.has_feature(c, "sneak_attack"):
		var dice: Variant = ch.class_column("rogue", "sneak_attack")
		var ready := e.features.sneak_attack_ready(c)
		var sa := _entry("sneak_attack_info", PASSIVES, "Sneak Attack", "%s · %s" % [dice, "ready" if ready else "used this turn"], "free", "Applies on its own when it can", "none")
		out.append(sa)
	if CombatFeatures.has_feature(c, "channel_divinity"):
		var cw := e._action_check(c)
		if cw == "" and ch.resource_left("channel_divinity") <= 0:
			cw = "No Channel Divinity left"
		var n := ch.resource_left("channel_divinity")
		var heal := _entry("divine_spark_heal", tab, "Divine Spark: Heal", "%d left · 1d8+%d" % [n, ch.ability_mod(&"wis")], "action", cw, "ally")
		heal["range"] = 30
		out.append(heal)
		var harm := _entry("divine_spark_harm", tab, "Divine Spark: Harm", "Con DC %d · radiant" % e.features._cleric_dc(c), "action", cw, "enemy")
		harm["range"] = 30
		out.append(harm)
		var tw := cw
		if tw == "":
			var any := false
			for h in e.hostiles_of(c):
				if str(h.creature.creature_type) == "undead" and e.distance(c, h) <= 30:
					any = true
			tw = "" if any else "No Undead within 30 ft"
		out.append(_entry("turn_undead", tab, "Turn Undead", "Wis DC %d · 30 ft" % e.features._cleric_dc(c), "action", tw, "none"))
		if CombatFeatures.has_feature(c, "preserve_life"):
			var pw := cw
			if pw == "" and e.features.preserve_life_room(c).is_empty():
				pw = "No Bloodied allies within 30 ft"
			out.append(_entry("preserve_life", tab, "Preserve Life", "%d HP to share" % (5 * ch.class_level_of("cleric")), "action", pw, "none"))
	if e.spells.has_spiritual_weapon(c):
		var sww := bwhy
		var swa := _entry("spiritual_weapon_attack", tab, "Spiritual Weapon", "move 20 ft + attack", "bonus", sww, "enemy",
			"The weapon flies up to 20 ft to a creature and strikes it (melee spell attack).")
		out.append(swa)


func _spells(c: Combatant, out: Array[Dictionary]) -> void:
	for s in e.spells.castable(c):
		var data := Compendium.shared().spell_data(str(s["id"]))
		var level := int(s["level"])
		var cost := "bonus" if str(s["casting"]) == "bonus_action" else ("reaction" if str(s["casting"]) == "reaction" else "action")
		var sub := "Cantrip" if level == 0 else "Level %d" % level
		if bool(s["free"]):
			sub += " · free"
		var preview := (c.creature as Character).spell_preview(str(s["id"]), level)
		if preview.has("damage_dice"):
			sub += " · %s" % preview["damage_dice"]
		elif preview.has("heal_dice"):
			sub += " · heal %s" % preview["heal_dice"]
		var a := _entry("spell:" + str(s["id"]), SPELLS, str(s["name"]), sub, cost, str(s["reason"]), _spell_targeting(data),
			str(data.get("summary", "")))
		a["spell_id"] = str(s["id"])
		a["slot"] = level
		a["range"] = e.spells.range_ft(data)
		var t := data.get("targets", {}) as Dictionary
		a["count"] = int(t.get("count", 1))
		a["repeat"] = str(s["id"]) in ["magic_missile", "scorching_ray"]
		a["concentration"] = bool((data.get("duration", {}) as Dictionary).get("concentration", false))
		if str(s["id"]) == "command":
			# One slot per word the engine knows (Approach and Drop: deviations.md).
			for word: String in SpellCaster.COMMAND_WORDS:
				var w := a.duplicate()
				w["id"] = "spell:command:" + word
				w["label"] = "Command: " + word.capitalize()
				w["opts"] = {"word": word}
				out.append(w)
			continue
		out.append(a)


func _spell_targeting(data: Dictionary) -> String:
	if data.has("area"):
		if str((data.get("range", {}) as Dictionary).get("kind", "")) == "self":
			return "none" if str((data["area"] as Dictionary).get("shape", "")) == "emanation" else "direction"
		return "point"
	var t := data.get("targets", {}) as Dictionary
	if str(t.get("kind", "creature")) == "self":
		return "none"
	var tags := data.get("tags", []) as Array
	if int(t.get("count", 1)) > 1 or str(data.get("id", "")) in ["magic_missile", "scorching_ray"]:
		return "multi"
	if "healing" in tags or "buff" in tags or "defense" in tags:
		return "ally"
	if str(data.get("id", "")) == "spare_the_dying":
		return "dying"
	return "creature"


func _items(c: Combatant, out: Array[Dictionary]) -> void:
	if e.has_kit(c):
		var kit := _entry("healers_kit", ITEMS, "Healer's Kit", "stabilize, no check", "action", e._action_check(c), "dying")
		kit["range"] = 5
		out.append(kit)


func _passives(c: Combatant, out: Array[Dictionary]) -> void:
	if not c.creature is Character:
		return
	for f in (c.creature as Character).features:
		if str(f["action"]) != "passive" or str(f["summary"]) == "":
			continue
		var p := _entry("passive:" + str(f["id"]), PASSIVES, str(f["name"]), str(f["source"]), "free", "Always on", "none", str(f["summary"]))
		out.append(p)


# --- Doing it -------------------------------------------------------------------------------------

## Carries out `action` with the chosen targets / point / direction. `slot` upcasts spells (0 = lowest).
func perform(c: Combatant, action: Dictionary, targets: Array = [], point: Vector2 = Vector2.INF,
		dir: Vector2 = Vector2.ZERO, slot: int = 0, opts: Dictionary = {}) -> CombatResult:
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() else null
	var id := str(action["id"])
	match str(action["kind"]):
		"attack":
			return e.attack(c, t, str(action["option_id"]))
		"offhand":
			return e.offhand_attack(c, t, str(action["option_id"]))
		"spell":
			var all_opts := (action.get("opts", {}) as Dictionary).duplicate()
			all_opts.merge(opts, true)
			return e.spells.cast(c, str(action["spell_id"]), slot, targets, point, dir, all_opts)
	match id:
		"grapple":
			return e.unarmed_special(c, t, "grapple")
		"shove_prone":
			return e.unarmed_special(c, t, "shove_prone")
		"shove_push":
			return e.unarmed_special(c, t, "shove")
		"dash":
			return e.dash(c)
		"disengage":
			return e.disengage(c)
		"dodge":
			return e.dodge(c)
		"help":
			return e.help_attack(c, t)
		"hide":
			return e.hide(c)
		"search":
			return e.search(c)
		"study":
			return e.study(c, t)
		"ready":
			return e.ready_attack(c, str(action["option_id"]))
		"stabilize":
			return e.stabilize(c, t, false)
		"healers_kit":
			return e.stabilize(c, t, true)
		"escape":
			return e.escape_grapple(c)
		"stand":
			return e.stand_up(c)
		"drop_prone":
			return e.drop_prone(c)
		"second_wind":
			return e.features.second_wind(c)
		"action_surge":
			return e.features.action_surge(c)
		"cunning_dash":
			return e.dash(c, true)
		"cunning_disengage":
			return e.disengage(c, true)
		"cunning_hide":
			return e.hide(c, true)
		"steady_aim":
			return e.features.steady_aim(c)
		"divine_spark_heal":
			return e.features.divine_spark(c, t, false)
		"divine_spark_harm":
			return e.features.divine_spark(c, t, true, str(opts.get("damage_type", "radiant")))
		"turn_undead":
			return e.features.turn_undead(c)
		"preserve_life":
			return e.features.preserve_life(c)
		"spiritual_weapon_attack":
			if t == null:
				return CombatResult.fail("Choose a target")
			var w := e.spells.spirit_weapons.get(c.id, {}) as Dictionary
			var cell := _weapon_cell(c, t, w.get("cell", c.cell) as Vector2i)
			return e.spells.spiritual_weapon_attack(c, t, cell)
	return CombatResult.fail(str(action.get("reason", "Not available")))


## Where the spiritual weapon goes to strike `t`: the free square beside it nearest the weapon.
func _weapon_cell(_c: Combatant, t: Combatant, from: Vector2i) -> Vector2i:
	var best := from
	var bd := 1 << 30
	for dx in range(-1, t.size_cells + 1):
		for dz in range(-1, t.size_cells + 1):
			var cell := t.cell + Vector2i(dx, dz)
			if cell in t.footprint() or e.grid.is_solid(cell) or e.occupant_at(cell) != null:
				continue
			var d := e.grid.distance_ft(from, 1, cell, 1)
			if d < bd:
				bd = d
				best = cell
	return best


## Whether `t` is a valid target for `action` from where `c` stands: "" or why not.
func target_why(c: Combatant, action: Dictionary, t: Combatant) -> String:
	if t == null:
		return "No creature there"
	var rng := int(action.get("range", 0))
	match str(action["targeting"]):
		"enemy":
			if not c.hostile_to(t):
				return "Choose an enemy"
		"ally":
			if c.hostile_to(t):
				return "Choose an ally"
		"dying":
			if t.creature.hp > 0 or t.creature.dead:
				return "Choose a dying creature"
	if t.creature.dead:
		return "%s is dead" % t.name()
	match str(action["kind"]):
		"attack", "offhand":
			var o := e.option_by_id(c, str(action["option_id"]))
			return e.attack_legal(c, t, o)
	if rng > 0 and t != c and e.distance(c, t) > rng:
		return "Out of range (%d ft, range %d ft)" % [e.distance(c, t), rng]
	if t != c and int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL:
		return "No line of sight"
	return ""


# --- Previews -------------------------------------------------------------------------------------

## The target tooltip for an attack (cb_01): hit chance and the d20 needed, damage with its average, mastery
## effects, every Advantage and Disadvantage source, cover, and what the party knows of the target's defenses.
func attack_preview(c: Combatant, action: Dictionary, t: Combatant) -> Dictionary:
	var lines: Array[String] = []
	var title := t.name()
	if t.creature.is_bloodied():
		title += " · Bloodied"
	var why := target_why(c, action, t)
	var out := {"title": title, "lines": lines, "legal": why == "", "reason": why, "chance": 0.0}
	if str(action["kind"]) not in ["attack", "offhand"]:
		if why != "":
			lines.append(why)
		return out
	var o := e.option_by_id(c, str(action["option_id"]))
	var p := o["profile"] as WeaponProfile
	var hc := e.hit_chance(c, t, o)
	out["chance"] = float(hc["chance"])
	lines.append("%s: hit %d%% (needs %d+ on the d20)" % [p.name, roundi(float(hc["chance"]) * 100.0), int(hc["needs"])])
	var bonus := p.damage_bonus.total() if str(action["kind"]) == "attack" else mini(0, p.damage_bonus.total())
	lines.append("Damage %s%s %s (avg %.0f)%s" % [p.damage_dice, ("%+d" % bonus) if bonus != 0 else "", str(p.damage_type).capitalize(),
		p.average_damage() - (p.damage_bonus.total() - bonus), (" · %s" % p.mastery.capitalize()) if p.mastery != "" else ""])
	if p.mastery == "graze":
		lines.append("Graze: %d damage even on a miss" % maxi(0, c.creature.ability_mod(p.ability)))
	var sit := hc["situation"] as Dictionary
	var adv := sit["advantage"] as Array
	var dis := sit["disadvantage"] as Array
	if adv.is_empty() and dis.is_empty():
		lines.append("No Advantage or Disadvantage")
	for s: Variant in adv:
		lines.append("Advantage: %s" % s)
	for s: Variant in dis:
		lines.append("Disadvantage: %s" % s)
	if int(sit["cover"]) > 0:
		lines.append("%s (+%d AC) from %s" % [CombatGrid.COVER_NAMES[int(sit["cover"])], int(sit["cover_bonus"]), sit["cover_by"]])
	lines.append("AC %d%s" % [int(hc["ac"]), _known_defenses(t)])
	if e.features.sneak_attack_ready(c) and ("finesse" in p.properties or not p.melee):
		lines.append("Sneak Attack if you hit with Advantage or an ally beside it")
	if why != "":
		lines.append("Can't: " + why)
	return out


func _known_defenses(t: Combatant) -> String:
	if not t.creature is Monster:
		return ""
	var m := t.creature as Monster
	if not e.studied.has(str(m.data.get("id", ""))):
		return " · defenses unknown (Study to learn)"
	var parts: Array[String] = []
	for k: String in ["resistances", "immunities", "vulnerabilities"]:
		var v := m.data.get(k, []) as Array
		if not v.is_empty():
			parts.append("%s: %s" % [k.capitalize(), ", ".join(v)])
	return " · " + ("; ".join(parts) if not parts.is_empty() else "no resistances")


## The area a spell would cover and who's in it (cb_02): {cells, creatures: [{id, name, ally, line}], warnings}.
func spell_preview(c: Combatant, action: Dictionary, point: Vector2, dir: Vector2, slot: int = 0) -> Dictionary:
	var data := Compendium.shared().spell_data(str(action["spell_id"]))
	var cells: Array[Vector2i] = []
	if data.has("area"):
		cells = e.spells.area_for(c, data, point, dir)
	var who: Array[Dictionary] = []
	var warnings: Array[String] = []
	var level := int(data.get("level", 0))
	var use_slot := level if slot <= 0 else maxi(slot, level)
	var ch := c.creature as Character
	var preview := ch.spell_preview(str(action["spell_id"]), use_slot)
	var dc := 0
	if preview.has("save_dc"):
		dc = (preview["save_dc"] as Breakdown).total()
	else:
		var entry := e.spells._entry_any(c, str(action["spell_id"]))
		dc = (e.spells.numbers(c, entry)["dc"] as Breakdown).total() if not entry.is_empty() else 0
	for o in e.spells.creatures_in(cells):
		if o == c and str((data.get("range", {}) as Dictionary).get("kind", "")) == "self":
			continue
		var line := o.name()
		var unaffected := str(action["spell_id"]) == "sleep" and (o.creature.is_condition_immune(&"exhaustion") or o.creature.has_flag("trance"))
		if unaffected:
			line += ": unaffected (doesn't sleep)"
		elif data.has("save"):
			var ab := StringName(str(data["save"]))
			var bonus := o.creature.save_bonus(ab).total()
			var fail := clampf((dc - bonus - 1) / 20.0, 0.0, 1.0)
			line += ": %s save DC %d, fails %d%%" % [Creature.ABILITY_SHORT[ab], dc, roundi(fail * 100.0)]
			if preview.has("damage_dice"):
				var avg := _avg(str(preview["damage_dice"])) + (preview["damage_bonus"] as Breakdown).total()
				var half := str(data.get("save_success", "")) == "half"
				var expected := avg * (fail + (0.5 * (1.0 - fail) if half else 0.0))
				line += " · ~%d damage" % roundi(expected)
				if avg >= o.creature.hp:
					line += " · likely drops" if fail > 0.5 else " · may drop"
		var ally := not c.hostile_to(o)
		if ally and o != c:
			warnings.append("Friendly fire: %s is in the area" % o.name())
		who.append({"id": o.id, "name": o.name(), "ally": ally, "line": line})
	if bool(action.get("concentration", false)) and c.creature.concentration != null:
		warnings.append("Ends your Concentration on %s" % c.creature.concentration.name)
	return {"cells": cells, "creatures": who, "warnings": warnings, "dc": dc, "slot": use_slot}


static func _avg(expr: String) -> float:
	var p := DiceRoller.parse_expr(expr)
	return int(p["count"]) * (int(p["sides"]) + 1) / 2.0 + int(p["modifier"])


## Slot levels `c` could cast `spell_id` with (the lowest first), for the upcast pips.
func slot_choices(c: Combatant, spell_id: String) -> Array[int]:
	var out: Array[int] = []
	var data := Compendium.shared().spell_data(spell_id)
	var level := int(data.get("level", 0))
	if level == 0 or not c.creature is Character:
		return out
	for l in range(level, 10):
		if (c.creature as Character).slots_left(l) > 0:
			out.append(l)
	return out


## Squares `c` could move to this turn, as move() would take them (a Prone creature with the movement for it stands
## up first): {cell: {cost, prev, occupied}} with costs including standing up.
func move_reach(c: Combatant) -> Dictionary:
	if c.creature.has_condition(&"prone") and c.speed() > 0 and c.movement_left >= c.speed() / 2:
		var stand := c.speed() / 2
		var r := e.reachable_for(c, c.movement_left - stand, true)
		for cell: Vector2i in r:
			(r[cell] as Dictionary)["cost"] = int((r[cell] as Dictionary)["cost"]) + stand
		return r
	return e.reachable_for(c)


## Moving to `cell` (cb_01): {ok, cost, left, path, warnings, reason}. `reach` is move_reach(c), cached by the HUD.
func move_preview(c: Combatant, cell: Vector2i, reach: Dictionary = {}) -> Dictionary:
	var r := reach if not reach.is_empty() else move_reach(c)
	var path: Array[Vector2i] = []
	var out := {"ok": false, "cost": 0, "left": c.movement_left, "path": path, "warnings": [] as Array[String], "reason": ""}
	if c.speed() <= 0:
		out["reason"] = "Speed 0"
		return out
	if not r.has(cell) or cell == c.cell:
		out["reason"] = "Out of reach (%d ft left)" % c.movement_left
		return out
	var info := r[cell] as Dictionary
	if bool(info["occupied"]):
		out["reason"] = "Occupied"
		return out
	path = CombatGrid.path_to(r, cell)
	var cost := int(info["cost"])
	if c.creature.has_condition(&"prone") and c.movement_left < c.speed() / 2:
		cost *= 2
	out["ok"] = true
	out["cost"] = cost
	out["left"] = c.movement_left - cost
	out["path"] = path
	var warnings: Array[String] = []
	if c.creature.has_condition(&"prone"):
		warnings.append("Stands up first (%d ft)" % (c.speed() / 2) if c.movement_left >= c.speed() / 2 else "Crawling while Prone costs double")
	if not c.disengaged:
		var seen := {}
		for i in range(1, path.size()):
			for p in e._provokers(c, path[i - 1], path[i]):
				if not seen.has(p.id):
					seen[p.id] = true
					warnings.append("Leaves %s's reach: Opportunity Attack" % p.name())
	for cc in path:
		if e.grid.has_flag(cc, CombatGrid.DIFFICULT):
			warnings.append("Difficult Terrain costs double")
			break
	out["warnings"] = warnings
	return out
