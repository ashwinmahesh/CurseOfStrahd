class_name Trade
extends RefCounted
## Prices at a merchant (U11's trading half, plan §5.6): what a shop asks and offers follows the merchant's attitude to
## the party and a Persuasion haggle, and a shop can keep stock that changes with the days (the Vistani trader). The
## numbers are ours: the 2024 rules leave a merchant's prices to the DM (docs/rules/deviations.md). StoryState's shop
## functions and the shop screen read this; it changes nothing but the haggle's flags.
##
## A haggle is one Persuasion check by the hero at the counter against the shop's DC (HAGGLE_DC unless its `haggle`
## block says). Won, the merchant treats the party as good customers for good: 10% off what they sell, 10% more for
## what they buy. Lost, that merchant never haggles with the party again (the owner's rule: a failed social check is
## final). A shop can name its own `won` and `lost` flags so its dialogue and the screen share one haggle (Bildrath).

## [what the party pays, what the merchant pays] as factors on the shop's own prices, by the merchant's attitude.
const ATTITUDE := {"friendly": [0.9, 1.1], "indifferent": [1.0, 1.0], "hostile": [1.25, 0.75]}
## The same for a won haggle, on top of the attitude.
const HAGGLED: Array[float] = [0.9, 1.1]
const HAGGLE_DC := 15


static func shop(npc_id: String) -> Dictionary:
	return Compendium.shared().get_entry("npcs", npc_id).get("shop", {}) as Dictionary


# --- Prices ---------------------------------------------------------------------------------------

## Every price is a whole number of gold pieces (owner, 2026-10-08): rounded up after the attitude and the haggle, so
## anything worth less than 1 gp costs, or fetches, 1 gp. Free things stay free. Shops, the trader, temples and inns
## all price through here.
static func whole_gp(gp: float) -> float:
	var v := snappedf(gp, 0.01)
	return 0.0 if v <= 0.0 else ceilf(v)


## What the party pays for something whose shop price (markup or set price included) is `base`.
static func buy_price(st: StoryState, npc_id: String, base: float) -> float:
	var f := float((ATTITUDE.get(st.attitude(npc_id), [1.0, 1.0]) as Array)[0])
	if haggle_state(st, npc_id) == "won":
		f *= HAGGLED[0]
	for pf: Variant in shop(npc_id).get("price_flags", []):
		var p := pf as Dictionary
		if base >= float(p.get("min_price", 0)) and StoryConditions.check(str(p["if"]), st):
			f *= float(p.get("buy", 1.0))
	return whole_gp(base * f)


## What the merchant pays for something they'd give `base` for at an indifferent counter.
static func sell_price(st: StoryState, npc_id: String, base: float) -> float:
	var f := float((ATTITUDE.get(st.attitude(npc_id), [1.0, 1.0]) as Array)[1])
	if haggle_state(st, npc_id) == "won":
		f *= HAGGLED[1]
	return whole_gp(base * f)


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


## "won" (good customers for good), "lost" (no more tries, ever) or "" (they may try).
static func haggle_state(st: StoryState, npc_id: String) -> String:
	var h := shop(npc_id).get("haggle", {}) as Dictionary
	if bool(st.get_flag(str(h.get("won", "_haggle_won/" + npc_id)), false)):
		return "won"
	if bool(st.get_flag(str(h.get("lost", "_haggle_lost/" + npc_id)), false)):
		return "lost"
	return ""


## Why the party can't haggle with `npc_id` now ("" if they can).
static func why_no_haggle(st: StoryState, npc_id: String) -> String:
	var name_ := Compendium.shared().display_name("npcs", npc_id).get_slice(" ", 0)
	match haggle_state(st, npc_id):
		"won":
			return "%s already gives you the good-customer price" % name_
		"lost":
			return "%s won't haggle again" % name_
	if st.attitude(npc_id) == "hostile":
		return "%s won't bargain with you" % name_
	return ""


## `ch` haggles with `npc_id`: a Persuasion check against the shop's DC, rolled in the open. Records the result and
## returns the test, or null if the party can't haggle now. `extra`: dice cast on them first (Guidance, GuidanceOffer).
static func haggle(st: StoryState, npc_id: String, ch: Character, dice: DiceRoller, extra: Array = []) -> D20Test:
	if ch == null or ch.hp <= 0 or why_no_haggle(st, npc_id) != "":
		return null
	var dc := haggle_dc(npc_id)
	var test := ch.roll_check(dice, &"persuasion", dc, CheckAids.before_check(ch, &"persuasion"), [], "", [], extra)
	var h := shop(npc_id).get("haggle", {}) as Dictionary
	st.set_flag(str(h.get("won" if test.success else "lost", ("_haggle_won/" if test.success else "_haggle_lost/") + npc_id)), true)
	return test


# --- Magic stock ----------------------------------------------------------------------------------

## How many of a magic item a shop keeps (Ashwin, 2026-10-14): one of anything lasting, three of a potion, scroll or
## other consumable, twenty pieces of ammunition (sold a piece at a time, StoryState.shop_lot). What the party buys
## stays bought (StoryState.shops).
const MAGIC_QTY := {"lasting": 1, "consumable": 3, "ammunition": 20}
## Rarities in the order a shop lists its magic stock.
const RARITY_ORDER: Array[String] = ["common", "uncommon", "rare", "very_rare", "legendary"]


## The party's milestone level a merchant shows an item of `rarity` from (data/treasure/levels.json `shop_levels`,
## the same tiers found treasure follows: rare from 5, very rare from 9, legendary from 10). Common and uncommon: 1.
static func magic_level(rarity: String) -> int:
	return int((Treasure.config().get("shop_levels", {}) as Dictionary).get(rarity, 1))


## A shop's magic stock as it stands (its `magic` list; Ashwin, 2026-10-14: every magic item the story doesn't need is
## for sale somewhere): each item that's playable and whose rarity the party's milestone level has reached, while the
## shop's `magic_if` holds, sold at its own price (cost_gp, Sane Magical Prices: data/treasure/magic_prices.json)
## whatever the shop marks up its other goods by, rarest last. An item built on a weapon or armor ("Flame Tongue")
## comes with `bases`, the mundane items it can be made on, and the party picks one (StoryState.shop_wares prices each);
## one with a single base is sold as that item ("Javelin of Lightning", "+1 Shield").
static func magic_stock(st: StoryState, npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sh := shop(npc_id)
	if not StoryConditions.check(str(sh.get("magic_if", "")), st):
		return out
	var comp := Compendium.shared()
	for v: Variant in sh.get("magic", []):
		var id := str(v)
		var data := comp.item_data(id)
		if data.is_empty() or not Compendium.playable(data) or st.target_level() < magic_level(MagicItems.rarity(data)):
			continue
		var line := {"id": id, "qty": magic_qty(data), "markup": 1.0, "magic": true}
		if MagicItems.is_template(data):
			var bases := comp.template_bases(id)
			if bases.is_empty() or str((data["template"] as Dictionary).get("on", "")) == "spell":
				continue
			if bases.size() == 1:
				line["id"] = "%s%s%s" % [id, MagicItems.SEP, bases[0]]
				line["stock_id"] = id
			else:
				line["bases"] = bases
		out.append(line)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := RARITY_ORDER.find(MagicItems.rarity(comp.item_data(str(a["id"]))))
		var rb := RARITY_ORDER.find(MagicItems.rarity(comp.item_data(str(b["id"]))))
		if ra != rb:
			return ra < rb
		return comp.display_name("items", str(a["id"])) < comp.display_name("items", str(b["id"])))
	return out


## What a merchant with magic stock pays for a magic item, as a share of its price (Ashwin, 2026-10-17: vendors who sell
## magic items buy them too): half, whatever share of the price they pay for their other goods. A shop's own
## `magic_sell_rate` can say otherwise.
const MAGIC_SELL_RATE := 0.5


## Whether `npc_id` buys magic items: a merchant whose magic stock is open to the party (a `magic` list, and its
## `magic_if` holds). They buy any magic item with a price, whatever their `buys` list says.
static func buys_magic(st: StoryState, npc_id: String) -> bool:
	var sh := shop(npc_id)
	return not (sh.get("magic", []) as Array).is_empty() and StoryConditions.check(str(sh.get("magic_if", "")), st)


## How many of `data` a shop's magic stock holds (MAGIC_QTY).
static func magic_qty(data: Dictionary) -> int:
	if str(data.get("category", "")) == "ammunition":
		return int(MAGIC_QTY["ammunition"])
	return int(MAGIC_QTY["consumable" if MagicItems.is_consumable(data) else "lasting"])


# --- Stock that changes ---------------------------------------------------------------------------

## A shop's `rotating` stock as it stands this stretch of days: `count` things from its `pool`, one of each, picked
## again every `days` days (the same picks for the same days in a playthrough). Each line's stock_id carries the
## stretch, so what the party bought comes back with the next stretch's picks. A shop can split its pool into
## `groups` ([{pool, count}]) so every stretch brings some of each kind (Vadoma: curios, arms, scrolls).
static func rotation(st: StoryState, npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rot := shop(npc_id).get("rotating", {}) as Dictionary
	if rot.is_empty():
		return out
	var stretch := stretch_of(st, npc_id)
	var groups: Array = rot.get("groups", [rot]) as Array
	for gi in groups.size():
		var g := groups[gi] as Dictionary
		var pool: Array = (g.get("pool", []) as Array).duplicate()
		var key := "%d:rotation:%s:%d" % [st.playthrough_seed, npc_id, stretch] + (":%d" % gi if gi > 0 else "")
		var rng := DiceRoller.new(hash(key))
		for i in mini(int(g.get("count", 3)), pool.size()):
			var id := str(pool.pop_at(rng.roll_one(pool.size(), "Trader's stock") - 1))
			out.append({"id": id, "qty": 1, "stock_id": "%s@%d" % [id, stretch]})
	return out


## Which stretch of days a rotating shop is in (day 1 to `days` is stretch 0).
static func stretch_of(st: StoryState, npc_id: String) -> int:
	var days := maxi(1, int((shop(npc_id).get("rotating", {}) as Dictionary).get("days", 3)))
	return (st.day - 1) / days
