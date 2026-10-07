class_name FieldItems
extends RefCounted
## Using magic items outside a fight (ADR 0012): from the inventory's item card. Powers that work like spells go through
## the combat engine on FieldCasting's peaceful board, so charges, DCs and lasting effects behave as in a fight;
## exploring spells (Detect Magic from a wand, Comprehend Languages from a helm) are recorded like FieldCasting's
## utility spells; the rest are the exploring and story powers only items have: a Manual's study, a Bag of Beans, an
## Alchemy Jug, a Robe of Useful Items' patches, Daern's Instant Fortress, a Deck of Many Things.


## What `ch` can do with `item_id` right now: [{power_id, label, legal, reason, targeting, spell_id}] for powers marked
## `field` (or potions and scrolls, which are field powers by nature).
static func options(party: Array[Character], ch: Character, item_id: String, dice: DiceRoller) -> Array[Dictionary]:
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
		var o := {"power_id": str(power.get("id", "")), "label": str(power.get("name", "Use")), "legal": why == "", "reason": why,
			"targeting": targeting, "spell_id": spell_id, "text": str(power.get("text", "")), "choices": (power.get("choice", {}) as Dictionary).get("from", [])}
		if str(power.get("custom", "")) == "ring_store":
			o["store"] = store_options(party, p)
			if why == "" and (o["store"] as Array).is_empty():
				o["legal"] = false
				o["reason"] = "Nobody can cast a spell that fits"
		out.append(o)
	return out


## Ring of Spell Storing: the spells party members could cast into the ring now (any creature can, touching it), at
## each level they have a slot for and the ring has room for: [{caster, spell, level, label}].
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
			for lvl in range(base, mini(5, room) + 1):
				if m.slots_left(lvl) > 0:
					out.append({"caster": m.id, "spell": sid, "level": lvl, "label": "%s: %s (level %d)" % [m.name.get_slice(" ", 0),
						sd.get("name", sid), lvl]})
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
	"flavour", "drink_field_spell", "chime_of_opening", "mystery_key", "wand_of_secrets", "feather_token"]


## Uses a power outside a fight. `target` is the character it's used on (yourself if null). Returns {ok, text, lines,
## effect}: `effect` names an exploring effect the world applies (a spell id like detect_magic, "secrets", "unlock",
## "long_rest").
static func use(st: StoryState, ch: Character, item_id: String, power_id: String, target: Character, dice: DiceRoller,
		opts: Dictionary = {}) -> Dictionary:
	var e := FieldCasting._board(st.party, ch, dice)
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
		var res := _custom(st, ch, c, e, p, target, dice, opts)
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
	# An exploring spell (no effect in a fight): recorded for its duration, as FieldCasting does.
	if not spell.is_empty() and not e.spells.has_combat_rules(spell) and not FieldCasting.EXPLORING_TOO.has(spell_id):
		var dur := spell.get("duration", {}) as Dictionary
		var unit_minutes := {"minutes": 1, "hours": 60, "days": 1440}
		var lasting: int = int(dur.get("amount", 1)) * int(unit_minutes.get(str(dur.get("kind", "")), 0))
		if lasting > 0:
			st.active_spells[spell_id] = {"until": st.total_minutes() + lasting, "caster": ch.id}
		e.items._after_use(c, p, spell, int(power.get("level", spell.get("level", 0))))
		st.advance_minutes(1)
		return {"ok": true, "text": "%s uses the %s: %s." % [ch.name.get_slice(" ", 0), data.get("name", ""), spell.get("name", "")],
			"lines": [], "effect": spell_id}
	var tc := e.get_c(target.id) if target != null else c
	var before := e.log.entries.size()
	var r := e.items.use(c, item_id, power_id, [tc] if tc != null else [], Vector2.INF, Vector2.ZERO, int(opts.get("level", 0)), opts)
	var lines: Array[String] = []
	for i in range(before, e.log.entries.size()):
		if str(e.log.entries[i]["kind"]) != "turn":
			lines.append(str(e.log.entries[i]["text"]))
	if not r.ok:
		return {"ok": false, "text": r.reason, "lines": lines}
	return {"ok": true, "text": "\n".join(lines), "lines": lines, "effect": spell_id}


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
		"read_tome":
			# The Tome of Strahd (Curse of Strahd): its history goes into the codex; the vampire knows it was read.
			var first := not "tome_of_strahd" in st.codex
			if first:
				st.codex.append("tome_of_strahd")
				st.advance_minutes(3 * 60)
			st.set_flag("tome_of_strahd_read", true)
			st.set_flag("strahd_knows_tome_read", true)
			return {"ok": true, "text": "%s reads the %s through. Somewhere, a door closes very quietly." % [nm, label] if first
				else "%s turns the pages again. The ending hasn't changed." % nm}
		"drink_field_spell":
			var mins := int(params.get("minutes", 10))
			st.active_spells[str(params.get("spell", ""))] = {"until": st.total_minutes() + mins, "caster": who.id}
			st.advance_minutes(int(params.get("apply_minutes", 0)))
			e.items.specials.use(c, p, [e.get_c(who.id)], Vector2.INF, Vector2.ZERO, 0, opts)
			return {"ok": true, "text": "%s: %s for %d minutes." % [label, str(params.get("spell", "")).replace("_", " ").capitalize(), mins],
				"effect": str(params.get("spell", ""))}
		"alchemy_jug":
			var liquid := str(opts.get("choice", "fresh_water"))
			if liquid in ["acid", "basic_poison", "oil"]:
				ch.add_item(liquid)
			return {"ok": true, "text": "The jug fills with %s." % liquid.replace("_", " ")}
		"manual_study", "exalted_deeds", "vile_darkness":
			return _study(st, ch, p, opts)
		"instant_fortress", "rod_of_security":
			for m in st.party:
				m.finish_long_rest()
			st.advance_minutes(8 * 60)
			return {"ok": true, "effect": "long_rest", "text": "%s: the party rests in perfect safety and wakes refreshed." % label}
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
	for b: Variant in boons:
		if str((b as Dictionary).get("source", "")) == str(data.get("name", "")):
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
	if not caster.expend_slot(lvl):
		return {"ok": false, "text": "No level %d slot left" % lvl}
	var cid := str(known.get("class_id", ""))
	var rec := {"spell": spell_id, "level": lvl, "dc": caster.spell_save_dc(cid).total(), "attack": caster.spell_attack_bonus(cid).total(),
		"ability": str(known.get("ability", "int"))}
	var stored := entry.get("stored", []) as Array
	stored.append(rec)
	entry["stored"] = stored
	return {"ok": true, "text": "%s casts %s (level %d) into the %s: %d of %d levels now stored." % [caster.name.get_slice(" ", 0),
		spell.get("name", ""), lvl, (p["data"] as Dictionary).get("name", ""), used + lvl, cap]}


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
