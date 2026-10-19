class_name WorldChecks
extends RefCounted
## Skill checks on things in the world, outside fights and conversations (owner, 2026-10-09 and 2026-10-11: every skill
## should have real uses out there, Nature, Arcana and Acrobatics included). A prop, door or chest in a location can carry
## `checks` (data/schemas/location.schema.json `check`, docs/story/world_checks.md): a skill (or a plain ability) and a
## DC, the label the right-click menu shows, and what success and failure do.
##
## Who rolls: the party's best hand at it who hasn't tried it yet. Each character gets one try (the owner's rule that
## failed checks are final; `once`: one try for the whole party). The 2024 PHB's help comes before the roll: a party member
## proficient in the skill takes the Help action (Advantage) unless the thing is done `alone`, someone with Guidance may
## cast it for 1d4 (offered first, GuidanceOffer), and Helpful Friend adds its own Advantage (CheckAids). After a
## failure the roller can still spend Heroic Inspiration, a Lucky Foot or Tactical Mind on it (CheckAids.options).
##
## This file is the rules and the record (StoryState, the location's `checks` states). LocationChecks shows it on the
## board and does what reaches into the location (revealing, unlocking, moving the party, a fight).

## Plain ability checks a thing can ask for, besides the 18 skills.
const ABILITIES: Array[StringName] = [&"str", &"dex", &"con", &"int", &"wis", &"cha"]
## Minutes a check takes when its data doesn't say.
const MINUTES := 1


static func skill_of(check: Dictionary) -> StringName:
	return StringName(str(check.get("skill", "")))


static func is_skill(check: Dictionary) -> bool:
	return Abilities.SKILLS.has(skill_of(check))


## "Animal Handling", "Strength".
static func skill_name(check: Dictionary) -> String:
	var k := skill_of(check)
	if Abilities.SKILLS.has(k):
		return str(k).replace("_", " ").capitalize()
	return str(Creature.ABILITY_NAMES.get(k, str(k).capitalize()))


## The location's record of its checks: {<check id>: "done" | "spent", "tried:<check id>:<who>": true}. Made on first use,
## so older saves need no upgrade.
static func records(st: StoryState, loc_id: String) -> Dictionary:
	var ls := st.loc_state(loc_id)
	if not ls.has("checks"):
		ls["checks"] = {}
	return ls["checks"] as Dictionary


## Succeeded already.
static func done(st: StoryState, loc_id: String, check: Dictionary) -> bool:
	return str(records(st, loc_id).get(str(check["id"]), "")) == "done"


## Nothing more to try: it succeeded, or its one try for the party (`once`) failed.
static func spent(st: StoryState, loc_id: String, check: Dictionary) -> bool:
	return str(records(st, loc_id).get(str(check["id"]), "")) in ["done", "spent"]


static func tried(st: StoryState, loc_id: String, check: Dictionary, ch: Character) -> bool:
	return bool(records(st, loc_id).get(_tried_key(check, ch), false))


static func _tried_key(check: Dictionary, ch: Character) -> String:
	return "tried:%s:%s" % [check["id"], ch.id if ch.id != "" else ch.name]


## Shown in the menu now: its `when` holds, it isn't spent, and it still has something to do.
static func open(st: StoryState, loc_id: String, check: Dictionary) -> bool:
	return not spent(st, loc_id, check) and StoryConditions.check(str(check.get("when", "")), st) and not moot(st, loc_id, check)


## What a success can do that the party may already have done another way: finding, disarming, unlocking, opening.
const ONLY_WAYS: Array[String] = ["text", "reveal", "disarm", "unlock", "open"]


## Its success would only find, disarm, unlock or open things that already are (a Search found the satchel the climb
## would have reached): nothing left to try it for.
static func moot(st: StoryState, loc_id: String, check: Dictionary) -> bool:
	var win := check.get("success", {}) as Dictionary
	if win.keys().any(func(k: Variant) -> bool: return not str(k) in ONLY_WAYS) or win.keys().all(func(k: Variant) -> bool: return str(k) == "text"):
		return false
	var ls := st.loc_state(loc_id)
	for r: Variant in win.get("reveal", []):
		var ref := str(r)
		# Somewhere else's state is only read, never made (hovering mustn't add places to the save).
		var where := st.location_states.get(ref.get_slice(":", 0), {}) as Dictionary if ref.contains(":") else ls
		var id := ref.get_slice(":", 1) if ref.contains(":") else ref
		if not bool((where.get("found", {}) as Dictionary).get(id, false)) and str((where.get("traps", {}) as Dictionary).get(id, "")) == "":
			return false
	for t: Variant in win.get("disarm", []):
		if not str((ls["traps"] as Dictionary).get(str(t), "")) in ["disarmed", "triggered"]:
			return false
	for u: Variant in win.get("unlock", []):
		if not str((ls["doors"] as Dictionary).get(str(u), "")) in ["unlocked", "open"]:
			return false
	for o: Variant in win.get("open", []):
		if str((ls["doors"] as Dictionary).get(str(o), "")) != "open":
			return false
	return true


## The checks on a thing that are open now.
static func open_checks(st: StoryState, loc_id: String, spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Variant in spec.get("checks", []):
		if open(st, loc_id, c as Dictionary):
			out.append(c as Dictionary)
	return out


static func able(ch: Character) -> bool:
	return ch != null and not ch.dead and ch.hp > 0 and not ch.has_condition(&"unconscious")


## The party member who'd roll `check` now: whoever has the best chance among the able members who haven't tried it
## (then the best bonus, then the leader first), or null when everyone has.
static func roller(st: StoryState, loc_id: String, check: Dictionary) -> Character:
	var best: Character = null
	var best_chance := -1.0
	var best_bonus := -99
	for ch in st.party:
		if not able(ch) or tried(st, loc_id, check, ch):
			continue
		var odds := _odds(st, loc_id, check, ch)
		var c := float(odds["chance"])
		if c > best_chance + 0.0001 or (absf(c - best_chance) <= 0.0001 and int(odds["bonus"]) > best_bonus):
			best = ch
			best_chance = c
			best_bonus = int(odds["bonus"])
	return best


## Someone able hasn't tried it yet (cheaper than `roller`, for hover names).
static func anyone_left(st: StoryState, loc_id: String, check: Dictionary) -> bool:
	return st.party.any(func(ch: Character) -> bool: return able(ch) and not tried(st, loc_id, check, ch))


## Who takes the Help action for `who` (2024 PHB: an ally proficient in the skill gives Advantage on the check), or null:
## a plain ability check takes no Help, nor does a thing done `alone`.
static func helper(st: StoryState, check: Dictionary, who: Character) -> Character:
	if bool(check.get("alone", false)) or not is_skill(check):
		return null
	var best: Character = null
	for ch in st.party:
		if ch != who and able(ch) and ch.skill_rank(skill_of(check)) > 0 and (best == null or ch.skill_rank(skill_of(check)) > best.skill_rank(skill_of(check))):
			best = ch
	return best


## Who'd cast Guidance on `who` first (2024 PHB: 1d4 on checks with the chosen skill), for the menu, or null: the
## caster on Automatic, else the first offered (GuidanceOffer) who isn't concentrating on another spell, which Guidance
## would end. Only for skill checks. Unless it's the Automatic caster, the player is asked before the roll
## (LocationView.ask_guidance), so the menu's chance leaves it out (Ashwin, 2026-10-13: asked, never added on its own).
static func guide(st: StoryState, check: Dictionary, who: Character) -> Creature:
	if not is_skill(check):
		return null
	var o := GuidanceOffer.offer(st, who, skill_of(check))
	if o["auto"] != null:
		return o["auto"] as Creature
	for e: Variant in o["casters"]:
		if str((e as Dictionary)["ends"]) == "":
			return (e as Dictionary)["caster"] as Creature
	return null


## What the menu shows: {who, helper, guide, guide_sure, bonus, advantage: [sources], disadvantage: [sources], chance},
## or {} when nobody's left to try. `guide_sure`: Guidance will be cast without asking (its caster is on Automatic), so
## the chance counts it.
static func preview(st: StoryState, loc_id: String, check: Dictionary) -> Dictionary:
	var who := roller(st, loc_id, check)
	if who == null:
		return {}
	return _odds(st, loc_id, check, who)


static func _odds(st: StoryState, loc_id: String, check: Dictionary, who: Character) -> Dictionary:
	var k := skill_of(check)
	var bonus := who.skill_bonus(k) if is_skill(check) else who.ability_check_bonus(k)
	var adv := _advantage(st, check, who)
	var dis := _disadvantage(st, loc_id, check)
	var src := who.d20_sources(who.check_keys(k))
	var all_adv: Array = []
	all_adv.append_array(src["advantage"] as Array)
	all_adv.append_array(adv)
	var all_dis: Array = []
	all_dis.append_array(src["disadvantage"] as Array)
	all_dis.append_array(dis)
	var g := guide(st, check, who)
	var sure := g != null and GuidanceOffer.rule_of(g) == "auto"
	return {"who": who, "helper": helper(st, check, who), "guide": g, "guide_sure": sure, "bonus": bonus.total(), "advantage": all_adv,
		"disadvantage": all_dis, "chance": chance(bonus.total(), int(check["dc"]), not all_adv.is_empty(), not all_dis.is_empty(), sure)}


## Advantage the party brings before the roll: Help. (Helpful Friend spends a use, so it's asked for only when rolling.)
static func _advantage(st: StoryState, check: Dictionary, who: Character) -> Array[String]:
	var out: Array[String] = []
	var h := helper(st, check, who)
	if h != null:
		out.append("Help (%s)" % h.name.get_slice(" ", 0))
	return out


## Fog or a storm outdoors gives a Perception check Disadvantage, as on a Search.
static func _disadvantage(st: StoryState, loc_id: String, check: Dictionary) -> Array[String]:
	if skill_of(check) == &"perception":
		return Weather.sight_penalty(st, loc_id)
	return []


## The chance a d20 + `bonus` (+1d4 with `d4`) meets `dc`: Advantage and Disadvantage cancel out; a natural 1 or 20 is
## nothing special on an ability check (2024 PHB).
static func chance(bonus: int, dc: int, adv: bool, dis: bool, d4: bool = false) -> float:
	var total := 0.0
	var faces: Array[int] = [0]
	if d4:
		faces.assign([1, 2, 3, 4])
	for extra in faces:
		var need := dc - bonus - extra
		var p := clampf((21.0 - need) / 20.0, 0.0, 1.0)
		if adv and not dis:
			p = 1.0 - (1.0 - p) * (1.0 - p)
		elif dis and not adv:
			p = p * p
		total += p
	return total / faces.size()


## Rolls `check` for the party and records the try: {test, who, helper, success}, or {} when nobody can try. `extra`:
## dice cast on the roller first (Guidance, GuidanceOffer).
static func attempt(st: StoryState, loc_id: String, check: Dictionary, dice: DiceRoller, extra: Array = []) -> Dictionary:
	var who := roller(st, loc_id, check)
	if who == null:
		return {}
	var k := skill_of(check)
	var adv := _advantage(st, check, who)
	adv.append_array(CheckAids.before_check(who, k))
	var bonus := who.skill_bonus(k) if is_skill(check) else who.ability_check_bonus(k)
	var keys := who.check_keys(k)
	keys.append("world_check")
	var t := who.roll_d20(dice, D20Test.Kind.ABILITY_CHECK, bonus, int(check["dc"]), keys, adv, _disadvantage(st, loc_id, check),
		"%s: %s" % [who.name, str(check.get("label", skill_name(check)))], 20, extra)
	record(st, loc_id, check, who, t.success)
	st.advance_minutes(int(check.get("minutes", MINUTES)))
	return {"test": t, "who": who, "helper": helper(st, check, who), "success": t.success}


## Writes down how a try by `who` went (again after an aid turns a failure into a success).
static func record(st: StoryState, loc_id: String, check: Dictionary, who: Character, success: bool) -> void:
	var r := records(st, loc_id)
	r[_tried_key(check, who)] = true
	if success:
		r[str(check["id"])] = "done"
	elif bool(check.get("once", false)):
		r[str(check["id"])] = "spent"
	else:
		r.erase(str(check["id"]))
	st.last_check = success


## Does the part of an outcome (a check's `success` or `failure`) that lives in the story, for `who`: items and gold to
## them, a flag, a codex entry, Heroic Inspiration, healing or harm, time lost. Returns {gains: [String] for a toast,
## lines: [String] for the roll log, hurt: {who, amount (what got through), type} when it dealt damage}. Items aren't in
## `gains`: each has its own notice (StoryState.gain_item).
static func apply(st: StoryState, outcome: Dictionary, who: Character, dice: DiceRoller, source: String) -> Dictionary:
	var gains: Array[String] = []
	var lines: Array[String] = []
	var hurt := {}
	for e: Variant in outcome.get("items", []):
		var entry := e as Dictionary
		var qty := int(entry.get("qty", 1))
		st.gain_item(str(entry["id"]), qty, who)
	if float(outcome.get("gold", 0)) > 0.0:
		st.gold += float(outcome["gold"])
		gains.append("%d gold" % int(outcome["gold"]))
	if str(outcome.get("flag", "")) != "":
		st.set_flag(str(outcome["flag"]))
	var codex := outcome.get("codex", {}) as Dictionary
	if not codex.is_empty():
		var lore := st.add_codex(str(codex["id"]))
		if lore >= 0:
			gains.append("Added to the codex: %s%s" % [codex.get("title", codex["id"]), Xp.tag(lore)])
	if bool(outcome.get("inspiration", false)):
		var said := _inspire(st, who)
		if said != "":
			gains.append(said)
	if str(outcome.get("heal", "")) != "":
		for ch in st.party:
			if able(ch) and ch.hp < ch.max_hp():
				var healed := ch.heal(int(dice.roll_expr(str(outcome["heal"]), "%s (%s)" % [source, ch.name])["total"]), source)
				if healed > 0:
					lines.append("%s regains %d Hit Points" % [ch.name.get_slice(" ", 0), healed])
	if str(outcome.get("temp_hp", "")) != "":
		for ch in st.party:
			if able(ch):
				var n := int(dice.roll_expr(str(outcome["temp_hp"]), "%s (%s)" % [source, ch.name])["total"])
				if ch.add_temp_hp(n, source):
					lines.append("%s gains %d Temporary Hit Points" % [ch.name.get_slice(" ", 0), n])
	if str(outcome.get("damage", "")) != "" and who != null:
		var amount := int(dice.roll_expr(str(outcome["damage"]), source)["total"])
		var dr := who.take_damage(amount, StringName(str(outcome.get("damage_type", "bludgeoning"))), false, dice, source)
		lines.append(dr.describe(who.name))
		hurt = {"who": who, "amount": dr.final, "type": StringName(str(outcome.get("damage_type", "bludgeoning")))}
	if int(outcome.get("minutes", 0)) > 0:
		st.advance_minutes(int(outcome["minutes"]))
	return {"gains": gains, "lines": lines, "hurt": hurt}


## Heroic Inspiration for `who`; someone who already has it passes it to the first party member who lacks it (2024 PHB,
## as InCharacter does). Returns the notice, or "" when everyone has it.
static func _inspire(st: StoryState, who: Character) -> String:
	if who != null and not who.heroic_inspiration:
		who.heroic_inspiration = true
		return "%s gains Heroic Inspiration" % who.name.get_slice(" ", 0)
	for ch in st.party:
		if not ch.dead and not ch.heroic_inspiration:
			ch.heroic_inspiration = true
			return "Heroic Inspiration passes to %s" % ch.name.get_slice(" ", 0)
	return ""


## Every check in a location's data, with the thing that carries it: [{check, spec, list}] (`list`: "props", "doors" or
## "containers").
static func all_in(loc: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in ["props", "doors", "containers"]:
		for t: Variant in loc.get(key, []):
			for c: Variant in (t as Dictionary).get("checks", []):
				out.append({"check": c, "spec": t, "list": key})
	return out


## The check `check_id` on thing `spec`, or {}.
static func find(spec: Dictionary, check_id: String) -> Dictionary:
	for c: Variant in spec.get("checks", []):
		if str((c as Dictionary)["id"]) == check_id:
			return c as Dictionary
	return {}
