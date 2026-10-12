class_name Oracles
extends RefCounted
## What the scouting and divining spells tell while exploring (Ashwin's answer to the spell audit, 2026-10-12;
## docs/rules/deviations.md, Scouting and divining), read from the place the party stands in and the story as it
## stands: the fights still waiting there (those that start on their own), its hidden finds, its traps, and Strahd's
## attention. What they find is marked found in StoryState; LocationMagic puts it on the map. Pure logic: no nodes.
## - Augury: weal (something still hidden here), woe (a fight still waits here), both, or neither.
## - Divination: one true answer: what waits here, or else where a hidden find is (it shows).
## - Commune: three answers: how closely Strahd watches, whether a fight waits here, whether anything's hidden here.
## - Contact Other Plane: an Intelligence save (DC 15) or 6d6 Psychic damage and no answer (never below 1 Hit Point
##   outside a fight); else five answers: every fight waiting here, and up to five hidden finds shown.
## - Commune with Nature: outdoors only; every hidden find here shows, and what waits here is named.
## - Clairvoyance, Arcane Eye: every trap here shows, and what waits here is named.
## - Legend Lore: a legend of the valley's bestiary entry fills in (studied: defenses and traits).
## - Scrying: the same for one of them, unless it makes its Wisdom save against the caster's spell save DC.
## - Unseen Servant: the nearest hidden trap within 30 ft is sprung harmlessly (disarmed).
## - Stone Shape, Passwall: the nearest locked or secret door within 30 ft opens.

const HANDLED: Array[String] = ["augury", "divination", "commune", "contact_other_plane", "commune_with_nature",
	"clairvoyance", "arcane_eye", "legend_lore", "scrying"]
const SELF_STARTING: Array[String] = ["enter_area", "open", "examine"]
## The valley's legends Legend Lore and Scrying can name (monster ids).
const LEGENDS: Array[String] = ["strahd_von_zarovich", "rahadin", "vampire_spawn", "baba_lysaga", "night_hag",
	"vladimir_horngaard", "sir_godfrey_gwilym", "kiril_stoyanovich", "the_grandsire", "izek_strazni", "exethanter",
	"rag_queen"]


## What `spell_id` tells, cast by `caster` where the party stands (`choice`: Legend Lore's and Scrying's legend).
static func cast(st: StoryState, caster: Character, spell_id: String, choice: String = "") -> String:
	var who := caster.name.get_slice(" ", 0)
	var here := st.location
	match spell_id:
		"augury":
			var woe := not waiting(st, here).is_empty()
			var weal := not hidden(st, here).is_empty()
			var omen := "Weal and woe" if weal and woe else ("Woe" if woe else ("Weal" if weal else "Nothing"))
			var why := ("something here still waits to fight you, and something here is still hidden" if weal and woe else
				("something here still waits to fight you" if woe else ("something here is still hidden" if weal else
				"the omens are empty: nothing here waits for you, and nothing here is hidden")))
			return "%s casts Augury. %s: %s." % [who, omen, why]
		"divination":
			var foes := waiting(st, here)
			if not foes.is_empty():
				return "%s casts Divination, and the answer comes plainly: %s still wait here." % [who, _foes_line(foes)]
			var finds := hidden(st, here)
			if not finds.is_empty():
				reveal(st, here, str(finds[0]["id"]))
				return "%s casts Divination, and the answer comes plainly: nothing waits here, but look at %s." % [who, finds[0]["label"]]
			return "%s casts Divination, and the answer comes plainly: there's nothing more here for you." % who
		"commune":
			var watched := str({"unnoticed": "Not yet", "watched": "He has noticed you", "marked": "Yes, closely",
				"hunted": "He is hunting you"}.get(str(StrahdPresence.tier(st).get("id", "")), "Not yet"))
			return "%s casts Commune. Is Strahd watching? %s. Does anything wait here? %s. Is anything hidden here? %s." % [who,
				watched, "Yes" if not waiting(st, here).is_empty() else "No", "Yes" if not hidden(st, here).is_empty() else "No"]
		"contact_other_plane":
			var save := caster.roll_save(DiceRoller.new(st.playthrough_seed + st.total_minutes()), &"int", 15, [], [],
				"Intelligence save vs Contact Other Plane (%s)" % caster.name)
			if not save.success:
				var hurt := int(DiceRoller.new(st.playthrough_seed + st.total_minutes() + 1).roll_expr("6d6", "Contact Other Plane")["total"])
				caster.hp = maxi(1, caster.hp - hurt)
				return "%s reaches for a mind beyond the world and it's too much: %d Psychic damage, and no answer." % [who, hurt]
			var shown: Array[String] = []
			for f: Dictionary in hidden(st, here).slice(0, 5):
				reveal(st, here, str(f["id"]))
				shown.append(str(f["label"]))
			var foes2 := waiting(st, here)
			return "%s's mind holds against the other plane, and it answers. %s %s" % [who,
				("Still waiting here: %s." % _foes_line(foes2)) if not foes2.is_empty() else "Nothing waits here.",
				("Look at %s." % ", ".join(shown)) if not shown.is_empty() else "Nothing here is hidden."]
		"commune_with_nature":
			var shown2: Array[String] = []
			for f: Dictionary in hidden(st, here):
				reveal(st, here, str(f["id"]))
				shown2.append(str(f["label"]))
			var foes3 := waiting(st, here)
			return "%s casts Commune with Nature, and the land answers. %s %s" % [who,
				("Hidden here: %s." % ", ".join(shown2)) if not shown2.is_empty() else "Nothing here is hidden.",
				("Waiting here: %s." % _foes_line(foes3)) if not foes3.is_empty() else "Nothing waits for you here."]
		"clairvoyance", "arcane_eye":
			var traps := find_traps(st, here)
			var foes4 := waiting(st, here)
			return "%s casts %s and looks the place over. %s %s" % [who, Compendium.shared().display_name("spells", spell_id),
				("%d trap%s show%s." % [traps.size(), "" if traps.size() == 1 else "s", "s" if traps.size() == 1 else ""]) if not traps.is_empty() else "No traps.",
				("Waiting: %s." % _foes_line(foes4)) if not foes4.is_empty() else "Nothing waits here."]
		"legend_lore":
			var id := choice if choice in LEGENDS else LEGENDS[0]
			Bestiary.learn(st, id)
			return "%s casts Legend Lore on %s: everything the tales know is in the bestiary now." % [who, _name(id)]
		"scrying":
			var id2 := choice if choice in LEGENDS else LEGENDS[0]
			var target := Monster.from_data(Compendium.shared().monster_data(id2))
			var dc := caster.spell_save_dc(str((caster.spellcasting[0] as Dictionary).get("class_id", ""))).total() \
				if not caster.spellcasting.is_empty() else 13
			var resist := target.roll_save(DiceRoller.new(st.playthrough_seed + st.total_minutes()), &"wis", dc, [], [],
				"Wisdom save vs Scrying (%s)" % target.name)
			if resist.success:
				return "%s casts Scrying, but %s feels the sensor and the vision clouds over." % [who, _name(id2)]
			Bestiary.learn(st, id2)
			return "%s watches %s through the sensor long enough to learn how it fights: the bestiary has it all now." % [who, _name(id2)]
	return ""


## The fights still waiting in `location_id` that start on their own: [{id, foes: {name: count}}].
static func waiting(st: StoryState, location_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var states := st.loc_state(location_id)["encounters"] as Dictionary
	for en: Variant in Compendium.shared().get_entry("locations", location_id).get("encounters", []):
		var spec := en as Dictionary
		var state: Variant = states.get(str(spec.get("id", "")), false)
		if state is bool and bool(state):
			continue
		if not str(spec.get("trigger", "")).get_slice(":", 0) in SELF_STARTING and str(state) != "started":
			continue
		if not StoryConditions.check(StoryConditions.encounter_when(spec), st):
			continue
		var foes := {}
		for m: Variant in spec.get("monsters", []):
			var md := m as Dictionary
			var nm := str(md.get("name", Compendium.shared().get_entry("monsters", str(md["monster"])).get("name", md["monster"])))
			foes[nm] = int(foes.get(nm, 0)) + 1
		out.append({"id": str(spec.get("id", "")), "foes": foes})
	return out


## The hidden finds in `location_id` not found yet whose condition holds: [{id, label}].
static func hidden(st: StoryState, location_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var found := st.loc_state(location_id)["found"] as Dictionary
	for p: Variant in Compendium.shared().get_entry("locations", location_id).get("props", []):
		var prop := p as Dictionary
		if str(prop.get("kind", "")) != "search" or bool(found.get(str(prop["id"]), false)):
			continue
		if not StoryConditions.check(str(prop.get("when", "")), st):
			continue
		out.append({"id": str(prop["id"]), "label": str(prop.get("label", "something"))})
	return out


static func reveal(st: StoryState, location_id: String, prop_id: String) -> void:
	(st.loc_state(location_id)["found"] as Dictionary)[prop_id] = true


## Every trap in `location_id` not yet found, sprung or disarmed (whose condition holds), marked found: their ids.
static func find_traps(st: StoryState, location_id: String) -> Array[String]:
	var out: Array[String] = []
	var states := st.loc_state(location_id)["traps"] as Dictionary
	for t: Variant in Compendium.shared().get_entry("locations", location_id).get("traps", []):
		var trap := t as Dictionary
		if str(states.get(str(trap["id"]), "")) != "" or not StoryConditions.check(str(trap.get("when", "")), st):
			continue
		states[str(trap["id"])] = "found"
		out.append(str(trap["id"]))
	return out


## Unseen Servant: the nearest trap within `ft` of `cell` in `location_id` that hasn't gone off or been disarmed, sprung
## harmlessly (disarmed). The trap, or {}.
static func spring_trap(st: StoryState, location_id: String, cell: Vector2i, ft: int = 30) -> Dictionary:
	var states := st.loc_state(location_id)["traps"] as Dictionary
	var best := {}
	var best_ft := ft + 1
	for t: Variant in Compendium.shared().get_entry("locations", location_id).get("traps", []):
		var trap := t as Dictionary
		if str(states.get(str(trap["id"]), "")) in ["disarmed", "triggered"] or not StoryConditions.check(str(trap.get("when", "")), st):
			continue
		for tc: Variant in trap.get("cells", []):
			var d := _feet(cell, Vector2i(int((tc as Array)[0]), int((tc as Array)[1])))
			if d < best_ft:
				best_ft = d
				best = trap
	if not best.is_empty():
		states[str(best["id"])] = "disarmed"
	return best


## Stone Shape, Passwall: the nearest locked or secret door within `ft` of `cell` opens (a secret one is found too).
## The door, or {}.
static func open_way(st: StoryState, location_id: String, cell: Vector2i, ft: int = 30) -> Dictionary:
	var ls := st.loc_state(location_id)
	var best := {}
	var best_ft := ft + 1
	for d: Variant in Compendium.shared().get_entry("locations", location_id).get("doors", []):
		var door := d as Dictionary
		var secret := int(door.get("secret_dc", 0)) > 0 and not bool((ls["found"] as Dictionary).get(str(door["id"]), false))
		var locked := (bool(door.get("locked", false)) or int(door.get("lock_dc", 0)) > 0) \
			and not str((ls["doors"] as Dictionary).get(str(door["id"]), "")) in ["unlocked", "open", "broken"] \
			and not (door.has("unlocked_when") and StoryConditions.check(str(door["unlocked_when"]), st))
		if not secret and not locked:
			continue
		var dist := _feet(cell, Vector2i(int((door["cell"] as Array)[0]), int((door["cell"] as Array)[1])))
		if dist < best_ft:
			best_ft = dist
			best = door
	if not best.is_empty():
		(ls["found"] as Dictionary)[str(best["id"])] = true
		(ls["doors"] as Dictionary)[str(best["id"])] = "unlocked"
	return best


static func _feet(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) * 5


static func _name(monster_id: String) -> String:
	return str(Compendium.shared().get_entry("monsters", monster_id).get("name", monster_id.capitalize()))


## "3 Zombies and a Ghoul" from the fights waiting.
static func _foes_line(fights: Array[Dictionary]) -> String:
	var all := {}
	for f: Dictionary in fights:
		for nm: String in f["foes"]:
			all[nm] = int(all.get(nm, 0)) + int(f["foes"][nm])
	var parts: Array[String] = []
	for nm: String in all:
		var n := int(all[nm])
		parts.append(("a %s" % nm) if n == 1 else ("%d %ss" % [n, nm]))
	if parts.size() > 1:
		return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]
	return parts[0] if not parts.is_empty() else "something"
