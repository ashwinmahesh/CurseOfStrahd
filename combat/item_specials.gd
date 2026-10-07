class_name ItemSpecials
extends RefCounted
## Bespoke magic item rules (ADR 0012): powers a recipe can't say (`"custom": "<id>"` on a power) and the passive
## rules of particular items that need code at a moment of the fight (a Vorpal Sword's 20, a Ring of Evasion's
## Reaction, Boots of Speed making Opportunity Attacks harder, a Sword of Wounding's wounds). CombatItems calls in.

var _items: WeakRef
## The rest of the custom powers (wondrous items and artifacts): combat/item_powers.gd.
var more: ItemPowers
## Heroes of Faerûn and Arcana Unleashed items: combat/faerun_items.gd.
var fr: FaerunItems


func _init(items: CombatItems) -> void:
	_items = weakref(items)
	more = ItemPowers.new(self)
	fr = FaerunItems.new(self)


func items() -> CombatItems:
	return _items.get_ref() as CombatItems


func enc() -> Encounter:
	return items().enc()


func ch_of(c: Combatant) -> Character:
	return CombatItems.ch_of(c)


## Whether `c` has an active item with this id or template (attuned and worn or held as it must be).
func has(c: Combatant, item_or_template: String) -> bool:
	return items().has_active(c, item_or_template)


# --- Powers ----------------------------------------------------------------------------------------

## "" if a custom power can be used now, else why not.
func why(c: Combatant, p: Dictionary) -> String:
	var fw := fr.why(c, p)
	if fw != "" or str((p["power"] as Dictionary).get("custom", "")).begins_with("fr_"):
		return fw
	var w := _weapon_why(c, p)
	return w if w != "" else _arcana_why(c, p)


## Carries out a custom power (CombatItems has already checked charges, uses and attunement; this pays the action).
func use(c: Combatant, p: Dictionary, targets: Array, point: Vector2, dir: Vector2, level: int, opts: Dictionary) -> CombatResult:
	var power := p["power"] as Dictionary
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else c
	var id := str(power.get("custom", ""))
	match id:
		"drink_grant", "drink_field_spell", "potion_of_vitality", "potion_of_longevity", "potion_of_poison", "philter_of_love":
			return _drink(c, p, t, id)
		"end_granted_effect":
			return _end_granted(c, p)
	if id.begins_with("fr_"):
		return fr.use(c, p, targets, point, dir, level, opts)
	return _use_more(c, p, targets, point, dir, level, opts)


## Custom powers added with later batches of items (see below).
func _use_more(c: Combatant, p: Dictionary, targets: Array, point: Vector2, _dir: Vector2, _level: int, opts: Dictionary) -> CombatResult:
	return _use_weapon_power(c, p, targets, point, opts)


func _pay(c: Combatant, p: Dictionary) -> void:
	items()._pay(c, CombatItems.power_cost(p["power"] as Dictionary, {}))


## Drinking a potion with a bespoke effect: the drinker is `t` (yourself, or a creature within 5 ft you give it to).
func _drink(c: Combatant, p: Dictionary, t: Combatant, id: String) -> CombatResult:
	var e := enc()
	if t != c and e.distance(c, t) > 5:
		return CombatResult.fail("Must be within 5 ft")
	_pay(c, p)
	var data := p["data"] as Dictionary
	var power := p["power"] as Dictionary
	var params := power.get("params", {}) as Dictionary
	var label := str(data.get("name", ""))
	e.log.add("info", "%s %s %s" % [c.name(), "drinks" if t == c else "gives %s" % t.name(), label], c.id)
	match id:
		"drink_field_spell":
			# The effect of an exploring spell (Detect Thoughts, Clairvoyance, Etherealness): noted on the drinker so the
			# story can read it (`spell:<id>`); in a fight it changes nothing.
			var fx := Effect.new(label, &"item", str(p["item_id"]))
			fx.lasting({"kind": "minutes", "amount": int(params.get("minutes", 10))})
			fx.modifiers.append(Modifier.of("flag", {"value": "active_spell:%s" % params.get("spell", "")}, label, &"item"))
			t.creature.add_effect(fx)
		"potion_of_vitality":
			if t.creature.exhaustion > 0:
				e.log.add("heal", "%s shakes off %d levels of Exhaustion" % [t.name(), t.creature.exhaustion], t.id)
				t.creature.exhaustion = 0
			e.spells.cure(t, &"poisoned")
			var fv := Effect.new(label, &"item", str(p["item_id"]))
			fv.lasting({"kind": "hours", "amount": 24})
			fv.modifiers.append(Modifier.of("flag", {"value": "max_hit_dice"}, label, &"item"))
			t.creature.add_effect(fv)
		"potion_of_longevity":
			var years := int(e.dice.roll_expr("1d6+6", label)["total"])
			e.log.add("info", "%s grows %d years younger (Potion of Longevity)" % [t.name(), years], t.id)
		"potion_of_poison":
			var rolled := e._roll_damage_dice("4d6", false, 0, label)
			e.deal_damage(null, t, [{"amount": int(rolled["total"]), "type": "poison"}], false, label, [str(rolled["text"])])
			if t.is_alive():
				var sv := t.creature.roll_save(e.dice, &"con", 13, [], [], "Con save (Potion of Poison)")
				if not sv.success:
					var fp := Effect.new(label, &"item", str(p["item_id"]))
					fp.lasting({"kind": "hours", "amount": 1})
					fp.conditions.append(&"poisoned")
					t.creature.add_effect(fp)
					e.log.add("condition", "%s is Poisoned (Potion of Poison)" % t.name(), t.id, [sv.describe()])
		"philter_of_love":
			# The first creature the drinker sees: the nearest other creature it can see.
			var best: Combatant = null
			for o in e.living():
				if o != t and e.can_see(t, o) and (best == null or e.distance(t, o) < e.distance(t, best)):
					best = o
			if best != null:
				var fl := Effect.new(label, &"item", str(p["item_id"]))
				fl.caster_id = best.id
				fl.lasting({"kind": "hours", "amount": 1})
				fl.conditions.append(&"charmed")
				t.creature.add_effect(fl)
				e.log.add("condition", "%s is Charmed by %s (Philter of Love)" % [t.name(), best.name()], t.id)
	e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## Ends the effect a potion left on the drinker (Gaseous Form ended as a Bonus Action).
func _end_granted(c: Combatant, p: Dictionary) -> CombatResult:
	_pay(c, p)
	var src := str(p["item_id"])
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == src or fx.source_id == "%s__drink" % src:
			c.creature.remove_effect(fx)
	enc().log.add("info", "%s ends the potion's effect" % c.name(), c.id)
	enc().events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


## A toggle power just switched on (extra setup some need).
func toggled_on(_c: Combatant, _p: Dictionary, _fx: Effect) -> void:
	pass


# --- Attacks -----------------------------------------------------------------------------------------

static func _specials(it: Dictionary) -> Array:
	return ((it["data"] as Dictionary).get("weapon_rules", {}) as Dictionary).get("special", []) as Array


static func _nat20(st: Dictionary) -> bool:
	return st.has("t") and (st["t"] as D20Test).kept == 20


static func _living(t: Combatant) -> bool:
	return not str(t.creature.creature_type) in ["construct", "undead"]


## Extra dice a weapon's special rules add on a hit (Mace of Smiting's 20, Sword of Sharpness's 20).
func hit_dice(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary, it: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = fr.hit_dice(c, target, option, st, it)
	var label := str((it["data"] as Dictionary).get("name", ""))
	var p := option["profile"] as WeaponProfile
	for sp: Variant in _specials(it):
		match str(sp):
			"smiting":
				var construct := str(target.creature.creature_type) == "construct"
				if construct:
					out.append({"dice": "2", "type": str(p.damage_type), "label": "%s (+3 against Constructs)" % label})
				if _nat20(st):
					out.append({"dice": "14" if construct else "7", "type": "bludgeoning", "label": label})
			"sharpness":
				if _nat20(st):
					out.append({"dice": "4d6", "type": "slashing", "label": label})
			"striking":
				# Staff of Striking: the charges armed for this hit, an extra 1d6 Force each.
				var fx := items().toggle_effect(c, str(it["id"]), "strike")
				var ch := ch_of(c)
				if fx != null and ch != null and bool(option.get("melee", true)):
					var n := mini(clampi(int(str(fx.data.get("choice", "1"))), 1, 3), ch.charges_left(str(it["id"])))
					c.creature.remove_effect(fx)
					if n > 0:
						ch.spend_charges(str(it["id"]), n)
						out.append({"dice": "%dd6" % n, "type": "force", "label": "%s (%d charges)" % [label, n]})
						if ch.charges_left(str(it["id"])) <= 0:
							items().last_charge(c, str(it["id"]), it["data"] as Dictionary)
	return out


## After a weapon hits: the rules that need the damage dealt first.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, dr: DamageResult, st: Dictionary, r: CombatResult, it: Dictionary) -> void:
	var e := enc()
	var data := it["data"] as Dictionary
	var label := str(data.get("name", ""))
	var iid := str(it["id"])
	fr.after_hit(c, target, option, dr, st, r, it)
	for sp: Variant in _specials(it):
		if str(sp) == "blackrazor" and not target.is_alive() and _living(target) and not target.has_meta("soul_devoured"):
			target.set_meta("soul_devoured", true)
			var gain := target.creature.max_hp()
			c.creature.add_temp_hp(gain, label)
			var fed := Effect.new("Blackrazor's feast", &"item", str(it["id"]))
			fed.stack_key = "blackrazor_fed"
			fed.lasting({"kind": "hours", "amount": 24})
			fed.data["ends_without_temp_hp"] = true
			fed.modifiers.append(Modifier.of("advantage", {"on": ["attack", "save:all", "check:all"]}, label, &"item"))
			c.creature.add_effect(fed)
			r.lines.append(e.log.add("heal", "Blackrazor devours %s's soul: %s gains %d Temporary Hit Points" % [target.name(), c.name(), gain], c.id))
		if not target.is_alive():
			return
		match str(sp):
			"disruption":
				if str(target.creature.creature_type) in ["fiend", "undead"] and target.creature.hp <= 25:
					var t := target.creature.roll_save(e.dice, &"wis", 15, [], [], "Wis save (%s)" % label)
					if not t.success:
						_destroy(target, label, r)
					else:
						_frighten_until_my_turn_end(c, target, label)
			"smiting":
				if _nat20(st) and str(target.creature.creature_type) == "construct" and target.creature.hp <= 25:
					_destroy(target, label, r)
			"nine_lives":
				var ch := ch_of(c)
				if bool(st.get("critical", false)) and ch != null and ch.charges_left(iid) > 0 and _living(target) \
						and target.creature.hp + dr.final < 100:
					var t2 := target.creature.roll_save(e.dice, &"con", 15, [], [], "Con save (%s)" % label)
					if not t2.success:
						ch.spend_charges(iid, 1)
						_destroy(target, label, r, "%s tears the life from %s" % [label, target.name()])
			"life_stealing":
				if _nat20(st) and _living(target):
					var rolled := e._roll_damage_dice("3d6", false, 0, label)
					var d2 := e.deal_damage(c, target, [{"amount": int(rolled["total"]), "type": "necrotic"}], false, label, [str(rolled["text"])])
					if d2.final > 0 and c.creature.add_temp_hp(d2.final, label):
						r.lines.append(e.log.add("heal", "%s gains %d Temporary Hit Points (%s)" % [c.name(), d2.final, label], c.id))
			"sharpness":
				if _nat20(st) and e.dice.roll_one(20, "%s: a second 20?" % label) == 20:
					var fx := Effect.new("Severed limb (%s)" % label, &"item", iid)
					fx.modifiers.append(Modifier.of("disadvantage", {"on": ["attack", "check:str", "check:dex"]}, "Severed limb", &"item"))
					fx.modifiers.append(Modifier.of("speed_percent", {"value": 50}, "Severed limb", &"item"))
					target.creature.add_effect(fx)
					r.lines.append(e.log.add("condition", "%s lops off one of %s's limbs" % [label, target.name()], target.id))
			"hammer_of_thunderbolts":
				if bool((st.get("opts", {}) as Dictionary).get("hammer_hurl", false)):
					hammer_thunder(c, target)
			"wounding":
				target.creature.unhealable += dr.final
				var key := "wounded_%d_%d" % [e.round_no, e.turn_index]
				if not c.has_meta(key):
					c.set_meta(key, true)
					_wound(c, target, iid, label)
			"vorpal":
				if _nat20(st):
					_vorpal(c, target, label, r)
			"wave":
				if bool(st.get("critical", false)):
					var half := target.creature.max_hp() / 2
					e.deal_damage(c, target, [{"amount": half, "type": "necrotic"}], false, label)
			"blackrazor":
				if str(target.creature.creature_type) == "undead":
					var hurt := e._roll_damage_dice("1d10", false, 0, label)
					e.deal_damage(null, c, [{"amount": int(hurt["total"]), "type": "necrotic"}], false, "Blackrazor recoils", [str(hurt["text"])])
					target.creature.heal(maxi(e.dice.roll_one(10, label), e.heal_floor(target)), label)
	if target.is_alive() and str(option.get("kind", "")) != "thrown":
		_spent_ammo_on_hit(c, option)


func _destroy(target: Combatant, label: String, r: CombatResult, text: String = "") -> void:
	var e := enc()
	target.creature.hp = 0
	target.creature.dead = true
	r.lines.append(e.log.add("death", text if text != "" else "%s is destroyed (%s)" % [target.name(), label], target.id))
	e.events.append({"type": "death", "id": target.id})
	e._check_over()


func _frighten_until_my_turn_end(c: Combatant, target: Combatant, label: String) -> void:
	var e := enc()
	var fx := Effect.new(label, &"item", "")
	fx.caster_id = c.id
	fx.conditions.append(&"frightened")
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	fx.skip_turn_ends = e.own_turn_skip(c)
	target.creature.add_effect(fx)
	e.log.add("condition", "%s is Frightened until the end of %s's next turn (%s)" % [target.name(), c.name(), label], target.id)
	e.events.append({"type": "condition", "id": target.id})


## Sword of Wounding: one more wound on the target (1d4 Necrotic per wound at the start of its turns).
func _wound(c: Combatant, target: Combatant, iid: String, label: String) -> void:
	var e := enc()
	for fx in target.creature.effects:
		if fx.stack_key == "wounding:%s" % c.id:
			fx.data["wounds"] = int(fx.data.get("wounds", 1)) + 1
			e.log.add("condition", "%s is wounded again (%d wounds, %s)" % [target.name(), int(fx.data["wounds"]), label], target.id)
			return
	var w := Effect.new("Wounded (%s)" % label, &"item", iid)
	w.stack_key = "wounding:%s" % c.id
	w.caster_id = c.id
	w.data["wounds"] = 1
	w.modifiers.append(Modifier.of("flag", {"value": "wounded"}, label, &"item"))
	target.creature.add_effect(w)
	e.log.add("condition", "%s is wounded (%s)" % [target.name(), label], target.id)
	e.events.append({"type": "condition", "id": target.id})


## A Vorpal Sword's 20: off with its head, unless it has no head to lose, resists the cut or is a legend; then 30 more.
func _vorpal(c: Combatant, target: Combatant, label: String, r: CombatResult) -> void:
	var e := enc()
	var headless := str(target.creature.creature_type) in ["ooze", "elemental", "plant"] or target.creature.has_flag("headless")
	var legendary := target.creature is Monster and (target.creature as Monster).data.has("legendary_actions")
	var too_big := target.creature.size == &"gargantuan"
	if target.creature.immunity_source(&"slashing") != "" or headless or legendary or too_big:
		e.deal_damage(c, target, [{"amount": 30, "type": "slashing", "ignore_resistance": true, "ignore_source": label}], false, label)
		return
	_destroy(target, label, r, "%s cuts off %s's head" % [label, target.name()])


## Magic ammunition loses its magic once it hits (Ammunition of Slaying once its extra damage is dealt).
func _spent_ammo_on_hit(_c: Combatant, _option: Dictionary) -> void:
	pass


## Before an attack roll is made: target-specific bonuses (Mace of Smiting against Constructs), the Oathbow against a
## sworn enemy, the Berserker Axe's curse on other weapons, an Arrow-Catching Shield or Shield of Missile Attraction
## pulling a shot onto its bearer.
func before_roll(st: Dictionary, out: Array) -> void:
	fr.before_roll(st, out)
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var sit := st["sit"] as Dictionary
	var p := option.get("profile") as WeaponProfile
	var weapon_id := p.item_id if p != null else ""
	var ranged_weapon := str(option.get("kind", "")) in ["weapon", "thrown"] and not bool(option.get("melee", true))
	for it in items().attack_items(c, option):
		for sp: Variant in _specials(it):
			if str(sp) == "smiting" and str(target.creature.creature_type) == "construct":
				st["ac"] = int(st["ac"]) - 2
			if str(sp) == "oathbow" and str(c.get_meta("oathbow_sworn", "")) == target.id:
				(sit["advantage"] as Array[String]).append("Oathbow (sworn enemy)")
				var dis := sit["disadvantage"] as Array[String]
				dis.erase("long range")
				if int(sit.get("cover", 0)) < CombatGrid.Cover.TOTAL:
					st["ac"] = int(st["ac"]) - int(sit.get("cover_bonus", 0))
	# Ring of Elemental Command: Advantage against elementals of its element, and they have Disadvantage against you.
	if target.creature is Monster:
		for el: String in ["air", "earth", "fire", "water"]:
			if c.creature.has_flag("elemental_command:%s" % el) and str((target.creature as Monster).data.get("id", "")).begins_with(el + "_elemental"):
				(sit["advantage"] as Array[String]).append("Ring of Elemental Command")
	if c.creature is Monster:
		for el2: String in ["air", "earth", "fire", "water"]:
			if target.creature.has_flag("elemental_command:%s" % el2) and str((c.creature as Monster).data.get("id", "")).begins_with(el2 + "_elemental"):
				(sit["disadvantage"] as Array[String]).append("Ring of Elemental Command (target)")
	# Cloak of Displacement: attackers have Disadvantage until the wearer is hurt (back at the start of its turn).
	if has(target, "cloak_of_displacement") and not target.has_meta("displacement_off") and not target.creature.has_condition(&"incapacitated") \
			and not target.creature.has_condition(&"restrained") and target.speed() > 0:
		(sit["disadvantage"] as Array[String]).append("Cloak of Displacement (target)")
	# Boots of Speed: Opportunity Attacks against the wearer have Disadvantage.
	var opts := st.get("opts", {}) as Dictionary
	if bool(opts.get("reaction", false)) and not bool(opts.get("readied", false)) and target.creature.has_flag("oa_disadvantage"):
		(sit["disadvantage"] as Array[String]).append("Boots of Speed (target)")
	# Oathbow: Disadvantage with every other weapon while the sworn enemy lives.
	var sworn := str(c.get_meta("oathbow_sworn", ""))
	if sworn != "" and e.get_c(sworn) != null and e.get_c(sworn).is_alive():
		var w := items().comp().item_data(weapon_id)
		if str(w.get("template_id", "")) != "oathbow" and p != null:
			(sit["disadvantage"] as Array[String]).append("Oathbow: a sworn enemy still lives")
	# Berserker Axe: Disadvantage with other weapons while a foe is within 60 ft.
	if has(c, "berserker_axe") and p != null and str(items().comp().item_data(weapon_id).get("template_id", "")) != "berserker_axe":
		for h in e.hostiles_of(c):
			if e.distance(c, h) <= 60 and e.can_see(c, h):
				(sit["disadvantage"] as Array[String]).append("Berserker Axe's curse")
				break
	# Shields that pull shots aimed at others.
	if not ranged_weapon:
		return
	for o in e.living():
		if o == target or o == c or e.distance(o, target) > 10:
			continue
		for it2 in items().active(o):
			var ar := ((it2["data"] as Dictionary).get("armor_rules", {}) as Dictionary)
			if ar.has("attract_missiles") and e.distance(o, target) <= int(ar["attract_missiles"]):
				st["target"] = o
				st["ac"] = o.creature.ac_value() + int(sit.get("cover_bonus", 0)) + int(ar.get("ac_vs_ranged", 0))
				e.log.add("info", "The %s pulls the shot meant for %s onto %s" % [(it2["data"] as Dictionary).get("name", ""), target.name(), o.name()], o.id)
				return
			if bool(ar.get("catch_arrows", false)) and e.distance(o, target) <= 5 and o.allied_with(target) and e.spells.can_react(o):
				var oo := o
				var shield_ac := int(ar.get("ac_vs_ranged", 0))
				out.append({"kind": "arrow_catching_shield", "reactor": o, "trigger": c.id, "title": "Reaction: Arrow-Catching Shield?",
					"text": "%s shoots at %s, beside %s. Become the target instead (+%d AC against it)." % [c.name(), target.name(), o.name(), shield_ac],
					"still": func() -> bool: return e.spells.can_react(oo),
					"use": func() -> void:
						oo.reaction_available = false
						st["target"] = oo
						st["ac"] = oo.creature.ac_value() + shield_ac
						e.log.add("reaction", "%s catches the shot meant for %s on the shield" % [oo.name(), target.name()], oo.id)})


## Gloves of Missile Snaring: a Reaction cuts a ranged weapon hit by 1d10 + Dex (a free hand needed).
func against_damage(st: Dictionary, total: Callable, cut: Callable, out: Array) -> void:
	var e := enc()
	var target := st["target"] as Combatant
	var c := st["c"] as Combatant
	var option := st["option"] as Dictionary
	if bool(option.get("melee", true)) or not str(option.get("kind", "")) in ["weapon", "thrown", "monster"]:
		return
	if not has(target, "gloves_of_missile_snaring") or not e.spells.can_react(target):
		return
	var ch := ch_of(target)
	if ch != null and not ch.equipped("main_hand").is_empty() and not ch.equipped("off_hand").is_empty():
		return
	var dex := target.creature.ability_mod(&"dex")
	out.append({"kind": "missile_snaring", "reactor": target, "trigger": c.id, "title": "Reaction: Gloves of Missile Snaring?",
		"text": "%s's shot hits %s for %d. Snatch at it: reduce the damage by 1d10 + %d." % [c.name(), target.name(), total.call(), dex],
		"still": func() -> bool: return e.spells.can_react(target) and int(total.call()) > 0,
		"use": func() -> void:
			target.reaction_available = false
			cut.call(maxi(0, e.dice.roll_one(10, "Missile Snaring") + dex), "Gloves of Missile Snaring")
			if int(total.call()) <= 0:
				e.log.add("reaction", "%s catches the missile out of the air" % target.name(), target.id)})


## Brooch of Shielding: Magic Missile can't hurt its wearer.
func adjust_incoming(_source: Combatant, target: Combatant, parts: Array, label: String) -> void:
	if target.creature.has_flag("immune_magic_missile") and label.contains("Magic Missile"):
		for p: Variant in parts:
			(p as Dictionary)["amount"] = 0
		enc().log.add("info", "%s's Brooch of Shielding drinks in the missile" % target.name(), target.id)


## After damage: the Berserker Axe's curse answering a hostile creature's blow; a Staff of the Python's snake killed
## takes the staff with it.
func on_damaged(source: Combatant, target: Combatant, amount: int, parts: Array) -> void:
	fr.on_damaged(source, target, amount, parts)
	var e := enc()
	if amount > 0 and has(target, "cloak_of_displacement"):
		target.set_meta("displacement_off", true)
	# A Deck of Illusions creature: anything that strikes it passes through, and it fades.
	if target.creature.has_flag("illusion") and target.is_alive():
		e.spells._dismiss(target.id)
		e.log.add("info", "The illusion is revealed and fades", target.id)
	# Helm of Brilliance: Fire damage from a failed save against a spell; on a 1 the gems burst.
	if amount > 0 and has(target, "helm_of_brilliance"):
		var fire_spell := false
		for p: Variant in parts:
			if str((p as Dictionary).get("type", "")) == "fire" and bool((p as Dictionary).get("spell", false)):
				fire_spell = true
		if fire_spell and e.dice.roll_one(20, "Helm of Brilliance") == 1:
			_helm_bursts(target)
	if target.has_meta("staff_item") and target.creature.dead:
		var owner := e.get_c(str(target.get_meta("summoner", "")))
		if owner != null and ch_of(owner) != null:
			var sid := str(target.get_meta("staff_item"))
			ch_of(owner).remove_one(sid)
			for fx: Effect in owner.creature.effects.duplicate():
				if fx.stack_key == "item_grant:%s" % sid:
					owner.creature.remove_effect(fx)
			e.log.add("info", "The snake dies and the staff shatters", owner.id)
	if amount <= 0 or source == null or not source.hostile_to(target) or not target.is_alive():
		return
	if has(target, "berserker_axe") and not target.creature.has_flag("berserk"):
		var t := target.creature.roll_save(e.dice, &"wis", 15, [], [], "Wis save (Berserker Axe)")
		if not t.success:
			var fx := Effect.new("Berserk (Berserker Axe)", &"item", "berserker_axe")
			fx.stack_key = "berserk"
			fx.modifiers.append(Modifier.of("flag", {"value": "berserk"}, "Berserker Axe", &"item"))
			target.creature.add_effect(fx)
			e.log.add("condition", "%s goes berserk (Berserker Axe)" % target.name(), target.id, [t.describe()])
			e.events.append({"type": "condition", "id": target.id})


## Wand of Binding: a charge (and the Reaction) for Advantage on a save against being Paralyzed or Restrained.
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if kind != D20Test.Kind.SAVING_THROW or not ("save_vs:paralyzed" in keys or "save_vs:restrained" in keys):
		return out
	var ch := ch_of(c)
	if ch == null or not enc().spells.can_react(c) or str(c.reaction_rules.get("assisted_escape", "auto")) == "never":
		return out
	for it in items().carried(c):
		if str(it["id"]) == "wand_of_binding" and str(it["id"]) in ch.attuned and int((it["entry"] as Dictionary).get("charges", 0)) > 0:
			(it["entry"] as Dictionary)["charges"] = int((it["entry"] as Dictionary)["charges"]) - 1
			c.reaction_available = false
			out.append("Wand of Binding")
			enc().log.add("reaction", "%s spends a charge of the Wand of Binding: Advantage on the save" % c.name(), c.id)
			if int((it["entry"] as Dictionary)["charges"]) <= 0:
				items().last_charge(c, "wand_of_binding", it["data"] as Dictionary)
			break
	return out


## A failed D20 Test: a Ring of Evasion turns a failed Dex save into a success; a Luck Blade rerolls a failure once a
## day (used automatically, like the game's other mid-roll choices; deviations.md).
func after_d20(c: Combatant, t: D20Test, keys: Array[String]) -> void:
	fr.after_d20(c, t, keys)
	var e := enc()
	var ch := ch_of(c)
	if ch == null or t.success or t.target <= 0:
		return
	if t.kind == D20Test.Kind.SAVING_THROW and "save:dex" in keys and e.spells.can_react(c) and str(c.reaction_rules.get("ring_of_evasion", "auto")) != "never":
		for it in items().active(c):
			if str(it["id"]) == "ring_of_evasion" and int((it["entry"] as Dictionary).get("charges", 0)) > 0:
				(it["entry"] as Dictionary)["charges"] = int((it["entry"] as Dictionary)["charges"]) - 1
				c.reaction_available = false
				t.add_bonus(maxi(0, t.target - t.total), "Ring of Evasion")
				e.log.add("reaction", "%s's Ring of Evasion turns the failed save into a success" % c.name(), c.id)
				return
	for it2 in items().carried(c):
		var d := it2["data"] as Dictionary
		if str(d.get("template_id", "")) != "luck_blade" or not str(it2["id"]) in ch.attuned:
			continue
		var entry := it2["entry"] as Dictionary
		if int((entry.get("uses", {}) as Dictionary).get("luck", 0)) >= 1 or str(c.reaction_rules.get("luck_blade", "auto")) == "never":
			continue
		if not entry.has("uses"):
			entry["uses"] = {}
		(entry["uses"] as Dictionary)["luck"] = 1
		var before := t.describe()
		t.set_natural(e.dice.d20("Luck Blade"), "Luck Blade")
		e.log.add("info", "%s calls on the Luck Blade's luck and rerolls" % c.name(), c.id, [before, t.describe()])
		return


# --- Turns -----------------------------------------------------------------------------------------

## Weapon of Warning: its wielder and the wielder's allies within 30 ft have Advantage on Initiative.
func initiative_advantage(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	var e := enc()
	for o in e.combatants:
		if o.allied_with(c) or o == c:
			if (o == c or e.distance(o, c) <= 30) and _warned(o):
				out.append("Weapon of Warning (%s)" % o.name())
				break
	return out


func _warned(c: Combatant) -> bool:
	for it in items().carried(c):
		if "warning" in _specials(it) and (not MagicItems.needs_attunement(it["data"] as Dictionary) or str(it["id"]) in ch_of(c).attuned):
			return true
	return false


## Weapon of Warning: neither its wielder nor allies within 30 ft can be surprised.
func surprise_filter(ids: Array) -> Array:
	var e := enc()
	var out: Array = []
	for id: Variant in ids:
		var c := e.get_c(str(id))
		var safe := false
		if c != null:
			for o in e.combatants:
				if (o == c or (o.allied_with(c) and e.distance(o, c) <= 30)) and o.creature is Character and _warned(o):
					safe = true
		if safe:
			e.log.add("info", "%s's Weapon of Warning: %s isn't surprised" % ["A", c.name()], c.id)
		else:
			out.append(id)
	return out


## The start of a creature's turn: summoned helpers whose time is up leave, Sword of Wounding's wounds bleed, a
## berserker attacks.
func turn_start(c: Combatant) -> void:
	fr.turn_start(c)
	var e := enc()
	for o in e.combatants:
		if o.has_meta("vanish_round") and str(o.get_meta("summoner", "")) == c.id and int(o.get_meta("vanish_round")) <= e.round_no and o.is_alive():
			e.spells._dismiss(o.id)
	for fx: Effect in c.creature.effects.duplicate():
		if not fx.stack_key.begins_with("wounding:") or not c.is_alive():
			continue
		var n := int(fx.data.get("wounds", 1))
		var src := e.get_c(fx.caster_id)
		var rolled := e._roll_damage_dice("%dd4" % n, false, 0, "Wounds")
		var dr := e.deal_damage(src, c, [{"amount": int(rolled["total"]), "type": "necrotic"}], false, "%d wound%s (Sword of Wounding)" % [n, "" if n == 1 else "s"], [str(rolled["text"])])
		c.creature.unhealable += dr.final
		if c.is_alive():
			var t := c.creature.roll_save(e.dice, &"con", 15, [], [], "Con save (wounds)")
			if t.success:
				c.creature.remove_effect(fx)
				e.log.add("info", "%s's wounds close" % c.name(), c.id, [t.describe()])
	if c.creature.has_flag("berserk"):
		_berserk_turn(c)
	c.remove_meta("displacement_off")
	# Cloak of the Bat: in Dim Light or darkness its wearer can fly at 40 ft (this turn).
	if c.creature.has_flag("bat_cloak"):
		for fxb: Effect in c.creature.effects.duplicate():
			if fxb.stack_key == "bat_flight":
				c.creature.remove_effect(fxb)
		if e.light_at(c.cell) != "bright":
			var fly := Effect.new("Cloak of the Bat", &"item", "cloak_of_the_bat")
			fly.stack_key = "bat_flight"
			fly.modifiers.append(Modifier.of("speed_set", {"kind": "fly", "value": 40}, "Cloak of the Bat", &"item"))
			c.creature.add_effect(fly)
	# Periapt of Wound Closure: a dying wearer stabilizes at the start of its turn.
	if c.creature.has_flag("wound_closure") and c.creature.hp == 0 and not c.creature.dead and not c.creature.stable:
		c.creature.stabilize()
		e.log.add("info", "%s's Periapt of Wound Closure stops the bleeding: Stable" % c.name(), c.id)
	if c.creature.has_flag("artifact_regeneration") and c.creature.hp >= 1:
		var healed := c.creature.heal(e.dice.roll_one(6, "Regeneration"), "Artifact")
		if healed > 0:
			e.log.add("heal", "%s regains %d Hit Points (artifact)" % [c.name(), healed], c.id)
	# Helm of Brilliance (a diamond left): Undead starting their turn within 30 ft of its wearer take 1d6 Radiant.
	if str(c.creature.creature_type) == "undead":
		for o in e.living():
			if o != c and e.distance(o, c) <= 30 and has(o, "helm_of_brilliance"):
				var it := items().active_item(o, "helm_of_brilliance")
				if int(((it["entry"] as Dictionary).get("gems", {}) as Dictionary).get("diamond", 0)) > 0:
					var rolled := e._roll_damage_dice("1d6", false, 0, "Helm of Brilliance")
					e.deal_damage(o, c, [{"amount": int(rolled["total"]), "type": "radiant"}], false, "Helm of Brilliance", [str(rolled["text"])])
					break


func turn_end(_c: Combatant) -> void:
	pass


## Berserker Axe: berserk until a turn starts with nobody in sight within 60 ft; otherwise the action goes on attacking
## the nearest creature with the axe (friend or foe).
func _berserk_turn(c: Combatant) -> void:
	var e := enc()
	var near: Combatant = null
	for o in e.living():
		if o != c and not o.is_down() and e.distance(c, o) <= 60 and e.can_see(c, o):
			if near == null or e.distance(c, o) < e.distance(c, near):
				near = o
	if near == null:
		for fx: Effect in c.creature.effects.duplicate():
			if fx.stack_key == "berserk":
				c.creature.remove_effect(fx)
		e.log.add("info", "%s's berserk fury fades" % c.name(), c.id)
		return
	var axe := ""
	for o in e.attack_options(c):
		if str(o["kind"]) == "weapon" and str(e.items.comp().item_data((o["profile"] as WeaponProfile).item_id).get("template_id", "")) == "berserker_axe":
			axe = str(o["id"])
	if axe == "" or not c.can_act():
		return
	e.log.add("info", "%s is berserk and attacks the nearest creature, %s" % [c.name(), near.name()], c.id)
	if e.distance(c, near) > 5:
		var best := Vector2i(-1, -1)
		var cost := 1 << 30
		var reach := e.reachable_for(c)
		for cell: Vector2i in reach:
			if e.grid.distance_ft(cell, c.size_cells, near.cell, near.size_cells) <= 5 and int((reach[cell] as Dictionary).get("cost", 999)) < cost:
				cost = int((reach[cell] as Dictionary).get("cost", 999))
				best = cell
		if best.x >= 0:
			e.move(c, best)
	var guard := 0
	while c.can_act() and (c.action_available or c.attacks_left > 0) and guard < 6 and e.pending == null:
		guard += 1
		var target: Combatant = null
		for o2 in e.living():
			if o2 != c and not o2.is_down() and e.attack_legal(c, o2, e.option_by_id(c, axe)) == "":
				if target == null or e.distance(c, o2) < e.distance(c, target):
					target = o2
		if target == null:
			break
		e.attack(c, target, axe)


# --- Custom powers (weapons) ---------------------------------------------------------------------------

func _weapon_why(c: Combatant, p: Dictionary) -> String:
	var power := p["power"] as Dictionary
	var e := enc()
	match str(power.get("custom", "")):
		"oathbow":
			var sworn := e.get_c(str(c.get_meta("oathbow_sworn", "")))
			if sworn != null and sworn.is_alive():
				return "Your sworn enemy, %s, still lives" % sworn.name()
		"defender":
			if int(c.get_meta("defender_round", -1)) == e.round_no:
				return "Already shifted this turn"
		"dancing_sword_command":
			var obj := e.spells.zones.object_of(c.id, "dancing_sword")
			if obj == null:
				return "The sword isn't dancing"
	return ""


func _use_weapon_power(c: Combatant, p: Dictionary, targets: Array, point: Vector2, opts: Dictionary) -> CombatResult:
	var e := enc()
	var power := p["power"] as Dictionary
	var iid := str(p["item_id"])
	var data := p["data"] as Dictionary
	var label := str(data.get("name", ""))
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
	match str(power.get("custom", "")):
		"bonus_weapon_attack":
			var o := e.option_by_id(c, "weapon:" + iid)
			if o.is_empty() or t == null:
				return CombatResult.fail("Choose a target")
			var why := e.attack_legal(c, t, o)
			if why != "":
				return CombatResult.fail(why)
			c.bonus_available = false
			e.log.add("info", "%s strikes again (%s)" % [c.name(), label], c.id)
			return e._resolve_attack(c, t, o, {})
		"defender":
			var n := clampi(int(str(opts.get("choice", "1"))), 1, 3)
			c.set_meta("defender_round", e.round_no)
			var fx := Effect.new("%s's guard" % label, &"item", iid)
			fx.stack_key = "defender:%s" % iid
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = c.id
			fx.modifiers.append(Modifier.of("ac", {"value": n}, label, &"item"))
			fx.modifiers.append(Modifier.of("attack", {"value": -n, "when": {"item": iid}}, label, &"item"))
			fx.modifiers.append(Modifier.of("damage", {"value": -n, "when": {"item": iid}}, label, &"item"))
			c.creature.add_effect(fx)
			e.log.add("info", "%s shifts %d of the Defender's bonus to AC" % [c.name(), n], c.id)
			e.events.append({"type": "condition", "id": c.id})
			return CombatResult.new()
		"oathbow":
			if t == null or not c.hostile_to(t):
				return CombatResult.fail("Choose an enemy")
			c.set_meta("oathbow_sworn", t.id)
			e.log.add("info", "%s names %s a sworn enemy: \"Swift death to you who have wronged me.\"" % [c.name(), t.name()], c.id)
			return CombatResult.new()
		"javelin_of_lightning":
			return _javelin(c, p, t)
		"hammer_hurl":
			return _hammer_hurl(c, p, t)
		"veterans_cane":
			var ch := ch_of(c)
			var slot := str(ch.entry_of(iid).get("slot", ""))
			_pay_cost(c, "bonus")
			ch.remove_one(iid)
			ch.add_item("longsword")
			if slot in ["main_hand", "off_hand"]:
				ch.equip("longsword", slot)
			e.log.add("info", "%s's cane becomes a longsword" % c.name(), c.id)
			return CombatResult.new()
		"quench_flames":
			_pay_cost(c, "magic")
			e.log.add("info", "%s's %s snuffs out every ordinary flame within 30 ft" % [c.name(), label], c.id)
			return CombatResult.new()
		"sun_blade_light":
			_pay_cost(c, "bonus")
			var r := clampi(int(str(opts.get("choice", "15"))), 10, 30)
			items().attach_light(c, "light:%s" % iid, r, r, true)
			e.log.add("info", "%s's Sun Blade shines %d ft bright" % [c.name(), r], c.id)
			return CombatResult.new()
		"dancing_sword":
			return _dance(c, p, t, true)
		"dancing_sword_command":
			return _dance(c, p, t, false)
	return _use_arcana(c, p, targets, point, opts)


# --- Custom powers (rings, wands, rods, staffs) ------------------------------------------------------------

func _arcana_why(c: Combatant, p: Dictionary) -> String:
	var power := p["power"] as Dictionary
	var e := enc()
	if bool((p["entry"] as Dictionary).get("transformed", false)) and str(power.get("custom", "")) != "python_recall":
		return "It's a snake right now"
	match str(power.get("custom", "")):
		"ring_spell_storing":
			if ((p["entry"] as Dictionary).get("stored", []) as Array).is_empty():
				return "No spells stored"
		"summon_monster":
			var mid := str((power.get("params", {}) as Dictionary).get("monster", ""))
			if items().comp().monster_data(mid).is_empty():
				return "Not available yet (no stat block for %s)" % mid.replace("_", " ")
		"end_effect":
			if not _has_item_effect(c, str(p["item_id"])):
				return "Not active"
	if e == null:
		return ""
	return more.why(c, p)


func _has_item_effect(c: Combatant, iid: String) -> bool:
	for fx in c.creature.effects:
		if fx.source_id == iid:
			return true
	return false


func _use_arcana(c: Combatant, p: Dictionary, targets: Array, point: Vector2, opts: Dictionary) -> CombatResult:
	var e := enc()
	var power := p["power"] as Dictionary
	var params := power.get("params", {}) as Dictionary
	var iid := str(p["item_id"])
	var data := p["data"] as Dictionary
	var label := str(data.get("name", ""))
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
	var cost := CombatItems.power_cost(power, {})
	match str(power.get("custom", "")):
		"flavour":
			_pay_cost(c, cost)
			e.log.add("info", "%s's %s %s" % [c.name(), label, params.get("text", "does something harmless")], c.id)
			return CombatResult.new()
		"ravenkind_hold":
			# Holy Symbol of Ravenkind (Curse of Strahd): every vampire and vampire spawn within range that can see the
			# symbol saves (Wisdom) or is Paralyzed for a minute, saving again at the end of each of its turns.
			_pay_cost(c, cost)
			var dc := int(params.get("dc", 15))
			var held := 0
			for v in e.living():
				if not v.creature is Monster or not e.can_see(v, c) or e.distance(c, v) > int(params.get("range", 30)):
					continue
				var mid := str((v.creature as Monster).data.get("id", ""))
				if not (mid.contains("vampire") or mid.begins_with("strahd")):
					continue
				var sv := v.creature.roll_save(e.dice, &"wis", dc, [], [], "Wis save (%s)" % label)
				if sv.success:
					e.log.add("info", "%s resists the %s" % [v.name(), label], v.id, [sv.describe()])
					continue
				var fx := Effect.new(label, &"item", iid)
				fx.caster_id = c.id
				fx.conditions.append(&"paralyzed")
				fx.lasting_rounds(10, c.id)
				fx.repeat_save = {"ability": "wis", "dc": dc, "when": "end"}
				v.creature.add_effect(fx)
				held += 1
				e.log.add("condition", "%s is held fast by the %s" % [v.name(), label], v.id, [sv.describe()])
				e.events.append({"type": "condition", "id": v.id})
			if held == 0:
				e.log.add("info", "%s raises the %s; no vampire is held" % [c.name(), label], c.id)
			return CombatResult.new()
		"summon_monster":
			_pay_cost(c, cost)
			return summon(c, str(params.get("monster", "")), int(params.get("count", 1)), point, params, label)
		"ring_invisibility":
			_pay_cost(c, cost)
			var fx := Effect.new(label, &"item", iid)
			fx.stack_key = "item:%s:vanish" % iid
			fx.conditions.append(&"invisible")
			fx.ends_on.append_array(["attack_roll", "cast_spell"])
			fx.data["powers"] = [{"id": "appear", "name": "Become visible", "cost": "bonus", "custom": "end_effect"}]
			c.creature.add_effect(fx)
			e.log.add("condition", "%s turns Invisible (%s)" % [c.name(), label], c.id)
			e.events.append({"type": "condition", "id": c.id})
			return CombatResult.new()
		"end_effect":
			_pay_cost(c, cost)
			for fx2: Effect in c.creature.effects.duplicate():
				if fx2.source_id == iid:
					c.creature.remove_effect(fx2)
			e.log.add("info", "%s ends %s's effect" % [c.name(), label], c.id)
			e.events.append({"type": "condition", "id": c.id})
			return CombatResult.new()
		"x_ray_vision":
			_pay_cost(c, cost)
			_x_ray(c, p, label)
			return CombatResult.new()
		"enemy_detection":
			_pay_cost(c, cost)
			var near: Combatant = null
			for h in e.hostiles_of(c):
				if e.distance(c, h) <= 60 and (near == null or e.distance(c, h) < e.distance(c, near)):
					near = h
			if near == null:
				e.log.add("info", "%s's wand senses no hostile creature within 60 ft" % c.name(), c.id)
			else:
				var d := e.center_of(near) - e.center_of(c)
				e.log.add("info", "%s's wand points %s: the nearest hostile creature is that way" % [c.name(), _compass(d)], c.id)
			return CombatResult.new()
		"ring_spell_storing":
			return _cast_stored(c, p, targets, point, opts)
		"wand_of_wonder":
			_pay_cost(c, cost)
			return wonder(c, p, t, point)
		"retributive_strike":
			_pay_cost(c, cost)
			return retributive_strike(c, p)
		"staff_python":
			_pay_cost(c, cost)
			var ch := ch_of(c)
			var r := summon(c, "giant_constrictor_snake", 1, point, {"name": "Python (%s)" % label}, label)
			if r.ok:
				for o in e.combatants:
					if str(o.get_meta("summoner", "")) == c.id and o.creature.name.begins_with("Python") and not o.has_meta("staff_item"):
						o.set_meta("staff_item", iid)
				ch.unequip_item(iid)
				(p["entry"] as Dictionary)["transformed"] = true
				var fx := Effect.new(label, &"item", iid)
				fx.stack_key = "item_grant:%s" % iid
				fx.data["powers"] = [{"id": "recall", "name": "Turn the snake back into the staff", "cost": "bonus", "custom": "python_recall"}]
				c.creature.add_effect(fx)
			return r
		"python_recall":
			_pay_cost(c, cost)
			for o2 in e.combatants:
				if str(o2.get_meta("staff_item", "")) == iid and str(o2.get_meta("summoner", "")) == c.id and o2.is_alive():
					e.spells._dismiss(o2.id)
			ch_of(c).entry_of(iid).erase("transformed")
			for fx3: Effect in c.creature.effects.duplicate():
				if fx3.stack_key == "item_grant:%s" % iid:
					c.creature.remove_effect(fx3)
			e.log.add("info", "The snake becomes %s's staff again" % c.name(), c.id)
			return CombatResult.new()
		"thunder_and_lightning":
			_pay_cost(c, cost)
			var nums := {"dc": Breakdown.new("Spell save DC").add(label, 17), "attack": Breakdown.new("Spell attack").add(label, 9), "mod": 0, "ability": &"int"}
			var dir := (point - e.center_of(c)).normalized() if point != Vector2.INF else Vector2(1, 0)
			for rk: String in ["strike", "clap"]:
				var sd := items().comp().spell_data("%s__%s" % [MagicItems.recipe_owner(iid), rk])
				items().cast(c, sd, 0, [], point, dir, nums, "free", {}, str(sd.get("name", "")))
			return CombatResult.new()
		"rod_of_absorption_draw":
			var ch2 := ch_of(c)
			var lvl := clampi(int(str(opts.get("choice", "1"))), 1, 5)
			var entry := p["entry"] as Dictionary
			if int(entry.get("charges", 0)) < lvl:
				return CombatResult.fail("Not enough stored energy (%d levels)" % int(entry.get("charges", 0)))
			if ch2.slots_used[lvl - 1] <= 0:
				return CombatResult.fail("No spent level %d slot to fill" % lvl)
			entry["charges"] = int(entry["charges"]) - lvl
			ch2.slots_used[lvl - 1] -= 1
			e.log.add("info", "%s draws %d levels of energy from the rod: a level %d slot" % [c.name(), lvl, lvl], c.id)
			return CombatResult.new()
		"rod_of_alertness_aura":
			_pay_cost(c, cost)
			items().attach_light(c, "alertness_aura", 60, 60)
			for a in e.combatants:
				if (a == c or a.allied_with(c)) and e.distance(a, c) <= 60:
					var fx := Effect.new("Protective Aura (Rod of Alertness)", &"item", iid)
					fx.lasting({"kind": "minutes", "amount": 10})
					fx.turn_owner_id = c.id
					fx.modifiers.append(Modifier.of("ac", {"value": 1}, "Rod of Alertness", &"item"))
					fx.modifiers.append(Modifier.of("save", {"ability": "all", "value": 1}, "Rod of Alertness", &"item"))
					fx.modifiers.append(Modifier.of("flag", {"value": "senses_invisible"}, "Rod of Alertness", &"item"))
					a.creature.add_effect(fx)
			e.log.add("spell", "%s plants the Rod of Alertness: a protective light spreads 60 ft" % c.name(), c.id)
			return CombatResult.new()
		"lordly_might_form":
			_pay_cost(c, cost)
			return _lordly_form(c, iid, str(opts.get("choice", "rod")))
		"pact_slot":
			_pay_cost(c, cost)
			var ch3 := ch_of(c)
			if ch3.pact_slots_used <= 0:
				return CombatResult.fail("No Pact Magic slot to regain")
			ch3.pact_slots_used -= 1
			e.log.add("info", "%s regains a Pact Magic slot (%s)" % [c.name(), label], c.id)
			return CombatResult.new()
		"tentacle_rod":
			if t == null or e.distance(c, t) > 15:
				return CombatResult.fail("Choose a creature within 15 ft")
			_pay_cost(c, cost)
			return _tentacles(c, t, label)
	return more.use(c, p, targets, point, opts)


## Rod of Lordly Might's buttons: a fiery blade (a Flame Tongue longsword), a battleaxe, a spear, or the mace again.
func _lordly_form(c: Combatant, iid: String, form: String) -> CombatResult:
	var e := enc()
	for fx: Effect in c.creature.effects.duplicate():
		if fx.stack_key.begins_with("item:%s:form" % iid):
			c.creature.remove_effect(fx)
	var shapes := {"blade": ["1d8", "slashing", "a blade of fire"], "battleaxe": ["1d8", "slashing", "a battleaxe"], "spear": ["1d6", "piercing", "a spear"]}
	if shapes.has(form):
		var sh := shapes[form] as Array
		var fx2 := Effect.new("Rod of Lordly Might (%s)" % form, &"item", iid)
		fx2.stack_key = "item:%s:form_%s" % [iid, form]
		fx2.modifiers.append(Modifier.of("weapon_override", {"items": [iid], "die": str(sh[0]), "damage_type": str(sh[1])}, "Rod of Lordly Might", &"item"))
		c.creature.add_effect(fx2)
		if form == "blade":
			var lit := Effect.new("Rod of Lordly Might (blade)", &"item", iid)
			lit.stack_key = CombatItems.toggle_key(iid, "form_blade")
			c.creature.add_effect(lit)
			items().attach_light(c, CombatItems.toggle_key(iid, "form_blade"), 40, 40)
		e.log.add("info", "%s presses a button: the rod becomes %s" % [c.name(), str(sh[2])], c.id)
	else:
		items().detach_light(c, CombatItems.toggle_key(iid, "form_blade"))
		e.log.add("info", "%s's rod returns to its mace form" % c.name(), c.id)
	return CombatResult.new()


## Tentacle Rod: three tentacle attacks (+9, 1d6 Bludgeoning); three hits and a failed Con save (DC 15) hamper the target.
func _tentacles(c: Combatant, t: Combatant, label: String) -> CombatResult:
	var e := enc()
	var hits := 0
	for i in 3:
		if not t.is_alive():
			break
		var atk := Breakdown.new("Tentacle").add(label, 9)
		var test := c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, atk, t.creature.ac_value(), ["attack", "attack:melee"], [], [],
			"%s → %s (tentacle %d)" % [c.name(), t.name(), i + 1])
		if test.success:
			hits += 1
			var rolled := e._roll_damage_dice("1d6", test.critical, 0, label)
			e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "bludgeoning"}], test.critical, label, [test.describe(), str(rolled["text"])])
		else:
			e.log.add("miss", "A tentacle misses %s" % t.name(), c.id, [test.describe()])
	if hits == 3 and t.is_alive():
		var sv := t.creature.roll_save(e.dice, &"con", 15, [], [], "Con save (%s)" % label, ["save_vs:spell"])
		if not sv.success:
			var fx := Effect.new(label, &"item", "tentacle_rod")
			fx.caster_id = c.id
			fx.lasting_rounds(10, c.id)
			fx.repeat_save = {"ability": "con", "dc": 15, "when": "end"}
			fx.modifiers.append(Modifier.of("speed_percent", {"value": 50}, label, &"item"))
			fx.modifiers.append(Modifier.of("disadvantage", {"on": "save:dex"}, label, &"item"))
			fx.modifiers.append(Modifier.of("flag", {"value": "no_reactions"}, label, &"item"))
			fx.modifiers.append(Modifier.of("flag", {"value": "slowed"}, label, &"item"))
			t.creature.add_effect(fx)
			e.log.add("condition", "%s is wrapped up by the tentacles" % t.name(), t.id, [sv.describe()])
	return CombatResult.new()


## Staff of Power / Staff of the Magi: broken on purpose. 50% the wielder slips to another plane, otherwise takes
## 16 × charges Force; everyone else within 30 ft saves (Dex DC 17) against 8, 6 or 4 × charges by distance.
func retributive_strike(c: Combatant, p: Dictionary) -> CombatResult:
	var e := enc()
	var ch := ch_of(c)
	var iid := str(p["item_id"])
	var n := maxi(0, int((p["entry"] as Dictionary).get("charges", 0)))
	ch.unequip_item(iid)
	ch.remove_one(iid)
	e.log.add("spell", "%s breaks the %s: a blast of raw magic (%d charges)" % [c.name(), (p["data"] as Dictionary).get("name", ""), n], c.id)
	var center := c
	for o in e.living():
		if o == c:
			continue
		var d := e.distance(o, center)
		if d > 30:
			continue
		var mult := 8 if d <= 10 else (6 if d <= 20 else 4)
		var sv := o.creature.roll_save(e.dice, &"dex", 17, [], [], "Dex save (Retributive Strike)", ["save_vs:spell"])
		var amt := mult * n if not sv.success else mult * n / 2
		e.deal_damage(c, o, [{"amount": amt, "type": "force"}], false, "Retributive Strike", [sv.describe()])
	if e.dice.roll_one(100, "Retributive Strike: another plane?") <= 50:
		e.log.add("info", "%s vanishes to another plane, escaping the blast" % c.name(), c.id)
		c.creature.dead = true
		e.events.append({"type": "vanish", "id": c.id})
	else:
		e.deal_damage(null, c, [{"amount": 16 * n, "type": "force"}], false, "Retributive Strike")
	e._check_over()
	return CombatResult.new()


## Rod of Absorption, Staff of the Magi: the Reaction that soaks up a spell aimed only at the wielder.
func absorb(c: Combatant, t: Combatant, ctx: Dictionary, r: CombatResult) -> bool:
	var e := enc()
	var s := ctx["s"] as Dictionary
	var lvl := int(ctx.get("slot", 1))
	for it in items().active(t):
		var tid := str((it["data"] as Dictionary).get("template_id", it["id"]))
		var entry := it["entry"] as Dictionary
		if tid == "rod_of_absorption":
			if int(entry.get("absorbed_total", 0)) + lvl > 50 or e._reaction_decision(t, "rod_of_absorption") == "never":
				continue
			t.reaction_available = false
			entry["absorbed_total"] = int(entry.get("absorbed_total", 0)) + lvl
			entry["charges"] = int(entry.get("charges", 0)) + lvl
			r.lines.append(e.log.add("reaction", "%s's Rod of Absorption drinks in %s (%d levels stored)" % [t.name(), s.get("name", ""), int(entry["charges"])], t.id))
			return true
		if tid == "staff_of_the_magi":
			if e._reaction_decision(t, "staff_of_the_magi") == "never":
				continue
			t.reaction_available = false
			entry["charges"] = int(entry.get("charges", 0)) + lvl
			r.lines.append(e.log.add("reaction", "%s's Staff of the Magi absorbs %s (+%d charges)" % [t.name(), s.get("name", ""), lvl], t.id))
			if int(entry["charges"]) > 50:
				var p := {"item_id": str(it["id"]), "data": it["data"], "entry": entry, "power": {}}
				retributive_strike(t, p)
			return true
		# Ioun Stones of Absorption (level 4 or lower, 20 levels) and Greater Absorption (level 8 or lower, 50 levels).
		if tid in ["ioun_stone_absorption", "ioun_stone_greater_absorption"]:
			var cap := 4 if tid == "ioun_stone_absorption" else 8
			if lvl > cap or int(entry.get("charges", 0)) < lvl or e._reaction_decision(t, tid) == "never":
				continue
			t.reaction_available = false
			entry["charges"] = int(entry["charges"]) - lvl
			r.lines.append(e.log.add("reaction", "%s's Ioun Stone swallows %s (%d levels left)" % [t.name(), s.get("name", ""), int(entry["charges"])], t.id))
			if int(entry["charges"]) <= 0:
				var ch := ch_of(t)
				ch.unequip_item(str(it["id"]))
				ch.remove_one(str(it["id"]))
				e.log.add("info", "The Ioun Stone burns out and turns to dust", t.id)
			return true
	if c == null:
		return false
	return false


static func _compass(d: Vector2) -> String:
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var a := fposmod(d.angle(), TAU)
	return names[int(round(a / (TAU / 8.0))) % 8]


## Ring of X-ray Vision: a minute of seeing through walls; a second use before a Long Rest risks Exhaustion.
func _x_ray(c: Combatant, p: Dictionary, label: String) -> void:
	var e := enc()
	var entry := p["entry"] as Dictionary
	if int(entry.get("xray_uses", 0)) > 0:
		var sv := c.creature.roll_save(e.dice, &"con", 15, [], [], "Con save (%s)" % label)
		if not sv.success:
			c.creature.add_exhaustion(1)
			e.log.add("condition", "%s gains a level of Exhaustion from the strain" % c.name(), c.id, [sv.describe()])
	entry["xray_uses"] = int(entry.get("xray_uses", 0)) + 1
	var fx := Effect.new(label, &"item", str(p["item_id"]))
	fx.lasting({"kind": "minutes", "amount": 1})
	fx.turn_owner_id = c.id
	fx.modifiers.append(Modifier.of("flag", {"value": "x_ray_vision"}, label, &"item"))
	c.creature.add_effect(fx)
	e.log.add("info", "%s sees through solid matter within 30 ft" % c.name(), c.id)


## Summons creatures from an item (a Figurine of Wondrous Power, Bag of Tricks, Horn of Valhalla, an elemental's
## brazier): they join the summoner's side under the player's control, and leave when the time is up (or the
## Concentration ends).
func summon(c: Combatant, monster_id: String, count: int, point: Vector2, params: Dictionary, label: String) -> CombatResult:
	var e := enc()
	var r := CombatResult.new()
	var data := items().comp().monster_data(monster_id)
	if data.is_empty():
		return CombatResult.fail("No stat block for %s" % monster_id)
	var conc: Concentration = null
	if bool(params.get("concentration", false)):
		conc = c.creature.begin_concentration("item_summon:%s" % monster_id, label)
	var cell := Vector2i(floori(point.x), floori(point.y)) if point != Vector2.INF else c.cell
	for i in count:
		var m := Monster.from_data(data, e.dice)
		if params.has("name"):
			m.name = str(params["name"])
		var size := CombatGrid.size_cells_for(m.size)
		var at := cell
		if at.x < 0 or not e.spells._room_for(at, size):
			at = e.spells._free_cell_near(at if at.x >= 0 else c.cell, size)
		var sc := e.add(m, &"guest" if c.side == &"party" else c.side, at)
		sc.controller = c.controller
		sc.set_meta("summoner", c.id)
		sc.set_meta("vanishes", true)
		if params.has("rounds") or params.has("minutes") or params.has("hours"):
			var rounds := int(params.get("rounds", int(params.get("minutes", 0)) * 10 + int(params.get("hours", 0)) * 600))
			sc.set_meta("vanish_round", e.round_no + rounds)
		if not e.spells.summoned.has(c.id):
			e.spells.summoned[c.id] = []
		(e.spells.summoned[c.id] as Array).append(sc.id)
		if conc != null:
			var marker := Effect.new(label, &"item", monster_id)
			marker.modifiers.append(Modifier.of("flag", {"value": "summoned"}, label, &"item"))
			conc.attach(m, marker)
			var sid := sc.id
			var sp := e.spells
			marker.on_end = func() -> void: sp._dismiss(sid)
		if e.state == Encounter.State.ACTIVE:
			e.insert_after(c, sc)
		e.events.append({"type": "summon_creature", "id": sc.id, "cell": at, "caster": c.id})
		r.lines.append(e.log.add("spell", "%s appears beside %s (%s)" % [m.name, c.name(), label], c.id))
	return r


## Ring of Spell Storing: casts a stored spell at its stored level with the storer's numbers.
func _cast_stored(c: Combatant, p: Dictionary, targets: Array, point: Vector2, opts: Dictionary) -> CombatResult:
	var e := enc()
	var entry := p["entry"] as Dictionary
	var stored := entry.get("stored", []) as Array
	var pick := int(str(opts.get("choice", "0")))
	if pick < 0 or pick >= stored.size():
		pick = 0
	var st := stored[pick] as Dictionary
	var spell := items().comp().spell_data(str(st["spell"]))
	if spell.is_empty():
		return CombatResult.fail("Unknown spell")
	var nums := {"dc": Breakdown.new("Spell save DC").add("Stored", int(st.get("dc", 13))),
		"attack": Breakdown.new("Spell attack").add("Stored", int(st.get("attack", 5))), "mod": int(st.get("mod", 0)),
		"ability": StringName(str(st.get("ability", "int")))}
	var r := items().cast(c, spell, int(st.get("level", spell.get("level", 1))), targets, point, Vector2.ZERO, nums,
		CombatItems.power_cost({}, spell), opts, "%s (Ring of Spell Storing)" % spell.get("name", ""))
	if r.ok:
		stored.remove_at(pick)
	return r


# --- Wand of Wonder ------------------------------------------------------------------------------------------

## Rolls on the Wand of Wonder table (2024 DMG, d100) and makes it happen. Spells from it use save DC 15.
func wonder(c: Combatant, p: Dictionary, t: Combatant, point: Vector2) -> CombatResult:
	var e := enc()
	var roll := e.dice.roll_one(100, "Wand of Wonder")
	var target := t if t != null else c
	var at := point if point != Vector2.INF else e.center_of(target)
	var nums := {"dc": Breakdown.new("Spell save DC").add("Wand of Wonder", 15), "attack": Breakdown.new("Spell attack").add("Wand of Wonder", 7),
		"mod": 0, "ability": &"int"}
	e.log.add("roll", "%s waves the Wand of Wonder: %d" % [c.name(), roll], c.id)
	var dir := (e.center_of(target) - e.center_of(c)).normalized()
	if roll <= 5:
		return _wonder_cast(c, "slow", [target], at, dir, nums)
	if roll <= 10:
		return _wonder_cast(c, "faerie_fire", [], at, dir, nums)
	if roll <= 15:
		var fx := Effect.new("Wand of Wonder", &"item", "wand_of_wonder")
		fx.conditions.append(&"stunned")
		fx.ends = Effect.Ends.START_OF_TURN
		fx.turn_owner_id = c.id
		c.creature.add_effect(fx)
		e.log.add("condition", "%s is Stunned until their next turn, convinced something amazing just happened" % c.name(), c.id)
		return CombatResult.new()
	if roll <= 20:
		return _wonder_cast(c, "gust_of_wind", [], at, dir, nums)
	if roll <= 25:
		e.log.add("info", "%s hears %s's surface thoughts for a moment (Detect Thoughts)" % [c.name(), target.name()], c.id)
		return CombatResult.new()
	if roll <= 30:
		return _wonder_cast(c, "stinking_cloud", [], at, dir, nums)
	if roll <= 33:
		_wonder_zone(c, at, 60, "light", 1, "Heavy rain")
		return CombatResult.new()
	if roll <= 36:
		var beast := ["rhinoceros", "elephant", "rat"][e.dice.roll_one(3, "Wand of Wonder beast") - 1] as String
		if items().comp().monster_data(beast).is_empty():
			e.log.add("info", "An animal appears near %s and bolts off into the dark" % target.name(), c.id)
			return CombatResult.new()
		return summon(c, beast, 1, at, {"name": beast.capitalize()}, "Wand of Wonder")
	if roll <= 46:
		return _wonder_cast(c, "lightning_bolt", [], at, dir, nums)
	if roll <= 49:
		_wonder_zone(c, e.center_of(c), 30, "heavy", 100, "A cloud of butterflies")
		return CombatResult.new()
	if roll <= 53:
		return _wonder_cast(c, "enlarge_reduce", [target], at, dir, nums, {"choice": "enlarge"})
	if roll <= 58:
		return _wonder_cast(c, "darkness", [], at, dir, nums)
	if roll <= 62:
		e.log.add("info", "Grass sprouts all over the ground within 60 ft of %s" % target.name(), c.id)
		return CombatResult.new()
	if roll <= 65:
		e.log.add("info", "Something small near %s winks out of existence" % target.name(), c.id)
		return CombatResult.new()
	if roll <= 69:
		return _wonder_cast(c, "enlarge_reduce", [c], e.center_of(c), dir, nums, {"choice": "reduce"})
	if roll <= 79:
		return _wonder_cast(c, "fireball", [], at, dir, nums)
	if roll <= 84:
		return _wonder_cast(c, "invisibility", [c], e.center_of(c), dir, nums)
	if roll <= 87:
		e.log.add("info", "Leaves sprout from %s; they wither after a day" % target.name(), c.id)
		return CombatResult.new()
	if roll <= 90:
		var gems := e.dice.roll_one(4, "Gems") * 10
		var cells := e.spells.area_for(c, {"area": {"shape": "line", "size": 30, "width": 5}, "range": {"kind": "self"}}, Vector2.INF, dir)
		e.log.add("info", "%d gems shoot out in a 30-ft line" % gems, c.id)
		for o in e.spells.creatures_in(cells):
			if o != c and o.is_alive():
				var hits := maxi(1, gems / 5)
				e.deal_damage(c, o, [{"amount": hits, "type": "bludgeoning"}], false, "Wand of Wonder gems")
		return CombatResult.new()
	if roll <= 95:
		for o2 in e.living():
			if e.distance(c, o2) <= 30:
				var sv := o2.creature.roll_save(e.dice, &"con", 15, [], [], "Con save (Wand of Wonder light)", ["save_vs:spell"])
				if not sv.success:
					var fb := Effect.new("Wand of Wonder", &"item", "wand_of_wonder")
					fb.conditions.append(&"blinded")
					fb.lasting_rounds(10, c.id)
					fb.repeat_save = {"ability": "con", "dc": 15, "when": "end"}
					o2.creature.add_effect(fb)
					e.log.add("condition", "%s is Blinded by the shimmering light" % o2.name(), o2.id)
		return CombatResult.new()
	if roll <= 97:
		e.log.add("info", "%s's skin turns bright blue for 1d10 days" % target.name(), target.id)
		return CombatResult.new()
	return _wonder_cast(c, "flesh_to_stone", [target], at, dir, nums)


func _wonder_cast(c: Combatant, spell_id: String, targets: Array, at: Vector2, dir: Vector2, nums: Dictionary, opts: Dictionary = {}) -> CombatResult:
	var spell := items().comp().spell_data(spell_id)
	if spell.is_empty():
		enc().log.add("info", "The wand sputters (%s isn't in the game yet)" % spell_id.replace("_", " "), c.id)
		return CombatResult.new()
	var lvl := int(spell.get("level", 0))
	return items().cast(c, spell, lvl, targets, at, dir, nums, "free", opts, "%s (Wand of Wonder)" % spell.get("name", ""))


## A lingering cloud or downpour from the wand: obscurement on the squares around `at`.
func _wonder_zone(c: Combatant, at: Vector2, radius: int, obscured: String, rounds: int, label: String) -> void:
	var e := enc()
	var cells := e.spells.area_for(c, {"area": {"shape": "sphere", "size": radius}, "range": {"kind": "feet", "feet": 120}}, at, Vector2.ZERO)
	var o := FieldObject.new(FieldObject.Kind.ZONE, "wand_of_wonder", label)
	o.caster_id = c.id
	o.cells = cells
	o.cell = Vector2i(floori(at.x), floori(at.y))
	o.rules = {"obscured": obscured}
	o.rounds_left = rounds
	e.spells.zones.add(o, CombatResult.new())
	e.log.add("info", "%s fills a %d-ft radius" % [label, radius], c.id)


func _pay_cost(c: Combatant, cost: String) -> void:
	items()._pay(c, cost)


## Javelin of Lightning: the bolt's line (Dex DC 13, 4d6 Lightning) on the way, then the throw itself with 4d6 more.
func _javelin(c: Combatant, p: Dictionary, t: Combatant) -> CombatResult:
	var e := enc()
	var iid := str(p["item_id"])
	if t == null or e.distance(c, t) > 120:
		return CombatResult.fail("Choose a target within 120 ft")
	var option := e.option_by_id(c, "thrown:" + iid)
	if option.is_empty():
		return CombatResult.fail("Not carried")
	var dir := (e.center_of(t) - e.center_of(c)).normalized()
	var line := {"area": {"shape": "line", "size": e.distance(c, t), "width": 5}, "range": {"kind": "self"}}
	var cells := e.spells.area_for(c, line, Vector2.INF, dir)
	e.events.append({"type": "spell", "caster": c.id, "spell": "lightning_bolt", "cells": cells, "targets": []})
	e.log.add("spell", "%s hurls the Javelin of Lightning: it becomes a bolt of lightning" % c.name(), c.id)
	var rolled := e._roll_damage_dice("4d6", false, 0, "Javelin of Lightning")
	for o in e.spells.creatures_in(cells):
		if o == c or o == t or not o.is_alive():
			continue
		var sv := o.creature.roll_save(e.dice, &"dex", 13, [], [], "Dex save (Javelin of Lightning)", ["save_vs:spell"])
		var amount := int(rolled["total"]) if not sv.success else int(rolled["total"]) / 2
		e.deal_damage(c, o, [{"amount": amount, "type": "lightning"}], false, "Javelin of Lightning", [sv.describe(), str(rolled["text"])])
	return e.attack(c, t, "thrown:" + iid, {"extra_dice": [{"dice": "4d6", "type": "lightning", "label": "Javelin of Lightning"}]})


## Hammer of Thunderbolts: a thrown attack (20/60 ft); a hit unleashes a thunderclap (Con DC 17 or Stunned).
func _hammer_hurl(c: Combatant, p: Dictionary, t: Combatant) -> CombatResult:
	var e := enc()
	var ch := ch_of(c)
	var iid := str(p["item_id"])
	if t == null:
		return CombatResult.fail("Choose a target")
	var prof := WeaponProfile.build(ch, p["data"] as Dictionary, true, false)
	prof.normal_range = 20
	prof.long_range = 60
	var option := {"id": "thrown:" + iid, "label": prof.name, "kind": "thrown", "profile": prof, "melee": false, "range": [20, 60], "reach": 5}
	var why := e.attack_legal(c, t, option)
	if why != "":
		return CombatResult.fail(why)
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		e.spend_action(c)
		c.took_attack_action = true
		c.attacks_left = e.attacks_per_action(c) - 1
	else:
		return CombatResult.fail("No attacks left this turn")
	return e._resolve_attack(c, t, option, {"hammer_hurl": true})


## The thunderclap after a hurled Hammer of Thunderbolts hits.
func hammer_thunder(c: Combatant, target: Combatant) -> void:
	var e := enc()
	e.log.add("spell", "The hammer unleashes a thunderclap heard 300 ft away", c.id)
	for o in e.living():
		if o == c or e.distance(o, target) > 30:
			continue
		var sv := o.creature.roll_save(e.dice, &"con", 17, [], [], "Con save (Hammer of Thunderbolts)", ["save_vs:spell"])
		if not sv.success:
			var fx := Effect.new("Thunderclap", &"item", "hammer_of_thunderbolts")
			fx.caster_id = c.id
			fx.conditions.append(&"stunned")
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = c.id
			fx.skip_turn_ends = e.own_turn_skip(c)
			o.creature.add_effect(fx)
			e.log.add("condition", "%s is Stunned by the thunderclap" % o.name(), o.id, [sv.describe()])
			e.events.append({"type": "condition", "id": o.id})


## Dancing Sword: tossed, it hovers and attacks (up to four attacks, one per Bonus Action), then returns.
func _dance(c: Combatant, p: Dictionary, t: Combatant, toss: bool) -> CombatResult:
	var e := enc()
	var iid := str(p["item_id"])
	if t == null or not c.hostile_to(t):
		return CombatResult.fail("Choose an enemy")
	if e.distance(c, t) > 35:
		return CombatResult.fail("The sword can't fly that far (30 ft from you)")
	var option := e.option_by_id(c, "weapon:" + iid)
	if option.is_empty():
		return CombatResult.fail("Not carried")
	c.bonus_available = false
	var obj := e.spells.zones.object_of(c.id, "dancing_sword")
	if obj == null:
		obj = FieldObject.new(FieldObject.Kind.WEAPON, "dancing_sword", "Dancing Sword")
		obj.caster_id = c.id
		obj.rounds_left = 100000
		obj.rules = {"attacks": 0, "item": iid}
		obj.cell = e.spells._beside(c, t)
		e.spells.zones.add(obj, CombatResult.new())
		var fx := Effect.new("Dancing Sword", &"item", iid)
		fx.stack_key = "item_grant:dancing_sword"
		fx.data["powers"] = [{"id": "command", "name": "Dancing Sword: strike", "cost": "bonus", "custom": "dancing_sword_command", "targeting": "enemy", "range": 30}]
		c.creature.add_effect(fx)
	else:
		obj.cell = e.spells._beside(c, t)
		e.events.append({"type": "object", "id": obj.id, "kind": "weapon", "cell": obj.cell})
	e.log.add("info", "%s's sword %s and strikes at %s" % [c.name(), "leaps into the air" if toss else "flies", t.name()], c.id)
	obj.rules["attacks"] = int(obj.rules.get("attacks", 0)) + 1
	var r := e._resolve_attack(c, t, option, {"dancing": true})
	if int(obj.rules["attacks"]) >= 4:
		obj.ended = true
		e.spells.zones.prune()
		for fx2: Effect in c.creature.effects.duplicate():
			if fx2.stack_key == "item_grant:dancing_sword":
				c.creature.remove_effect(fx2)
		e.log.add("info", "The Dancing Sword flies back to %s's hand" % c.name(), c.id)
	return r


## Helm of Brilliance: the gems fire beams at everyone within 60 ft (Dex DC 17: Radiant equal to the gems left), and
## the helm is destroyed.
func _helm_bursts(c: Combatant) -> void:
	var e := enc()
	var it := items().active_item(c, "helm_of_brilliance")
	if it.is_empty():
		return
	var gems := (it["entry"] as Dictionary).get("gems", {}) as Dictionary
	var n := 0
	for k: String in gems:
		n += int(gems[k])
	e.log.add("spell", "%s's Helm of Brilliance bursts in a storm of light" % c.name(), c.id)
	for o in e.living():
		if o == c or e.distance(o, c) > 60:
			continue
		var sv := o.creature.roll_save(e.dice, &"dex", 17, [], [], "Dex save (Helm of Brilliance)", ["save_vs:spell"])
		if not sv.success:
			e.deal_damage(c, o, [{"amount": n, "type": "radiant"}], false, "Helm of Brilliance", [sv.describe()])
	var ch := ch_of(c)
	ch.unequip_item(str(it["id"]))
	ch.remove_one(str(it["id"]))


## When a fight starts: Blackrazor hastens its wielder once a day, the sword deciding when (at the start of a fight).
func combat_started() -> void:
	var e := enc()
	for c in e.combatants:
		for it in items().active(c):
			if not "blackrazor" in _specials(it):
				continue
			var entry := it["entry"] as Dictionary
			if int((entry.get("uses", {}) as Dictionary).get("haste", 0)) > 0:
				continue
			if not entry.has("uses"):
				entry["uses"] = {}
			(entry["uses"] as Dictionary)["haste"] = 1
			var haste := items().comp().spell_data("haste")
			if not haste.is_empty():
				var fx := Effect.new("Haste (Blackrazor)", &"item", str(it["id"]))
				fx.lasting_rounds(10, c.id)
				for m: Array in [["ac", {"value": 2}], ["advantage", {"on": "save:dex"}], ["flag", {"value": "hasted"}], ["speed_percent", {"value": 200}]]:
					fx.modifiers.append(Modifier.of(str(m[0]), m[1] as Dictionary, "Blackrazor", &"item"))
				c.creature.add_effect(fx)
				e.log.add("spell", "Blackrazor quickens %s (Haste)" % c.name(), c.id)
