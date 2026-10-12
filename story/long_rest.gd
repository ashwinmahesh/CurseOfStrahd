class_name LongRest
extends RefCounted
## A Long Rest's eight hours (plan §5.2), wherever it's taken: the rest screen, the camp in the wild (LocationCamp) and
## the magic items that make a safe place to sleep (FieldItems). A risky place may interrupt it (a d6 shows 1, unless
## a ward keeps the rest or Alarm wakes the party first); an interrupted rest gives a Short Rest's benefits after an
## hour. A finished one takes eight hours off the clock and brings everything back (Creature.finish_long_rest), for the
## party and the guests travelling with it. Pure story logic: whoever started it shows what's returned and starts what
## follows the night (the Narrator's lines, Strahd's visit, a camp's night visitors).

const HOURS := 8
## How long after a Long Rest its morning lasts (game minutes): while it does, the rest screen still offers what a
## rest's end offers (the companions' words, the change of prepared spells), whatever closed it meanwhile (Strahd's
## night visit, the inventory a magic item's rest was taken from).
const MORNING_MINUTES := 60


## Takes the rest in a place whose rule is `rule` ("safe" or "risky": the place's, after the difficulty's safe rests).
## Returns {interrupted: bool, text: String, lines: Array[String]}: `text` says how the night went, `lines` what the
## inn and the spells cast as it ends add.
static func take(st: StoryState, rule: String, dice: DiceRoller) -> Dictionary:
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
		for ch in st.party:
			if not ch.dead:
				ch.finish_short_rest()
		return {"interrupted": true, "lines": [] as Array[String],
			"text": "Something moves in the dark, and nobody sleeps again. (Interrupted: a Short Rest's benefits only.)"}
	var lines := finish(st, dice)
	return {"interrupted": false, "text": "Eight hours pass. Everyone wakes rested, if not refreshed." + warned, "lines": lines}


## The rest's eight hours and what they bring back, once nothing has interrupted it: the clock, the 16 hours until the
## next (RestRules), the miles walked since, every living member's and guest's Hit Points and features, nothing left
## over from a fight, the inn's comfort (F14) and the spells each hero casts on waking (RestCasts). Returns what the
## inn and those spells add, a line each.
static func finish(st: StoryState, dice: DiceRoller) -> Array[String]:
	st.advance_minutes(HOURS * 60)
	st.miles_since_long_rest = 0.0
	RestRules.note_long_rest(st)
	st.morning = {"at": st.total_minutes()}
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

