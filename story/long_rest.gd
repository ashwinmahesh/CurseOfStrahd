class_name LongRest
extends RefCounted
## A Long Rest's eight hours (plan §5.2), wherever it's taken: the rest screen, the camp (LocationCamp: wherever the
## place's rest is risky) and the magic items that make a safe place to sleep (FieldItems). A risky place may interrupt it (a d6 shows 1, unless
## a ward keeps the rest or Alarm wakes the party first) an hour in. A finished one takes eight hours off the clock and
## brings everything back (Creature.finish_long_rest), for the party and the guests travelling with it. Either way they
## slept, which ends Concentration (Creature.fall_asleep).
## Whatever comes at the party in the night comes before the rest's benefits (the owner, 2026-10-13): the night's
## visitors at camp, and a visit of Strahd's that may come to blows (StrahdPresence.may_fight). The party fights with
## what it had when it lay down; once the fight is won (or Strahd's visit is over without one), it lies down again
## and finishes the rest on its own (resume): the hours still to sleep, and an hour more for each fight (2024 PHB:
## a rest resumed after an interruption takes an extra hour per interruption; the 16 hours since the last Long Rest
## don't stop it). Until then the rest is broken (BROKEN, kept in the save). If foes still wait in the place, or
## nothing came that the party could fight (the rest screen's night, a camp where nothing finds a way in), nobody
## sleeps again and the hour slept gives a Short Rest's benefits (restless; 2024 PHB).
## Pure story logic: whoever started it shows what's returned and starts what follows the night (the Narrator's
## lines, Strahd's visit, a camp's night visitors).

const HOURS := 8
## How long after a Long Rest its morning lasts (game minutes): while it does, the rest screen still offers what a
## rest's end offers (the companions' words, the change of prepared spells), whatever closed it meanwhile (Strahd's
## night visit, the inventory a magic item's rest was taken from).
const MORNING_MINUTES := 60
## st.flags: the Long Rest something in the night broke into, until the party sleeps on or gives up (an underscore
## key: bookkeeping, not story): {start: the minute it began, left: minutes still to sleep (an hour more for each
## fight), at: the minute it broke, strahd: true when Strahd's visit broke it, night: whether the rest ran through the
## night (his visit's trigger)}.
const BROKEN := "_long_rest_broken"
## What a night's result says happened (`how`): it was slept through (the benefits are in); something came out of the
## dark (the d6), or Strahd's visit is coming (the benefits wait for the fight); nobody sleeps again (a Short Rest's
## benefits).
const SLEPT := "slept"
const DARK := "dark"
const STRAHD := "strahd"
const RESTLESS := "restless"


## Takes the rest in a place whose rule is `rule` ("safe" or "risky": the place's, after the difficulty's safe rests).
## Returns {how, interrupted: how isn't SLEPT, minutes: how long since it began, text: how the night went, lines: what
## the inn and the spells cast as it ends add}. DARK: the caller brings what came (the camp's visitors) or, with
## nothing to fight, ends the night (restless). STRAHD: the caller lets his visit play (game root `strahd_after_rest`).
static func take(st: StoryState, rule: String, dice: DiceRoller) -> Dictionary:
	var start := st.total_minutes()
	var interrupted := false
	var warned := ""
	if rule == "risky" and Wards.keeps_rest(st) == "":
		interrupted = dice.roll_one(6, "Long Rest interruption") == 1
	# Alarm: whatever comes in the night finds you awake and ready, and slinks off; you sleep again.
	if interrupted and Wards.alarmed(st):
		interrupted = false
		warned = " In the small hours the Alarm sounds; you're up before whatever it was gets close, and it slinks away."
	if interrupted:
		st.advance_minutes(60)
		_break(st, start, HOURS * 60 - 60, false)
		return _result(st, DARK, start, "Something moves in the dark, and the camp wakes to it.")
	return _sleep_on(st, dice, start, HOURS * 60, true, warned)


## A safe place's rest from a magic item (the Rod of Security; Daern's Instant Fortress is a place now, so its rest is
## take() in a `safe` map): never interrupted, but Strahd may still come in the night, and a visit that may come to
## blows comes before the benefits, as anywhere.
static func take_safe(st: StoryState, dice: DiceRoller) -> Dictionary:
	return _sleep_on(st, dice, st.total_minutes(), HOURS * 60, true)


## Whether a Long Rest is broken: something came in the night and the party hasn't slept on or given up yet.
static func broken(st: StoryState) -> bool:
	return st.flags.get(BROKEN, null) is Dictionary


## Whether the broken rest waits on Strahd's visit (it came, or is coming, before the rest's benefits).
static func waits_on_strahd(st: StoryState) -> bool:
	return broken(st) and bool((st.flags[BROKEN] as Dictionary).get("strahd", false))


## The broken rest's bookkeeping (BROKEN), or {}.
static func broken_rest(st: StoryState) -> Dictionary:
	return st.flags[BROKEN] as Dictionary if broken(st) else {}


## A fight in the broken night was won: finishing the rest takes an hour more (2024 PHB, an hour per interruption).
static func fought(st: StoryState) -> void:
	if broken(st):
		var b := st.flags[BROKEN] as Dictionary
		b["left"] = int(b.get("left", 0)) + 60


## The night's trouble is over (its fight won, Strahd's visit done): the party lies down again and sleeps the hours
## still left, then has the rest's benefits, the 16 hours since the last Long Rest notwithstanding. Strahd's visit
## isn't asked for again in a night he has already broken. If foes still wait in this place (RestRules), nobody sleeps
## again (restless). Returns what take() does; {} when no rest was broken.
static func resume(st: StoryState, dice: DiceRoller) -> Dictionary:
	if not broken(st):
		return {}
	var b := (st.flags[BROKEN] as Dictionary).duplicate()
	if not RestRules.waiting_fights(st, st.location).is_empty() and Wards.shelter(st) == "":
		return restless(st, "Enemies still prowl this place, and nobody sleeps again. (A Short Rest's benefits only.)")
	st.flags.erase(BROKEN)
	var again := "The night's trouble dealt with, the party lies down again and sleeps until it's done. "
	var res := _sleep_on(st, dice, int(b["start"]), int(b["left"]), not bool(b.get("strahd", false)))
	if str(res["how"]) == SLEPT:
		res["text"] = again + str(res["text"])
	return res


## The broken night is over, and nobody sleeps again: the hour slept before it broke gives the party a Short Rest's
## benefits (2024 PHB), and the next Long Rest may start whenever the place allows (the 16 hours count from a finished
## one). `text` says why; the d6's night by default.
static func restless(st: StoryState, text: String = "") -> Dictionary:
	var start := int(broken_rest(st).get("start", st.total_minutes()))
	st.flags.erase(BROKEN)
	for ch in st.party:
		if not ch.dead:
			ch.finish_short_rest()
	RestRules.note_short_rest(st)
	if text == "":
		text = "Something moves in the dark, and nobody sleeps again. (Interrupted: a Short Rest's benefits only.)"
	return _result(st, RESTLESS, start, text)


## Sleeps `left` minutes of the rest begun at `start`, then (unless `ask_strahd` is false) asks whether Strahd's visit
## tonight may come to blows: if so the rest breaks there, before its benefits; else they come (finish's).
static func _sleep_on(st: StoryState, dice: DiceRoller, start: int, left: int, ask_strahd: bool, warned: String = "") -> Dictionary:
	st.advance_minutes(left)
	var night := Campaign.module().night_between(start, st.total_minutes())
	if ask_strahd and Campaign.module().visit_may_fight(st, "rest", {"night": night}):
		_break(st, start, 0, true)
		(st.flags[BROKEN] as Dictionary)["night"] = night
		return _result(st, STRAHD, start, "Before dawn, the one on watch shakes everyone awake: something is out there.")
	var res := _result(st, SLEPT, start, "Eight hours pass. Everyone wakes rested, if not refreshed." + warned)
	res["lines"] = _benefits(st, dice)
	return res


## Notes the rest as broken (BROKEN): they'd slept before it came, which ends Concentration.
static func _break(st: StoryState, start: int, left: int, strahd: bool) -> void:
	st.flags[BROKEN] = {"start": start, "left": left, "at": st.total_minutes(), "strahd": strahd}
	for ch in st.party:
		if not ch.dead:
			ch.fall_asleep()
	for g in st.guests:
		if not g.dead:
			g.fall_asleep()


static func _result(st: StoryState, how: String, start: int, text: String) -> Dictionary:
	return {"how": how, "interrupted": how != SLEPT, "minutes": st.total_minutes() - start, "text": text,
		"lines": [] as Array[String]}


## The rest's eight hours and what they bring back, once nothing has interrupted it (the tests' and anything that
## needs no night: Strahd isn't asked): the clock, then the benefits.
static func finish(st: StoryState, dice: DiceRoller) -> Array[String]:
	st.advance_minutes(HOURS * 60)
	return _benefits(st, dice)


## What a finished rest brings back: the 16 hours until the next (RestRules), the miles walked since, every living
## member's and guest's Hit Points and features, nothing left over from a fight, the inn's comfort (F14) and the
## spells each hero casts on waking (RestCasts). Returns what the inn and those spells add, a line each.
static func _benefits(st: StoryState, dice: DiceRoller) -> Array[String]:
	st.miles_since_long_rest = 0.0
	RestRules.note_long_rest(st)
	st.morning = {"at": st.total_minutes()}
	st.flags.erase(RestRules.SHORT_CHANGE)   # the Long Rest offers those changes itself
	for ch in st.party:
		if not ch.dead:
			ch.finish_long_rest()
			EncounterSetup.clear_fight_effects(ch)
	for g in st.guests:
		if not g.dead:
			g.finish_long_rest()
	var lines: Array[String] = []
	var room := Services.after_long_rest(st)   # a room booked at the inn (F14)
	if room != "":
		lines.append(room)
	lines.append_array(RestCasts.after_long_rest(st.party, dice))
	return lines


## Whether the morning after the last Long Rest is still on (MORNING_MINUTES since it ended, and no Long Rest since).
static func morning_open(st: StoryState) -> bool:
	if st.morning.is_empty() or not st.flags.has(RestRules.DONE_AT):
		return false
	var at := int(st.morning.get("at", -1))
	return at == int(st.flags[RestRules.DONE_AT]) and st.total_minutes() - at <= MORNING_MINUTES
