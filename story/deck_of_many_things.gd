class_name DeckOfManyThings
extends RefCounted
## The Deck of Many Things (2024 DMG, the 22-card deck): each card drawn takes hold at once. What the game can play
## happens to the drawer, the party's purse or the story; the rest is told and flagged for the story to read
## (deviations.md: the game uses milestones, so experience cards become levels or nothing).

const CARDS: Array[String] = ["balance", "comet", "donjon", "euryale", "fates", "flames", "fool", "gem", "idiot", "jester", "key",
	"knight", "moon", "rogue", "ruin", "skull", "star", "sun", "talons", "throne", "vizier", "void"]


## Draws `count` cards for `ch`. Returns {ok, text, lines}.
static func draw(st: StoryState, ch: Character, count: int, dice: DiceRoller) -> Dictionary:
	var lines: Array[String] = []
	var left := count
	var guard := 0
	while left > 0 and guard < 12:
		guard += 1
		left -= 1
		var card := CARDS[dice.roll_one(CARDS.size(), "Deck of Many Things") - 1]
		var res := _card(st, ch, card, dice)
		lines.append(str(res["text"]))
		left += int(res.get("more", 0))
		if bool(res.get("gone", false)):
			break
	st.flags["deck_of_many_things_drawn"] = true
	return {"ok": true, "text": "\n".join(lines), "lines": lines}


static func _boon(ch: Character, ab: String, value: int, raise: int, source: String) -> void:
	if not ch.build.has("item_boons"):
		ch.build["item_boons"] = []
	(ch.build["item_boons"] as Array).append({"ability": ab, "value": value, "max_raise": raise, "source": source})
	ch.refresh()


static func _card(st: StoryState, ch: Character, card: String, dice: DiceRoller) -> Dictionary:
	var nm := ch.name.get_slice(" ", 0)
	match card:
		"balance":
			st.flags["deck_balance:%s" % ch.id] = true
			return {"text": "Balance: %s's outlook turns upside down." % nm}
		"comet":
			st.flags["deck_comet:%s" % ch.id] = true
			return {"text": "Comet: if %s defeats the next hostile foe single-handed, a new level awaits." % nm}
		"donjon":
			st.lose_member(ch, "imprisoned by the Deck of Many Things")
			return {"text": "Donjon: %s vanishes into an extradimensional prison." % nm, "gone": true}
		"euryale":
			var fx := Effect.new("Euryale's curse", &"item", "deck_of_many_things")
			fx.modifiers.append(Modifier.of("save", {"ability": "all", "value": -2}, "Euryale (Deck of Many Things)", &"item"))
			ch.add_effect(fx)
			return {"text": "Euryale: a medusa's curse gives %s a -2 penalty to saving throws." % nm}
		"fates":
			ch.heroic_inspiration = true
			st.flags["deck_fates:%s" % ch.id] = true
			return {"text": "Fates: reality bends — %s may undo one event (Heroic Inspiration now, and the story remembers)." % nm}
		"flames":
			st.flags["deck_flames"] = true
			return {"text": "Flames: a powerful devil becomes %s's enemy." % nm}
		"fool":
			return {"text": "Fool: %s draws again, poorer in pride." % nm, "more": 1}
		"gem":
			st.gold += 50000
			return {"text": "Gem: fifty gems worth 1,000 gp each spill out (50,000 gp to the party)."}
		"idiot":
			var loss := int(dice.roll_expr("1d4+1", "Idiot")["total"])
			_boon(ch, "int", -loss, 0, "Idiot (Deck of Many Things)")
			return {"text": "Idiot: %s's Intelligence drops by %d, for good." % [nm, loss], "more": 1}
		"jester":
			return {"text": "Jester: %s may draw two more cards." % nm, "more": 2}
		"key":
			var w := _key_weapon(ch, dice)
			if w != "":
				ch.add_item(w)
			return {"text": "Key: a magic weapon appears in %s's hands: %s." % [nm, Compendium.shared().display_name("items", w)]}
		"knight":
			st.flags["deck_knight"] = true
			return {"text": "Knight: a fighter appears and swears to serve %s (they guard your camp)." % nm}
		"moon":
			var fx2 := Effect.new("Moon (Deck of Many Things)", &"item", "deck_of_many_things")
			fx2.data["powers"] = [{"id": "wish", "name": "Moon's wish", "spell": "wish", "cost": "magic",
				"uses": {"count": int(dice.roll_one(3, "Moon")), "per": "never"}, "ends_effect": true}]
			ch.add_effect(fx2)
			return {"text": "Moon: %s is granted wishes (cast Wish from the Items tab)." % nm}
		"rogue":
			st.flags["deck_rogue"] = true
			return {"text": "Rogue: someone %s trusts turns against them." % nm}
		"ruin":
			st.gold = 0.0
			ch.currency = {"cp": 0, "sp": 0, "ep": 0, "gp": 0, "pp": 0}
			for e: Dictionary in ch.inventory.duplicate():
				if str(Compendium.shared().item_data(str(e["id"])).get("category", "")) == "treasure":
					ch.inventory.erase(e)
			return {"text": "Ruin: every coin and jewel the party owns turns to dust (magic items are spared)."}
		"skull":
			st.flags["deck_skull:%s" % ch.id] = true
			return {"text": "Skull: an Avatar of Death rises to hunt %s; it will come for them." % nm}
		"star":
			var abs: Array[String] = ["str", "dex", "con", "int", "wis", "cha"]
			var best := abs[0]
			for a in abs:
				if ch.ability_score(StringName(a)) > ch.ability_score(StringName(best)):
					best = a
			_boon(ch, best, 2, 4, "Star (Deck of Many Things)")
			return {"text": "Star: %s's %s rises by 2." % [nm, Creature.ABILITY_NAMES[StringName(best)]]}
		"sun":
			st.milestones += 1
			var item := _random_wondrous(dice)
			if item != "":
				ch.add_item(item)
			return {"text": "Sun: %s is ready for a new level, and a wondrous item appears: %s." % [nm, Compendium.shared().display_name("items", item)]}
		"talons":
			var lost := 0
			for e2: Dictionary in ch.inventory.duplicate():
				var d := Compendium.shared().item_data(str(e2["id"]))
				if MagicItems.is_magic(d) and not bool(d.get("quest_locked", false)):
					ch.inventory.erase(e2)
					lost += 1
			ch.attuned.clear()
			ch.items_changed()
			return {"text": "Talons: every magic item %s carries crumbles away (%d)." % [nm, lost]}
		"throne":
			var fx3 := Effect.new("Throne (Deck of Many Things)", &"item", "deck_of_many_things")
			fx3.modifiers.append(Modifier.of("proficiency", {"kind": "skill", "value": "persuasion"}, "Throne", &"item"))
			fx3.modifiers.append(Modifier.of("expertise", {"value": "persuasion"}, "Throne", &"item"))
			ch.add_effect(fx3)
			st.flags["deck_throne"] = true
			return {"text": "Throne: %s gains Expertise in Persuasion and a claim to a keep somewhere far away." % nm}
		"vizier":
			st.flags["deck_vizier"] = true
			return {"text": "Vizier: %s will know the answer to one question when the time comes." % nm}
		"void":
			st.lose_member(ch, "soul lost to the Void")
			return {"text": "The Void: %s's soul is torn away; the body falls still." % nm, "gone": true}
	return {"text": "The card fades."}


static func _key_weapon(ch: Character, dice: DiceRoller) -> String:
	var templates := ["flame_tongue", "frost_brand", "giant_slayer", "dragon_slayer", "sun_blade", "weapon_plus_2", "weapon_plus_3", "vicious_weapon"]
	var t := templates[dice.roll_one(templates.size(), "Key") - 1] as String
	var bases := Compendium.shared().template_bases(t)
	var fit: Array[String] = []
	for b in bases:
		if ch.weapon_proficient(Compendium.shared().item_data(b)):
			fit.append(b)
	if fit.is_empty():
		fit = bases
	return "%s__%s" % [t, fit[dice.roll_one(fit.size(), "Key weapon") - 1]] if not fit.is_empty() else ""


static func _random_wondrous(dice: DiceRoller) -> String:
	var pool: Array[String] = []
	for d in Compendium.shared().all_playable("magic_items"):
		if str(d.get("category", "")) == "wondrous" and MagicItems.rarity(d) in ["uncommon", "rare"] and bool((d.get("treasure", {}) as Dictionary).get("random", true)):
			pool.append(str(d["id"]))
	return pool[dice.roll_one(pool.size(), "Sun") - 1] if not pool.is_empty() else ""
