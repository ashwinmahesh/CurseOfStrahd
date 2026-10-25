class_name FieldItems
extends RefCounted
## Using magic items outside a fight (ADR 0012): from the inventory's item card. Powers that work like spells go through
## the combat engine on FieldCasting's peaceful board, so charges, DCs and lasting effects behave as in a fight;
## exploring spells (Detect Magic from a wand, Comprehend Languages from a helm) are recorded like FieldCasting's
## utility spells; the rest are the exploring and story powers only items have: a Manual's study, a Bag of Beans, an
## Alchemy Jug, a Robe of Useful Items' patches, Daern's Instant Fortress (a tower on the map: FortressSite), a Deck of Many
## Things.


## Copying a Spell Scroll into a Wizard's spellbook (Ashwin, 2026-10-18; 2024 PHB Wizard, "Copying a Spell into the
## Book", and 2024 DMG, Spell Scroll): a Wizard spell of a level the Wizard can prepare, not already in the book, for 2
## hours and 50 GP of inks per spell level, outside fights; then an Intelligence (Arcana) check against DC 10 plus the
## spell's level. On a success the spell goes into the book; success or failure, the scroll is destroyed, and the inks
## and hours are spent. {spell, level, dc, gp, minutes} for the inventory card to show before it's tried.
static func scroll_copy_terms(scroll_id: String) -> Dictionary:
	var sid := Character.scroll_spell_of(Compendium.shared().item_data(scroll_id))
	var lv := int(Compendium.shared().spell_data(sid).get("level", 0)) if sid != "" else 0
	return {"spell": sid, "level": lv, "dc": Character.SCROLL_COPY_DC_BASE + lv, "gp": lv * Character.COPY_GP_PER_LEVEL,
		"minutes": lv * Character.COPY_MINUTES_PER_LEVEL}


## Why `wizard` can't copy `scroll_id` now, or "": the spellbook rules (Character.copy_scroll_problem), then the inks.
static func copy_scroll_problem(st: StoryState, wizard: Character, scroll_id: String) -> String:
	var why := wizard.copy_scroll_problem(scroll_id)
	if why != "":
		return why
	var t := scroll_copy_terms(scroll_id)
	if st.gold < float(t["gp"]):
		return "Needs %d gp of inks; the party has %d" % [int(t["gp"]), int(st.gold)]
	return ""


## `wizard` copies the scroll `entry` (one of `holder`'s, `scroll_id`): pays the inks and the hours, rolls the Arcana
## check with `dice`, and uses the scroll up either way. {ok, copied, text, test}; ok false (nothing spent) if
## copy_scroll_problem says no or the scroll isn't there.
static func copy_scroll(st: StoryState, holder: Character, scroll_id: String, wizard: Character, dice: DiceRoller,
		entry: Dictionary = {}) -> Dictionary:
	var why := copy_scroll_problem(st, wizard, scroll_id)
	if why == "" and not holder.carries(scroll_id):
		why = "Not carried"
	if why != "":
		return {"ok": false, "copied": false, "text": why, "test": null}
	var t := scroll_copy_terms(scroll_id)
	var spell_name := Compendium.shared().display_name("spells", str(t["spell"]))
	var who := wizard.name.get_slice(" ", 0)
	st.gold -= float(t["gp"])
	st.advance_minutes(int(t["minutes"]))
	var test := wizard.roll_check(dice, &"arcana", int(t["dc"]), [], [], "%s copies %s (Arcana)" % [who, spell_name])
	holder.remove_one(scroll_id, entry)
	if test.success:
		wizard.copy_spell(str(t["spell"]))
		return {"ok": true, "copied": true, "test": test,
			"text": "%s copies %s into the spellbook (Arcana %d against DC %d). The scroll crumbles as the last line dries." % [who, spell_name, test.total, test.target]}
	return {"ok": true, "copied": false, "test": test,
		"text": "%s loses the thread of %s (Arcana %d against DC %d), and the scroll crumbles to dust." % [who, spell_name, test.total, test.target]}


## What `ch` can do with `item_id` right now: [{power_id, label, legal, reason, targeting, spell_id}] for powers marked
## `field` (or potions and scrolls, which are field powers by nature). `st`, when given, lets a power whose use depends on
## the story's state say why it can't be used now (Daern's Instant Fortress: one standing already, nobody to fold).
static func options(party: Array[Character], ch: Character, item_id: String, dice: DiceRoller, st: StoryState = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := FieldCasting._board(party, ch, dice)
	var c := e.get_c(ch.id)
	if c == null:
		return out
	for p in e.items.powers(c):
		if str(p["item_id"]) != item_id:
			continue
		var power := p["power"] as Dictionary
		if not bool(power.get("field", false)):
			continue
		var why := _field_why(e, c, p)
		var spell_id := CombatItems.power_spell(item_id, power)
		var spell := Compendium.shared().spell_data(spell_id) if spell_id != "" else {}
		var targeting := "self"
		if not spell.is_empty():
			var kind := str((spell.get("targets", {}) as Dictionary).get("kind", "self"))
			targeting = "ally" if kind in ["creature", "ally"] else "self"
		# A Spell Scroll is cast, not used: "Cast Find Familiar".
		var label := "Cast %s" % spell.get("name", spell_id) if bool(power.get("scroll", false)) and not spell.is_empty() else str(power.get("name", "Use"))
		var o := {"power_id": str(power.get("id", "")), "label": label, "legal": why == "", "reason": why,
			"targeting": targeting, "spell_id": spell_id, "text": str(power.get("text", "")), "choices": (power.get("choice", {}) as Dictionary).get("from", [])}
		# Universal Pantograph: what it could copy.
		if str(power.get("custom", "")) == "fr_duplicate":
			o["choices"] = FaerunItems.duplicable(ch)
		# The Golden Idol: the gemstones the holder carries, to turn into coin.
		if str(power.get("custom", "")) == "trade_to_coin":
			o["choices"] = ((power.get("params", {}) as Dictionary).get("from", []) as Array).filter(func(g: Variant) -> bool: return ch.carries(str(g)))
			if why == "" and (o["choices"] as Array).is_empty():
				o["legal"] = false
				o["reason"] = "No gemstones to change"
		# A power that brings back the dead (a Spell Scroll of Revivify, the Rod of Resurrection) is aimed at a dead party
		# member (the inventory's "<power> on <hero>"), legal while there's one it can reach.
		if FieldCasting.REVIVAL.has(spell_id):
			o["revive"] = true
			o["targeting"] = "dead"
			if why == "" and party.all(func(m: Character) -> bool: return not m.dead):
				o["legal"] = false
				o["reason"] = "Nobody in the party is dead"
		if str(power.get("custom", "")) == "ring_store":
			o["store"] = store_options(party, p)
			if why == "" and (o["store"] as Array).is_empty():
				o["legal"] = false
				o["reason"] = "Nobody can cast a spell that fits"
		# Daern's Instant Fortress: raise it in the open air, fold it from outside with nobody in it.
		if str(power.get("custom", "")) == "instant_fortress" and st != null and why == "":
			var fwhy := FortressSite.why_not_fold(st) if _fortress_mode(power) == "fold" else FortressSite.why_not_raise(st)
			if fwhy != "":
				o["legal"] = false
				o["reason"] = fwhy
		out.append(o)
	return out


## Ring of Spell Storing: the spells party members could cast into the ring now (any creature can, touching it), at
## each level the ring has room for and they have a slot to cast it at (a Pact Magic caster at any level from the
## spell's own up to its pact level, Character.storing_levels): [{caster, spell, level, base, slot, label}]. `slot` is the
## level of the slot that pays, `base` the spell's own level.
static func store_options(party: Array[Character], p: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cap := int(((p["power"] as Dictionary).get("params", {}) as Dictionary).get("capacity", 5))
	var room := cap - stored_levels(p["entry"] as Dictionary)
	for m in party:
		if m.hp <= 0 or m.dead:
			continue
		var seen := {}
		for k in m.known_spells():
			var sid := str(k["id"])
			var sd := Compendium.shared().spell_data(sid)
			var base := int(sd.get("level", 0))
			if seen.has(sid) or base < 1 or base > 5:
				continue
			seen[sid] = true
			for lvl in m.storing_levels(base, mini(5, room)):
				out.append({"caster": m.id, "spell": sid, "level": lvl, "base": base, "slot": m.storing_slot_for(lvl),
					"label": "%s: %s (level %d)" % [m.name.get_slice(" ", 0), sd.get("name", sid), lvl]})
	return out


## Spell levels already stored in a Ring of Spell Storing's entry.
static func stored_levels(entry: Dictionary) -> int:
	var used := 0
	for s: Variant in entry.get("stored", []):
		used += int((s as Dictionary).get("level", 1))
	return used


static func _field_why(e: Encounter, c: Combatant, p: Dictionary) -> String:
	var power := p["power"] as Dictionary
	var why := e.items.power_why(c, p)
	# Outside a fight, the action economy doesn't matter and "outside combat only" is exactly right.
	if why in ["Outside combat only", "Action already used", "Bonus Action already used", "Only one Magic action this turn"]:
		why = ""
	if why == "No effect in a fight":
		why = ""
	if why == "" and power.has("custom") and not str(power["custom"]) in FIELD_CUSTOM and not str(power["custom"]).begins_with("fr_") \
			and bool(power.get("combat", true)) == false:
		why = "Not built yet"
	# Lock openers work on a lock in the world: the door's or chest's right-click menu offers them.
	if why == "" and str(power.get("custom", "")) in ["chime_of_opening", "mystery_key"]:
		why = "Right-click a locked door or chest to use it"
	return why


const FIELD_CUSTOM: Array[String] = ["read_tome", "alchemy_jug", "bag_of_beans", "deck_of_many_things", "exalted_deeds", "vile_darkness",
	"manual_study", "instant_fortress", "rod_of_security", "oil_of_sharpness", "ring_store", "sense_dragons", "useful_items",
	"flavour", "drink_field_spell", "chime_of_opening", "mystery_key", "wand_of_secrets", "feather_token", "paint_object", "trade_to_coin", "icon_augury"]


## Uses a power outside a fight. `target` is the creature it's used on (yourself if null): a party member, or a story
## ally travelling with the party (st.guests; owner, 2026-10-12) for a power aimed at a creature. Returns {ok, text,
## lines, effect}: `effect` names an exploring effect the world applies (a spell id like detect_magic, "secrets",
## "unlock", "long_rest").
static func use(st: StoryState, ch: Character, item_id: String, power_id: String, target: Creature, dice: DiceRoller,
		opts: Dictionary = {}) -> Dictionary:
	var e := FieldCasting._board(st.party, ch, dice, 5, st.guests)
	var c := e.get_c(ch.id)
	if c == null:
		return {"ok": false, "text": "%s isn't in the party" % ch.name, "lines": []}
	var p := e.items.find_power(c, item_id, power_id)
	if p.is_empty():
		return {"ok": false, "text": "Not carried", "lines": []}
	var why := _field_why(e, c, p)
	if why != "":
		return {"ok": false, "text": why, "lines": []}
	var power := p["power"] as Dictionary
	var data := p["data"] as Dictionary
	if power.has("custom") and str(power["custom"]) in FIELD_CUSTOM:
		if target != null and not target is Character:
			return {"ok": false, "text": "Only for the party", "lines": []}
		var res := _custom(st, ch, c, e, p, target as Character, dice, opts)
		if bool(res.get("ok", false)):
			e.items._after_use(c, p, {}, 0)
		return res
	# Heroes of Faerûn and Arcana Unleashed items' own field powers (combat/faerun_items.gd).
	if str(power.get("custom", "")).begins_with("fr_") and not bool(power.get("combat", true)):
		var fres := FaerunItems.field_use(ch, p, dice, opts)
		if bool(fres.get("ok", false)):
			e.items._after_use(c, p, {}, 0)
		return fres
	var spell_id := CombatItems.power_spell(item_id, power)
	var spell := Compendium.shared().spell_data(spell_id) if spell_id != "" else {}
	# A power that brings back the dead (Ashwin, 2026-10-15): a Spell Scroll of Revivify or Raise Dead, the Rod of
	# Resurrection, on a dead party member, for as long after the death as the spell allows (FieldCasting.revive_with_item).
	# A scroll above the reader's levels needs its check first and is used up either way; nothing is spent on someone it
	# can't bring back.
	if FieldCasting.REVIVAL.has(spell_id):
		var dead := target as Character if target is Character else null
		if dead == null or not dead.dead or not dead in st.party:
			return {"ok": false, "text": "Choose a fallen party member to use it on", "lines": []}
		var rwhy := FieldCasting.revive_why(st, spell_id, dead)
		if rwhy != "":
			return {"ok": false, "text": rwhy, "lines": []}
		var lvl := int(power.get("level", spell.get("level", 0)))
		if bool(power.get("scroll", false)):
			var sfail := e.items.scroll_check(c, spell)
			e.items._after_use(c, p, spell, lvl)
			if sfail != "":
				st.advance_minutes(1)
				return {"ok": false, "text": sfail, "lines": [], "spent": true}
		else:
			e.items._after_use(c, p, spell, lvl)
		var rv := FieldCasting.revive_with_item(st, ch, spell_id, dead)
		rv["lines"] = []
		return rv
	# Catnap from an item (the Wand of Slumber): outside a fight its user and up to two companions sleep ten minutes and
	# wake with a Short Rest's benefits.
	if spell_id == "catnap" and not bool(power.get("scroll", false)):
		var slept: Array[String] = []
		for m: Character in [ch] + st.party.filter(func(o: Character) -> bool: return o != ch):
			if slept.size() >= 3 or m.hp <= 0 or m.dead:
				continue
			m.finish_short_rest()
			slept.append(m.name.get_slice(" ", 0))
		e.items._after_use(c, p, spell, int(spell.get("level", 3)))
		st.advance_minutes(10)
		return {"ok": true, "lines": [], "text": "%s: %s sleep ten minutes and wake rested, as after a Short Rest." % [spell.get("name", "Catnap"),
			", ".join(slept)]}
	# A Spell Scroll of an exploring spell (Find Familiar, Detect Magic, Light) is cast as when exploring, in the spell's
	# own time; one above the reader's levels needs its check first (2024 DMG), and the scroll is used up either way.
	if bool(power.get("scroll", false)) and not spell.is_empty() \
			and (not e.spells.has_combat_rules(spell) or FieldCasting.EXPLORING_TOO.has(spell_id)):
		var fail := e.items.scroll_check(c, spell)
		e.items._after_use(c, p, spell, int(spell.get("level", 0)))
		if fail != "":
			st.advance_minutes(1)
			return {"ok": false, "text": fail, "lines": [], "spent": true}
		var cast := FieldCasting.cast_from_scroll(st, ch, spell_id)
		cast["lines"] = []
		return cast
	# An exploring spell (no effect in a fight): recorded for its duration, as FieldCasting does.
	if not spell.is_empty() and not e.spells.has_combat_rules(spell) and not FieldCasting.EXPLORING_TOO.has(spell_id):
		var dur := spell.get("duration", {}) as Dictionary
		var unit_minutes := {"minutes": 1, "hours": 60, "days": 1440}
		var lasting: int = int(dur.get("amount", 1)) * int(unit_minutes.get(str(dur.get("kind", "")), 0))
		if lasting > 0:
			st.active_spells[spell_id] = {"until": st.total_minutes() + lasting, "caster": ch.id}
			if Effect.until_long_rest(dur):
				RestRules.keep_until_long_rest(st, spell_id)
		e.items._after_use(c, p, spell, int(power.get("level", spell.get("level", 0))))
		st.advance_minutes(1)
		return {"ok": true, "text": "%s uses the %s: %s." % [ch.name.get_slice(" ", 0), data.get("name", ""), spell.get("name", "")],
			"lines": [], "effect": spell_id}
	# `field_targets`: several creatures at once (the sheet's "4 of us" for a Staff of Healing's Mass Cure Wounds, ItemSpells).
	var tcs: Array = []
	for t: Variant in opts.get("field_targets", [target if target != null else ch]):
		var tc := e.get_c((t as Creature).id)
		if tc != null:
			tcs.append(tc)
	var cast_opts := opts.duplicate()
	cast_opts.erase("field_targets")
	# A spell that fills an area (a Staff of Healing's Mass Cure Wounds) is centred on its caster, in the middle of the party.
	var point := e.center_of(c) if spell.has("area") else Vector2.INF
	var before := e.log.entries.size()
	var r := e.items.use(c, item_id, power_id, tcs, point, Vector2.ZERO, int(opts.get("level", 0)), cast_opts)
	var lines: Array[String] = []
	for i in range(before, e.log.entries.size()):
		if str(e.log.entries[i]["kind"]) != "turn":
			lines.append(str(e.log.entries[i]["text"]))
	if not r.ok:
		return {"ok": false, "text": r.reason, "lines": lines}
	return {"ok": true, "text": "\n".join(lines), "lines": lines, "effect": spell_id}


## A potion given to a story ally outside a fight (owner, 2026-10-12; 2024: administering a potion is a Bonus Action):
## `to` drinks it, even when down, so its healing or what it grants is theirs, and it comes out of `ch`'s pack.
## Returns {ok, text, lines}.
static func give_potion(st: StoryState, ch: Character, item_id: String, power_id: String, to: Creature, dice: DiceRoller) -> Dictionary:
	var e := FieldCasting._board(st.party, ch, dice, 5, st.guests)
	var c := e.get_c(ch.id)
	var tc := e.get_c(to.id) if to != null else null
	if c == null or tc == null:
		return {"ok": false, "text": "Not here", "lines": []}
	if str(Compendium.shared().item_data(item_id).get("category", "")) != "potion":
		return {"ok": false, "text": "Only a potion is given to drink", "lines": []}
	var p := e.items.find_power(c, item_id, power_id)
	if p.is_empty():
		return {"ok": false, "text": "Not carried", "lines": []}
	var why := _field_why(e, c, p)
	if why != "":
		return {"ok": false, "text": why, "lines": []}
	var power := p["power"] as Dictionary
	var spell := Compendium.shared().spell_data(CombatItems.power_spell(item_id, power))
	if spell.is_empty():
		return {"ok": false, "text": "Nothing to do", "lines": []}
	var lvl := int(power.get("level", spell.get("level", 0)))
	var before := e.log.entries.size()
	var r := e.items.cast(tc, spell, lvl, [tc], Vector2.INF, Vector2.ZERO, e.items.numbers(c, p, lvl),
		CombatItems.power_cost(power, spell), {}, str((p["data"] as Dictionary).get("name", item_id)))
	var lines: Array[String] = []
	for i in range(before, e.log.entries.size()):
		if str(e.log.entries[i]["kind"]) != "turn":
			lines.append(str(e.log.entries[i]["text"]))
	if not r.ok:
		return {"ok": false, "text": r.reason, "lines": lines}
	e.items._grant(tc, tc, p)
	e.items._after_use(c, p, spell, lvl)
	return {"ok": true, "text": "\n".join(lines), "lines": lines}


# --- Exploring and story powers ------------------------------------------------------------------------

static func _custom(st: StoryState, ch: Character, c: Combatant, e: Encounter, p: Dictionary, target: Character, dice: DiceRoller,
		opts: Dictionary) -> Dictionary:
	var power := p["power"] as Dictionary
	var params := power.get("params", {}) as Dictionary
	var data := p["data"] as Dictionary
	var entry := p["entry"] as Dictionary
	var iid := str(p["item_id"])
	var label := str(data.get("name", ""))
	var who := target if target != null else ch
	var nm := ch.name.get_slice(" ", 0)
	match str(power["custom"]):
		"flavour":
			return {"ok": true, "text": "%s's %s %s." % [nm, label, params.get("text", "does something harmless")]}
		"icon_augury":
			# The Icon of Ravenloft's Augury: the same reading as the spell (story/oracles.gd), cast from the icon.
			return {"ok": true, "effect": "augury", "text": Campaign.module().cast_spell(st, ch, "augury")}
		"read_tome":
			# The Tome of Strahd (Curse of Strahd): its history goes into the codex; the vampire knows it was read.
			var lore := st.add_codex("tome_of_strahd")
			var first := lore >= 0
			if first:
				st.advance_minutes(3 * 60)
			st.set_flag("tome_of_strahd_read", true)
			st.set_flag("strahd_knows_tome_read", true)
			# Every reading plays the book as a conversation over its pictures (the power's params `dialogue`,
			# narrative/strahd/tome.dialogue: Strahd's own words, the Narrator filling in what he left out; Ashwin,
			# 2026-10-20); the inventory closes, starts it, and narrates `text` when it ends.
			return {"ok": true, "text": "%s reads the %s through. Somewhere, a door closes very quietly.%s" % [nm, label, Xp.tag(lore)] if first
				else "%s turns the pages again. The ending hasn't changed." % nm, "dialogue": str(params.get("dialogue", ""))}
		"drink_field_spell":
			var mins := int(params.get("minutes", 10))
			st.active_spells[str(params.get("spell", ""))] = {"until": st.total_minutes() + mins, "caster": who.id}
			st.advance_minutes(int(params.get("apply_minutes", 0)))
			e.items.specials.use(c, p, [e.get_c(who.id)], Vector2.INF, Vector2.ZERO, 0, opts)
			return {"ok": true, "text": "%s: %s for %d minutes." % [label, str(params.get("spell", "")).replace("_", " ").capitalize(), mins],
				"effect": str(params.get("spell", ""))}
		"trade_to_coin":
			# Golden Idol of Good Fortunes: a gemstone the holder touches becomes coins of the same worth (full value, where
			# a shop pays half).
			var gem := str(opts.get("choice", ""))
			if not gem in (params.get("from", []) as Array) or not ch.carries(gem):
				return {"ok": false, "text": "No such gemstone to change"}
			ch.remove_one(gem)
			var worth := float(Compendium.shared().item_data(gem).get("cost_gp", 0))
			st.gold += worth
			return {"ok": true, "text": "%s's idol turns the %s to coin: %d gp." % [nm, Compendium.shared().display_name("items", gem).to_lower(), roundi(worth)]}
		"paint_object":
			# Nolzur's Marvelous Pigments: a pot paints an object worth up to 25 GP, and it's real (one of the power's list).
			var object := str(opts.get("choice", ""))
			if not object in ((power.get("choice", {}) as Dictionary).get("from", []) as Array):
				return {"ok": false, "text": "Choose what to paint"}
			who.add_item(object)
			return {"ok": true, "text": "%s paints %s, and it's real." % [nm, Compendium.shared().display_name("items", object).to_lower()]}
		"alchemy_jug":
			var liquid := str(opts.get("choice", "fresh_water"))
			if liquid in ["acid", "basic_poison", "oil"]:
				ch.add_item(liquid)
			return {"ok": true, "text": "The jug fills with %s." % liquid.replace("_", " ")}
		"manual_study", "exalted_deeds", "vile_darkness":
			return _study(st, ch, p, opts)
		"instant_fortress":
			return _fortress(st, ch, power, opts)
		"rod_of_security":
			# A safe place to sleep wherever the party is, but still not within 16 hours of the last Long Rest (RestRules).
			var wait := RestRules.item_rest_refusal(st)
			if wait != "":
				return {"ok": false, "text": wait, "lines": []}
			# The same Long Rest as anywhere else (LongRest.take_safe): the guests, the miles walked, the spells cast on
			# waking, and Strahd's visit that may come to blows before them (`held`: the rest goes on once he's gone).
			var res := LongRest.take_safe(st, dice)
			if str(res["how"]) == LongRest.STRAHD:
				return {"ok": true, "effect": "long_rest", "held": true, "minutes": int(res["minutes"]),
					"text": "%s: the party beds down in safety. %s" % [label, res["text"]]}
			var said := "%s: the party rests in perfect safety and wakes refreshed." % label
			return {"ok": true, "effect": "long_rest", "minutes": int(res["minutes"]), "text": " ".join([said] + (res["lines"] as Array))}
		"oil_of_sharpness":
			var weapon := str(opts.get("choice", ""))
			if weapon == "":
				for en in who.inventory:
					var wd := Compendium.shared().item_data(str(en["id"]))
					if Gear.is_weapon(wd) and str((wd["weapon"] as Dictionary).get("damage_type", "")) in ["slashing", "piercing"] and str(en.get("slot", "")) != "":
						weapon = str(en["id"])
				if weapon == "":
					return {"ok": false, "text": "Hold a slashing or piercing weapon to coat"}
			var fx := Effect.new(label, &"item", iid)
			fx.lasting({"kind": "hours", "amount": 1})
			fx.modifiers.append(Modifier.of("attack", {"value": 3, "when": {"item": weapon}}, label, &"item"))
			fx.modifiers.append(Modifier.of("damage", {"value": 3, "when": {"item": weapon}}, label, &"item"))
			who.add_effect(fx)
			st.advance_minutes(1)
			return {"ok": true, "text": "%s's %s gleams: +3 for an hour." % [who.name.get_slice(" ", 0), Compendium.shared().display_name("items", weapon)]}
		"ring_store":
			return _store_spell(st, ch, p, opts)
		"sense_dragons":
			return {"ok": true, "text": "%s reaches out: no living dragon of its kind stirs within 30 miles of Barovia." % label}
		"useful_items":
			return _patch(st, ch, p, opts, dice)
		"bag_of_beans":
			return _bean(st, ch, dice)
		"deck_of_many_things":
			return DeckOfManyThings.draw(st, ch, clampi(int(str(opts.get("choice", "1"))), 1, 4), dice)
		"feather_token":
			match str(params.get("kind", "")):
				"bird":
					st.flags["travel_speed_today"] = st.day
					return {"ok": true, "effect": "travel", "text": "A Roc carries the party on its back: today's journeys take half the time."}
			return {"ok": true, "text": "The feather token works its magic (%s)." % str(params.get("kind", "")).replace("_", " ")}
		"wand_of_secrets":
			# The world finds the nearest secret door or trap (LocationView.apply_spell_effect("secrets")).
			return {"ok": true, "effect": "secrets", "text": "%s waves the Wand of Secrets." % nm}
	return {"ok": false, "text": "Not built yet"}


## Which of Daern's Instant Fortress's two powers `power` is: "raise" or "fold".
static func _fortress_mode(power: Dictionary) -> String:
	return str((power.get("params", {}) as Dictionary).get("mode", "raise"))


## Daern's Instant Fortress (story/fortress_site.gd): the first power sets the tower down in the open where the party
## stands, the second folds it back into the statuette. The world dresses the map (`effect`: fortress_raise or
## fortress_fold, LocationMagic). `opts.plot` is the plot the live map found (FortressSite.plot_in); without one it is
## worked out from the saved state.
static func _fortress(st: StoryState, ch: Character, power: Dictionary, opts: Dictionary) -> Dictionary:
	var nm := ch.name.get_slice(" ", 0)
	if _fortress_mode(power) == "fold":
		var fold_why := FortressSite.why_not_fold(st)
		if fold_why != "":
			return {"ok": false, "text": fold_why, "lines": []}
		FortressSite.fold(st)
		return {"ok": true, "effect": "fortress_fold", "lines": [],
			"text": "%s speaks the word again, and the tower shrinks back into the statuette." % nm}
	var why := FortressSite.why_not_raise(st)
	if why != "":
		return {"ok": false, "text": why, "lines": []}
	var plot: Dictionary = opts["plot"] as Dictionary if opts.has("plot") else FortressSite.plot_for(st)
	if plot.is_empty():
		return {"ok": false, "text": FortressSite.NO_ROOM, "lines": []}
	FortressSite.raise(st, plot, ch)
	return {"ok": true, "effect": "fortress_raise", "lines": [],
		"text": "%s sets the statuette down and speaks the word: a tower grows where the party stands, its door facing it." % nm}


## A manual or tome studied: +2 to a score and its maximum, for good; the book's magic is spent.
static func _study(st: StoryState, ch: Character, p: Dictionary, opts: Dictionary) -> Dictionary:
	var power := p["power"] as Dictionary
	var params := power.get("params", {}) as Dictionary
	var data := p["data"] as Dictionary
	var ab := str(params.get("ability", "wis"))
	var custom := str(power["custom"])
	if custom == "vile_darkness":
		ab = str(opts.get("choice", "int"))
	if custom == "exalted_deeds":
		ab = "wis"
	if not ch.build.has("item_boons"):
		ch.build["item_boons"] = []
	var boons := ch.build["item_boons"] as Array
	# A tome that stays (Exalted Deeds, Vile Darkness) gives its gift once; a manual is used up, and another copy of it
	# works again (the 2024 DMG doesn't stop anyone studying a second one).
	for b: Variant in boons:
		if custom != "manual_study" and str((b as Dictionary).get("source", "")) == str(data.get("name", "")):
			return {"ok": false, "text": "%s has already taken what this book can give" % ch.name}
	boons.append({"ability": ab, "value": 2, "max_raise": 2 if custom != "exalted_deeds" else 4, "source": str(data.get("name", ""))})
	if custom == "vile_darkness":
		var lower := "cha" if ab != "cha" else "wis"
		boons.append({"ability": lower, "value": -2, "max_raise": 0, "source": "%s (the price)" % data.get("name", "")})
	ch.refresh()
	st.advance_minutes((80 if custom != "manual_study" else 48) * 60)
	if custom == "manual_study":
		ch.remove_one(str(p["item_id"]))
		ch.add_item("book")
	return {"ok": true, "text": "%s studies the %s: %s rises by 2 (and so does its maximum)." % [ch.name.get_slice(" ", 0), data.get("name", ""),
		Creature.ABILITY_NAMES[StringName(ab)]]}


## Ring of Spell Storing / Ioun Stone of Reserve: the wearer casts a spell of level 1-5 into it, spending the slot.
## Ring of Spell Storing: `opts.caster` (a party member's id; the ring's holder if absent) casts `opts.spell` at
## `opts.level` into the ring, spending the slot. The spell keeps the caster's DC and attack bonus for that class.
static func _store_spell(st: StoryState, ch: Character, p: Dictionary, opts: Dictionary) -> Dictionary:
	var entry := p["entry"] as Dictionary
	var cap := int(((p["power"] as Dictionary).get("params", {}) as Dictionary).get("capacity", 5))
	var caster := ch
	for m in st.party:
		if m.id == str(opts.get("caster", "")):
			caster = m
	var spell_id := str(opts.get("spell", ""))
	var spell := Compendium.shared().spell_data(spell_id)
	var known := {}
	for k in caster.known_spells():
		if str(k["id"]) == spell_id:
			known = k
	if spell.is_empty() or known.is_empty():
		return {"ok": false, "text": "Choose a spell %s can cast" % caster.name.get_slice(" ", 0)}
	var lvl := maxi(int(spell.get("level", 0)), int(opts.get("level", 0)))
	if lvl < 1 or lvl > 5:
		return {"ok": false, "text": "Only spells of level 1 to 5"}
	var used := stored_levels(entry)
	if used + lvl > cap:
		return {"ok": false, "text": "Not enough room (%d of %d levels used)" % [used, cap]}
	var slot := caster.storing_slot_for(lvl)
	if not caster.expend_storing_slot(lvl):
		return {"ok": false, "text": "No slot left to cast a level %d spell with" % lvl}
	var cid := str(known.get("class_id", ""))
	var rec := {"spell": spell_id, "level": lvl, "dc": caster.spell_save_dc(cid).total(), "attack": caster.spell_attack_bonus(cid).total(),
		"ability": str(known.get("ability", "int"))}
	var stored := entry.get("stored", []) as Array
	stored.append(rec)
	entry["stored"] = stored
	return {"ok": true, "text": "%s casts %s (level %d%s) into the %s: %d of %d levels now stored." % [caster.name.get_slice(" ", 0),
		spell.get("name", ""), lvl, ", from a level %d Pact Magic slot" % slot if slot > lvl else "", (p["data"] as Dictionary).get("name", ""),
		used + lvl, cap]}


## Robe of Useful Items: a patch becomes what it shows.
static func _patch(st: StoryState, ch: Character, p: Dictionary, opts: Dictionary, dice: DiceRoller) -> Dictionary:
	var entry := p["entry"] as Dictionary
	var patches := entry.get("patches", []) as Array
	if patches.is_empty():
		return {"ok": false, "text": "No patches left"}
	var pick := str(opts.get("choice", patches[0]))
	if not pick in patches:
		pick = str(patches[0])
	patches.erase(pick)
	var items := {"dagger": "dagger", "bullseye_lantern": "bullseye_lantern", "mirror": "mirror", "pole": "pole", "rope": "rope", "sack": "sack"}
	var text := ""
	match pick:
		"bag_of_100_gp":
			st.gold += 100
			text = "a bag of 100 gp"
		"silver_coffer":
			st.gold += 500
			text = "a silver coffer worth 500 gp"
		"ten_gems":
			st.gold += 1000
			text = "ten gems worth 100 gp each"
		"potions_of_healing":
			ch.add_item("potion_of_healing", 4)
			text = "four Potions of Healing"
		"spell_scroll":
			var lvl := dice.roll_one(3, "Scroll level")
			var pool := Compendium.shared().spells_for("", lvl)
			if not pool.is_empty():
				var sp := pool[dice.roll_one(pool.size(), "Scroll spell") - 1]
				ch.add_item("spell_scroll__%s" % sp["id"])
				text = "a Spell Scroll of %s" % sp.get("name", "")
		_:
			if items.has(pick):
				ch.add_item(str(items[pick]))
			text = "a %s" % pick.replace("_", " ")
	if patches.is_empty():
		ch.remove_one(str(p["item_id"]))
		ch.add_item("robe")
	return {"ok": true, "text": "%s pulls off a patch: %s." % [ch.name.get_slice(" ", 0), text]}


## Bag of Beans (condensed 2024 table): what sprouts a minute after a bean is planted and watered.
static func _bean(st: StoryState, ch: Character, dice: DiceRoller) -> Dictionary:
	var roll := dice.roll_one(100, "Bag of Beans")
	var nm := ch.name.get_slice(" ", 0)
	if roll <= 1:
		return {"ok": true, "text": "Toadstools sprout. Eating one heals or poisons — %s decides not to try." % nm}
	if roll <= 10:
		return {"ok": true, "text": "A geyser erupts for a minute and drenches everyone nearby."}
	if roll <= 20:
		return {"ok": true, "text": "A treant sprouts and stalks off into the woods, wanting nothing to do with you."}
	if roll <= 30:
		return {"ok": true, "text": "An animate stone statue rises, glares at %s, and crumbles." % nm}
	if roll <= 40:
		return {"ok": true, "text": "A hot spring bubbles up; the party soaks and feels better (no other effect)."}
	if roll <= 50:
		ch.add_item("goodberry", 4)
		return {"ok": true, "text": "A bush of glowing berries grows: %s picks four magic berries." % nm}
	if roll <= 60:
		return {"ok": true, "text": "A tree grows with a tiny house and a friendly gnome inside, who waves."}
	if roll <= 70:
		st.gold += 100
		return {"ok": true, "text": "A pile of silver coins pushes out of the ground: 100 gp worth."}
	if roll <= 80:
		ch.add_item("potion_of_healing")
		return {"ok": true, "text": "A pod splits to show a Potion of Healing."}
	if roll <= 90:
		return {"ok": true, "text": "A giant beanstalk grows into the clouds... and wilts in Barovia's grey sky."}
	if roll <= 98:
		var fx := Effect.new("Bag of Beans: fireflies", &"item", "bag_of_beans")
		fx.lasting({"kind": "hours", "amount": 1})
		fx.modifiers.append(Modifier.of("advantage", {"on": "check:perception"}, "Bag of Beans", &"item"))
		ch.add_effect(fx)
		return {"ok": true, "text": "A cloud of fireflies circles %s for an hour, lighting the way." % nm}
	ch.add_item("bag_of_beans")
	return {"ok": true, "text": "A new Bag of Beans sprouts from the ground."}



## How much faster the party travels with the magic it carries (the best item counts once): a Carpet of Flying or a
## Feather Token's roc halves journeys, Horseshoes of a Zephyr or of Speed shorten them.
static func travel_mult(st: StoryState) -> float:
	if st == null:
		return 1.0
	var best := 1.0
	if int(st.flags.get("travel_speed_today", -1)) == st.day:
		best = 2.0
	for ch in st.party:
		for e in ch.inventory:
			var d := Compendium.shared().item_data(str(e["id"]))
			best = maxf(best, float((d.get("travel", {}) as Dictionary).get("speed_mult", 1.0)))
	return best
