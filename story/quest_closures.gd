class_name QuestClosures
extends RefCounted
## Quests that end by themselves (side quest failure plan, F1). A quest's data (data/quests) may list `closes` rules:
## {stage, when, from, leave, warn, old_saves}.
##   stage      the ending the rule moves the quest to: usually a failure, a quiet success (`recovering`) is allowed.
##   when       a condition (docs/contracts/dialogue.md; empty is always true): a clock (`quest_days.x >= 3`,
##              `days_since.flag >= 2`), the state of the world, or both.
##   from       the open stages the rule applies to (default: every open stage of the quest).
##   leave      a region id: the rule fires only as the party leaves that region, with `when` holding.
##   warn       the journal's amber line while the quest stands at a stage the rule applies to (QuestLog `warn`).
##   warn_when  a condition the warning also waits for (the danger shows itself: the temple's first voice), else always.
##   old_saves  also run when a save loads, for a stuck state an earlier version let a party reach (journal only, no
##              notice). Clocks never run on load: an old save has no honest start time.
## sweep() is called wherever the story can have moved: after a conversation or a fight, when the clock moves, on
## arrival, as the party leaves a region, and on load. Pure logic: the world shows what it returns.

## How many times sweep() looks again after a closure (a failure can set what another quest's rule reads).
const ROUNDS := 6


## The rules a quest's data lists.
static func rules(quest_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in Compendium.shared().get_entry("quests", quest_id).get("closes", []):
		out.append(r as Dictionary)
	return out


## Whether `rule` applies while the quest stands at `stage` (its `from`; every open stage when it names none).
static func applies(rule: Dictionary, stage: String) -> bool:
	var from := rule.get("from", []) as Array
	return from.is_empty() or stage in from


## The rule that closes the open quest `quest_id` now, or {}. `ctx`: `leaving` (the region the party is leaving, "" when
## it isn't) and `load` (a save was just loaded: only `old_saves` rules, and never one that waits for a departure).
static func firing(st: StoryState, quest_id: String, ctx: Dictionary = {}) -> Dictionary:
	if st.quest_stage(quest_id) == "" or st.quest_ended(quest_id):
		return {}
	var leaving := str(ctx.get("leaving", ""))
	var loading := bool(ctx.get("load", false))
	for rule: Dictionary in rules(quest_id):
		if not applies(rule, st.quest_stage(quest_id)):
			continue
		if loading and (not bool(rule.get("old_saves", false)) or str(rule.get("leave", "")) != ""):
			continue
		if str(rule.get("leave", "")) != "" and str(rule["leave"]) != leaving:
			continue
		if StoryConditions.check(str(rule.get("when", "")), st):
			return rule
	return {}


## Closes every open quest whose rule holds. Returns the notices to show ("Quest failed: X"), in the order they closed.
static func sweep(st: StoryState, ctx: Dictionary = {}) -> Array[String]:
	var said: Array[String] = []
	for _round in ROUNDS:
		var closed := false
		for quest_id: String in st.quests.keys():
			var rule := firing(st, quest_id, ctx)
			if not rule.is_empty() and st.set_quest_stage(quest_id, str(rule["stage"])):
				said.append(st.quest_notice())
				closed = true
		if not closed:
			break
	return said


## The region the party leaves by walking from location `from_id` to a location in `region`: "" when it stays in the
## same region (or has no place to leave).
static func region_left(from_id: String, region: String) -> String:
	if from_id == "":
		return ""
	var from_region := str(Compendium.shared().get_entry("locations", from_id).get("region", ""))
	return from_region if from_region != region else ""


## The journal's warning for an open quest: the first `warn` among the rules that apply at its stage (and whose
## `warn_when` holds), or "".
static func warning(st: StoryState, quest_id: String) -> String:
	if st.quest_stage(quest_id) == "" or st.quest_ended(quest_id):
		return ""
	for rule: Dictionary in rules(quest_id):
		if str(rule.get("warn", "")) != "" and applies(rule, st.quest_stage(quest_id)) \
				and StoryConditions.check(str(rule.get("warn_when", "")), st):
			return Campaign.module().fill(str(rule["warn"]), st)
	return ""


## The open quests that picking `ch` would close: those with a rule, at their stage, that names the hero with `term`
## (`gifted` for a dark gift, `fallen` for the altar's sacrifice), for the picker to mark (F4's broken seal). Names, in
## the journal's words.
static func closed_by_pick(st: StoryState, ch: Character, term: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("\\b%s:([a-z][a-z0-9_]*)" % term)
	for quest_id: String in st.quests.keys():
		if st.quest_stage(quest_id) == "" or st.quest_ended(quest_id):
			continue
		for rule: Dictionary in rules(quest_id):
			var m := re.search(str(rule.get("when", "")))
			if m != null and applies(rule, st.quest_stage(quest_id)) and StoryState.member_matches(ch, "name:" + m.get_string(1)):
				out.append(Compendium.shared().display_name("quests", quest_id))
				break
	return out
