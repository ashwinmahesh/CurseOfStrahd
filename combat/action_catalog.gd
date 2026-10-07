class_name ActionCatalog
extends RefCounted
## The hotbar (combat view spec, cb_01): every option a creature has this turn, with what it costs, whether it can
## be used now and why not, how it's aimed, and the numbers to show. The HUD lists these and calls perform(); it
## never computes rules itself. Previews (hit chances, area templates, movement paths) come from here too.
##
## An action: {id, tab, label, sub, cost: action|attack|bonus|reaction|free|movement, legal, reason, targeting,
##   count, repeat, range, spell_id, slot, option_id, kind, help}
## targeting: none (at once), enemy, ally, creature, dying (a creature at 0 HP), multi (up to `count` creatures,
##   repeats allowed when `repeat`), point (a grid point in range), direction (aimed from the caster), wall (squares
##   drawn one at a time, sent as opts.path: SpellTargeting).

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
	_sustained(c, out)
	_items(c, out)
	_quick(c, out)
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
	out.append(_entry("dash", COMMON, "Dash", "+%d ft" % c.speed(), "action", why if why != "" else ("Cannot Dash while affected" if c.creature.has_flag("cannot_dash") else ""), "none", "Gain extra movement equal to your Speed."))
	out.append(_entry("disengage", COMMON, "Disengage", "no Opp. Attacks", "action", why if why != "" else ("Hunter’s Rime prevents Disengage" if not e.can_disengage(c) else ""), "none", "Your movement doesn't provoke Opportunity Attacks this turn."))
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


## FeatureActions' entries as hotbar actions.
func _feature_entries(c: Combatant, out: Array[Dictionary], tab: String) -> void:
	for fa in e.feature_actions.list(c):
		var en := _entry(str(fa["id"]), tab, str(fa["label"]), str(fa["sub"]), str(fa["cost"]), str(fa["why"]), str(fa["targeting"]), str(fa["help"]))
		en["kind"] = "feat"
		en["range"] = int(fa["range"])
		# Some features take a choice from the right-click menu (Lay On Hands: how many points).
		if fa.has("choices"):
			en["choices"] = fa["choices"]
			en["choice_label"] = str(fa.get("choice_label", "Choose"))
		en["count"] = int(fa.get("count", 1))
		# Aimed from an Echo Knight's echo ("from": that echo; "from_echo": whichever echo reaches).
		for k: String in ["from", "from_echo"]:
			if fa.has(k):
				en[k] = fa[k]
		out.append(en)


func _class_actions(c: Combatant, out: Array[Dictionary]) -> void:
	if not c.creature is Character:
		# A shaped character or a summoned creature the player runs: its own actions, leaving Wild Shape, ending Fluid Shape.
		_feature_entries(c, out, class_tab(c))
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
	_effect_actions(c, out, tab)
	_feature_entries(c, out, tab)
	for ro in e.features.rider_options(c):
		var armed := str(ro["id"]) in c.armed
		var rw := e._turn_check(c)
		if rw == "" and not armed:
			rw = str(ro["why"])
		var re := _entry("rider:" + str(ro["id"]), tab, ("✓ " if armed else "") + str(ro["label"]), ("armed · " if armed else "") + str(ro["sub"]), "free", rw, "none",
			"Arm it for your next hit this turn (click again to disarm). %s" % ro["sub"])
		re["kind"] = "rider"
		out.append(re)
	# War Magic (Eldritch Knight 7): a cantrip in place of one attack of the Attack action.
	if (CombatFeatures.has_feature(c, "war_magic") or not e.triggered_features.recipes(c, "attack_cantrip").is_empty()) and (c.attacks_left > 0 or c.action_available):
		for sp in e.spells.castable(c):
			if int(sp["level"]) == 0 and str(sp["casting"]) == "action":
				var data := Compendium.shared().spell_data(str(sp["id"]))
				if not e.spells.has_combat_rules(data) or not e.triggered_features.cantrip_attack(c, data, sp):
					continue
				var wm := _entry("war_magic:" + str(sp["id"]), tab, "Cantrip attack: %s" % sp["name"], "replaces an attack", "attack", e.features_attack_why(c), _spell_targeting(data),
					"Cast this cantrip in place of one of your attacks.")
				wm["kind"] = "spell"
				wm["spell_id"] = str(sp["id"])
				wm["range"] = e.spells.range_ft(data, c)
				wm["opts"] = {"war_magic": true}
				out.append(wm)


## Actions that come from effects on the creature: breaking free of Web or Entangle, shaking a sleeping ally
## awake, and Haste's extra action.
func _effect_actions(c: Combatant, out: Array[Dictionary], tab: String) -> void:
	var why := e._action_check(c)
	for fx: Effect in c.creature.effects:
		if not fx.escape.is_empty():
			var esc := _entry("escape_effect:%d" % fx.id, COMMON, "Break free: %s" % fx.name, "%s DC %d" % [str(fx.escape["skill"]).capitalize(), int(fx.escape["dc"])],
				"action", why, "none", "An ability check against the spell's save DC ends it on you.")
			out.append(esc)
	if c.creature.effects.any(func(fx: Effect) -> bool: return bool(fx.data.get("douse", false))):
		out.append(_entry("douse", COMMON, "Put out the flames", "drop Prone and roll", "action", why, "none",
			"Use your action to fall Prone and roll on the ground, ending the Burning on you."))
	var sleepers := false
	for a in e.allies_of(c):
		if e.distance(c, a) <= 5 and e.sleeper(a) != null:
			sleepers = true
	if sleepers:
		var w := _entry("wake", COMMON, "Wake", "shake an ally", "action", why, "ally", "Use your action to shake a magically sleeping or entranced creature within 5 ft awake.")
		w["range"] = 5
		out.append(w)
	if c.creature.has_flag("jump"):
		var jw := e._turn_check(c)
		if jw == "" and int(c.get_meta("jumped_round", -1)) == e.round_no:
			jw = "Already jumped this turn"
		elif jw == "" and c.movement_left < 10:
			jw = "Needs 10 ft of movement"
		var j := _entry("jump", COMMON, "Jump", "30 ft for 10 ft", "movement", jw, "point", "Leap up to 30 ft over creatures and rough ground (Jump spell), once a turn.")
		j["range"] = 30
		out.append(j)
	if c.haste_action and c.creature.has_flag("hasted"):
		var hw := e._turn_check(c)
		if hw == "" and not c.can_act():
			hw = "Can't act"
		out.append(_entry("haste:dash", tab, "Haste: Dash", "extra action", "free", hw, "none", "Haste's extra action: Dash."))
		out.append(_entry("haste:disengage", tab, "Haste: Disengage", "extra action", "free", hw, "none", "Haste's extra action: Disengage."))
		out.append(_entry("haste:hide", tab, "Haste: Hide", "extra action", "free", hw if hw != "" else e.hide_blocker(c), "none", "Haste's extra action: Hide."))
		var best := e.best_melee_option(c, null)
		for o in e.attack_options(c):
			if str(o["kind"]) == "unarmed":
				continue
			var ha := _entry("haste:attack:" + str(o["id"]), tab, "Haste: %s" % (o["profile"] as WeaponProfile).name, "one attack", "free", hw, "enemy",
				"Haste's extra action: one weapon attack.")
			ha["option_id"] = str(o["id"])
			var p := o["profile"] as WeaponProfile
			ha["range"] = p.reach if bool(o["melee"]) else (p.long_range if p.long_range > 0 else p.normal_range)
			out.append(ha)
		if best.is_empty():
			pass


## Actions a spell keeps granting while it lasts (Spiritual Weapon's strike, Witch Bolt's arc, Flaming Sphere's
## roll, Dragon's Breath, Produce Flame's hurl...).
func _sustained(c: Combatant, out: Array[Dictionary]) -> void:
	var tab := SPELLS if c.creature is Character and not (c.creature as Character).spellcasting.is_empty() else class_tab(c)
	for a in e.spells.sustained_actions(c):
		var d := a["def"] as Dictionary
		var targeting := "none"
		match str(a["do"]):
			"attack":
				targeting = "multi" if int(d.get("attacks", 1)) > 1 else "enemy"
			"area", "aim":
				targeting = "direction"
			"move_object":
				targeting = "point"
			"move_mark":
				targeting = "enemy"
			"heal_one":
				targeting = "ally"
			"faerun":
				targeting = str(d.get("targeting", "creature"))
		var cost := "bonus" if str(a["cost"]) == "bonus_action" else ("free" if str(a["cost"]) == "free" else "action")
		var entry := _entry("sustain:" + str(a["id"]), tab, str(a["label"]), str(d.get("sub", "")), cost, str(a["reason"]), targeting,
			str(d.get("help", "")))
		entry["kind"] = "sustain"
		entry["sustain_id"] = str(a["id"])
		entry["count"] = int(d.get("attacks", 1))
		entry["repeat"] = int(d.get("attacks", 1)) > 1
		entry["range"] = int(d.get("range", int(d.get("move", 0)) + int(d.get("reach", 0))))
		entry["spell_id"] = str(a["spell_id"])
		out.append(entry)


func _spells(c: Combatant, out: Array[Dictionary]) -> void:
	for s in e.spells.castable(c):
		var data := Compendium.shared().spell_data(str(s["id"]))
		var level := int(s["level"])
		var cost := "bonus" if str(s["casting"]) == "bonus_action" else ("reaction" if str(s["casting"]) == "reaction" else "action")
		var sub := "Cantrip" if level == 0 else "Level %d" % level
		if bool(s["free"]):
			sub += " · free"
		# A shape that keeps its spellcasting (Shapechange, Boon of Fluid Forms) previews with the caster's own sheet.
		var preview := e.spells.caster_char(c).spell_preview(str(s["id"]), level)
		if preview.has("damage_dice"):
			sub += " · %s" % preview["damage_dice"]
		elif preview.has("heal_dice"):
			sub += " · heal %s" % preview["heal_dice"]
		var a := _entry("spell:" + str(s["id"]), SPELLS, str(s["name"]), sub, cost, str(s["reason"]), _spell_targeting(data),
			str(data.get("summary", "")))
		# A smite (Divine Smite, Searing Smite...) is cast right after a hit: choosing it arms it for your next hit,
		# and nothing (no slot, no free casting) is spent until an attack lands.
		if bool(data.get("on_hit_spell", false)):
			a["targeting"] = "none"
			a["sub"] = sub + " · arms your next hit"
			a["help"] = "Arms it: it's cast on your next hit with a weapon, spending its slot (or free use) only then. Choose it again to disarm."
		a["spell_id"] = str(s["id"])
		a["slot"] = level
		a["range"] = e.spells.range_ft(data)
		var t := data.get("targets", {}) as Dictionary
		a["count"] = int(t.get("count", 1))
		a["repeat"] = str(s["id"]) in ["magic_missile", "scorching_ray"] or bool(data.get("repeat_targets", false))
		a["concentration"] = bool((data.get("duration", {}) as Dictionary).get("concentration", false))
		if c.creature is Character:
			var mm: Array = []
			for m: String in SpellCaster.metamagic_known(c.creature as Character):
				if e.spells._metamagic_check(c, data, [m]) == "":
					mm.append({"id": m, "label": "%s Spell (%d SP)" % [m.capitalize(), int(SpellCaster.METAMAGIC_COST[m])]})
			for opt: String in e.spells.class_cast_options(c, data):
				mm.append({"id": opt, "label": "Psychic Spells: Psychic damage" if opt == "psychic_spells" else "Psionic Sorcery (%d SP, no slot)" % int(data.get("level", 0))})
			if not mm.is_empty():
				a["metamagic"] = mm
		var choice := data.get("choice", {}) as Dictionary
		if not choice.is_empty() and str(s["id"]) != "command":
			var opts_list: Array = []
			for v: Variant in choice.get("from", []):
				opts_list.append({"value": str(v), "label": str(v).replace("_", " ").capitalize()})
			a["choices"] = opts_list
			a["choice_label"] = str(choice.get("label", "Choose"))
			a["opts"] = {"choice": str((opts_list[0] as Dictionary)["value"])}
			a["sub"] = str(a["sub"]) + " · " + str((opts_list[0] as Dictionary)["label"])
		# Pact of the Chain: the familiar's form.
		if str(s["id"]) == "find_familiar" and ClassFeatures.knows_invocation(c, "pact_of_the_chain"):
			var ff: Array = []
			for f: String in SummonBlocks.CHAIN_FORMS:
				ff.append({"value": f, "label": f.replace("_", " ").capitalize()})
			a["choices"] = ff
			a["choice_label"] = "Familiar"
			a["opts"] = {"choice": "imp"}
		elif str(s["id"]) == "find_familiar" and CombatFeatures.has_feature(c, "necromancy_familiar"):
			a["choices"] = [{"value": "skeleton", "label": "Skeleton"}, {"value": "zombie", "label": "Zombie"}, {"value": "owl", "label": "Undead owl"}]
			a["choice_label"] = "Familiar"
			a["opts"] = {"choice": "skeleton"}
		# Polymorph and the higher shape spells: the form (it must not out-rank its limit; "Best fit" picks for you).
		if str(s["id"]) in ["polymorph", "true_polymorph", "shapechange", "animal_shapes"]:
			var forms: Array = [{"value": "", "label": "Best fit"}]
			var pool: Array[Dictionary] = ShapeChange.beast_forms(30.0) if str(s["id"]) == "polymorph" else (HighMagic.forms(4.0, ["beast"]) if str(s["id"]) == "animal_shapes" else HighMagic.forms(30.0))
			for f in pool:
				forms.append({"value": str(f["id"]), "label": "%s (CR %s)" % [f.get("name", ""), str(f.get("cr", 0))]})
			a["choices"] = forms
			a["choice_label"] = "Beast form"
			a["opts"] = {"choice": ""}
		for feature in e.spells.caster_char(c).resource_casts(str(s["id"])):
			var paid := a.duplicate(true)
			var cast_entry := e.spells.resource_cast_entry(c, data, str(feature["id"]))
			paid["id"] = str(a["id"]) + ":" + str(feature["id"])
			paid["label"] = str(feature["name"]) + " · " + str(a["label"])
			paid["cost"] = "bonus" if str((feature["resource_cast"] as Dictionary).get("casting", "action")) == "bonus_action" else "action"
			paid["reason"] = str(cast_entry["reason"])
			paid["legal"] = bool(cast_entry["legal"])
			paid["opts"] = (a.get("opts", {}) as Dictionary).duplicate()
			(paid["opts"] as Dictionary)["resource_cast"] = str(feature["id"])
			paid.erase("metamagic")
			out.append(paid)
		for feature in e.triggered_features.spell_sequences(c, data, s):
			var sequence := a.duplicate(true)
			sequence["id"] = str(a["id"]) + ":" + str(feature["id"])
			sequence["label"] = str(feature["name"]) + " · " + str(a["label"])
			sequence["cost"] = "bonus"
			sequence["reason"] = e.triggered_features.sequence_why(c, data, s, feature)
			sequence["legal"] = str(sequence["reason"]) == ""
			sequence["opts"] = (a.get("opts", {}) as Dictionary).duplicate()
			(sequence["opts"] as Dictionary)["spell_sequence"] = str(feature["id"])
			out.append(sequence)
		for feature in e.triggered_features.casting_forms(c, data):
			var form := a.duplicate(true)
			form["id"] = str(a["id"]) + ":" + str(feature["id"])
			form["label"] = str(a["label"]) + " · " + str(feature["name"])
			form["opts"] = (a.get("opts", {}) as Dictionary).duplicate()
			(form["opts"] as Dictionary)["cast_form"] = str(feature["id"])
			out.append(form)
		for feature in e.triggered_features.casting_boosts(c, data):
			var boosted := a.duplicate(true)
			boosted["id"] = str(a["id"]) + ":" + str(feature["id"])
			boosted["label"] = str(a["label"]) + " · " + str(feature["name"])
			boosted["opts"] = (a.get("opts", {}) as Dictionary).duplicate()
			(boosted["opts"] as Dictionary)["slot_boost"] = str(feature["id"])
			if int((data.get("upcast", {}) as Dictionary).get("targets", 0)) > 0:
				boosted["targeting"] = "multi"
			out.append(boosted)
		if e.spells.can_splinter(c, data):
			var split := a.duplicate(true)
			split["id"] = str(a["id"]) + ":splintered"
			split["label"] = str(a["label"]) + " · two spirits"
			split["targeting"] = "points"
			split["count"] = 2
			var split_opts := (split.get("opts", {}) as Dictionary).duplicate()
			split_opts["splintered"] = true
			split["opts"] = split_opts
			out.append(split)
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
	return spell_targeting(data)


## How the hotbar targets a spell: none, direction, point, wall, place, enemy, ally, dying, dead, multi or creature.
static func spell_targeting(data: Dictionary) -> String:
	if data.has("area"):
		if str((data.get("range", {}) as Dictionary).get("kind", "")) == "self":
			return "none" if str((data["area"] as Dictionary).get("shape", "")) == "emanation" else "direction"
		# A wall drawn square by square (its ring, globe or dome choice is placed at a point instead).
		return "wall" if SpellTargeting.drawn_wall(data) else "point"
	var t := data.get("targets", {}) as Dictionary
	if str(data.get("id", "")) in ["misty_step", "dimension_door"]:
		return "place"
	if str(t.get("kind", "creature")) == "self":
		return "none"
	if str(t.get("kind", "")) == "enemy":
		return "enemy"
	if str(t.get("kind", "")) == "ally" and int(t.get("count", 1)) <= 1 and int((data.get("upcast", {}) as Dictionary).get("targets", 0)) == 0:
		return "ally"
	if str(data.get("id", "")) == "spare_the_dying":
		return "dying"
	var tags := data.get("tags", []) as Array
	if bool((data.get("object", {}) as Dictionary).get("pick_attack_targets", false)):
		return "multi"
	if data.has("object") or str(data.get("id", "")) in ["misty_step", "dimension_door"] or str(data.get("id", "")) in SpellCaster.SUMMON_SPELLS:
		return "place"
	if str(data.get("id", "")) == "revivify":
		return "dead"
	if str(t.get("count", "")) == "any" or int(t.get("count", 1)) > 1 or int((data.get("upcast", {}) as Dictionary).get("targets", 0)) > 0 \
			or str(data.get("id", "")) in ["magic_missile", "scorching_ray", "eldritch_blast"]:
		return "multi"
	if "healing" in tags or "buff" in tags or "defense" in tags or "restoration" in tags:
		return "ally"
	if str(data.get("id", "")) == "spare_the_dying":
		return "dying"
	return "creature"


func _items(c: Combatant, out: Array[Dictionary]) -> void:
	# Potions, scrolls, oils and every magic item power (combat/combat_items.gd).
	out.append_array(e.items.list(c))
	# Goodberries and other heal-only consumables that aren't potions: a Bonus Action to eat one or give it away.
	if c.creature is Character:
		var seen := {}
		for entry in (c.creature as Character).inventory:
			var iid := str(entry["id"])
			if seen.has(iid) or int(entry["qty"]) <= 0:
				continue
			var item := Compendium.shared().item_data(iid)
			if str(item.get("category", "")) == "potion":
				continue
			var heal := {}
			for fx: Variant in item.get("effects", []):
				if str((fx as Dictionary).get("effect", "")) == "heal":
					heal = (fx as Dictionary).get("params", {}) as Dictionary
			if heal.is_empty():
				continue
			seen[iid] = true
			var amount := str(heal.get("dice", str(heal.get("flat", 1))))
			var it := _entry("item:" + iid, ITEMS, str(item.get("name", iid)), "%d left · heal %s" % [e.item_count(c, iid), amount], "bonus",
				e._bonus_check(c), "ally", str(item.get("summary", "")))
			it["range"] = 5
			it["kind"] = "consumable"
			out.append(it)
	if e.has_kit(c):
		var kit := _entry("healers_kit", ITEMS, "Healer's Kit", "stabilize, no check", "action", e._action_check(c), "dying")
		kit["range"] = 5
		out.append(kit)


## Quick slots (plan §5.6, the inventory's paper doll): the consumables a character keeps to hand are on the Common tab
## too.
func _quick(c: Combatant, out: Array[Dictionary]) -> void:
	if not c.creature is Character or (c.creature as Character).quick_slots.is_empty():
		return
	var quick := (c.creature as Character).quick_slots
	for a: Dictionary in out.duplicate():
		var iid := str(a.get("item_id", str(a["id"]).get_slice(":", 1) if str(a["id"]).begins_with("item:") else ""))
		if str(a["tab"]) == ITEMS and iid in quick:
			var q: Dictionary = a.duplicate()
			q["tab"] = COMMON
			out.append(q)


func _passives(c: Combatant, out: Array[Dictionary]) -> void:
	if not c.creature is Character:
		return
	for f in (c.creature as Character).features:
		if str(f["action"]) != "passive" or str(f["summary"]) == "":
			continue
		var p := _entry("passive:" + str(f["id"]), PASSIVES, str(f["name"]), str(f["source"]), "free", "Always on", "none", str(f["summary"]))
		out.append(p)


# --- Full details (right-click → Info) -------------------------------------------------------------

## Weapon properties and mastery properties in our own words (2024 PHB "Equipment").
const PROPERTY_TEXT := {
	"ammunition": "Needs ammunition, used up with each attack.",
	"finesse": "Use Strength or Dexterity for the attack and damage, whichever is higher.",
	"heavy": "Disadvantage on attacks if your Strength (melee) or Dexterity (ranged) is under 13.",
	"light": "After attacking with it in the Attack action, you can attack with a different Light weapon as a Bonus Action (no ability modifier to that damage unless negative).",
	"loading": "Only one shot per action, Bonus Action or Reaction, whatever your number of attacks.",
	"range": "Two ranges: normal, and long (with Disadvantage). Can't attack beyond the long range.",
	"reach": "Adds 5 ft to your reach for attacks and Opportunity Attacks.",
	"thrown": "Can be thrown for a ranged attack with the same ability as a melee attack; it leaves your hand.",
	"two_handed": "Needs two hands to attack with.",
	"versatile": "Can be used with two hands for the larger damage die.",
}
const MASTERY_TEXT := {
	"cleave": "On a melee hit, make one extra attack against a second creature within 5 ft of the first (once per turn; no ability modifier to its damage).",
	"graze": "On a miss, the target still takes damage equal to your ability modifier.",
	"nick": "The Light extra attack is part of the Attack action instead of a Bonus Action (once per turn).",
	"push": "On a hit, push a Large or smaller target 10 ft straight away from you.",
	"sap": "On a hit, the target has Disadvantage on its next attack roll before your next turn.",
	"slow": "On a hit that deals damage, the target's Speed drops by 10 ft until the start of your next turn.",
	"topple": "On a hit, the target makes a Constitution save (8 + ability modifier + Proficiency) or falls Prone.",
	"vex": "On a hit that deals damage, you have Advantage on your next attack against that target before the end of your next turn.",
}
## The standard actions in our own words (2024 PHB "Actions").
const ACTION_TEXT := {
	"dash": "For the rest of the turn, gain extra movement equal to your Speed.",
	"disengage": "Your movement doesn't provoke Opportunity Attacks for the rest of the turn.",
	"dodge": "Until the start of your next turn, attack rolls against you have Disadvantage if you can see the attacker, and you have Advantage on Dexterity saves. Lost if you're Incapacitated or your Speed is 0.",
	"help": "Distract an enemy within 5 ft: the next attack roll one of your allies makes against it before your next turn has Advantage.",
	"hide": "A DC 15 Dexterity (Stealth) check while out of every enemy's sight (Three-Quarters or Total Cover). On a success you're Invisible until you attack, cast a spell aloud, or an enemy finds you.",
	"search": "A Wisdom (Perception) check to find hidden creatures; it beats their Stealth total to find them.",
	"study": "An Intelligence check (Arcana, History, Nature or Religion by the creature's type) to recall what a creature is: its defenses and traits.",
	"ready": "Hold an attack: when an enemy you can see comes within reach, you make it with your Reaction. Lasts until the start of your next turn. To ready a spell, right-click it on the Spells tab: it's cast now (spending the slot) and held with Concentration until it's released.",
	"stabilize": "Help a dying creature within 5 ft: a DC 10 Wisdom (Medicine) check makes it Stable.",
	"healers_kit": "Spend one use of the kit to make a dying creature within 5 ft Stable, no check needed.",
	"grapple": "One of your attacks: the target (no more than one size larger) makes a Strength or Dexterity save against 8 + Str + Proficiency or is Grappled (Speed 0).",
	"shove_prone": "One of your attacks: the target makes a Strength or Dexterity save or falls Prone.",
	"shove_push": "One of your attacks: the target makes a Strength or Dexterity save or is pushed 5 ft away.",
	"escape": "A Strength (Athletics) or Dexterity (Acrobatics) check against the grapple's DC to break free.",
	"douse": "Drop Prone and roll on the ground to put out the flames burning you.",
	"stand": "Standing up costs half your Speed.",
	"drop_prone": "Drop Prone for free: ranged attacks against you have Disadvantage, melee attacks from within 5 ft have Advantage.",
	"influence": "Try to change a creature's attitude with words. Nothing here will listen.",
	"utilize": "Use an object, such as a lever or a potion.",
}


## Everything about a hotbar entry for the Info panel: {title, lines}.
func details(c: Combatant, action: Dictionary) -> Dictionary:
	var kind := str(action["kind"])
	if kind in ["attack", "offhand"]:
		return _weapon_details(c, action)
	if kind == "spell":
		return _spell_details(c, action)
	if kind in ["item", "item_spell"]:
		return _item_details(c, action)
	var lines: Array[String] = []
	var id := str(action["id"])
	var feature := _feature_for(c, id)
	var cost := str(action["cost"])
	lines.append("Costs: %s" % _cost_text(cost))
	if not feature.is_empty():
		lines.append("From: %s" % feature.get("source", ""))
		if str(feature.get("summary", "")) != "":
			lines.append(str(feature["summary"]))
		if str(feature.get("text", "")) != "":
			lines.append(str(feature["text"]))
	elif ACTION_TEXT.has(id):
		lines.append(str(ACTION_TEXT[id]))
	elif str(action.get("help", "")) != "":
		lines.append(str(action["help"]))
	if str(action["sub"]) != "":
		lines.append("Now: %s" % action["sub"])
	if not bool(action["legal"]):
		lines.append("Can't use it now: %s" % action["reason"])
	return {"title": str(action["label"]), "lines": lines}


## A magic item power: what it costs, what it does, the item's charges and its own text.
func _item_details(c: Combatant, action: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	var data := Compendium.shared().item_data(str(action.get("item_id", "")))
	lines.append("Costs: %s" % _cost_text(str(action["cost"])))
	lines.append("From: %s" % data.get("name", ""))
	if str(action.get("help", "")) != "":
		lines.append(str(action["help"]))
	if str(action["sub"]) != "":
		lines.append("Now: %s" % action["sub"])
	if action.has("dc"):
		lines.append("Save DC %d · Attack %+d" % [int(action["dc"]), int(action.get("attack_bonus", 0))])
	if str(data.get("text", "")) != "":
		lines.append(str(data["text"]))
	if not bool(action["legal"]):
		lines.append("Can't use it now: %s" % action["reason"])
	if str(action.get("kind", "")) == "item_spell":
		var sd := _spell_details(c, action)
		for l: Variant in sd["lines"]:
			if not str(l).begins_with("Costs"):
				lines.append(str(l))
	return {"title": str(action["label"]), "lines": lines}


func _cost_text(cost: String) -> String:
	match cost:
		"action":
			return "an Action"
		"attack":
			return "one attack of your Attack action"
		"bonus":
			return "a Bonus Action"
		"reaction":
			return "a Reaction"
		"movement":
			return "movement"
	return "nothing (free)"


## The class or species feature behind a hotbar entry, by id (channel_divinity covers its options).
func _feature_for(c: Combatant, id: String) -> Dictionary:
	if not c.creature is Character:
		return {}
	var want := id.trim_prefix("passive:")
	if want.begins_with("cunning_"):
		want = "cunning_action"
	elif want in ["divine_spark_heal", "divine_spark_harm", "turn_undead"]:
		want = "channel_divinity"
	elif want == "sneak_attack_info":
		want = "sneak_attack"
	for f in (c.creature as Character).features:
		if str(f["id"]) == want:
			return f
	return {}


func _weapon_details(c: Combatant, action: Dictionary) -> Dictionary:
	var o := e.option_by_id(c, str(action["option_id"]))
	var lines: Array[String] = []
	if o.is_empty():
		return {"title": str(action["label"]), "lines": lines}
	var p := o["profile"] as WeaponProfile
	var item := Compendium.shared().item_data(p.item_id)
	var w := item.get("weapon", {}) as Dictionary
	if not w.is_empty():
		lines.append("%s weapon" % str(w.get("kind", "")).replace("_", " ").capitalize())
	lines.append("Costs: %s" % _cost_text(str(action["cost"])))
	lines.append("Attack: %s" % p.attack.describe())
	var offhand := str(action["kind"]) == "offhand"
	var bonus := p.damage_bonus.total() if not offhand else mini(0, p.damage_bonus.total())
	lines.append("Damage: %s%s %s, average %.1f" % [p.damage_dice, ("%+d" % bonus) if bonus != 0 else "",
		str(p.damage_type).capitalize(), p.average_damage() - (p.damage_bonus.total() - bonus)])
	if not p.damage_bonus.parts.is_empty():
		lines.append("Damage bonus: %s%s" % [p.damage_bonus.describe(), " (not added: off-hand attack)" if offhand and p.damage_bonus.total() > 0 else ""])
	if p.die_minimum > 0:
		lines.append("Damage dice below %d count as %d (%s)" % [p.die_minimum, p.die_minimum, p.die_minimum_source])
	if bool(o["melee"]):
		lines.append("Reach: %d ft" % p.reach)
	else:
		lines.append("Range: %d ft, long range %d ft (Disadvantage)" % [p.normal_range, p.long_range])
	if p.crit_range < 20:
		lines.append("Critical Hit on a %d-20" % p.crit_range)
	for prop: Variant in p.properties:
		var key := str(prop)
		if PROPERTY_TEXT.has(key):
			var pname := key.replace("_", "-")
			lines.append("%s: %s" % [pname.left(1).to_upper() + pname.substr(1), PROPERTY_TEXT[key]])
	if p.mastery != "":
		lines.append("Mastery, %s: %s" % [p.mastery.capitalize(), MASTERY_TEXT.get(p.mastery, "")])
	elif str(w.get("mastery", "")) != "":
		lines.append("Mastery %s: not one of your weapon masteries" % str(w["mastery"]).capitalize())
	if p.item_id != "unarmed_strike" and c.creature is Character:
		lines.append("Carried: %d" % e.item_count(c, p.item_id))
	for n in p.notes:
		lines.append(n)
	if not bool(action["legal"]):
		lines.append("Can't use it now: %s" % action["reason"])
	return {"title": p.name, "lines": lines}


func _spell_details(c: Combatant, action: Dictionary) -> Dictionary:
	var sid := str(action["spell_id"])
	var data := Compendium.shared().spell_data(sid)
	var lines: Array[String] = []
	var level := int(data.get("level", 0))
	var school := str(data.get("school", "")).capitalize()
	lines.append("%s cantrip" % school if level == 0 else "Level %d %s" % [level, school])
	var ct := str((data.get("casting_time", {}) as Dictionary).get("unit", "action"))
	var rng := data.get("range", {}) as Dictionary
	var range_text := "Self" if str(rng.get("kind", "")) == "self" else ("Touch" if str(rng.get("kind", "")) == "touch" else "%d ft" % int(rng.get("feet", 0)))
	var area := data.get("area", {}) as Dictionary
	if not area.is_empty():
		range_text += " · %d-ft %s" % [int(area["size"]), str(area["shape"]).capitalize()]
	lines.append("Casting time: %s · Range: %s" % [ct.replace("_", " ").capitalize(), range_text])
	var comp := data.get("components", {}) as Dictionary
	var parts: Array[String] = []
	if bool(comp.get("v", false)):
		parts.append("V")
	if bool(comp.get("s", false)):
		parts.append("S")
	if comp.has("m"):
		parts.append("M (%s)" % comp["m"])
	lines.append("Components: %s" % ", ".join(parts))
	var dur := data.get("duration", {}) as Dictionary
	var dur_text := str(dur.get("kind", "instantaneous")).capitalize()
	if dur.has("amount"):
		var unit := str(dur["kind"])
		dur_text = "%d %s" % [int(dur["amount"]), unit.trim_suffix("s") if int(dur["amount"]) == 1 else unit]
	if bool(dur.get("concentration", false)):
		dur_text = "Concentration, up to " + dur_text
	lines.append("Duration: %s" % dur_text)
	var ch := c.creature as Character
	var slot := int(action.get("slot", level))
	var prev := ch.spell_preview(sid, slot)
	if prev.has("save_dc"):
		lines.append("%s saving throw, DC %s" % [Creature.ABILITY_NAMES.get(StringName(str(prev.get("save", ""))), ""), (prev["save_dc"] as Breakdown).describe()])
	if prev.has("attack"):
		lines.append("Spell attack: %s" % (prev["attack"] as Breakdown).describe())
	if prev.has("damage_dice"):
		var db := prev["damage_bonus"] as Breakdown
		lines.append("Damage: %s %s%s" % [prev["damage_dice"], str(prev.get("damage_type", "")).capitalize(), (" · " + db.describe()) if not db.parts.is_empty() else ""])
	if prev.has("heal_dice"):
		lines.append("Healing: %s · %s" % [prev["heal_dice"], (prev["heal_bonus"] as Breakdown).describe()])
	var up := data.get("upcast", {}) as Dictionary
	if not up.is_empty():
		var bits: Array[String] = []
		if up.has("damage"):
			bits.append("+%s damage" % up["damage"])
		if up.has("heal"):
			bits.append("+%s healing" % up["heal"])
		if up.has("targets"):
			bits.append("+%d target" % int(up["targets"]))
		if up.has("projectiles"):
			bits.append("+%d dart or ray" % int(up["projectiles"]))
		if up.has("text"):
			bits.append(str(up["text"]))
		lines.append("At higher levels, per slot level above %d: %s" % [level, "; ".join(bits)])
	for k in ch.known_spells():
		if str(k["id"]) == sid:
			var how := str(k["kind"]).capitalize()
			if str(k["kind"]) == "granted" and ch.resource_left("spell:" + sid) > 0:
				how = "Free casting (%d left, then with a slot)" % ch.resource_left("spell:" + sid)
			lines.append("Known from: %s (%s)" % [k.get("source", ""), how])
			break
	if level > 0:
		lines.append("Your slots: %s" % slots_text(c))
	lines.append(str(data.get("text", data.get("summary", ""))))
	if not bool(action["legal"]):
		lines.append("Can't cast it now: %s" % action["reason"])
	return {"title": str(data.get("name", sid)), "lines": lines}


## Spell slots left by level, e.g. "1st 3/4 · 2nd 2/2" ("" for non-casters).
func slots_text(c: Combatant) -> String:
	if not c.creature is Character:
		return ""
	var ch := c.creature as Character
	var parts: Array[String] = []
	var totals := ch.spell_slots()
	for l in range(1, 10):
		if totals[l - 1] > 0:
			parts.append("%s %d/%d" % [_ordinal(l), ch.slots_left(l), totals[l - 1]])
	return " · ".join(parts)


## Slot pips for the hotbar: [{level, left, total}].
func slot_pips(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.creature is Character:
		return out
	var ch := c.creature as Character
	var totals := ch.spell_slots()
	for l in range(1, 10):
		if totals[l - 1] > 0:
			out.append({"level": l, "left": ch.slots_left(l), "total": totals[l - 1]})
	return out


static func _ordinal(n: int) -> String:
	match n:
		1:
			return "1st"
		2:
			return "2nd"
		3:
			return "3rd"
	return "%dth" % n


# --- Doing it -------------------------------------------------------------------------------------

## Carries out `action` with the chosen targets / point / direction. `slot` upcasts spells (0 = lowest).
func perform(c: Combatant, action: Dictionary, targets: Array = [], point: Vector2 = Vector2.INF,
		dir: Vector2 = Vector2.ZERO, slot: int = 0, opts: Dictionary = {}) -> CombatResult:
	var mark := e.events.size()
	e.faerun.before_action(c)
	var r := _perform(c, action, targets, point, dir, slot, opts)
	if r.ok:
		e.faerun.after_action(c, action, targets)
	# A class feature in use: an `ability` event ahead of what it did, for the view's effect (emit-only).
	var key := ability_key(action)
	var source := "feature"
	if key.begins_with("creature:"):
		# A stat-block action the player runs (a summoned or shaped creature's): keyed like the monster's own.
		source = "monster"
		key = MonsterActions.action_key(c, {"id": key.substr(9)})
	# A feature that already told the view itself (a save action's own event, Turn Undead's spell event) needs no more.
	var told := e.events.slice(mark).any(func(ev: Variant) -> bool: return str((ev as Dictionary).get("type", "")) in ["ability", "spell"])
	if key != "" and r.ok and mark <= e.events.size() and not told:
		e.events.insert(mark, {"type": "ability", "source": source, "by": c.id, "key": key,
			"targets": targets.map(func(x: Variant) -> String: return (x as Combatant).id), "cells": []})
	return r


## Class features used from the hotbar that the view shows (Second Wind, Rage, Lay On Hands...): the feature's id
## for an `ability` event, or "" for anything else (attacks, spells, items and the common actions show themselves).
static func ability_key(action: Dictionary) -> String:
	var id := str(action.get("id", ""))
	if str(action.get("kind", "")) == "feat":
		var key := id.substr(5)
		for pre: String in ["cf:", "rh:", "fr:", "ek:"]:
			if key.begins_with(pre):
				key = key.substr(pre.length())
		# A data-defined activation (FeatureRecipes) shows as its feature; ending one shows nothing.
		if key.begins_with("recipe:"):
			key = "" if key.ends_with(":dismiss") else key.substr(7)
		return key
	if id in FEATURE_ACTIONS:
		return id
	return ""


const FEATURE_ACTIONS: Array[String] = ["second_wind", "action_surge", "steady_aim", "divine_spark_heal", "divine_spark_harm",
	"turn_undead", "preserve_life"]


func _perform(c: Combatant, action: Dictionary, targets: Array, point: Vector2, dir: Vector2, slot: int,
		opts: Dictionary) -> CombatResult:
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() else null
	var id := str(action["id"])
	match str(action["kind"]):
		"attack":
			return e.attack(c, t, str(action["option_id"]))
		"offhand":
			return e.offhand_attack(c, t, str(action["option_id"]))
		"spell":
			if bool(Compendium.shared().spell_data(str(action["spell_id"])).get("on_hit_spell", false)):
				return e.features.toggle_rider(c, "smite:" + str(action["spell_id"]))
			var all_opts := (action.get("opts", {}) as Dictionary).duplicate()
			all_opts.merge(opts, true)
			return e.spells.cast(c, str(action["spell_id"]), slot, targets, point, dir, all_opts)
		"ready_spell":
			return e.ready_spell(c, str(action["spell_id"]), slot)
		"feat":
			var fchoice := str((action.get("opts", {}) as Dictionary).get("choice", opts.get("choice", "")))
			return e.feature_actions.perform(c, id.substr(5), t, point if point != Vector2.INF else (Vector2(dir.x, dir.y) + e.center_of(c) if dir != Vector2.ZERO else Vector2.INF), fchoice, targets)
		"rider":
			return e.features.toggle_rider(c, id.substr(6))
		"sustain":
			var sid := str(action["sustain_id"])
			var a := e.spells.sustained_for(c, str(action["spell_id"]))
			var pt := point
			if t != null and pt == Vector2.INF:
				var obj := e.spells.zones.object_of(str(a.get("caster_id", c.id)), str(action["spell_id"]))
				if obj != null and obj.kind != FieldObject.Kind.ZONE:
					var cell := _weapon_cell(c, t, obj.cell)
					pt = Vector2(cell.x + 0.5, cell.y + 0.5)
			return e.spells.use_sustained(c, sid, targets, pt, dir)
		"escape_effect":
			return e.escape_effect(c, int(id.get_slice(":", 1)))
		"haste":
			return e.haste_action_use(c, id.get_slice(":", 1), t, id.substr(("haste:attack:").length()) if id.begins_with("haste:attack:") else "")
		"item", "item_spell":
			return e.items.perform(c, action, targets, point, dir, slot, opts)
		"consumable":
			return e.use_item(c, id.substr(5), t if t != null else c)
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
		"douse":
			return e.douse(c)
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
		"wake":
			return e.wake(c, t)
		"jump":
			return e.jump(c, Vector2i(floori(point.x), floori(point.y)))
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
	# An attack (a weapon, an Unarmed Strike, an attack-roll spell like Fire Bolt) never targets its own user.
	if t == c and _is_attack(c, action):
		return "Can't attack yourself"
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
		"dead":
			if not t.creature.dead:
				return "Choose a creature that died"
			if e.distance(c, t) > maxi(rng, 5):
				return "Out of reach"
			return ""
	if t.creature.dead:
		return "%s is dead" % t.name()
	if str(action["kind"]) == "sustain":
		var a := e.spells.sustained_for(c, str(action["spell_id"]))
		var obj := e.spells.zones.object_of(str(a.get("caster_id", c.id)), str(action["spell_id"])) if not a.is_empty() else null
		if obj != null and obj.kind != FieldObject.Kind.ZONE:
			if e.grid.distance_ft(obj.cell, 1, t.cell, t.size_cells) > rng:
				return "Too far from the %s (%d ft)" % [obj.name, rng]
			return ""
	if str(action["kind"]) == "spell" and bool(Compendium.shared().spell_data(str(action["spell_id"])).get("requires_sight", false)) and not e.can_see(c, t):
		return "You must see the target"
	if str(action["kind"]) == "spell" and c.creature.has_condition(&"charmed"):
		var charm := e.charm_blocks(c, t)
		if charm != "" and c.hostile_to(t):
			return charm
	match str(action["kind"]):
		"attack", "offhand":
			# An Echo Knight's Attack action (and a Nick attack, which costs nothing) can come from its echo.
			var o := e.option_by_id(c, str(action["option_id"]))
			return e.echo_knight.attack_why(c, t, o, str(action["kind"]) == "attack" or str(action["cost"]) == "free")
		"haste":
			if str(action["option_id"]) != "":
				return e.echo_knight.attack_why(c, t, e.option_by_id(c, str(action["option_id"])), true)
	var from_echo: Variant = e.echo_knight.range_why(c, action, t, rng) if rng > 0 else null
	if from_echo != null:
		return str(from_echo)
	if rng > 0 and t != c and e.distance(c, t) > rng:
		return "Out of range (%d ft, range %d ft)" % [e.distance(c, t), rng]
	if t != c and int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL:
		return "No line of sight"
	return ""


## Whether `action` makes an attack roll against its target.
func _is_attack(c: Combatant, action: Dictionary) -> bool:
	match str(action["kind"]):
		"attack", "offhand":
			return true
		"haste":
			return str(action.get("option_id", "")) != ""
		"spell", "sustain", "item_spell":
			return Compendium.shared().spell_data(str(action.get("spell_id", ""))).has("attack")
	return str(action.get("option_id", "")) != "" and not e.option_by_id(c, str(action["option_id"])).is_empty()


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
	var hc := e.echo_knight.hit_chance(c, t, o, str(action["kind"]) == "attack" or str(action["cost"]) == "free")
	out["chance"] = float(hc["chance"])
	lines.append("%s: hit %d%% (needs %d+ on the d20)" % [p.name, roundi(float(hc["chance"]) * 100.0), int(hc["needs"])])
	if hc.has("from"):
		lines.append("From %s's space" % str(hc["from"]))
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
	elif not adv.is_empty() and not dis.is_empty():
		lines.append("Advantage and Disadvantage cancel out: a single d20")
	# The roll's edge leads the tooltip's title so it can't be missed.
	out["edge"] = "advantage" if dis.is_empty() and not adv.is_empty() else ("disadvantage" if adv.is_empty() and not dis.is_empty() else "")
	if str(out["edge"]) != "":
		out["title"] = "%s · %s" % [out["title"], "ADVANTAGE" if str(out["edge"]) == "advantage" else "DISADVANTAGE"]
	for s: Variant in adv:
		lines.append("Advantage: %s" % s)
	for s: Variant in dis:
		lines.append("Disadvantage: %s" % s)
	if int(sit["cover"]) > 0:
		lines.append("%s (+%d AC) from %s" % [CombatGrid.COVER_NAMES[int(sit["cover"])], int(sit["cover_bonus"]), sit["cover_by"]])
	lines.append("AC %d%s" % [int(hc["ac"]), _known_defenses(t)])
	for fxm: Effect in t.creature.effects:
		if fxm.data.has("mark_by"):
			lines.append(fxm.name + (": your extra damage on a hit" if str(fxm.data["mark_by"]) == c.id else ""))
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
		# A wall's ring or globe shows as it's cast (SpellTargeting.wall_cells).
		cells = e.spells.targeting.wall_cells(data, action.get("opts", {}) as Dictionary, point, e.spells.area_for(c, data, point, dir))
	var who: Array[Dictionary] = []
	var warnings: Array[String] = []
	var level := int(data.get("level", 0))
	var use_slot := level if slot <= 0 else maxi(slot, level)
	var ch := c.creature as Character
	var preview := cast_preview(c, action, use_slot)
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


## Levels a hotbar spell entry can be cast at: spell slots, or an item's charge levels (a Wand of Fireballs).
func level_choices(c: Combatant, action: Dictionary) -> Array[int]:
	if str((action.get("opts", {}) as Dictionary).get("resource_cast", "")) != "":
		return [int(action["slot"])]
	if str(action.get("kind", "")) == "item_spell":
		var out: Array[int] = []
		for l: Variant in action.get("levels", []):
			out.append(int(l))
		return out
	var levels := slot_choices(c, str(action.get("spell_id", "")))
	var opts := action.get("opts", {}) as Dictionary
	var sequence_id := str(opts.get("spell_sequence", ""))
	if sequence_id != "":
		for feature in e.triggered_features.recipes(c, "spell_sequence"):
			if str(feature["id"]) == sequence_id:
				var cap := int((feature["spell_sequence"] as Dictionary)["max_level"]) - (1 if "twinned" in (opts.get("metamagic", []) as Array) else 0)
				levels = levels.filter(func(level: int) -> bool: return level <= cap)
	return levels


## Character.spell_preview for a hotbar entry, with an item's own DC and attack bonus in place of the caster's.
func cast_preview(c: Combatant, action: Dictionary, slot: int) -> Dictionary:
	var prev := e.spells.caster_char(c).spell_preview(str(action["spell_id"]), slot)
	if action.has("dc"):
		var data := Compendium.shared().spell_data(str(action["spell_id"]))
		if data.has("save"):
			prev["save"] = str(data["save"])
			prev["save_dc"] = Breakdown.new("Spell save DC").add(str(action.get("label", "Item")), int(action["dc"]))
		if data.has("attack"):
			prev["attack"] = Breakdown.new("Spell attack").add(str(action.get("label", "Item")), int(action.get("attack_bonus", int(action["dc"]) - 8)))
	return prev


## Slot levels `c` could cast `spell_id` with (the lowest first), for the upcast pips.
func slot_choices(c: Combatant, spell_id: String) -> Array[int]:
	var out: Array[int] = []
	var data := Compendium.shared().spell_data(spell_id)
	var level := int(data.get("level", 0))
	var ch := e.spells.caster_char(c)
	if level == 0 or ch == null:
		return out
	for l in range(level, 10):
		if ch.slots_left(l) > 0:
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
## The right-click menu for a square in a fight (owner ask, 2026-10-07): Move here (or why not: you can pass through
## an ally but not stop on them), then everything `c` could do to whoever stands there right now (attacks, spells,
## Help, Stabilize, items...) and Info. [{id, label, enabled, why, action?}], id "move", "info" or "act:<action id>".
func square_actions(c: Combatant, cell: Vector2i, reach: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var o := e.occupant_at(cell)
	if cell != c.cell:
		var mp := move_preview(c, cell, reach)
		var why := str(mp["reason"])
		if why == "Occupied":
			why = "You can move through %s's space but not stop in it" % o.name() if o != null and c.allied_with(o) else "Someone is there"
		out.append({"id": "move", "label": "Move here (%d ft)" % int(mp["cost"]) if bool(mp["ok"]) else "Move here", "enabled": bool(mp["ok"]), "why": why})
	if o == null or o == c:
		return out
	var seen := {}
	for a in actions_for(c):
		if not bool(a["legal"]) or str(a["targeting"]) in ["none", "self", "point", "direction", "place", "multi", "wall"]:
			continue
		if seen.has(str(a["label"])) or target_why(c, a, o) != "":
			continue
		seen[str(a["label"])] = true
		out.append({"id": "act:%s" % a["id"], "label": str(a["label"]), "enabled": true, "action": a})
	out.append({"id": "info", "label": "Info"})
	return out


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
