class_name Trade
extends RefCounted
## Prices at a merchant (U11's trading half, plan §5.6): what a shop asks and offers follows the merchant's attitude to
## the party and a Persuasion haggle, and a shop can keep stock that changes with the days (the Vistani trader). The
## numbers are ours: the 2024 rules leave a merchant's prices to the DM (docs/rules/deviations.md). StoryState's shop
## functions and the shop screen read this; it changes nothing but the haggle's flags.
##
## A haggle is one Persuasion check by the hero at the counter against the shop's DC (HAGGLE_DC unless its `haggle`
## block says). Won, the merchant treats the party as good customers for good: 10% off what they sell, 10% more for
## what they buy. Lost, the party can't try that merchant again until a later day; a shop whose `haggle` names a
## `lost` flag (Bildrath) never haggles again. A shop can name its own `won` and `lost` flags so its dialogue and
## the screen share one haggle.

## [what the party pays, what the merchant pays] as factors on the shop's own prices, by the merchant's attitude.
const ATTITUDE := {"friendly": [0.9, 1.1], "indifferent": [1.0, 1.0], "hostile": [1.25, 0.75]}
## The same for a won haggle, on top of the attitude.
const HAGGLED: Array[float] = [0.9, 1.1]
const HAGGLE_DC := 15


static func shop(npc_id: String) -> Dictionary:
	return Compendium.shared().get_entry("npcs", npc_id).get("shop", {}) as Dictionary


# --- Prices ---------------------------------------------------------------------------------------

## What the party pays for something whose shop price (markup or set price included) is `base`.
static func buy_price(st: StoryState, npc_id: String, base: float) -> float:
	var f := float((ATTITUDE.get(st.attitude(npc_id), [1.0, 1.0]) as Array)[0])
	if haggle_state(st, npc_id) == "won":
		f *= HAGGLED[0]
	for pf: Variant in shop(npc_id).get("price_flags", []):
		var p := pf as Dictionary
		if base >= float(p.get("min_price", 0)) and StoryConditions.check(str(p["if"]), st):
			f *= float(p.get("buy", 1.0))
	return snappedf(base * f, 0.01)


## What the merchant pays for something they'd give `base` for at an indifferent counter.
static func sell_price(st: StoryState, npc_id: String, base: float) -> float:
	var f := float((ATTITUDE.get(st.attitude(npc_id), [1.0, 1.0]) as Array)[1])
	if haggle_state(st, npc_id) == "won":
		f *= HAGGLED[1]
	return snappedf(base * f, 0.01)


## The terms at this counter in a few words, for the shop screen: "You pay ×0.9 · they pay ×1.1".
static func terms(st: StoryState, npc_id: String) -> String:
	var a := ATTITUDE.get(st.attitude(npc_id), [1.0, 1.0]) as Array
	var buy := float(a[0])
	var sell := float(a[1])
	if haggle_state(st, npc_id) == "won":
		buy *= HAGGLED[0]
		sell *= HAGGLED[1]
	return "You pay ×%s · they pay ×%s" % [_factor(buy), _factor(sell)]


static func _factor(f: float) -> String:
	return str(snappedf(f, 0.01))


# --- Haggling -------------------------------------------------------------------------------------

static func haggle_dc(npc_id: String) -> int:
	return int((shop(npc_id).get("haggle", {}) as Dictionary).get("dc", HAGGLE_DC))


## "won" (good customers for good), "lost" (no more tries: today, or for good where the shop says) or "" (they may try).
static func haggle_state(st: StoryState, npc_id: String) -> String:
	var h := shop(npc_id).get("haggle", {}) as Dictionary
	if bool(st.get_flag(str(h.get("won", "_haggle_won/" + npc_id)), false)):
		return "won"
	if str(h.get("lost", "")) != "" and bool(st.get_flag(str(h["lost"]), false)):
		return "lost"
	return "lost" if int(st.get_flag("_haggle_failed/" + npc_id, 0)) == st.day else ""


## Why the party can't haggle with `npc_id` now ("" if they can).
static func why_no_haggle(st: StoryState, npc_id: String) -> String:
	var name_ := Compendium.shared().display_name("npcs", npc_id).get_slice(" ", 0)
	match haggle_state(st, npc_id):
		"won":
			return "%s already gives you the good-customer price" % name_
		"lost":
			var h := shop(npc_id).get("haggle", {}) as Dictionary
			return "%s won't haggle again" % name_ if str(h.get("lost", "")) != "" else "%s won't haggle again today" % name_
	if st.attitude(npc_id) == "hostile":
		return "%s won't bargain with you" % name_
	return ""


## `ch` haggles with `npc_id`: a Persuasion check against the shop's DC, rolled in the open. Records the result and
## returns the test, or null if the party can't haggle now.
static func haggle(st: StoryState, npc_id: String, ch: Character, dice: DiceRoller) -> D20Test:
	if ch == null or ch.hp <= 0 or why_no_haggle(st, npc_id) != "":
		return null
	var dc := haggle_dc(npc_id)
	var test := ch.roll_check(dice, &"persuasion", dc, CheckAids.before_check(ch, &"persuasion"))
	var h := shop(npc_id).get("haggle", {}) as Dictionary
	if test.success:
		st.set_flag(str(h.get("won", "_haggle_won/" + npc_id)), true)
	elif str(h.get("lost", "")) != "":
		st.set_flag(str(h["lost"]), true)
	else:
		st.set_flag("_haggle_failed/" + npc_id, st.day)
	return test


# --- Stock that changes ---------------------------------------------------------------------------

## A shop's `rotating` stock as it stands this stretch of days: `count` things from its `pool`, one of each, picked
## again every `days` days (the same picks for the same days in a playthrough). Each line's stock_id carries the
## stretch, so what the party bought comes back with the next stretch's picks.
static func rotation(st: StoryState, npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rot := shop(npc_id).get("rotating", {}) as Dictionary
	var pool: Array = (rot.get("pool", []) as Array).duplicate()
	if pool.is_empty():
		return out
	var stretch := stretch_of(st, npc_id)
	var rng := DiceRoller.new(hash("%d:rotation:%s:%d" % [st.playthrough_seed, npc_id, stretch]))
	for i in mini(int(rot.get("count", 3)), pool.size()):
		var id := str(pool.pop_at(rng.roll_one(pool.size(), "Trader's stock") - 1))
		out.append({"id": id, "qty": 1, "stock_id": "%s@%d" % [id, stretch]})
	return out


## Which stretch of days a rotating shop is in (day 1 to `days` is stretch 0).
static func stretch_of(st: StoryState, npc_id: String) -> int:
	var days := maxi(1, int((shop(npc_id).get("rotating", {}) as Dictionary).get("days", 3)))
	return (st.day - 1) / days
