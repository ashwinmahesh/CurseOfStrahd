class_name GuidanceOffer
extends RefCounted
## Guidance before a skill check outside a fight (Ashwin, 2026-10-13: a conversation's check, a check on something in
## the world, a search, a lock forced, a pocket picked, a climb, tending the dying, haggling). Whoever in the party can
## cast it is offered before the roll, never after, so a failed check stays final.
##
## The 2024 spell: an action, touch range, Concentration up to a minute; a willing creature (the caster too) adds 1d4 to
## ability checks with the skill the caster picks. Outside a fight the caster steps over and touches whoever's about to
## try (unless they can't reach them: a pit's floor), picks that check's skill, and the minute goes on the check, so the
## d4 goes on this roll and the caster isn't left concentrating on it. Casting it does end any other spell the caster
## was concentrating on, and the prompt says so.
##
## Each caster's standing answer is their Character.reaction_rules["guidance"] (Ask, Automatic or Off; the prompt's
## "Next time", or the Reactions tab in a fight): Ask brings up the prompt (GuidancePrompt), Automatic casts it without
## asking when someone's free to (it never ends another spell on its own), Off leaves that caster out. With no screen to
## ask on (headless: the tests and the bots that play the story), Ask casts nothing.

## The rule's key in Character.reaction_rules.
const RULE := "guidance"
const SPELL := "guidance"
const RULES: Array[String] = ["ask", "auto", "never"]
## Headless runs show no prompt unless a test turns this on.
static var headless_too := false


## Whether a prompt can be shown here (not in a headless run).
static func can_ask() -> bool:
	return headless_too or DisplayServer.get_name() != "headless"


## What's on offer before `who` makes a `skill` check against `dc` (0: a DC the player doesn't see): {who, skill, dc,
## casters: [{caster, ends, rule}], auto}. `casters`: everyone in the party and its guests who could cast it on them
## now, free hands first; `ends` names the spell casting it would end ("" when there's none); `auto` is the free caster
## whose rule is Automatic, or null. `near`: the only ones close enough to touch `who`, when it isn't everyone (a pit).
## No casters for a plain ability check (Guidance names a skill) or when `who` has Guidance on this skill already.
static func offer(st: StoryState, who: Creature, skill: StringName, dc: int = 0, near: Array = []) -> Dictionary:
	var out := {"st": st, "who": who, "skill": skill, "dc": dc, "casters": [] as Array[Dictionary], "auto": null}
	if who == null or not Abilities.SKILLS.has(skill) or guided(who, skill):
		return out
	var free: Array[Dictionary] = []
	var keeping: Array[Dictionary] = []
	var all: Array = []
	all.append_array(st.party)
	all.append_array(st.guests)
	for cr: Variant in all:
		var c := cr as Creature
		if c == null or not can_cast(c) or (not near.is_empty() and not c in near):
			continue
		var rule := rule_of(c)
		if rule == "never":
			continue
		var ends := kept_spell(st, c)
		var entry := {"caster": c, "ends": str(ends.get("name", "")), "rule": rule}
		if ends.is_empty():
			free.append(entry)
		else:
			keeping.append(entry)
	var casters: Array[Dictionary] = []
	casters.append_array(free)
	casters.append_array(keeping)
	out["casters"] = casters
	for e in free:
		if str(e["rule"]) == "auto":
			out["auto"] = e["caster"]
			break
	return out


## The spell `c` is concentrating on, which casting Guidance would end: {name, id, field} (`field`: an exploring spell
## cast outside a fight, kept on StoryState.active_spells rather than on the caster), or {}.
static func kept_spell(st: StoryState, c: Creature) -> Dictionary:
	if c.concentration != null and not c.concentration.ended and c.concentration.source_id != SPELL:
		return {"name": c.concentration.name, "id": c.concentration.source_id, "field": false}
	for id: String in st.active_spells:
		var a := st.active_spells[id] as Dictionary
		if str(a.get("caster", "")) != c.id or not st.spell_active(id):
			continue
		var data := Compendium.shared().spell_data(id)
		if bool((data.get("duration", {}) as Dictionary).get("concentration", false)):
			return {"name": str(data.get("name", id)), "id": id, "field": true}
	return {}


## The prompt comes up for `o`: someone could cast it, nobody casts it on their own (Automatic), one of them is on Ask,
## and there's a screen to ask on.
static func asks(o: Dictionary) -> bool:
	return o.get("auto") == null and (o.get("casters", []) as Array).any(func(e: Dictionary) -> bool: return str(e["rule"]) == "ask") \
		and can_ask()


## The dice to add to the roll when nobody is asked: Guidance from the Automatic caster, if there is one.
static func automatic(o: Dictionary) -> Array:
	if o.get("auto") == null:
		return []
	return cast(o["st"] as StoryState, o["auto"] as Creature)


## The prompt's answer: caster `index` of `o` casts it (-1: nobody), and `rule` ("" to leave them be) is every offered
## caster's answer from now on. The dice to add to the roll.
static func answer(o: Dictionary, index: int, rule: String = "") -> Array:
	var casters := o.get("casters", []) as Array
	if rule in RULES:
		for e: Variant in casters:
			set_rule((e as Dictionary)["caster"] as Creature, rule)
	if index < 0 or index >= casters.size():
		return []
	return cast(o["st"] as StoryState, (casters[index] as Dictionary)["caster"] as Creature)


## `caster` casts it on whoever's about to try: the spell they were concentrating on ends (an exploring spell's time and the help it
## gave with checks too). The die for Creature.roll_d20's `extra_dice`, named for who gave it:
## [{dice: "1d4", source: "Guidance (Hedda)"}].
static func cast(st: StoryState, caster: Creature) -> Array:
	var kept := kept_spell(st, caster)
	if not kept.is_empty() and not bool(kept["field"]):
		caster.concentration.end("cast Guidance")
	elif not kept.is_empty():
		var id := str(kept["id"])
		st.active_spells.erase(id)
		for ch in st.party:
			for fx: Effect in ch.effects.duplicate():
				if fx.source_id == id:
					ch.remove_effect(fx)
	return [{"dice": "1d4", "source": "Guidance (%s)" % caster.name.get_slice(" ", 0)}]


## `cr` knows Guidance and can cast it now: conscious, able to act and to cast.
static func can_cast(cr: Creature) -> bool:
	if cr.dead or cr.hp <= 0 or cr.has_condition(&"unconscious") or cr.has_flag("no_actions") or cr.has_flag("cant_cast"):
		return false
	if cr is Character:
		return (cr as Character).knows_spell(SPELL)
	if cr is Monster:
		return SPELL in (((cr as Monster).data.get("spellcasting", {}) as Dictionary).get("at_will", []) as Array)
	return false


## Whether `who` already adds Guidance's die to `skill` checks (cast on them in a fight, or from the character sheet).
static func guided(who: Creature, skill: StringName) -> bool:
	var keys := who.check_keys(skill)
	for fx in who.effects:
		if fx.source_id == SPELL and fx.modifiers.any(func(m: Modifier) -> bool: return m.stat == &"bonus_die" and m.matches_any(keys)):
			return true
	return false


## `cr`'s standing answer: "ask" (the default), "auto" or "never". Only a party member keeps one.
static func rule_of(cr: Creature) -> String:
	if cr is Character:
		var r := str((cr as Character).reaction_rules.get(RULE, "ask"))
		return r if r in RULES else "ask"
	return "ask"


static func set_rule(cr: Creature, rule: String) -> void:
	if cr is Character and rule in RULES:
		(cr as Character).reaction_rules[RULE] = rule


## The skill as the prompt names it: "Animal Handling".
static func skill_name(skill: StringName) -> String:
	return str(skill).replace("_", " ").capitalize()
