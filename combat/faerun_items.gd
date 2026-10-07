class_name FaerunItems
extends RefCounted
## Heroes of Faerûn and Arcana Unleashed magic items whose rules need code (ADR 0012): Mage Breaker, Namer's Needle,
## the Keyholes daggers' shapes and second try, Dispelling and Goading Ammunition, Tramontane Armor's grip and
## Grave Reaper's lantern. ItemSpecials hands over `fr_` custom powers and the weapon specials named here.

var _specials: WeakRef

## The shapes each Keyholes dagger can take (besides its own): weapon item ids, or "simple_melee" for them all.
const KEYHOLE_FORMS := {
	"three_keyholes_dagger": ["handaxe", "mace"],
	"ten_keyholes_dagger": ["simple_melee"],
	"many_keyholes_dagger": ["simple_melee", "battleaxe", "longsword", "rapier", "scimitar", "warhammer"],
}


func _init(specials: ItemSpecials) -> void:
	_specials = weakref(specials)


func sp() -> ItemSpecials:
	return _specials.get_ref() as ItemSpecials


func items() -> CombatItems:
	return sp().items()


func enc() -> Encounter:
	return sp().enc()


func _log(kind: String, text: String, who: Combatant, details: Array = []) -> void:
	enc().log.add(kind, text, who.id if who != null else "", details)


static func _specials_of(it: Dictionary) -> Array:
	return ((it["data"] as Dictionary).get("weapon_rules", {}) as Dictionary).get("special", []) as Array


## The weapons a Keyholes dagger can become.
static func keyhole_forms(item_id: String) -> Array[String]:
	var out: Array[String] = []
	for f: Variant in KEYHOLE_FORMS.get(item_id, []):
		if str(f) == "simple_melee":
			for w in Compendium.shared().items_where("weapon"):
				if str((w.get("weapon", {}) as Dictionary).get("kind", "")) == "simple_melee" and not str(w["id"]) in out:
					out.append(str(w["id"]))
		elif not str(f) in out:
			out.append(str(f))
	return out


# --- Custom powers -----------------------------------------------------------------------------------------------------

func why(c: Combatant, p: Dictionary) -> String:
	var power := p["power"] as Dictionary
	var e := enc()
	match str(power.get("custom", "")):
		"fr_reshape":
			if e.current() != c:
				return "On your turn, as you attack"
			if c.attacks_left <= 0 and not c.action_available:
				return "Take the Attack action to reshape it"
		"fr_tramontane_pull":
			if not items().toggled(c, str(p["item_id"]), "grip"):
				return "Wake the armor's grip first"
		"fr_martial_throw":
			if e.current() != c:
				return "On your turn, as you attack"
		"fr_orb_sorcery":
			var ch := CombatItems.ch_of(c)
			if ch == null or ch.resource_max("sorcery_points") <= 0:
				return "Only a Sorcerer can draw on it"
			if ch.resource_left("sorcery_points") >= ch.resource_max("sorcery_points"):
				return "No Sorcery Points spent"
	return ""


func use(c: Combatant, p: Dictionary, targets: Array, _point: Vector2, _dir: Vector2, _level: int, opts: Dictionary) -> CombatResult:
	var power := p["power"] as Dictionary
	match str(power.get("custom", "")):
		"fr_reshape":
			return _reshape(c, p, str(opts.get("choice", "")))
		"fr_speak_name":
			c.set_meta("needle_named_crit", true)
			_log("info", "%s readies the true name on the Namer's Needle" % c.name(), c)
			return CombatResult.new()
		"fr_tramontane_pull":
			return _tramontane_pull(c, p, targets)
	return use_more(c, p, targets, _point, _dir, opts)


## After a power's use: Grave Reaper's lantern holds five fragments.
func after_power(c: Combatant, p: Dictionary) -> void:
	if str((p["power"] as Dictionary).get("after", "")) == "fr_lantern_capacity":
		c.set_meta("lantern_capacity", 5)


## The Keyholes daggers: another weapon's statistics until the start of the wielder's next turn, attacking and
## dealing damage with Strength or Dexterity, whichever is better.
func _reshape(c: Combatant, p: Dictionary, form: String) -> CombatResult:
	var iid := str(p["item_id"])
	var tpl := (p["data"] as Dictionary).get("template", {}) as Dictionary
	var base := str(tpl.get("default", "dagger"))
	if form == "" or form == base:
		form = base
	elif not form in keyhole_forms(iid.get_slice("__", 0)):
		return CombatResult.fail("It can't become that")
	for fx: Effect in c.creature.effects.duplicate():
		if fx.stack_key == "keyhole:%s" % iid:
			c.creature.remove_effect(fx)
	var name := Compendium.shared().display_name("items", form)
	var fx2 := Effect.new("%s (%s)" % [(p["data"] as Dictionary).get("name", ""), name], &"item", iid)
	fx2.stack_key = "keyhole:%s" % iid
	fx2.modifiers.append(Modifier.of("weapon_form", {"items": [iid], "form": form, "either_ability": true}, str((p["data"] as Dictionary).get("name", "")), &"item"))
	fx2.ends = Effect.Ends.START_OF_TURN
	fx2.turn_owner_id = c.id
	c.creature.add_effect(fx2)
	_log("info", "%s's dagger reshapes into a %s" % [c.name(), name], c)
	return CombatResult.new()


## Tramontane Armor: chosen creatures within 20 ft make a Strength save (DC 15) or are Grappled (escape DC 15) and
## pulled up to 20 ft toward the wearer.
func _tramontane_pull(c: Combatant, _p: Dictionary, targets: Array) -> CombatResult:
	var e := enc()
	var chosen: Array[Combatant] = []
	for x: Variant in targets:
		if x is Combatant and x != c and (x as Combatant).is_alive() and e.distance(c, x as Combatant) <= 20 and not chosen.has(x as Combatant):
			chosen.append(x as Combatant)
	if chosen.is_empty():
		return CombatResult.fail("Choose creatures within 20 ft")
	items()._pay(c, "bonus")
	for t in chosen:
		var sv := t.creature.roll_save(e.dice, &"str", 15, [], [], "Strength save vs Tramontane Armor (%s)" % t.name(), ["save_vs:grappled"])
		if sv.success:
			_log("info", "%s resists the armor's pull" % t.name(), t, [sv.describe()])
			continue
		if t.creature.add_condition(&"grappled", "Tramontane Armor"):
			e.grapples[t.id] = c.id
			t.set_meta("escape_dc", 15)
		e.forced_move(t, e.center_of(c), 20, true)
		_log("condition", "%s is seized and dragged toward %s (Tramontane Armor)" % [t.name(), c.name()], t, [sv.describe()])
		e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


# --- Weapon specials ---------------------------------------------------------------------------------------------------

## Before the hit's damage: Mage Breaker marks a concentrating target so its Concentration save has Disadvantage.
func hit_dice(_c: Combatant, target: Combatant, _option: Dictionary, _st: Dictionary, it: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if "mage_breaker" in _specials_of(it) and target.creature.concentration != null:
		target.set_meta("mage_broken", true)
	return out


func after_hit(c: Combatant, target: Combatant, option: Dictionary, dr: DamageResult, st: Dictionary, r: CombatResult, it: Dictionary) -> void:
	var e := enc()
	var label := str((it["data"] as Dictionary).get("name", ""))
	after_hit_more(c, target, option, st, r, it)
	for s: Variant in _specials_of(it):
		match str(s):
			"mage_breaker":
				target.remove_meta("mage_broken")
			"namers_needle":
				_needle(c, target, r)
			"dispelling":
				if dr.final > 0 and target.is_alive():
					var ended: Array[String] = []
					for fx: Effect in target.creature.effects.duplicate():
						if fx.source_kind == &"spell" and fx.spell_level <= 3:
							target.creature.remove_effect(fx)
							if fx.concentration != null and fx.concentration.source_id == fx.source_id:
								fx.concentration.end("dispelled")
							if not fx.name in ended:
								ended.append(fx.name)
					e.spells.zones.prune()
					r.lines.append(e.log.add("spell", "%s: %s" % [label, "ends " + ", ".join(ended) + " on " + target.name() if not ended.is_empty() else "no spell on %s to end" % target.name()], c.id))
			"goading":
				if dr.final > 0 and target.is_alive():
					var sv := target.creature.roll_save(e.dice, &"cha", 13, [], [], "Charisma save vs %s (%s)" % [label, target.name()])
					if sv.success:
						r.lines.append(e.log.add("info", "%s shrugs off the goad" % target.name(), target.id, [sv.describe()]))
					else:
						var fx2 := Effect.new(label, &"item", str(it["id"])).with_modifier("flag", {"value": "no_reactions"})
						fx2.ends = Effect.Ends.START_OF_TURN
						fx2.turn_owner_id = target.id
						target.creature.add_effect(fx2)
						r.lines.append(e.log.add("condition", "%s is goaded: no Reactions until its next turn" % target.name(), target.id, [sv.describe()]))


## Namer's Needle: a hit makes a creature that has a language save (Wisdom DC 15) or speak its name; one that saves
## is immune for the day.
func _needle(c: Combatant, target: Combatant, r: CombatResult) -> void:
	var e := enc()
	if not target.is_alive() or c.id in (target.get_meta("named_to", []) as Array) or c.id in (target.get_meta("needle_immune", []) as Array):
		return
	var langs := (target.creature as Monster).data.get("languages", []) as Array if target.creature is Monster else ["common"]
	if langs.is_empty():
		return
	var sv := target.creature.roll_save(e.dice, &"wis", 15, [], [], "Wisdom save vs Namer's Needle (%s)" % target.name())
	if sv.success:
		var imm := (target.get_meta("needle_immune", []) as Array).duplicate()
		imm.append(c.id)
		target.set_meta("needle_immune", imm)
		r.lines.append(e.log.add("info", "%s keeps its name to itself" % target.name(), target.id, [sv.describe()]))
		return
	var named := (target.get_meta("named_to", []) as Array).duplicate()
	named.append(c.id)
	target.set_meta("named_to", named)
	r.lines.append(e.log.add("info", "%s blurts out its true name (Namer's Needle)" % target.name(), target.id, [sv.describe()]))


## Namer's Needle: once a day, speaking a named creature's name turns a hit with the needle into a Critical Hit.
func makes_crit(c: Combatant, target: Combatant, option: Dictionary, details: Array[String]) -> bool:
	if not bool(c.get_meta("needle_named_crit", false)) or not c.id in (target.get_meta("named_to", []) as Array):
		return false
	var p := option.get("profile") as WeaponProfile
	if p == null or not p.item_id.begins_with("namers_needle"):
		return false
	c.remove_meta("needle_named_crit")
	details.append("Namer's Needle: %s's true name turns the hit into a Critical Hit" % target.name())
	return true


## Many Keyholes Dagger: once a day, a missed attack with it can be rolled again, keeping the new roll.
func after_miss_offers(st: Dictionary) -> Array:
	var out: Array = []
	var c := st["c"] as Combatant
	var t := st["t"] as D20Test
	var option := st["option"] as Dictionary
	var prof := option.get("profile") as WeaponProfile
	if prof == null or not prof.item_id.begins_with("many_keyholes_dagger") or CombatItems.ch_of(c) == null:
		return out
	var p := items().find_power(c, prof.item_id, "second_try")
	if p.is_empty() or CombatItems.uses_spent(p) >= CombatItems.use_count(p):
		return out
	var e := enc()
	out.append({"kind": "keyhole_reroll", "reactor": c, "title": "Second Try?",
		"text": "%d vs AC %d: a miss. Roll the attack again with the Many Keyholes Dagger and keep the new roll?" % [t.total, int(st["ac"])],
		"cost": "Once per day",
		"still": func() -> bool: return not t.success,
		"use": func() -> void:
			CombatItems.spend_use(p)
			var n := e.dice.d20("Many Keyholes Dagger reroll")
			t.set_natural(n, "Many Keyholes Dagger")
			e.log.add("info", "%s tries again with the Many Keyholes Dagger: %d" % [c.name(), n], c.id)})
	return out


# --- Staffs, rods, wands and orbs (batch 9b) ----------------------------------------------------------------------------

## Custom powers of the staffs, rods, wands and orbs.
func use_more(c: Combatant, p: Dictionary, targets: Array, point: Vector2, dir: Vector2, opts: Dictionary) -> CombatResult:
	var power := p["power"] as Dictionary
	var e := enc()
	var label := str((p["data"] as Dictionary).get("name", ""))
	match str(power.get("custom", "")):
		"fr_martial_throw":
			var fx := Effect.new("%s (thrown)" % label, &"item", str(p["item_id"]))
			fx.stack_key = "martial_throw:%s" % p["item_id"]
			fx.modifiers.append(Modifier.of("weapon_form", {"items": [str(p["item_id"])], "add_properties": ["thrown"], "range": [20, 60]}, label, &"item"))
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = c.id
			fx.skip_turn_ends = e.own_turn_skip(c)
			c.creature.add_effect(fx)
			_log("info", "%s's quarterstaff can be thrown and flies back (%s)" % [c.name(), label], c)
			return CombatResult.new()
		"fr_diamond_stun":
			c.set_meta("diamond_stun", str(p["item_id"]))
			_log("info", "%s readies a stunning blow with the %s" % [c.name(), label], c)
			return CombatResult.new()
		"fr_pulverize":
			var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
			if t == null or t == c or str(t.creature.creature_type) != "humanoid" or not e.can_see(c, t):
				return CombatResult.fail("Choose a Humanoid you can see")
			items()._pay(c, "magic")
			var sv := t.creature.roll_save(e.dice, &"con", 17, [], [], "Constitution save vs %s (%s)" % [label, t.name()])
			var rolled := e._roll_damage_dice("10d8", false, 0, label)
			var amount := int(rolled["total"]) / (2 if sv.success else 1)
			e.deal_damage(c, t, [{"amount": amount, "type": "necrotic"}], false, label, [sv.describe(), str(rolled["text"])])
			if not sv.success and t.is_alive():
				t.creature.add_condition(&"prone", label)
				e.events.append({"type": "condition", "id": t.id})
			return CombatResult.new()
		"fr_slumber_aura":
			items()._pay(c, "magic")
			for t in e.combatants:
				if t == c or not t.is_alive() or t.is_down() or not c.hostile_to(t) or e.distance(c, t) > 30:
					continue
				if str(t.creature.creature_type) in ["undead", "construct"] or t.creature.condition_immunity_source(&"exhaustion") != "":
					_log("info", "%s doesn't sleep" % t.name(), t)
					continue
				var sv2 := t.creature.roll_save(e.dice, &"con", 17, [], [], "Constitution save vs %s (%s)" % [label, t.name()])
				if sv2.success:
					_log("info", "%s fights off the drowsiness" % t.name(), t, [sv2.describe()])
					continue
				var nap := Effect.new(label, &"item", str(p["item_id"]))
				nap.conditions.append(&"unconscious")
				nap.lasting({"kind": "hours", "amount": 1})
				nap.ends_on_damage = true
				nap.data["wakeable"] = true
				t.creature.add_effect(nap)
				_log("condition", "%s falls into a deep sleep (%s)" % [t.name(), label], t, [sv2.describe()])
				e.events.append({"type": "condition", "id": t.id})
			return CombatResult.new()
		"fr_teeth":
			return _teeth(c, p, point, dir, int(str(opts.get("choice", "1"))))
		"fr_orb_sorcery":
			var ch := CombatItems.ch_of(c)
			var spent := ch.resource_max("sorcery_points") - ch.resource_left("sorcery_points")
			if spent <= 0:
				return CombatResult.fail("No Sorcery Points spent")
			items()._pay(c, "magic")
			ch.restore_resource("sorcery_points", mini(2, spent))
			_log("info", "%s draws %d Sorcery Points back from the orb" % [c.name(), mini(2, spent)], c)
			return CombatResult.new()
	return CombatResult.fail("Not built yet")


## Wand of Teeth: 1 to 3 charges for a 30-ft Cone; Dex DC 15, 1d8 Piercing per charge and Poisoned until the
## wielder's next turn starts, half damage only on a success.
func _teeth(c: Combatant, p: Dictionary, point: Vector2, dir: Vector2, n: int) -> CombatResult:
	var e := enc()
	var ch := CombatItems.ch_of(c)
	var iid := str(p["item_id"])
	n = clampi(n, 1, 3)
	if ch.charges_left(iid) < n:
		return CombatResult.fail("Not enough charges")
	var aim := dir if dir != Vector2.ZERO else ((point - e.center_of(c)) if point != Vector2.INF else Vector2.ZERO)
	if aim.length() < 0.01:
		return CombatResult.fail("Choose a direction")
	var cells := e.grid.area_cells("cone", 30, e.center_of(c), aim.normalized())
	items()._pay(c, "magic")
	ch.spend_charges(iid, n)
	var label := str((p["data"] as Dictionary).get("name", ""))
	e.events.append({"type": "ability", "source": "feature", "by": c.id, "key": "wand_of_teeth", "targets": [], "cells": cells})
	var rolled := e._roll_damage_dice("%dd8" % n, false, 0, label)
	for t in e.combatants:
		if t == c or not t.is_alive() or not t.footprint().any(func(cell: Vector2i) -> bool: return cell in cells):
			continue
		var sv := t.creature.roll_save(e.dice, &"dex", 15, [], [], "Dexterity save vs %s (%s)" % [label, t.name()])
		var amount := int(rolled["total"]) / (2 if sv.success else 1)
		e.deal_damage(c, t, [{"amount": amount, "type": "piercing"}], false, label, [sv.describe(), str(rolled["text"])])
		if not sv.success and t.is_alive():
			var fx := Effect.new(label, &"item", iid).with_condition(&"poisoned")
			fx.caster_id = c.id
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = c.id
			t.creature.add_effect(fx)
	if ch.charges_left(iid) <= 0:
		items().last_charge(c, iid, p["data"] as Dictionary)
	return CombatResult.new()


## Before an attack roll: a Staff of Skulls' holder can spend its Reaction to give an attack by a creature it sees
## within 30 ft Disadvantage; the Martialist's Quarterstaff's wielder can spend a charge for Advantage and a shove.
func before_roll(st: Dictionary, out: Array) -> void:
	var e := enc()
	var c := st["c"] as Combatant
	var sit := st["sit"] as Dictionary
	var option := st["option"] as Dictionary
	var prof := option.get("profile") as WeaponProfile
	if prof != null and prof.item_id.begins_with("martialists_quarterstaff") and bool(option.get("melee", true)) and CombatItems.ch_of(c) != null \
			and CombatItems.ch_of(c).charges_left(prof.item_id) > 0:
		var iid := prof.item_id
		out.append({"kind": "martialist_strike", "reactor": c, "title": "Martialist's Strike?",
			"text": "Spend a charge of the Martialist's Quarterstaff for Advantage, and a hit knocks the target Prone unless it makes a DC 13 Strength save?",
			"cost": "1 charge", "still": func() -> bool: return true,
			"use": func() -> void:
				CombatItems.ch_of(c).spend_charges(iid, 1)
				(sit["advantage"] as Array[String]).append("Martialist's Quarterstaff")
				st["martialist_prone"] = true})
	for h in e.combatants:
		if h == c or not h.is_alive() or not h.hostile_to(c) or not e.spells.can_react(h) or e.distance(h, c) > 30 or not e.can_see(h, c):
			continue
		var staff := ""
		for id: String in ["chattering_staff_of_skulls", "pulverizing_staff_of_skulls"]:
			if items().has_active(h, id):
				staff = id
		if staff == "":
			continue
		out.append({"kind": "staff_of_skulls", "reactor": h, "title": "Staff of Skulls?",
			"text": "%s attacks. Spend your Reaction so the staff's skulls shriek and the attack has Disadvantage?" % c.name(),
			"cost": "Your Reaction", "still": func() -> bool: return h.reaction_available,
			"use": func() -> void:
				h.reaction_available = false
				(sit["disadvantage"] as Array[String]).append("Staff of Skulls")
				e.log.add("reaction", "%s's staff of skulls shrieks at %s" % [h.name(), c.name()], h.id)})
		break


## Diamond Staff's stunning blow and the Martialist's Quarterstaff's shove, after a hit.
func after_hit_more(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary, r: CombatResult, it: Dictionary) -> void:
	var e := enc()
	var iid := str(it["id"])
	var label := str((it["data"] as Dictionary).get("name", ""))
	if bool(st.get("martialist_prone", false)) and iid.begins_with("martialists_quarterstaff") and target.is_alive():
		st.erase("martialist_prone")
		var sv := target.creature.roll_save(e.dice, &"str", 13, [], [], "Strength save vs %s (%s)" % [label, target.name()])
		if not sv.success and target.creature.add_condition(&"prone", label):
			r.lines.append(e.log.add("condition", "%s is knocked Prone (%s)" % [target.name(), label], target.id, [sv.describe()]))
	if str(c.get_meta("diamond_stun", "")) == iid and bool(option.get("melee", true)) and target.is_alive():
		c.remove_meta("diamond_stun")
		var ch := CombatItems.ch_of(c)
		if ch == null or ch.charges_left(iid) < 2:
			return
		ch.spend_charges(iid, 2)
		var sv2 := target.creature.roll_save(e.dice, &"con", 17, [], [], "Constitution save vs %s (%s)" % [label, target.name()], ["save_vs:stunned"])
		if not sv2.success:
			var fx := Effect.new(label, &"item", iid).with_condition(&"stunned")
			fx.caster_id = c.id
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = c.id
			fx.skip_turn_ends = e.own_turn_skip(c)
			target.creature.add_effect(fx)
			r.lines.append(e.log.add("condition", "%s is Stunned (%s)" % [target.name(), label], target.id, [sv2.describe()]))
		if ch.charges_left(iid) <= 0:
			items().last_charge(c, iid, it["data"] as Dictionary)


## Dissuader: when a creature moves within 5 ft of its holder, the holder can spend its Reaction (once a day) to
## make chosen creatures within 30 ft save (Strength DC 15) or be pushed up to 30 ft away.
func after_step(mover: Combatant, from: Vector2i) -> void:
	var e := enc()
	for h in e.combatants:
		if h == mover or not h.is_alive() or not h.hostile_to(mover) or e.distance(h, mover) > 5:
			continue
		if e.grid.distance_ft(from, mover.size_cells, h.cell, h.size_cells) <= 5:
			continue
		var p := {}
		for it in items().active(h):
			if str(it["id"]).begins_with("dissuader"):
				p = items().find_power(h, str(it["id"]), "repel")
		if p.is_empty() or CombatItems.uses_spent(p) >= CombatItems.use_count(p) or not e.spells.can_react(h) \
				or str(h.reaction_rules.get("dissuader_repel", "auto")) == "never":
			continue
		CombatItems.spend_use(p)
		h.reaction_available = false
		_log("reaction", "%s's Dissuader thrums: back!" % h.name(), h)
		for t in e.combatants:
			if t == h or not t.is_alive() or not h.hostile_to(t) or e.distance(h, t) > 30:
				continue
			var sv := t.creature.roll_save(e.dice, &"str", 15, [], [], "Strength save vs Dissuader (%s)" % t.name())
			if not sv.success:
				e.forced_move(t, e.center_of(h), 30)
				_log("info", "%s is thrown back (Dissuader)" % t.name(), t, [sv.describe()])
		return
