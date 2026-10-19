# Found magic items (lane 26)

Owner ask (2026-10-08): more magic items through the whole game, found by curiosity: talking to different people
and searching nooks and crannies. Second pass (Ashwin, 2026-10-08): no common items (early ones become uncommon,
later ones rare or very rare) and more finds everywhere. Shop stock is the merchants lane's; this list is the things
you find or are given.

Rules for this list:
- 2024 DMG items only (the PHB's potions too). Rarity follows the party's level in each region
  (data/treasure/levels.json): uncommon up to level 4, rare from level 5, very rare from level 9. Legendary stays
  with the story's artifacts, except in the hoards of the four deadliest villains, met at level 10 (Strahd,
  Khazan, the Eye Below, Sarkhaza; Hoard upgrades, Ashwin 2026-10-15). tests/integration/test_found_items.gd checks the
  hidden finds against this.
- Most finds sit behind a hidden search or a conversation, fewer in plain chests.
- **Search (Perception DC n)**: a hidden spot the Search button can turn up within 15 ft. **Search (Investigation
  DC n)**: a hidden compartment you have to work out; the same Search rolls Investigation as well when one is near.
- **One look each**: a character who searches near a hidden find and misses it has missed it for good; someone else
  in the party can still try. Detect Magic tells you when something magical is hidden within 30 ft.
- **Gift**: an NPC hands it over in conversation (a favour, a quest's end, a check). **Tip**: an NPC tells you
  where something is hidden, and the spot shows up once you know (or an animal or a corpse does, under Speak with
  Animals or Speak with Dead: docs/story/talking_creatures.md). **Hoard**: a lair's container.
- Random treasure (story/treasure.gd) still rolls on top of this: one location in five now rolls nothing, down
  from about one in three, and nearly a third roll two items. Random rolls (chests and the road's spoils) never give a common item either: the
  DMG's common share goes to uncommon (data/treasure/levels.json).
- **Each lasting item once** (Ashwin, 2026-10-17; docs/story/magic_item_audit.md): no kind of item (a +1 and a +3 of
  one item are one kind, a +1 Longsword and a +1 Rapier two) is placed in two places, and random treasure never
  rolls one the story places, one already rolled, or one the party has. Potions, scrolls and ammunition repeat.
  tests/unit/test_loot_distinct.gd checks it. Finds lean to combat; items with no use in a fight roll a quarter as often.

Status: ✅ built · ○ planned

## Into the Mists (level 1)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Old Svalich Road, by the headless statues | Longsword of Warning (uncommon) | Search (Perception DC 13): a gate guard's sword in the weeds |
| ✅ | Old Svalich Road, the wayside shrine | +1 Quarterstaff (uncommon) | Search (Investigation DC 12): a pilgrim's staff under a loose board at the back of the shrine (was a Ring of Mind Shielding, which did nothing; (magic item audit, 2026-10-17)) |
| ✅ | Svalich Woods, the torn carcass | Boots of the Winterlands (uncommon) | Search (Perception DC 12): a traveller's pack under the carcass; or a Tip from the crow at the village edge (Speak with Animals) |
| ✅ | Ilarion, at the village well | Boots of Striding and Springing (uncommon) | Gift: once he's home with his children (The Last Traveller, docs/story/side_quests.md); Winged Boots are Mother's gift (magic item audit, 2026-10-17) |

## The Gates of Barovia (side quest, levels 6 and up)

| | Where | Item | How |
|---|---|---|---|
| ✅ | The vanguard's pay chest, the Gates | +2 Scimitar (rare) | Hoard: Marshal Dragomir's sabre, once he's beaten (The Last Muster, docs/story/side_quests.md); was a +2 Longsword, as Godrick's knighting sword is (magic item audit, 2026-10-17) |

## Death House (level 2)

Already there: Cloak of Protection (Durst footlocker), three Spell Scrolls (study chest), the children's cache.

| | Where | Item | How |
|---|---|---|---|
| ✅ | Ground floor, Den of Wolves | Eyes of Minute Seeing (uncommon) | Search (Investigation DC 13): under the card cabinet; Gustav never lost at cards (his marked deck); a Medallion of Thoughts until Detect Thoughts left the game (2026-10-13) |
| ✅ | Ground floor, kitchen | Driftglobe (uncommon) | Search (Perception DC 13): something wedged in the dumbwaiter shaft |
| ✅ | Upper floor, library | Wand of Magic Missiles (uncommon) | Search (Investigation DC 14): a hollow book among the histories |
| ✅ | Upper floor, conservatory | Instrument of the Bards, Doss Lute (uncommon) | Search (Investigation DC 13): a lute case behind the harp |
| ✅ | Upper floor, servants' room | Gloves of Missile Snaring (uncommon) | Search (Perception DC 14): under a servant's bed |
| ✅ | Third floor, master suite | Circlet of Blasting (uncommon) | Search (Investigation DC 13): a false bottom in Elisabeth's dressing-table drawer |
| ✅ | Third floor, nursemaid's room | +1 Shortsword (uncommon) | Search (Perception DC 14): wrapped under the mattress, a gift from Gustav (the Cloak of Elvenkind is Fen's; (magic item audit, 2026-10-17)) |
| ✅ | Attic, children's room | +1 Sling (uncommon) | Search (Investigation DC 12): Thorn's secret drawer in the toy chest (the Bag of Tricks is Agafia's; (magic item audit, 2026-10-17)) |
| ✅ | Dungeon, the cult's dormitory | Elemental Gem, Red Corundum (uncommon) | Search (Perception DC 13): under a straw pallet |
| ✅ | Dungeon, the cult's shrine | Dust of Disappearance (uncommon) | Search (Perception DC 14): a hollow in the painted statue's base |
| ✅ | Dungeon, lower level | Pipes of Haunting (uncommon) | Search (Investigation DC 14): one relic in the niches that isn't bone |

## Village of Barovia (level 3)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Village, the collapsed barn | Javelin of Lightning (uncommon) | Search (Perception DC 13): a stash under the fallen beams; or a Tip from the goat by the barn (Speak with Animals) |
| ✅ | Village, the churchyard | Wand of Secrets (uncommon) | Search (Perception DC 14): a grave dug up and filled in again |
| ✅ | Village, behind a rain barrel | Oil of Slipperiness (uncommon) | Search (Perception DC 12): a flask kept dry (lane 28's spot) |
| ✅ | Burgomaster's mansion, study | Brooch of Shielding (uncommon) | Search (Investigation DC 13): behind the study desk; or a Tip from Kolyan himself (Speak with Dead) |
| ✅ | Ismark | +1 Rapier (uncommon) | Gift: his father's sword, after the burial (a rapier since the +N Longsword is Godrick's; (magic item audit, 2026-10-17)) |
| ✅ | Blood of the Vine | Headband of Intellect (uncommon) | Search (Investigation DC 14): sewn into the lining of the scholar's satchel (the Eyes are in Death House; (magic item audit, 2026-10-17)) |
| ✅ | Blood of the Vine, the Vistani women | Deck of Illusions (uncommon) | Gift: win them over with a song (Performance DC 13) |
| ✅ | Church nave | Staff of the Adder (uncommon) | Search (Investigation DC 14): a hollow under the front pew (the one Amulet of the Devout is Liriel's sunburst; (magic item audit, 2026-10-17)) |
| ✅ | Church undercroft | +1 Mace (uncommon) | Search (Perception DC 14): in an old priest's hands in the burial niches (the Periapt of Health is Kip's charm; (magic item audit, 2026-10-17)) |
| ✅ | Father Donavich | Gem of Brightness (uncommon) | Gift: if Doru is given rest |
| ✅ | Mad Mary | Necklace of Prayer Beads (rare) | Gift: when Gertruda comes home (late in the game) |
| ✅ | Teodor's empty grave, the churchyard | Shield, +1 (uncommon) | Tip: Teodor tells you at dawn (The Polite Caller, docs/story/side_quests.md) |
| ✅ | Bildrath | Wraps of Unarmed Power, +1 (uncommon) | Gift: his hush money after the walking firewood (Cut After Noon) |
| ✅ | Old Mihail | Elemental Gem (Blue Sapphire) (uncommon) | Gift: the bride's little blue stone, once she's buried (Six Feet) |
| ✅ | The burgomaster's study, behind the bricks | Mithral Armor (uncommon) | Hoard: Sergiu's shirt, once the Tenant is dead (The Burgomaster's Hound, docs/story/side_quests.md) |
| ✅ | Death House, Walter's crypt | Stone of Good Luck (uncommon) | Gift: Veta's lucky stone, left on the lid once she's laid with her son (The Nursemaid's Grave, docs/story/side_quests.md) |
| ✅ | The charcoal-burners' hollow, Agafia | Bag of Tricks (Tan) (uncommon) | Gift: her grandmother's bag, once the pack's hunters are beaten at her door (The Oat Thief, docs/story/side_quests.md) |

## Svalich Road (level 4)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Tser Pool, the broken cart | Bag of Holding (uncommon) | Search (Investigation DC 12): a false floor in the cart (from the open road, 2026-10-09) |
| ✅ | Crossroads, the field wall by the falls track | Gauntlets of Ogre Power (uncommon) | Search (Perception DC 14): a farmer's cache behind the wall (from the open road, 2026-10-09); or a Tip from Nicu on the gallows (Speak with Dead) |
| ✅ | Tser Falls, the claw-marked pine | Goggles of Night (uncommon) | Search (Perception DC 14): a satchel snagged high in the branches (from the Svalich Woods road, 2026-10-09) |
| ✅ | Tser Falls, the fallen trunk | Staff of the Python (uncommon) | Search (Investigation DC 12): a hollow in the trunk (from the Svalich Woods road, 2026-10-09; was a second Bag of Tricks, (magic item audit, 2026-10-17)) |
| ✅ | Tser Falls, a woodcutter's stump | +1 Handaxe (uncommon) | Search (Perception DC 12): an axe left in the stump (lane 28's spot, from the Svalich Woods road, 2026-10-09) |
| ✅ | Crossroads, the unmarked mounds | Boots of Elvenkind (uncommon) | Search (Perception DC 14): a mound that isn't as old as the others; or a Tip from the raven on the fencepost (Speak with Animals) |
| ✅ | Crossroads, the carved milestone | Wand of Web (uncommon) | Search (Investigation DC 14): a hollow behind the stone; or a Tip from Steaua, tied to it (Speak with Animals) |
| ✅ | Tser Falls, the stone of tokens | Pearl of Power (uncommon) | Search (Perception DC 13): one token among the many that hums |
| ✅ | Tser Falls, the cairn of names | Necklace of Adaptation (uncommon) | Search (Perception DC 13) |
| ✅ | Tser Pool, the ribbon tree | +1 Shortbow (uncommon) | Search (Investigation DC 14): a Vistani cache in the roots (the boots went to Ilarion; (magic item audit, 2026-10-17)) |
| ✅ | Tser Pool, in the reeds | Elemental Gem, Yellow Diamond (uncommon) | Search (Perception DC 12): a gambler's stake in a bag of dice (lane 28's spot; was a Stone of Good Luck, now Veta's in The Nursemaid's Grave) |
| ✅ | Tser Pool, a hollow stump | Potion of Fire Breath (uncommon) | Search (Perception DC 14): a flask hidden from Stanimir (lane 28's spot); or a Tip from the camp dog (Speak with Animals) |
| ✅ | Big Tobar, Tser Pool | Efficient Quiver (uncommon) | Gift: once his son is home (Called by Name, docs/story/side_quests.md) |
| ✅ | Tser Pool, Madam Eva's painted chest | Potion of Clairvoyance (rare) | Hoard: a seer's own (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Radu, Tser Pool | Rod of the Pact Keeper, +1 (uncommon) | Gift: once the carriage's escort is beaten (The Grey Mare, docs/story/side_quests.md) |

## The roads (random encounters)

Ashwin (2026-10-09): the good finds that used to sit on the road maps, which only a random encounter opens, went into
the main story above (each row says where from), and the road maps got different finds. Every random encounter also
pays now (story/road_spoils.gd): a fight leaves coins by each foe's Challenge Rating, a potion, gem or spell scroll in
step with the party's level, and a chance of a magic item that grows with how hard the fight was; a meeting on the road
leaves a smaller purse and one find.

| | Where | Item | How |
|---|---|---|---|
| ✅ | The open road, the broken cart | Dust of Dryness (uncommon) | Search (Investigation DC 12): under a loose board |
| ✅ | The open road, the field wall | Gloves of Swimming and Climbing (uncommon) | Search (Perception DC 14): tucked in a gap |
| ✅ | Svalich Woods, the claw-marked pine | Ring of Jumping (uncommon) | Search (Perception DC 14): high on a branch |
| ✅ | Svalich Woods, the fallen trunk | Wand of Magic Detection (uncommon) | Search (Investigation DC 12): in a split |
| ✅ | Svalich Woods, a woodcutter's stump | Potion of Resistance, Cold (uncommon) | Search (Perception DC 12): his flask |
| ✅ | The miller's lane, the ditch | Potion of Gaseous Form (rare) | Search (Perception DC 13) |
| ✅ | The miller's lane, the wayside shrine | Potion of Resistance, Poison (uncommon) | Search (Perception DC 13): an offering |
| ✅ | The Amber Temple road, the frozen traveller | Potion of Giant Strength, Frost (rare) | Search (Perception DC 12): in his pack |

## The crossroads by day (side quest, level 5)

| | Where | Item | How |
|---|---|---|---|
| ✅ | The River Ivlis crossroads, the Wagon's belly | Gem of Seeing (rare) | Hoard: once the Tinker's Wagon is dead (The Tinker's Wagon, docs/story/side_quests.md) |

## The crossroads at night (side quest, level 8)

| | Where | Item | How |
|---|---|---|---|
| ✅ | The River Ivlis crossroads, the Huntsman's saddlebag | Ring of Animal Influence (rare) | Hoard: once the Huntsman is beaten (The Count's Huntsman, docs/story/side_quests.md) |
| ✅ | The River Ivlis crossroads, across the Huntsman's saddle | Oathbow (very rare) | Hoard: the black bow he hunted with, once he's beaten (Hoard upgrades, Ashwin 2026-10-15) |

## Vallaki (level 5)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Town, by the stocks | Ring of Protection (rare) | Search (Perception DC 13): trodden into the mud; or a Tip from the big dog in the square (Speak with Animals) |
| ✅ | Lower town, the leaning hovel | +1 Leather Armor (rare) | Search (Perception DC 14): a sack under the step (was a Handy Haversack, a third carry-all; (magic item audit, 2026-10-17)) |
| ✅ | Wachterhaus, Lady Wachter's desk | Eyes of Charming (uncommon) | Search (Investigation DC 15): a hidden drawer |
| ✅ | Wachterhaus cellar, the dark shrine | Rod of Rulership (rare) | Search (Perception DC 15): the cult's tithe under the shrine |
| ✅ | Burgomaster's mansion, Victor's attic | Tentacle Rod (rare) | Search (Investigation DC 15): under the chalk circle's loose board (the one Wand of the War Mage is Khazan's +3; (magic item audit, 2026-10-17)) |
| ✅ | Burgomaster's mansion, the Baron's study | Necklace of Fireballs (rare) | Search (Investigation DC 15): behind the festival ledger |
| ✅ | Burgomaster's mansion, Izek's chest | Potion of Hill Giant Strength (uncommon) | Hoard |
| ✅ | Burgomaster's mansion, Izek's chest | Potion of Fire Giant Strength (rare) | Hoard (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Blue Water Inn, the rooms upstairs | Gloves of Thievery (uncommon) | Search (Perception DC 15): a loose board under a bed |
| ✅ | Blue Water Inn, the taproom hearth | Bead of Force (rare) | Search (Investigation DC 15): a loose brick |
| ✅ | Rictavio (Van Richten) | Hat of Disguise (uncommon) | Gift: when you unmask him |
| ✅ | St. Andral's crypt | Mace of Disruption (rare) | Tip: when the bones are back, the saint's niche opens |
| ✅ | Coffin maker's storeroom | Slippers of Spider Climbing (uncommon) | Search (Investigation DC 14): a coffin with a false bottom |
| ✅ | Vistani camp, Luvash | Cloak of the Manta Ray (uncommon) | Gift: when Arabelle comes home |
| ✅ | Vistani camp, Arrigal's wagon | Dagger of Venom (rare) | Search (Investigation DC 16): Arrigal's hidden drawer; or a Tip from his black horse (Speak with Animals) |
| ✅ | Stella Wachter, St. Andral's | Cloak of the Bat (rare) | Gift: the master's birthday present, once her curse is broken (The Cat in the Window, docs/story/side_quests.md) |
| ✅ | Ignat the lamplighter | Ring of Resistance, Necrotic (rare) | Gift: Catalina's mother's ring, once Catalina is at rest (Black Roses) |
| ✅ | Watchman Dobre's satchel | Arcane Grimoire, +2 (rare) | Gift: in the satchel once Dobre is beaten (Ribbons) |
| ✅ | Yevgeni | Horn of Valhalla, Silver (rare) | Gift: his father's horn, with the bounty on Old Greytooth (The Hunters at the Inn) |
| ✅ | Urwin Martikov | Elven Chain (rare) | Gift: his grandfather's mail, once Bray is home and himself (The Ravens' Ransom, docs/story/side_quests.md) |
| ✅ | Old Sabin, the lantern stall | Dream Weaver (rare) | Gift: Liliana's dream-catcher, once Sandu's home from the lake (One Lantern Too Many, docs/story/side_quests.md) |
| ✅ | Haralamb the painter, the east row | Nolzur's Marvelous Pigments (very rare) | Gift: the count's paints, made clean, once his canvas is burned (The Count's Portraitist, docs/story/side_quests.md) |

## Lake Zarovich (level 8)

| | Where | Item | How |
|---|---|---|---|
| ✅ | The rotten jetty | +1 Breastplate (rare) | Search (Perception DC 14): under the boards (was a Ring of Water Walking, which did nothing; (magic item audit, 2026-10-17)) |
| ✅ | An empty hut | Folding Boat (rare) | Search (Investigation DC 14): a loose hearthstone |
| ✅ | The fishers' shrine | +2 Trident (rare) | Search (Perception DC 13) (was a Trident of Fish Command; (magic item audit, 2026-10-17)) |
| ✅ | The drowned chapel under the lake | Staff of Healing (rare) | Gift: once the bell is silenced (The Bell Under the Lake, docs/story/side_quests.md) |

## Old Bonegrinder (level 6)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Ground floor, the pantry | Dust of Sneezing and Choking (uncommon) | Search (Investigation DC 15): a sack of "flour" that isn't |
| ✅ | Ground floor, the great oven | Brazier of Commanding Fire Elementals (rare) | Search (Investigation DC 15): something cooling in the ash |
| ✅ | Loft, up in the rafters | Broom of Flying (uncommon) | Search (Perception DC 15): a broom far too clean for this house; or a Tip from the hags' garden (Speak with Plants) |
| ✅ | Loft, the little bags on hooks | Portable Hole (rare) | Search (Perception DC 15): a black cloth folded among the bags |
| ✅ | The crag, the dead oak | Figurine of Wondrous Power, Silver Raven (uncommon) | Search (Perception DC 14): a raven's hoard in the hollow; or a Tip from the ravens themselves (Speak with Animals) |
| ✅ | The hill, the ditch by the track | Vicious Dagger (rare) | Search (Perception DC 13): a knife dropped in a hurry (lane 28's spot, from the miller's lane, 2026-10-09) |
| ✅ | The track, Granny Ash's basket | Robe of Eyes (rare) | Hoard: once Granny Ash is dead (The Fourth Sister, docs/story/side_quests.md) |
| ✅ | Loft, the chest under the straw | Staff of Charming (rare), Wand of Wonder (rare) | Hoard: the coven's (Hoard upgrades, Ashwin 2026-10-15) |

## The Wizard of Wines (level 6)

| | Where | Item | How |
|---|---|---|---|
| ✅ | The yard well | Rope of Climbing (uncommon) | Search (Perception DC 13): tied off below the lip |
| ✅ | The yard, behind the casks | Eversmoking Bottle (uncommon) | Search (Perception DC 13): a bottle set aside (lane 28's spot) |
| ✅ | The vineyard, between the rows | +1 Moon Sickle (uncommon) | Search (Perception DC 12): dropped by a druid (lane 28's spot); or a Tip from the last green row (Speak with Plants) |
| ✅ | The vineyard's dead tree | Ring of Feather Falling (rare) | Search (Perception DC 15): the ravens' hoard; or a Tip from the winery's ravens (Speak with Animals) |
| ✅ | Cellar, the founder's cask | +2 Hand Crossbow (rare) | Search (Investigation DC 14) (was an Alchemy Jug; (magic item audit, 2026-10-17)) |
| ✅ | Press house, the wizard's casks | Rhythm-Maker's Drum, +2 (rare) | Search (Perception DC 14) (was a Decanter of Endless Water; (magic item audit, 2026-10-17)) |
| ✅ | Winery, the pried-up floorboards | Elemental Gem, Emerald (uncommon) | Search (Perception DC 15): what the druids missed |
| ✅ | Stefania Martikov | Periapt of Wound Closure (uncommon) | Gift: once the winery is reclaimed |
| ✅ | Davian Martikov | Wand of Fireballs (rare) | Gift: the Wizard of Wines' wand from the press-house rack, once the Black Row is cut out (The Black Row, docs/story/side_quests.md) |

## Yester Hill (level 7)

| | Where | Item | How |
|---|---|---|---|
| ✅ | The hill, a cairn of bones | Bracers of Archery (uncommon) | Search (Perception DC 15) |
| ✅ | The hill, the wicker cages | Rapier of Life Stealing (rare) | Search (Perception DC 15): a prisoner's sword under the cage floor (a rapier for a rogue, (magic item audit, 2026-10-17)) |
| ✅ | The back gully | Wand of Paralysis (rare) | Search (Investigation DC 15): a druid's cache |
| ✅ | The hill, a barrow mound | Scale Mail of Necrotic Resistance (rare) | Search (Perception DC 14): buried with a warrior (lane 28's spot; (magic item audit, 2026-10-17)) |
| ✅ | Gulthias Tree, the splintered heartwood | Staff of Withering (rare) | Search (Investigation DC 16) |
| ✅ | The wardens' hoard | Berserker Axe (rare, cursed) | Hoard |
| ✅ | Gulthias Tree, the druids' offerings | Staff of the Woodlands (rare), two Potions of Healing (Superior) (rare) | Hoard: Ruxandra's, at the crown (Hoard upgrades, Ashwin 2026-10-15) |

## Yester Hill (side quest, level 7)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Davian Martikov, the winery | Daern's Instant Fortress (rare) | Gift: once the lantern on Yester Hill is out (The Druid Who Came Back, docs/story/side_quests.md) |

## Krezk (level 7)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Krezk, the cairn by the track | Ring of Warmth (uncommon) | Search (Perception DC 14); or a Tip from Krezk's goats (Speak with Animals) |
| ✅ | Krezk, the watch fire | Sentinel Shield (uncommon) | Search (Perception DC 14): under the woodpile |
| ✅ | Krezk, a loose stone in the wall | Belt of Dwarvenkind (rare) | Search (Perception DC 14): rolled up behind the stone (lane 28's spot; the sling is Thorn's now, (magic item audit, 2026-10-17)) |
| ✅ | Krezk, the wayside shrine | Potion of Invulnerability (rare) | Search (Perception DC 13): a tin left for whoever needs it (from the miller's lane, 2026-10-09; Keoghtom's Ointment is Smaranda's in Vallaki, (magic item audit, 2026-10-17)) |
| ✅ | Krezk, the square by the shrine | Ring of the Ram (rare) | Gift: Old Pavel's father's ring, after Clovin's show (Clovin's Audience, docs/story/side_quests.md) |
| ✅ | Krezk, the watch house | Iron Bands of Bilarro (rare) | Gift: Krezk's bounty from Dmitri, once the Grandsire is dead (The Pack's Runt, docs/story/side_quests.md) |
| ✅ | Burgomaster's house, the eldest son's room | Ioun Stone of Awareness (rare) | Search (Investigation DC 15): a box under the bed |
| ✅ | Pool of the White Sun, the candle box | Scroll of Protection from Undead (rare) | Search (Investigation DC 14) |
| ✅ | Pool of the White Sun, the pool's edge | Bloodwell Vial, +2 (rare) | Search (Perception DC 13): a mourner's offering (lane 28's spot; (magic item audit, 2026-10-17)) |
| ✅ | Anna Krezkova | Amulet of Health (rare) | Gift: once Ilya is well |
| ✅ | Dmitri Krezkov | Armor, +1 (rare; chain mail) | Gift: his grandfather's mail, once Sorin is found (Lighter Than It Should Be, docs/story/side_quests.md) |

## The Abbey of St. Markovia (level 7)

| | Where | Item | How |
|---|---|---|---|
| ✅ | The bell tower | Chime of Opening (rare) | Search (Perception DC 15): a little chime hung inside the great bell |
| ✅ | The courtyard, a bench heaped with feathers | Feather Token, Whip (rare) | Search (Perception DC 12): one feather from no bird (lane 28's spot) |
| ✅ | Wards, the foundling cots | Figurine of Wondrous Power, Golden Lions (rare) | Search (Perception DC 14): a child's hidden treasure |
| ✅ | Wards, the matron's room | Robe of Useful Items (uncommon) | Search (Investigation DC 14): sewn into the trunk's lining |
| ✅ | Wards, the instrument cabinet | Periapt of Proof against Poison (rare) | Search (Investigation DC 15) |
| ✅ | Church, the Abbot's cot | Ioun Stone of Protection (rare) | Search (Investigation DC 16) |
| ✅ | Garden, the tool shed | Bag of Beans (rare) | Search (Investigation DC 13) |
| ✅ | Mother, on the courtyard wall | Winged Boots (uncommon) | Gift: her eighth gift, once she flies (Mother's Ninth Improvement, docs/story/side_quests.md) |
| ✅ | Church, the sacristy's vestment chest | Mace of Smiting (rare) | Hoard: the Abbot's; he tells you to take it in the repentant ending (Hoard upgrades, Ashwin 2026-10-15) |

## Argynvostholt (level 8)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Courtyard, the well | Cube of Force (rare) | Search (Perception DC 15) |
| ✅ | Hall, the armour stands | Flame Tongue Longsword (rare) | Search (Perception DC 15) |
| ✅ | Hall, the chapel altar | Bowl of Commanding Water Elementals (rare) | Search (Investigation DC 15): a reliquary behind the altar ((magic item audit, 2026-10-17)) |
| ✅ | Upper floor, the empty plinth | Ring of Resistance, Cold (rare) | Search (Investigation DC 16) |
| ✅ | Upper floor, the dragon's desk | Figurine of Wondrous Power, Bronze Griffon (rare) | Search (Investigation DC 16) (was a Wand of Enemy Detection; (magic item audit, 2026-10-17)) |
| ✅ | Beacon | Lantern of Revealing (uncommon) | Search (Perception DC 14): the lamp-keeper's niche |
| ✅ | Argynvost's mausoleum | Dragonhide Belt, +2 (rare) | Tip: once the beacon is lit, a niche at the bier opens (the +N Shield is Teodor's; (magic item audit, 2026-10-17)) |
| ✅ | Sir Godfrey | +1 Plate Armor (rare) | Gift: if he takes up the Order's oath again |
| ✅ | Sir Godfrey, at the squires' graves | Arrow-Catching Shield (rare) | Gift: Ioan's shield, once Cosmin stands the vigil (The Squire, docs/story/side_quests.md) |
| ✅ | Upper floor, the commander's strongbox | Ioun Stone (Leadership) (very rare), Potion of Heroism (rare) | Hoard: Vladimir's (lock 18) (Hoard upgrades, Ashwin 2026-10-15) |

## Van Richten's Tower and the Werewolf Den (level 8)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Van Richten's island, the lookout rock | Eyes of the Eagle (uncommon) | Search (Perception DC 14) |
| ✅ | Van Richten's tower, the wall of trophies | Wand of Binding (rare) | Search (Investigation DC 16) |
| ✅ | Van Richten's tower, the jars and bottles | Oil of Etherealness (rare) | Search (Investigation DC 15) |
| ✅ | Ezmerelda | Glamoured Studded Leather (rare) | Gift: once she trusts you |
| ✅ | Ezmerelda's Hunter's Ledger, the Count's Huntsman | +1 Ring Mail (rare) | Gift: the bounty for the name, from party level 7 (Ezmerelda's rewards, Ashwin 2026-10-19; The Hunter's Ledger, docs/story/side_quests.md) |
| ✅ | Ezmerelda's Hunter's Ledger, the Grandsire | +2 Battleaxe (rare) | Gift: the bounty for the name, from party level 7 |
| ✅ | Ezmerelda's Hunter's Ledger, Kiril Stoyanovich | +2 Spear (rare) | Gift: the bounty for the name, from party level 7 |
| ✅ | Ezmerelda's Hunter's Ledger, Khazan | Sun Blade (rare) | Gift: the bounty for the name, from party level 7 |
| ✅ | Ezmerelda's Hunter's Ledger, Baba Lysaga | +2 Greataxe (rare) | Gift: the bounty for the name, from party level 8 |
| ✅ | Ezmerelda's Hunter's Ledger, Sarkhaza | +2 Scale Mail (very rare) | Gift: the bounty for the name, from party level 9 |
| ✅ | Ezmerelda's Hunter's Ledger, the Eye Below | +3 Maul (very rare) | Gift: the bounty for the name, from party level 9 |
| ✅ | Van Richten's tower, his strongbox | Arrow of Undead Slaying, two (very rare) | Hoard: the hunter's own (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Werewolf den slope, something in the mud | Boots of Speed (rare) | Search (Perception DC 13): a hunter's boots; or a Tip from Mircea, whose they were, in the bone midden (Speak with Dead) |
| ✅ | Werewolf caves, Kiril's trophies | Shortsword of Wounding (rare) | Search (Perception DC 15) (a shortsword for a rogue, (magic item audit, 2026-10-17)) |
| ✅ | Werewolf caves, the shrine of Mother Night | Figurine of Wondrous Power, Marble Elephant (rare) | Search (Perception DC 15): an offering hidden under the shrine (the Moon Sickle is the vineyard's; (magic item audit, 2026-10-17)) |
| ✅ | Werewolf caves, the drying herbs | Elixir of Health (rare) | Search (Investigation DC 14); or a Tip from the wolfsbane at the den's door (Speak with Plants) |
| ✅ | Zuleika | Ring of Free Action (rare) | Gift: once Emil is free of his chains |
| ✅ | Zuleika | Potion of Healing (Supreme), two (very rare) | Gift: if Emil stays with his pack after the pack challenge (Ashwin, 2026-10-14: Supreme, not plain Healing) |
| ✅ | Kiril's hoard (locked chest, DC 15) | Ring of Regeneration (very rare), +2 Longbow (rare), +1 Splint Armor (rare; both were a wand and a ring found elsewhere, (magic item audit, 2026-10-17)) | Hoard: a pack leader's spoils from the Krezk road (Ashwin, 2026-10-14: replaces the two Potions of Healing) |

## Under Van Richten's Tower (side quest, level 10)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Khazan's undercroft, the drowned crypt | Bracers of Defense (rare) | Search (Investigation DC 16): a drowned apprentice's, in the silt |
| ✅ | Khazan's study, his coffer | Wand of the War Mage, +3 (very rare) | Hoard: once he's gone for good (The Name Over the Door, docs/story/side_quests.md) |
| ✅ | Khazan's study, his coffer | Robe of the Archmagi (legendary) | Hoard: his own robe, once he's gone for good (Hoard upgrades, Ashwin 2026-10-15) |

## Berez, Mount Baratok, the Tsolenka Pass (level 9)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Baba Lysaga's hut, the cradle | Wand of Polymorph (very rare) | Search (Investigation DC 17): sewn into the lining |
| ✅ | Baba Lysaga's hut, the bundles in the beams | Potion of Speed (very rare) | Search (Investigation DC 16): the one jar that doesn't hum |
| ✅ | Berez, a drowned house | Mantle of Spell Resistance (rare) | Search (Perception DC 15) |
| ✅ | Berez, the Rag Queen in the scarecrow field | Dancing Sword (very rare) | Gift: Dragos, in Krezk, once she's burned (The One-Horned Billy, docs/story/side_quests.md) |
| ✅ | The Tsolenka Pass, the gorge wall | Staff of Frost (very rare) | Gift: Mother Ecaterina's lamp-pole, once the Penitent is down (The Frozen Pilgrims, docs/story/side_quests.md) |
| ✅ | The Tsolenka Pass, under the roc's nest | Belt of Hill Giant Strength (rare) | Hoard: in the bones under the nest, once the falconer is beaten (The Last Egg, docs/story/side_quests.md) |
| ✅ | Mordenkainen, in his hut | Ring of Telekinesis (very rare) | Gift: Corvina's first ring, once her letters are brought back (The Mage's Lost Pages, docs/story/side_quests.md) |
| ✅ | Berez, the scarecrow | Staff of Swarming Insects (rare) | Search (Perception DC 15): its arm is a staff |
| ✅ | Berez, under a fallen beam | Dwarven Thrower (very rare) | Search (Perception DC 14): a drowned tinker's roll (lane 28's spot; was an Immovable Rod, (magic item audit, 2026-10-17)) |
| ✅ | Marina's monument, the dowry chest | Robe of Scintillating Colors (very rare) | Hoard: Strahd's gift to her |
| ✅ | Mount Baratok, the ring of glass | Wand of Lightning Bolts (rare) | Search (Perception DC 15): fused into the glass |
| ✅ | Mount Baratok, the opened cairn | Ioun Stone of Intellect (very rare) | Search (Perception DC 16) |
| ✅ | Mount Baratok, the warded cairn | Spell Scrolls of Chain Lightning, Disintegrate (level 6), Delayed Blast Fireball and Forcecage (level 7) (all very rare) | Unstack the stones (Arcana DC 16 unpicks the ward): Mordenkainen's own scrolls under his spellbook (Ashwin, 2026-10-19: was two level 1 scrolls; a reader needs the spell on their class list, and one above their top slot a spellcasting ability check, DC 10 + the spell's level) |
| ✅ | Mount Baratok, the hut's yard | Spell Scroll of Cone of Cold (rare) | Search (Perception DC 13): a page blown into the snow (lane 28's spot) |
| ✅ | The Mad Mage's hut, the dragonchess board | Figurine of Wondrous Power, Serpentine Owl (rare) | Search (Investigation DC 17): one piece isn't a piece |
| ✅ | The Mad Mage's hut, the shelves of blank books | Tome of Understanding (very rare) | Search (Investigation DC 17) |
| ✅ | Mordenkainen | Ring of Spell Storing (rare) | Gift: once he remembers who he is |
| ✅ | Tsolenka Pass, the bones on the shelf | Wings of Flying (rare) | Search (Perception DC 15): a traveller the roc dropped |
| ✅ | Tsolenka Pass, the landing | Feather Token, Bird (rare) | Search (Perception DC 12): tucked in a roc's quill (lane 28's spot) |
| ✅ | Tsolenka Pass, a frozen traveller on the climb | Cloak of Arachnida (very rare) | Search (Perception DC 12): in his pack (lane 28's spot, from the Amber Temple road, 2026-10-09; the Rope of Climbing is the winery well's, (magic item audit, 2026-10-17)) |
| ✅ | Tsolenka Pass, the roc's nest | +2 Greatsword (rare) | Hoard |
| ✅ | Tsolenka guard tower, the rack of old mail | +2 Half Plate (very rare) | Search (Investigation DC 16): armour that never rusted (Dmitri's +1 is the chain mail; (magic item audit, 2026-10-17)) |
| ✅ | Tsolenka guard tower | Horn of Blasting (rare) | Search (Perception DC 14): the watch horn behind the winch |
| ✅ | Baba Lysaga's hut, the shelf of humming jars | Potion of Flying (very rare), Potion of Invulnerability (rare) | Hoard: once she's dead, bargained with or broken (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | The Mad Mage's hut, his travelling satchel | Spell Scroll of Mordenkainen's Sword (very rare) | Hoard (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Tsolenka Pass, the roc's nest | Ioun Stone (Agility) (very rare) | Hoard (Hoard upgrades, Ashwin 2026-10-15) |

## Mount Ghakis (side quest, level 10)

| | Where | Item | How |
|---|---|---|---|
| ✅ | The keepers' post under Ghakis, the captain's rack | Dragon Slayer (rare) | Hoard: the count's insurance against his own dragon (The Warm Snow, docs/story/side_quests.md) |
| ✅ | Sarkhaza's cavern, under the hoard | Dragon Scale Mail, silver (very rare) | Gift: the dead silver's own scales, under the red once she's dead (The Warm Snow, docs/story/side_quests.md) |
| ✅ | Sarkhaza's cavern, in the tithes | Ioun Stone (Mastery) (legendary) | Hoard: once she's dead (The Warm Snow; Hoard upgrades, Ashwin 2026-10-15) |

## The Amber Temple (level 10)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Entrance, the frozen traveller | Frost Brand Longsword (very rare) | Search (Perception DC 14): clutched in a frozen hand; or a Tip from the traveller (Speak with Dead) |
| ✅ | Entrance, the rack of halberds | +3 Halberd (very rare) | Search (Investigation DC 16) |
| ✅ | The ledge, the cairn of names | Candle of Invocation (very rare) | Search (Perception DC 12): an offering that never burned down (lane 28's spot) |
| ✅ | Great hall, a warden's cell | Ioun Stone of Insight (very rare) | Search (Investigation DC 17) |
| ✅ | Great hall, the desk kept clear of frost | Tome of Leadership and Influence (very rare) | Search (Investigation DC 17) |
| ✅ | Library, the books in chains | Tome of Clear Thought (very rare) | Search (Investigation DC 18): a book chained shut that isn't what its spine says |
| ✅ | Vault, the heap of offerings | Staff of Power (very rare) | Search (Perception DC 16) |
| ✅ | Exethanter | Robe of Stars (very rare) | Gift: if you help him remember |
| ✅ | Library, the chained case | Spell Scrolls of Circle of Death and Harm (very rare) | Hoard: behind the flameskulls (Hoard upgrades, Ashwin 2026-10-15) |

## Under the Amber Temple's vaults (side quest, level 10)

| | Where | Item | How |
|---|---|---|---|
| ✅ | The chamber of the Eye, its hoard | Spellguard Shield (very rare) | Hoard: once the Eye Below is dead (The Amber Debt, docs/story/side_quests.md) |
| ✅ | The chamber of the Eye, its hoard | Ring of Spell Turning (legendary) | Hoard: a warden's ring, once the Eye Below is dead (The Amber Debt; Hoard upgrades, Ashwin 2026-10-15) |

## Castle Ravenloft (level 10)

| | Where | Item | How |
|---|---|---|---|
| ✅ | Gates, the dry well | Rope of Entanglement (rare) | Search (Perception DC 15) |
| ✅ | Dining hall, the organ | Staff of Striking (very rare) | Search (Investigation DC 16): a stop that opens a compartment (the Instrument of the Bards is Death House's lute; (magic item audit, 2026-10-17)) |
| ✅ | Chapel, under the altar's dust | Ioun Stone (Fortitude) (very rare) | Search (Investigation DC 17) ((magic item audit, 2026-10-17)) |
| ✅ | Court, the count's desk | Efreeti Bottle (very rare) | Search (Investigation DC 17) (was a Crystal Ball; (magic item audit, 2026-10-17)) |
| ✅ | Court, the trophy room | Scimitar of Sharpness (very rare) | Search (Perception DC 15): the sword that took the dragon's head, above its skull (was a Dragon Slayer; The Warm Snow has that one) |
| ✅ | Blinsky Toys, Vallaki, once Pidlwick II is brought down from the high tower | Figurine of Wondrous Power, Obsidian Steed (very rare) | Gift: Blinsky's masterwork (The Toymaker's Masterpiece, docs/story/side_quests.md) |
| ✅ | Treasury | Manual of Gainful Exercise (very rare) | Hoard |
| ✅ | Treasury, the iron strongbox | Rod of Lordly Might (legendary) | Hoard: the von Zarovich kings' sceptre (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Treasury, the casket of gems | Ioun Stone (Absorption) (very rare) | Hoard (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Count's floor, Strahd's jewel box | Ring of Shooting Stars (very rare) | Hoard (lock 17) (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Count's floor, Rahadin's footlocker | Scimitar of Speed (very rare), +3 Heavy Crossbow (very rare; was a Ring of X-ray Vision, (magic item audit, 2026-10-17)) | Hoard (lock 17, or Stealth while his back is turned) (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Count's floor, the brides' things | Mace of Terror (rare; Volenta's chest), Figurine of Wondrous Power, Onyx Dog (rare; Anastrasya's trunk), Ioun Stone (Reserve) (rare; Ludmilla's books) | Hoard (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Tower rooms, Escher's dressing table | +2 Studded Leather Armor (very rare; was Boots of Levitation, (magic item audit, 2026-10-17)), Philter of Love (uncommon) | Hoard (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Main floor, the hidden vault behind the hearth | Animated Shield (very rare) | Hoard (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Strahd's tomb, the chest at the dais | Nine Lives Stealer longsword (very rare) | Hoard: the sword he carried when he took the valley (Hoard upgrades, Ashwin 2026-10-15) |
| ✅ | Count's floor, the tall mirror | Cloak of Displacement (rare) | Search (Investigation DC 17): behind a mirror that shows no one |
| ✅ | Count's floor, Ludmilla's books | Manual of Bodily Health (very rare) | Search (Investigation DC 17) (the one Arcane Grimoire is Dobre's +2; (magic item audit, 2026-10-17)) |
| ✅ | Tower rooms, the witches' cauldron | Wand of Fear (rare) | Search (Perception DC 15) |
| ✅ | The roost, a glint of brass | Ring of Evasion (rare) | Search (Perception DC 15): a raven's nest; or a Tip from the roost's oldest raven (Speak with Animals) |
| ✅ | Catacombs, the conjurer's bier | Staff of Thunder and Lightning (very rare) | Search (Investigation DC 16) ((magic item audit, 2026-10-17)) |
| ✅ | Catacombs, the jester's sarcophagus | Cape of the Mountebank (rare) | Search (Investigation DC 15); or a Tip from the first Pidlwick (Speak with Dead) |
| ✅ | The high tower, the lamplighters' closet behind the tapestry | Staff of Fire (very rare), Potion of Supreme Healing, three diamonds, 450 gp | Hoard: the closet the tapestry's tower plan shows (Investigation DC 14), a late-game secret worth finding (Ashwin, magic item audit, 2026-10-17) |
| ✅ | Strahd's tomb, the chest at the dais | Potion of Supreme Healing, two (very rare) | Hoard |
| ✅ | Dungeon, the throne of bones | Ioun Stone (Strength) (very rare) | Search (Perception DC 16) (the Ring of Regeneration is Kiril's; (magic item audit, 2026-10-17)) |
| ✅ | Cyrus Belview | Ioun Stone of Sustenance (rare) | Gift: when you bring news of his family |
| ✅ | Pidlwick II | Figurine of Wondrous Power, Ebony Fly (rare) | Gift: when you bring back his key |
| ✅ | The catacombs, the crypt with no name | Rod of Absorption (very rare) | Hoard: in Corvina's crypt, once she's at rest (The Unnamed Crypt, docs/story/side_quests.md) |
| ✅ | The castle roofs, the south tower | Helm of Brilliance (very rare) | Gift: from Escher at dawn, whether he watches the sun come up or waits for one the count isn't in (Escher's Petition, docs/story/side_quests.md) |
| ✅ | Argynvostholt, the undercroft | Golden Idol of Good Fortunes (very rare) | Hoard: in the tithe-keeper's armour, once he's beaten (The Silver Hoard, docs/story/side_quests.md) |
| ✅ | Mount Baratok, the ring of glass | Censer of Controlling Air Elementals (rare) | Hoard: sunk in the glass where the mage's storm stood (The Forgotten Storm, docs/story/side_quests.md) |
| ✅ | The Krezk road, the waystone | Wand of Slumber (rare) | Gift: from Lark, once Yanko has come into the light (The Waystone, docs/story/side_quests.md) |
| ✅ | The goat path above the Tsolenka Pass | Rod of Alertness (very rare) | Hoard: in the guide's pack, once he's beaten (The Guide to the Temple, docs/story/side_quests.md) |
| ✅ | The Webbed Gully off the falls path | Boon Companion's Bands (uncommon) | Gift: from Tsura, once she's cut down (The Spiders' Gully, docs/story/side_quests.md) |
| ✅ | Under Lake Baratok, the Drowned Library | Manual of Quickness of Action (very rare) | Gift: from Xaver, once the Index is destroyed (The Drowned Library, docs/story/side_quests.md) |
| ✅ | Lake Zarovich, the Reed Isle | Dimensional Shackles (rare) | Gift: from Ostap, once the Baron's boatmen are beaten (The Baron's Island, docs/story/side_quests.md) |
| ✅ | The Old Svalich Road, the Grey Goose | Pipes of the Sewers (uncommon) | Hoard: under the hearthstone, once the innkeeper puts his lantern down (The Lantern in the Roadhouse, docs/story/side_quests.md) |
| ✅ | The Village of Barovia, the high pasture | Potion of Animal Friendship (uncommon) | Gift: from Goodwife Petra or Erno, once Snowdrop's fate is settled (The Goatherd's Count, docs/story/side_quests.md) |
| ✅ | The Tser Pool camp, the plank stage | Wind Fan (uncommon) | Gift: from Lavinia, once she knows where Bujor is (The Dancing Bear, docs/story/side_quests.md) |
| ✅ | Yester Hill, the foot of the hill | Blood Amulet (rare) | Gift: from Freydis, once Silverjaw is back in her mound (The Barrow on Yester Hill, docs/story/side_quests.md) |
| ✅ | Mount Ghakis, the count's quarry | Dwarven Plate (very rare) | Gift: from the mountain captive, once Grandfather's heart is back in the mountain (The Mountain's Heart, docs/story/side_quests.md) |
| ✅ | Mount Ghakis, the count's quarry | Stone of Controlling Earth Elementals (rare) | Hoard: Grandfather's heart, kept, cooled to a fist of red stone (The Mountain's Heart, docs/story/side_quests.md) |
