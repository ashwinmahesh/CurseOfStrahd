# Magic item audit (2026-10-17)

Ashwin's five magic item todos, done in one pass on branch `item-audit`. Each section says what was wrong, the rule
now, and every change, so the whole thing can be scanned. Prices, the duplicate rule and the swaps are enforced by
tests (tests/unit/test_magic_shops.gd, tests/unit/test_loot_distinct.gd), so they stay true as content is added.

## 1. Prices

**What was wrong.** Prices came straight from Sane Magical Prices (Ashwin's pick, 2026-10-14), and that guide prices
by how useful its author thought an item was, not by rarity. Against the 2024 DMG's value for each rarity (common
100 gp, uncommon 400, rare 4,000, very rare 40,000, legendary 200,000; a consumable half), 266 of 512 prices were
nearer another rarity's value than their own: an uncommon Weapon of Warning at 60,000 gp (so a Handaxe of Warning
sold for 60,005), an uncommon Decanter of Endless Water at 135,000, uncommon Instruments of the Bards near 28,000,
while legendary items sat at a median of 24,000 (a Ring of Invisibility for 10,000, Sovereign Glue for 400) and very
rare potions at 180.

**The rule now.** The guide still orders items inside a rarity, but every price is held inside its rarity's band
around the 2024 DMG value: nearer its own rarity's value than any other rarity's, so between the geometric means with
the values either side.

| Rarity | Band (gp) | Consumable band (gp) |
|---|---:|---:|
| Common | 50-200 | 25-100 |
| Uncommon | 200-1,250 | 100-625 |
| Rare | 1,250-12,500 | 625-6,250 |
| Very rare | 12,500-90,000 | 6,250-45,000 |
| Legendary | 90,000-450,000 | 45,000-225,000 |

- A price a 2024 book prints wins over the guide and the band: the PHB's Potion of Healing (50 gp), cantrip scroll
  (30) and level 1 scroll (50). The 2024 DMG prints no other per-item prices.
- Spell Scrolls by level are now 30, 50, 120, 200, 625, 640, 6,250, 6,250, 6,250 and 45,000 gp (MagicItems.SCROLL_PRICE).
- Magic ammunition is still sold a piece at a time; its band is checked by the stack of ten it's found in, as a
  consumable (+1 Arrows stay 25 gp each, +3 ones rise from 400 to 625).
- A weapon or armor still adds its base's cost (a Handaxe of Warning is 1,250 + 5 = 1,255 gp).
- Selling is half the price at any merchant who buys the item (or the shop's own rate for mundane goods), so the
  most a found item now fetches is bounded by its rarity too.
- Where it lives: data/treasure/magic_prices.json (`bands`, `book`, `ammunition_stack`, `_bands_note`),
  tools/data/magic_prices.py (`make magic-prices` writes cost_gp; `make validate` checks it), docs/rules/deviations.md.

The full list of changed prices is in the appendix: 264 magic items and the two generic scroll items.

## 2. Merchants who sell magic items buy them too

Every merchant with magic stock open to the party now buys any magic item with a price at half its value, whatever
their `buys` list says (Trade.MAGIC_SELL_RATE, StoryState.shop_offer; a shop can set `magic_sell_rate`). Before, each
bought only its own trade's categories (Gunther arms and gear, Xaver nothing at all): no merchant anywhere bought a
ring, wand, rod or staff, and only Master Costel bought a wondrous item. Story items and artifacts (priced 0) are never
bought; Bildrath and other shops with no magic stock still buy only what they did; the Keepers' stores buy magic once
they're open to the party (`magic_if`). The 13 merchants: Blinsky, Davian Martikov, Dmitri Krezkov, Donavich, Father
Lucian, Gunther Arasek, Kasha Varo, Kasimir Velikov, Xaver, Rictavio, Stanimir, Urwin Martikov and Master Costel (and
any merchant given a `magic` list later). Nothing bought sells back for more (the best terms anywhere pay 0.61 of the price,
the best buying terms charge 0.81; test_nothing_bought_sells_back_for_more now checks every magic seller).

## 3. Each lasting item turns up once

**What was wrong.** 20 kinds of item were placed more than once across finds, hoards, gifts and rewards. The Amulet
of the Devout was placed six times (+1 under the village pew, at the Pool of the White Sun and in Liriel's gift, +2
in the Yester Hill barrow and behind Argynvostholt's altar, +3 in Strahd's chapel), the Wand of the War Mage three
times, the Bag of Tricks three times, a +N Longsword three times (Ismark, Dragomir, Godrick), and Winged Boots, Stones of Good Luck, Cloaks of
Elvenkind, Eyes of Minute Seeing, Rings of Regeneration, Wands of Enemy Detection, Rings of Animal Influence, Ropes
of Climbing, Arcane Grimoires, Moon Sickles, Keoghtom's Ointment, Belts of Giant Strength, Instruments of the Bards,
Rings of Resistance, +N Shields and +N Chain Mail twice each. Random chests and road spoils could roll any of these
again on top.

**The rule now** (data/treasure/levels.json `_distinct_note`, Treasure.kind_of):
- A kind of item appears in one place in the story. A +1, +2 or +3 of one item, or variants that work the same way
  (Belt of Giant Strength, Ring of Resistance, Bag of Tricks, Instrument of the Bards, Dragon Scale Mail), are one
  kind. Ioun Stones and Figurines of Wondrous Power do different things, so each counts alone. A plain +N weapon,
  armor or shield counts by its base: a +1 and a +2 Longsword are one kind, a +1 Rapier another.
- Potions, scrolls, ammunition and other consumables (oils, dusts, beads, feather tokens, elemental gems) can repeat.
- Random treasure (chests and road spoils) never rolls a kind the story places, one already rolled into another
  place's chests this playthrough, or one the party carries or keeps in the stash (Treasure.taken_kinds). A roll
  that would have repeated one gives another item of the rarity instead, so random chests now lean on potions,
  scrolls, +N arms and armor and the items the story doesn't place; the count of random items a place holds is
  unchanged.
- tests/unit/test_loot_distinct.gd scans every location and dialogue and fails on a repeat. Four gifts sit in two
  branches the story only ever reaches one of, and the test knows them: Godrick's knighting sword (+1 or +2), Godfrey's
  plate (after either oath), Escher's helm (dawn or waiting) and Ismark's father's sword (after the burial or at it).

**What each repeat became.** The copy kept is the one a scene's own words or a mechanic depend on; the others became
distinct items, combat ones picked to fill gaps in the class spread (section 4):

| Kind | Kept | The others became |
|---|---|---|
| Amulet of the Devout | Liriel's sunburst (her cutscene draws it), raised from +1 to +3 because she gives it in Strahd's chapel at level 10 | Village pew: Staff of the Adder · Pool of the White Sun: Bloodwell Vial +2 · Yester Hill barrow: Scale Mail of Necrotic Resistance · Argynvostholt reliquary: Bowl of Commanding Water Elementals · Strahd's chapel altar: Ioun Stone (Fortitude) |
| Wand of the War Mage | Khazan's coffer (+3, a hoard upgrade pick) | Victor's attic: Tentacle Rod · Catacombs conjurer's bier: Staff of Thunder and Lightning |
| Bag of Tricks | Agafia's tan bag (her lines describe it) | Thorn's toy chest: +1 Sling · Tser Falls trunk: Staff of the Python |
| +N Longsword | Godrick's knighting sword | Ismark's father's sword: +1 Rapier · Dragomir's blade: +2 Scimitar |
| Winged Boots | Mother's eighth gift ("an hour up") | Ilarion: Boots of Striding and Springing (they "walk on air, a little"), moved from the Tser Pool ribbon tree, which now holds a +1 Shortbow |
| Stone of Good Luck | Veta's stone on the crypt lid | Kip's apricot-pit charm: Periapt of Health, moved from the village church undercroft, where the old priest now holds a +1 Mace |
| Cloak of Elvenkind | Fen's cloak (his cutscene) | Death House nursemaid's mattress: +1 Shortsword |
| Eyes of Minute Seeing | Death House card cabinet (Gustav's marked deck; a test) | Blood of the Vine satchel: Headband of Intellect |
| Ring of Regeneration | Kiril's hoard | Strahd's throne of bones: Ioun Stone (Strength) |
| Wand of Enemy Detection | (neither: no use in a fight) | Kiril's hoard: +2 Longbow · Argynvostholt dragon's desk: Figurine (Bronze Griffon) |
| Ring of Animal Influence | The Huntsman's pack ring (his lines describe it) | Kiril's hoard: +1 Splint Armor |
| Rope of Climbing | The winery well (the climb check hands it over) | Tsolenka frozen traveller: Cloak of Arachnida |
| Arcane Grimoire | Dobre's satchel (+2) | Ludmilla's books: Manual of Bodily Health |
| Moon Sickle | The vineyard (+1; the vines' Speak with Plants tip names it) | Mother Night's shrine: Figurine (Marble Elephant) |
| Keoghtom's Ointment | Smaranda's herb stall | Krezk wayside shrine: Potion of Invulnerability |
| Belt of Giant Strength | The roc's nest (hill; the belt is described) | Mount Ghakis captive's father's gift: Dwarven Plate ("it knows stone") |
| Instrument of the Bards | Death House conservatory lute | The castle organ: Staff of Striking |
| Ring of Resistance | Catalina's mother's ring (necrotic) | Argynvostholt plinth: Feather Token (Whip) |
| +N Shield | Teodor's grave (+1; Teodor names it) | Argynvost's gift niche: Dragonhide Belt +2 |
| +N Chain Mail | Dmitri's grandfather's mail (+1) | Tsolenka guard tower: +2 Half Plate |

## 4. Combat focus and the spread across classes

**Audit.** Every lasting magic item the story places (finds, hoards, side quest and companion gifts) was classed as
combat (it does something in a fight: attacks, AC, saves, spells, summons, movement the battle map uses such as
climbing, jumping and falling, Stealth for the Hide action) or not, and tagged by who uses it. Before: 37 of 188 placed
items did nothing in a fight, and Dex fighters, rogues, rangers, monks and arcane casters got few items early, because
nearly every named sword was a longsword and the caster foci were all the cleric's amulet and the wizard's wand.

Who each placed item serves (a weapon by its base: finesse or ranged is Dex and ranged, a simple or light weapon
also Monk; armor by weight; a focus by its attunement; one item can count for several groups):

Before:

| Levels | Lasting items | No use in a fight | Str melee | Dex & ranged | Monk | Arcane caster | Divine caster | Anyone |
|---|---|---|---|---|---|---|---|---|
| Levels 1-4 | 41 | 9 | 7 | 3 | 2 | 3 | 3 | 19 |
| Levels 5-8 | 83 | 21 | 11 | 6 | 6 | 9 | 14 | 32 |
| Levels 9-10 | 63 | 7 | 13 | 3 | 4 | 11 | 11 | 26 |
| Companions | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |

After:

| Levels | Lasting items | No use in a fight | Str melee | Dex & ranged | Monk | Arcane caster | Divine caster | Anyone |
|---|---|---|---|---|---|---|---|---|
| Levels 1-4 | 50 | 9 | 9 | 7 | 6 | 7 | 6 | 18 |
| Levels 5-8 | 95 | 15 | 14 | 10 | 8 | 13 | 17 | 39 |
| Levels 9-10 | 66 | 2 | 16 | 6 | 7 | 9 | 11 | 30 |
| Companions | 3 | 0 | 0 | 1 | 0 | 0 | 1 | 1 |

**Swapped because it did nothing in a fight** (and nothing the scene's words depend on): Ring of Mind Shielding
(Old Svalich Road shrine: +1 Quarterstaff), Handy Haversack (Vallaki hovel, a third carry-all: +1 Leather Armor), Ring
of Water Walking (Lake Zarovich jetty: +1 Breastplate), Trident of Fish Command (fishers' shrine: +2 Trident), Alchemy
Jug (winery cellar: +2 Hand Crossbow), Decanter of Endless Water (press house: Rhythm-Maker's Drum +2), Immovable Rod
(Berez: Dwarven Thrower), Crystal Ball (Strahd's desk: Efreeti Bottle), Ring of X-ray Vision (Rahadin's footlocker: +3
Heavy Crossbow), Boots of Levitation (Escher's dressing table: +2 Studded Leather Armor), plus the Wands of Enemy
Detection and Ring of Animal Influence among the repeats above.

**Named swords re-based for Dex users** (same item, a blade a rogue or Dex fighter can use): Sword of Life Stealing
(Yester Hill cages) is now a rapier, Sword of Wounding (Kiril's trophies) a shortsword, Sword of Sharpness (Strahd's
trophy room) a scimitar. Flame Tongue, Frost Brand and Nine Lives Stealer stay longswords.

**Kept although they do nothing in a fight**, because the game's own systems use them or the scene's words name them:
Bag of Holding, Portable Hole, Driftglobe, Broom of Flying, Folding Boat, Robe of Useful Items, Bag of Beans, Chime of
Opening and Gloves of Thievery (locks), Eyes of Minute Seeing, Eyes of the Eagle, Wand of Magic Detection and Wand of
Secrets (hidden finds), the winery's Rope of Climbing, the Silver Raven (Ilinca's Speak with Animals tip), and the
gifts whose lines describe them (Efficient Quiver, Pipes of the Sewers, Cloak of the Manta Ray, Daern's Instant
Fortress, Dimensional Shackles, Ioun Stone of Sustenance, Ebony Fly, Gem of Seeing, Hat of Disguise, Marvelous
Pigments, Ring of Animal Influence).

**Random loot leans to combat.** levels.json `support_items` lists the 72 magic items with no use in a fight; a random
chest or road roll weighs each at a quarter of an ordinary item's chance (`support_weight` 0.25), so they still turn
up now and then.

**Withdrawn.** Two items did nothing at all in this game (no code reads their effects): the Ring of Mind Shielding and
the Ring of Water Walking are now `"playable": false` with a `removed` note, out of the shops, and a save's copies
become a Ring of Warmth or a Ring of Jumping (SaveSystem.WITHDRAWN, run on every load). Not withdrawn, but noted as
doing nothing for the same reason, neither placed as loot: Silver Harper Pin, Magewright's Gloves (both still sold).

## 5. The tapestry room

The secret is in Castle Ravenloft's high tower (data/locations/castle_ravenloft_spires.json): Investigation DC 14 on
the faded tapestry at the tower's foot reveals the panel into the lamplighters' closet, whose cupboard held two lamps,
oil, candles, a Potion of Healing and 40 gp. It now also holds a **Staff of Fire** (very rare, in keeping with the
lamplighters), a Potion of Supreme Healing, three diamonds and 450 gp, a hoard on the scale of the castle's other
level 10 secrets (very rare, not legendary: legendary items stay in the four level 10 villains' hoards). The closet's
first-sight line now hints that it keeps more than lamps.

## 6. Found spellbooks (2026-10-18)

Ashwin: found spellbooks should always hold spells a Wizard can learn. The warden's chest at the Amber Temple held the
PHB's blank Spellbook, and the Arcane Grimoires (books that work as a spellbook) and the Enduring Spellbook held
nothing either. Now:

| Book | Where | Spells (all on the Wizard list, in play) |
|---|---|---|
| A Warden's Spellbook (new, data/items/amber_warden_spellbook.json) | Amber Temple, a warden's chest (level 10) | Alarm, See Invisibility, Counterspell, Dispel Magic, Glyph of Warding, Banishment, Mordenkainen's Private Sanctum, Otiluke's Resilient Sphere, Wall of Force |
| The Dursts' Spellbook (unchanged; it already passed) | Death House, the Dursts' footlocker (level 2) | Comprehend Languages, Disguise Self, False Life, Ray of Sickness, Unseen Servant, Darkness, Gentle Repose |
| Arcane Grimoire, +1 | sold (Kasimir, Xaver) | Mage Armor, Magic Missile, Shield, Misty Step, Scorching Ray |
| Arcane Grimoire, +2 | Dobre's satchel (Ribbons, Vallaki, level 5); sold | Sleep, Thunderwave, Mirror Image, Web, Fireball, Haste |
| Arcane Grimoire, +3 | sold (Xaver) | Fly, Lightning Bolt, Dimension Door, Greater Invisibility, Ice Storm, Cone of Cold, Hold Monster |
| Enduring Spellbook | sold (Blinsky) | Detect Magic, Find Familiar, Identify, Magic Missile, Levitate |

A shop's blank Spellbook stays blank (it's paper to write in). Mordenkainen's book from the Baratok cairn isn't an
item: the story hands it back to him. tests/unit/test_spellbook_loot.gd fails if a book lists a spell a Wizard can't
learn (off the list, out of play, a cantrip, twice, or above what a Wizard two levels past the place can prepare), if a
blank spellbook is ever loot, or if random treasure could roll an empty one; test_spellbook_copy.gd copies from the
warden's book on the inventory card. A save whose warden's chest still holds the blank book, or whose non-Wizard took
it, gets the warden's book (StoryState._upgrade_found_spellbook, which now does the Dursts' book too).

## Lines left unvoiced

The swaps change what 34 Narrator lines describe (the search line for each find, the dragon's gift niche, the chapel
prayer and the lamplighters' closet). Five of them hold `{name}` and are never voiced; the other 29 need `make voice
SPEAKER=narrator` from the voice thread: in narrative/narrator/, village_of_barovia (pew_loose_stone,
undercroft_priest, satchel_lining), argynvostholt (altar_reliquary, dragon_desk_wand, plinth_ring, dragon_gift_niche),
castle_ravenloft_gates (altar_dust_amulet, organ_harp), vallaki (circle_loose_board, hovel_step_sack),
castle_ravenloft_catacombs (conjurer_wand), castle_ravenloft_court (ludmilla_grimoire, count_desk_ball,
dark_chapel_pray success), old_bonegrinder (lane_shrine_tin), castle_ravenloft_larders (bone_throne_ring), death_house
(nursemaid_mattress, toy_chest_drawer), svalich_road (ribbon_tree_cache, trunk_hollow), into_the_mists
(mists_shrine_board), berez (unrusted_hauberk), wizard_of_wines (founders_cask_stave, wizard_cask_decanter),
lake_zarovich (jetty_boards, shrine_trident), werewolf_den (shrine_sickle), castle_ravenloft_spires
(enter:spires_lamp_closet).

## Appendix: every price that changed

The template items (a Weapon of Warning, a Flame Tongue) show the magic's own price; the base weapon or armor's cost
is added on top.

| Item | Rarity | Was | Now |
|---|---|---:|---:|
| Potion of Climbing | common | 180 | 100 |
| Decanter of Endless Water | uncommon | 135,000 | 1,250 |
| Weapon of Warning | uncommon | 60,000 | 1,250 |
| Instrument of the Bards (Doss Lute) | uncommon | 28,500 | 1,250 |
| Instrument of the Bards (Mac-Fuirmidh Cittern) | uncommon | 27,000 | 1,250 |
| Instrument of the Bards (Fochlucan Bandore) | uncommon | 26,500 | 1,250 |
| Sentinel Shield | uncommon | 20,000 | 1,250 |
| Ring of Mind Shielding | uncommon | 16,000 | 1,250 |
| Amulet of the Devout, +1 | uncommon | 12,000 | 1,250 |
| Arcane Grimoire, +1 | uncommon | 12,000 | 1,250 |
| Bloodwell Vial, +1 | uncommon | 12,000 | 1,250 |
| Dragonhide Belt, +1 | uncommon | 12,000 | 1,250 |
| Moon Sickle, +1 | uncommon | 12,000 | 1,250 |
| Rhythm-Maker's Drum, +1 | uncommon | 12,000 | 1,250 |
| Rod of the Pact Keeper, +1 | uncommon | 12,000 | 1,250 |
| Boots of the Winterlands | uncommon | 10,000 | 1,250 |
| Broom of Flying | uncommon | 8,000 | 1,250 |
| Gauntlets of Ogre Power | uncommon | 8,000 | 1,250 |
| Headband of Intellect | uncommon | 8,000 | 1,250 |
| Wand of Magic Missiles | uncommon | 8,000 | 1,250 |
| Wand of Web | uncommon | 8,000 | 1,250 |
| Winged Boots | uncommon | 8,000 | 1,250 |
| Robe of Useful Items | uncommon | 7,590 | 1,250 |
| Brooch of Shielding | uncommon | 7,500 | 1,250 |
| Deck of Illusions | uncommon | 6,120 | 1,250 |
| Alchemy Jug | uncommon | 6,000 | 1,250 |
| Cloak of the Manta Ray | uncommon | 6,000 | 1,250 |
| Pearl of Power | uncommon | 6,000 | 1,250 |
| Pipes of Haunting | uncommon | 6,000 | 1,250 |
| Boots of Striding and Springing | uncommon | 5,000 | 1,250 |
| Cloak of Elvenkind | uncommon | 5,000 | 1,250 |
| Figurine of Wondrous Power (Silver Raven) | uncommon | 5,000 | 1,250 |
| Gem of Brightness | uncommon | 5,000 | 1,250 |
| Gloves of Thievery | uncommon | 5,000 | 1,250 |
| Hat of Disguise | uncommon | 5,000 | 1,250 |
| Immovable Rod | uncommon | 5,000 | 1,250 |
| Lantern of Revealing | uncommon | 5,000 | 1,250 |
| Periapt of Health | uncommon | 5,000 | 1,250 |
| Periapt of Wound Closure | uncommon | 5,000 | 1,250 |
| Slippers of Spider Climbing | uncommon | 5,000 | 1,250 |
| Stone of Good Luck (Luckstone) | uncommon | 4,200 | 1,250 |
| Bag of Holding | uncommon | 4,000 | 1,250 |
| Cloak of Protection | uncommon | 3,500 | 1,250 |
| Bag of Tricks (Gray) | uncommon | 3,000 | 1,250 |
| Bag of Tricks (Rust) | uncommon | 3,000 | 1,250 |
| Bag of Tricks (Tan) | uncommon | 3,000 | 1,250 |
| Blemished Idol of Good Fortunes | uncommon | 3,000 | 1,250 |
| Boon Companions’ Bands | uncommon | 3,000 | 1,250 |
| Budding Blossom Rod | uncommon | 3,000 | 1,250 |
| Eyes of Charming | uncommon | 3,000 | 1,250 |
| Gloves of Missile Snaring | uncommon | 3,000 | 1,250 |
| Magewright’s Gloves | uncommon | 3,000 | 1,250 |
| Martialist’s Quarterstaff | uncommon | 3,000 | 1,250 |
| Ominous Staff of Skulls | uncommon | 3,000 | 1,250 |
| Orb of Divination Detection | uncommon | 3,000 | 1,250 |
| Orb of Sorcery | uncommon | 3,000 | 1,250 |
| Ring of Dedicated Focus | uncommon | 3,000 | 1,250 |
| Ring of Swimming | uncommon | 3,000 | 1,250 |
| Silver Harper Pin | uncommon | 3,000 | 1,250 |
| Spell-Slinger’s Puppet | uncommon | 3,000 | 1,250 |
| Thespian’s Playbill | uncommon | 3,000 | 1,250 |
| Thief’s Thimble | uncommon | 3,000 | 1,250 |
| Three Keyholes Dagger | uncommon | 3,000 | 1,250 |
| Wand of Freshness | uncommon | 3,000 | 1,250 |
| Boots of Elvenkind | uncommon | 2,500 | 1,250 |
| Eyes of Minute Seeing | uncommon | 2,500 | 1,250 |
| Eyes of the Eagle | uncommon | 2,500 | 1,250 |
| Ring of Jumping | uncommon | 2,500 | 1,250 |
| Gloves of Swimming and Climbing | uncommon | 2,000 | 1,250 |
| Pipes of the Sewers | uncommon | 2,000 | 1,250 |
| Rope of Climbing | uncommon | 2,000 | 1,250 |
| Staff of the Python | uncommon | 2,000 | 1,250 |
| Elemental Gem (Blue Sapphire) | uncommon | 960 | 625 |
| Elemental Gem (Emerald) | uncommon | 960 | 625 |
| Elemental Gem (Red Corundum) | uncommon | 960 | 625 |
| Elemental Gem (Yellow Diamond) | uncommon | 960 | 625 |
| Staff of the Adder | uncommon | 1,800 | 1,250 |
| Potion of Giant Strength (Hill Giant) | uncommon | 800 | 625 |
| Bracers of Archery | uncommon | 1,500 | 1,250 |
| Circlet of Blasting | uncommon | 1,500 | 1,250 |
| Goggles of Night | uncommon | 1,500 | 1,250 |
| Javelin of Lightning | uncommon | 1,500 | 1,250 |
| Mariner's Armor | uncommon | 1,500 | 1,250 |
| Necklace of Adaptation | uncommon | 1,500 | 1,250 |
| Ring of Water Walking | uncommon | 1,500 | 1,250 |
| Shield, +1 | uncommon | 1,500 | 1,250 |
| Wand of Magic Detection | uncommon | 1,500 | 1,250 |
| Wand of Secrets | uncommon | 1,500 | 1,250 |
| Wind Fan | uncommon | 1,500 | 1,250 |
| Philter of Love | uncommon | 90 | 100 |
| Feather Token (Anchor) | rare | 50 | 625 |
| Elixir of Health | rare | 120 | 625 |
| Vicious Weapon | rare | 350 | 1,250 |
| Potion of Heroism | rare | 180 | 625 |
| Scroll of Protection (Aberration) | rare | 180 | 625 |
| Scroll of Protection (Beast) | rare | 180 | 625 |
| Scroll of Protection (Celestial) | rare | 180 | 625 |
| Scroll of Protection (Elemental) | rare | 180 | 625 |
| Scroll of Protection (Fey) | rare | 180 | 625 |
| Scroll of Protection (Fiend) | rare | 180 | 625 |
| Scroll of Protection (Plant) | rare | 180 | 625 |
| Scroll of Protection (Undead) | rare | 180 | 625 |
| Horn of Blasting | rare | 450 | 1,250 |
| Feather Token (Fan) | rare | 250 | 625 |
| Feather Token (Whip) | rare | 250 | 625 |
| Potion of Diminution | rare | 270 | 625 |
| Potion of Gaseous Form | rare | 300 | 625 |
| Daern's Instant Fortress | rare | 75,000 | 12,500 |
| Cloak of Displacement | rare | 60,000 | 12,500 |
| Necklace of Prayer Beads | rare | 51,975 | 12,500 |
| Staff of the Woodlands | rare | 44,000 | 12,500 |
| Instrument of the Bards (Cli Lyre) | rare | 35,000 | 12,500 |
| Gem of Seeing | rare | 32,000 | 12,500 |
| Wand of Fireballs | rare | 32,000 | 12,500 |
| Wand of Lightning Bolts | rare | 32,000 | 12,500 |
| Instrument of the Bards (Canaith Mandolin) | rare | 30,000 | 12,500 |
| Mantle of Spell Resistance | rare | 30,000 | 12,500 |
| Robe of Eyes | rare | 30,000 | 12,500 |
| Ring of Spell Storing | rare | 24,000 | 12,500 |
| Potion of Healing (Superior) | rare | 450 | 625 |
| Ring of Free Action | rare | 20,000 | 12,500 |
| Feather Token (Tree) | rare | 465 | 625 |
| Figurine of Wondrous Power (Ivory Goats) | rare | 1,000 | 1,250 |
| Ioun Stone (Sustenance) | rare | 1,000 | 1,250 |
| Sword of Life Stealing | rare | 1,000 | 1,250 |
| Amulet of the Devout, +2 | rare | 16,000 | 12,500 |
| Arcane Grimoire, +2 | rare | 16,000 | 12,500 |
| Bloodwell Vial, +2 | rare | 16,000 | 12,500 |
| Cube of Force | rare | 16,000 | 12,500 |
| Dragonhide Belt, +2 | rare | 16,000 | 12,500 |
| Moon Sickle, +2 | rare | 16,000 | 12,500 |
| Rhythm-Maker's Drum, +2 | rare | 16,000 | 12,500 |
| Rod of Rulership | rare | 16,000 | 12,500 |
| Rod of the Pact Keeper, +2 | rare | 16,000 | 12,500 |
| Staff of Swarming Insects | rare | 16,000 | 12,500 |
| Wand of Paralysis | rare | 16,000 | 12,500 |
| Figurine of Wondrous Power (Golden Lions) | rare | 1,200 | 1,250 |
| Ioun Stone (Protection) | rare | 1,200 | 1,250 |
| Staff of Healing | rare | 13,000 | 12,500 |
| Nolzur's Marvelous Pigments | very rare | 200 | 12,500 |
| Potion of Invisibility | very rare | 180 | 6,250 |
| Potion of Speed | very rare | 400 | 6,250 |
| Potion of Flying | very rare | 500 | 6,250 |
| Horseshoes of a Zephyr | very rare | 1,500 | 12,500 |
| Sword of Sharpness | very rare | 1,700 | 12,500 |
| Potion of Vitality | very rare | 960 | 6,250 |
| Dancing Sword | very rare | 2,000 | 12,500 |
| Frost Brand | very rare | 2,200 | 12,500 |
| Ioun Stone (Absorption) | very rare | 2,400 | 12,500 |
| Potion of Healing (Supreme) | very rare | 1,350 | 6,250 |
| Ioun Stone (Agility) | very rare | 3,000 | 12,500 |
| Ioun Stone (Fortitude) | very rare | 3,000 | 12,500 |
| Ioun Stone (Insight) | very rare | 3,000 | 12,500 |
| Ioun Stone (Intellect) | very rare | 3,000 | 12,500 |
| Ioun Stone (Leadership) | very rare | 3,000 | 12,500 |
| Ioun Stone (Strength) | very rare | 3,000 | 12,500 |
| Oathbow | very rare | 3,500 | 12,500 |
| Dragon Scale Mail (Black) | very rare | 4,000 | 12,500 |
| Dragon Scale Mail (Blue) | very rare | 4,000 | 12,500 |
| Dragon Scale Mail (Brass) | very rare | 4,000 | 12,500 |
| Dragon Scale Mail (Bronze) | very rare | 4,000 | 12,500 |
| Dragon Scale Mail (Copper) | very rare | 4,000 | 12,500 |
| Dragon Scale Mail (Gold) | very rare | 4,000 | 12,500 |
| Dragon Scale Mail (Green) | very rare | 4,000 | 12,500 |
| Dragon Scale Mail (Red) | very rare | 4,000 | 12,500 |
| Dragon Scale Mail (Silver) | very rare | 4,000 | 12,500 |
| Dragon Scale Mail (White) | very rare | 4,000 | 12,500 |
| Potion of Giant Strength (Cloud Giant) | very rare | 2,400 | 6,250 |
| Cloak of Arachnida | very rare | 5,000 | 12,500 |
| Animated Shield | very rare | 6,000 | 12,500 |
| Armor, +2 | very rare | 6,000 | 12,500 |
| Robe of Scintillating Colors | very rare | 6,000 | 12,500 |
| Scimitar of Speed | very rare | 6,000 | 12,500 |
| Oil of Sharpness | very rare | 3,200 | 6,250 |
| Ammunition, +3 | very rare | 400 | 625 |
| Nine Lives Stealer | very rare | 8,000 | 12,500 |
| Amulet of the Planes | very rare | 160,000 | 90,000 |
| Dwarven Plate | very rare | 9,000 | 12,500 |
| Figurine of Wondrous Power (Obsidian Steed) | very rare | 128,000 | 90,000 |
| Staff of Thunder and Lightning | very rare | 10,000 | 12,500 |
| Instrument of the Bards (Anstruth Harp) | very rare | 109,000 | 90,000 |
| Horn of Valhalla (Bronze) | very rare | 11,200 | 12,500 |
| Staff of Power | very rare | 95,500 | 90,000 |
| Ammunition of Slaying (Aberration) | very rare | 600 | 625 |
| Ammunition of Slaying (Beast) | very rare | 600 | 625 |
| Ammunition of Slaying (Celestial) | very rare | 600 | 625 |
| Ammunition of Slaying (Construct) | very rare | 600 | 625 |
| Ammunition of Slaying (Dragon) | very rare | 600 | 625 |
| Ammunition of Slaying (Elemental) | very rare | 600 | 625 |
| Ammunition of Slaying (Fey) | very rare | 600 | 625 |
| Ammunition of Slaying (Fiend) | very rare | 600 | 625 |
| Ammunition of Slaying (Giant) | very rare | 600 | 625 |
| Ammunition of Slaying (Humanoid) | very rare | 600 | 625 |
| Ammunition of Slaying (Monstrosity) | very rare | 600 | 625 |
| Ammunition of Slaying (Ooze) | very rare | 600 | 625 |
| Ammunition of Slaying (Plant) | very rare | 600 | 625 |
| Ammunition of Slaying (Undead) | very rare | 600 | 625 |
| Belt of Giant Strength (Fire Giant) | very rare | 12,000 | 12,500 |
| Belt of Giant Strength (Frost Giant) | very rare | 12,000 | 12,500 |
| Belt of Giant Strength (Stone Giant) | very rare | 12,000 | 12,500 |
| Candle of Invocation | very rare | 12,000 | 12,500 |
| Carpet of Flying (3 by 5 ft) | very rare | 12,000 | 12,500 |
| Carpet of Flying (4 by 6 ft) | very rare | 12,000 | 12,500 |
| Carpet of Flying (5 by 7 ft) | very rare | 12,000 | 12,500 |
| Carpet of Flying (6 by 9 ft) | very rare | 12,000 | 12,500 |
| Efreeti Bottle | very rare | 12,000 | 12,500 |
| Golden Idol of Good Fortunes | very rare | 12,000 | 12,500 |
| Helm of Brilliance | very rare | 12,000 | 12,500 |
| Manual of Bodily Health | very rare | 12,000 | 12,500 |
| Manual of Gainful Exercise | very rare | 12,000 | 12,500 |
| Manual of Golems | very rare | 12,000 | 12,500 |
| Manual of Quickness of Action | very rare | 12,000 | 12,500 |
| Many Keyholes Dagger | very rare | 12,000 | 12,500 |
| Pulverizing Staff of Skulls | very rare | 12,000 | 12,500 |
| Ring of Regeneration | very rare | 12,000 | 12,500 |
| Somniferous Blossom Rod | very rare | 12,000 | 12,500 |
| Tome of Clear Thought | very rare | 12,000 | 12,500 |
| Tome of Leadership and Influence | very rare | 12,000 | 12,500 |
| Tome of Understanding | very rare | 12,000 | 12,500 |
| Tramontane Armor | very rare | 12,000 | 12,500 |
| Workshop Wrecker | very rare | 12,000 | 12,500 |
| Sovereign Glue | legendary | 400 | 90,000 |
| Universal Solvent | legendary | 300 | 45,000 |
| Ioun Stone (Regeneration) | legendary | 4,000 | 90,000 |
| Potion of Giant Strength (Storm Giant) | legendary | 2,400 | 45,000 |
| Apparatus of Kwalish | legendary | 10,000 | 90,000 |
| Ring of Invisibility | legendary | 10,000 | 90,000 |
| Horn of Valhalla (Iron) | legendary | 14,000 | 90,000 |
| Ioun Stone (Mastery) | legendary | 15,000 | 90,000 |
| Sphere of Annihilation | legendary | 15,000 | 90,000 |
| Hammer of Thunderbolts | legendary | 16,000 | 90,000 |
| Ring of Elemental Command (Fire) | legendary | 17,000 | 90,000 |
| Armor of Invulnerability | legendary | 18,000 | 90,000 |
| Efreeti Chain | legendary | 20,000 | 90,000 |
| Talisman of the Sphere | legendary | 20,000 | 90,000 |
| Armor, +3 | legendary | 24,000 | 90,000 |
| Belt of Giant Strength (Cloud Giant) | legendary | 24,000 | 90,000 |
| Belt of Giant Strength (Storm Giant) | legendary | 24,000 | 90,000 |
| Deck of Many Things | legendary | 24,000 | 90,000 |
| Defender | legendary | 24,000 | 90,000 |
| Diamond Staff | legendary | 24,000 | 90,000 |
| Grave Reaper | legendary | 24,000 | 90,000 |
| Iron Flask | legendary | 24,000 | 90,000 |
| Luck Blade | legendary | 24,000 | 90,000 |
| Ring of Djinni Summoning | legendary | 24,000 | 90,000 |
| Rod of Resurrection | legendary | 24,000 | 90,000 |
| Tome of the Stilled Tongue | legendary | 24,000 | 90,000 |
| Vorpal Sword | legendary | 24,000 | 90,000 |
| Well of Many Worlds | legendary | 24,000 | 90,000 |
| Ring of Elemental Command (Water) | legendary | 25,000 | 90,000 |
| Rod of Lordly Might | legendary | 28,000 | 90,000 |
| Ring of Spell Turning | legendary | 30,000 | 90,000 |
| Ioun Stone (Greater Absorption) | legendary | 31,000 | 90,000 |
| Ring of Elemental Command (Earth) | legendary | 31,000 | 90,000 |
| Robe of the Archmagi | legendary | 34,000 | 90,000 |
| Ring of Elemental Command (Air) | legendary | 35,000 | 90,000 |
| Scarab of Protection | legendary | 36,000 | 90,000 |
| Cubic Gate | legendary | 40,000 | 90,000 |
| Plate Armor of Etherealness | legendary | 48,000 | 90,000 |
| Crystal Ball of Telepathy | legendary | 50,000 | 90,000 |
| Crystal Ball of True Seeing | legendary | 50,000 | 90,000 |
| Talisman of Ultimate Evil | legendary | 61,440 | 90,000 |
| Talisman of Pure Good | legendary | 71,680 | 90,000 |
| Cloak of Invisibility | legendary | 80,000 | 90,000 |
| Spell Scroll (cantrip), generic | common | 10 | 30 |
| Spell Scroll (level 1), generic | common | 60 | 50 |

