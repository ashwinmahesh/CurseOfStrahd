# Cheat codes

Every code the game's Cheat codes page accepts: 743 items, 542 of them magic, as of main `efefaa69` (2026-10-08).
Each code gives that item to the hero you pick, as many times as you like.

The codes come from `story/cheat_codes.gd`: the first six hex digits of sha256("cheat:<item id>"), in upper case, with
any clash settled in id order. They don't change when items are added, so a new item only adds a row here. Only
playable items answer to a code; an entry marked `"playable": false` keeps its code for later but isn't given. The
vault's Cheat Codes.md holds the same list and `make cheat-codes` rewrites it; `python3 tools/data/cheat_codes.py
--stdout` prints the current list.

## How to use a code

1. Press **Esc** for the pause menu and choose **Cheat codes** (beside Settings; it shows once you have a party).
2. Pick the hero to get the item (the one you have selected is picked already), type the code and press **Give** or
   Enter. Case, spaces and dashes don't matter.
3. Each press gives the item again. Ammunition comes as a bundle (20 Arrows), and magic items arrive identified.
4. A code marked *pick* is an item built on a base, like a +1 Weapon or a Spell Scroll: choose the weapon, armor or
   spell in the box before you give it. Spell Scroll (Cantrip) and Spell Scroll (Level 1) give a scroll of a random
   spell of that level instead.

Story items such as the Sunsword count as found for the story too, so giving them early can skip ahead.

## Magic items

### Common

| Item | Code | Kind | Pick |
|---|---|---|---|
| Armor of Gleaming | `E7B560` | Armor | pick an armor |
| Bead of Nourishment | `CA152D` | Wondrous |  |
| Bead of Refreshment | `C574D4` | Wondrous |  |
| Boots of False Tracks | `008573` | Wondrous |  |
| Candle of the Deep | `04B72D` | Wondrous |  |
| Cast-Off Armor | `9ECF68` | Armor | pick an armor |
| Cloak of Billowing | `3A908F` | Wondrous |  |
| Cloak of Many Fashions | `713739` | Wondrous |  |
| Clockwork Amulet | `5772CF` | Wondrous |  |
| Clothes of Mending | `3804F5` | Wondrous |  |
| Conjurer’s Canopy | `44A97E` | Wondrous |  |
| Dictation Quill | `BB173C` | Wondrous |  |
| Dread Helm | `5A7BEB` | Wondrous |  |
| Ear Horn of Hearing | `57F031` | Wondrous |  |
| Elocutionist’s Lexicon | `DB32BF` | Wondrous |  |
| Enduring Spellbook | `8ADA89` | Wondrous |  |
| Ensorcelled Missive | `F724CF` | Wondrous |  |
| Ersatz Eye | `DAAFBD` | Wondrous |  |
| Evergreen Fertilizer | `6C3C47` | Wondrous |  |
| Hat of Vermin | `FA34EF` | Wondrous |  |
| Hat of Wizardry | `B2AACD` | Wondrous |  |
| Heward's Handy Spice Pouch | `651D63` | Wondrous |  |
| Homeward Compass | `C35DC4` | Wondrous |  |
| Horn of Silent Alarm | `4F6392` | Wondrous |  |
| Instrument of Illusions | `725B3E` | Wondrous |  |
| Instrument of Scribing | `B56463` | Wondrous |  |
| Lock of Trickery | `D2FDA5` | Wondrous |  |
| Lucky Foot | `79459A` | Wondrous |  |
| Mechanical Wonder (Mobility) | `84FC63` | Wondrous |  |
| Moon-Touched Sword | `D85339` | Weapon | pick a weapon |
| Mystery Key | `7A89D5` | Wondrous |  |
| Orb of Direction | `E96FDC` | Wondrous |  |
| Orb of Time | `EB73B1` | Wondrous |  |
| Perfume of Bewitching | `F2F214` | Wondrous |  |
| Pipe of Smoke Monsters | `65091D` | Wondrous |  |
| Pole of Angling | `90200E` | Wondrous |  |
| Pole of Collapsing | `F82350` | Wondrous |  |
| Pot of Awakening | `926C7E` | Wondrous |  |
| Potion of Climbing | `67961D` | Potion |  |
| Rope of Mending | `5C8D17` | Wondrous |  |
| Ruby of the War Mage | `436E2B` | Wondrous |  |
| Shield of Expression | `3F1BDB` | Shield | pick a shield |
| Smoldering Armor | `F08972` | Armor | pick an armor |
| Spell Component Ring | `A71B97` | Ring |  |
| Spell Scroll | `51DB70` | Scroll | pick a spell |
| Staff of Adornment | `0F2613` | Staff |  |
| Staff of Birdcalls | `FC37D7` | Staff |  |
| Staff of Flowers | `8FA7D7` | Staff |  |
| Sweeping Broom | `6217B5` | Wondrous |  |
| Talking Doll | `14CBD0` | Wondrous |  |
| Tankard of Sobriety | `ED3541` | Wondrous |  |
| Unbreakable Arrow | `8FC146` | Ammunition |  |
| Veteran's Cane | `236393` | Weapon |  |
| Walloping Ammunition | `AD9435` | Ammunition | pick ammunition |
| Wand of Conducting | `3B8FBA` | Wand |  |
| Wand of Pyrotechnics | `D34980` | Wand |  |
| Wand of Scowls | `96A905` | Wand |  |
| Wand of Smiles | `EBD795` | Wand |  |

### Uncommon

| Item | Code | Kind | Pick |
|---|---|---|---|
| Adamantine Armor | `30D5A5` | Armor | pick an armor |
| Adamantine Weapon | `10FD84` | Weapon | pick a weapon or ammunition |
| Alchemy Jug | `CAA178` | Wondrous |  |
| Ammunition, +1 | `AF7996` | Ammunition | pick ammunition |
| Amulet of Proof against Detection and Location | `04C029` | Wondrous |  |
| Amulet of the Devout, +1 | `1512F8` | Wondrous |  |
| Arcane Grimoire, +1 | `7C1580` | Wondrous |  |
| Bag of Holding | `AC8D35` | Wondrous |  |
| Bag of Tricks (Gray) | `8966E0` | Wondrous |  |
| Bag of Tricks (Rust) | `E8DCC3` | Wondrous |  |
| Bag of Tricks (Tan) | `C0D299` | Wondrous |  |
| Barnacled Wave-Swept Weapon | `223462` | Weapon | pick a weapon |
| Black Potion of Dragon’s Breath | `3799C3` | Potion |  |
| Blemished Idol of Good Fortunes | `1EAFC5` | Wondrous |  |
| Bloodwell Vial, +1 | `91FCFD` | Wondrous |  |
| Blue Potion of Dragon’s Breath | `EC9137` | Potion |  |
| Boon Companions’ Bands | `DB4E69` | Ring |  |
| Boots of Elvenkind | `ACAEC8` | Wondrous |  |
| Boots of Striding and Springing | `6445D0` | Wondrous |  |
| Boots of the Winterlands | `ECBEC5` | Wondrous |  |
| Bracers of Archery | `153E48` | Wondrous |  |
| Brooch of Shielding | `F1FD38` | Wondrous |  |
| Broom of Flying | `71B8FD` | Wondrous |  |
| Budding Blossom Rod | `D66C24` | Rod |  |
| Cap of Water Breathing | `97B9E8` | Wondrous |  |
| Circlet of Blasting | `B73910` | Wondrous |  |
| Cloak of Elvenkind | `BA50B9` | Wondrous |  |
| Cloak of Protection | `A4E83D` | Wondrous |  |
| Cloak of the Manta Ray | `E3A122` | Wondrous |  |
| Decanter of Endless Water | `914DEF` | Wondrous |  |
| Deck of Illusions | `3D64B8` | Wondrous |  |
| Dispelling Ammunition | `FC2EA8` | Ammunition | pick ammunition |
| Dragonhide Belt, +1 | `DA059A` | Wondrous |  |
| Driftglobe | `9A8C3D` | Wondrous |  |
| Dust of Disappearance | `CF9DB2` | Wondrous |  |
| Dust of Dryness | `4A9A50` | Wondrous |  |
| Dust of Sneezing and Choking | `8C2671` | Wondrous |  |
| Efficient Quiver | `93F721` | Wondrous |  |
| Elemental Gem (Blue Sapphire) | `D3A2C8` | Wondrous |  |
| Elemental Gem (Emerald) | `249603` | Wondrous |  |
| Elemental Gem (Red Corundum) | `6FC7A7` | Wondrous |  |
| Elemental Gem (Yellow Diamond) | `5984F3` | Wondrous |  |
| Eversmoking Bottle | `032C95` | Wondrous |  |
| Eyes of Charming | `EF66BC` | Wondrous |  |
| Eyes of Minute Seeing | `A54A55` | Wondrous |  |
| Eyes of the Eagle | `449FF6` | Wondrous |  |
| Figurine of Wondrous Power (Silver Raven) | `D4E94D` | Wondrous |  |
| Gauntlets of Ogre Power | `D41577` | Wondrous |  |
| Gem of Brightness | `041B76` | Wondrous |  |
| Gloves of Missile Snaring | `F08BAB` | Wondrous |  |
| Gloves of Swimming and Climbing | `22B691` | Wondrous |  |
| Gloves of Thievery | `B3EA43` | Wondrous |  |
| Goading Ammunition | `D7C06E` | Ammunition | pick ammunition |
| Goggles of Night | `6C1AAB` | Wondrous |  |
| Green Potion of Dragon’s Breath | `C7ABA7` | Potion |  |
| Hat of Disguise | `C8D440` | Wondrous |  |
| Headband of Intellect | `BB420D` | Wondrous |  |
| Helm of Comprehending Languages | `BF57C0` | Wondrous |  |
| Helm of Telepathy | `77E848` | Wondrous |  |
| Immovable Rod | `0BE83D` | Rod |  |
| Instrument of the Bards (Doss Lute) | `A41E8E` | Wondrous |  |
| Instrument of the Bards (Fochlucan Bandore) | `B72BEC` | Wondrous |  |
| Instrument of the Bards (Mac-Fuirmidh Cittern) | `4A5395` | Wondrous |  |
| Javelin of Lightning | `219250` | Weapon |  |
| Keoghtom's Ointment | `DA1B18` | Wondrous |  |
| Lantern of Revealing | `408D8B` | Wondrous |  |
| Magewright’s Gloves | `D06B5F` | Wondrous |  |
| Mariner's Armor | `7290C1` | Armor | pick an armor |
| Martialist’s Quarterstaff | `8D25C2` | Staff |  |
| Medallion of Thoughts | `100F87` | Wondrous |  |
| Mithral Armor | `95278E` | Armor | pick an armor |
| Moon Sickle, +1 | `7FB2D2` | Weapon |  |
| Necklace of Adaptation | `12C31F` | Wondrous |  |
| Oil of Slipperiness | `52FFD1` | Potion |  |
| Ominous Staff of Skulls | `6B7E7C` | Staff |  |
| Orb of Divination Detection | `9FD467` | Focus |  |
| Orb of Sorcery | `DBC628` | Focus |  |
| Pearl of Power | `ED13D7` | Wondrous |  |
| Periapt of Health | `C8A6FF` | Wondrous |  |
| Periapt of Wound Closure | `7D975E` | Wondrous |  |
| Philter of Love | `2F7F38` | Potion |  |
| Pipes of Haunting | `FE5997` | Wondrous |  |
| Pipes of the Sewers | `787362` | Wondrous |  |
| Potion of Animal Friendship | `E9ED2F` | Potion |  |
| Potion of Fire Breath | `325072` | Potion |  |
| Potion of Giant Strength (Hill Giant) | `D6E962` | Potion |  |
| Potion of Growth | `4CCC58` | Potion |  |
| Potion of Healing (Greater) | `FF4A08` | Potion |  |
| Potion of Poison | `B3B294` | Potion |  |
| Potion of Resistance (Acid) | `2127DB` | Potion |  |
| Potion of Resistance (Cold) | `ED8A4B` | Potion |  |
| Potion of Resistance (Fire) | `240455` | Potion |  |
| Potion of Resistance (Force) | `49D4AE` | Potion |  |
| Potion of Resistance (Lightning) | `13550C` | Potion |  |
| Potion of Resistance (Necrotic) | `E34D75` | Potion |  |
| Potion of Resistance (Poison) | `10F536` | Potion |  |
| Potion of Resistance (Psychic) | `6F637B` | Potion |  |
| Potion of Resistance (Radiant) | `48815B` | Potion |  |
| Potion of Resistance (Thunder) | `F42393` | Potion |  |
| Potion of Tirelessness | `EDD25D` | Potion |  |
| Potion of Water Breathing | `9243F1` | Potion |  |
| Red Potion of Dragon’s Breath | `C5CF94` | Potion |  |
| Rhythm-Maker's Drum, +1 | `57E192` | Wondrous |  |
| Ring of Dedicated Focus | `BD6546` | Ring |  |
| Ring of Jumping | `E5F1A5` | Ring |  |
| Ring of Mind Shielding | `26BD50` | Ring |  |
| Ring of Swimming | `6798E8` | Ring |  |
| Ring of Warmth | `C908F5` | Ring |  |
| Ring of Water Walking | `3F8C54` | Ring |  |
| Robe of Useful Items | `7A853B` | Wondrous |  |
| Rod of the Pact Keeper, +1 | `7F4AAA` | Rod |  |
| Rope of Climbing | `C6832A` | Wondrous |  |
| Sending Stones | `509A92` | Wondrous |  |
| Sentinel Shield | `B8F013` | Shield | pick a shield |
| Shield, +1 | `16EC3E` | Shield | pick a shield |
| Silver Harper Pin | `AC7DD0` | Wondrous |  |
| Slippers of Spider Climbing | `6B01F9` | Wondrous |  |
| Spell-Slinger’s Puppet | `C926DC` | Wondrous |  |
| Staff of the Adder | `7EA386` | Staff |  |
| Staff of the Python | `E9B324` | Staff |  |
| Stone of Good Luck (Luckstone) | `4F66D1` | Wondrous |  |
| Thespian’s Playbill | `C118B1` | Wondrous |  |
| Thief’s Thimble | `C9277D` | Wondrous |  |
| Three Keyholes Dagger | `FE5D9F` | Weapon |  |
| Trident of Fish Command | `026EB6` | Weapon |  |
| Wand of Freshness | `97B08E` | Wand |  |
| Wand of Magic Detection | `D7D92C` | Wand |  |
| Wand of Magic Missiles | `8AED0E` | Wand |  |
| Wand of Secrets | `AB8979` | Wand |  |
| Wand of Web | `1518CC` | Wand |  |
| Wand of the War Mage, +1 | `32FACE` | Wand |  |
| Weapon of Warning | `62ABAE` | Weapon | pick a weapon |
| Weapon, +1 | `3360D9` | Weapon | pick a weapon |
| White Potion of Dragon’s Breath | `60AB1B` | Potion |  |
| Wind Fan | `0F3364` | Wondrous |  |
| Winged Boots | `DB1CA2` | Wondrous |  |
| Wraps of Unarmed Power, +1 | `39BDD3` | Wondrous |  |

### Rare

| Item | Code | Kind | Pick |
|---|---|---|---|
| Ammunition, +2 | `DC0B66` | Ammunition | pick ammunition |
| Amulet of Health | `46FE5A` | Wondrous |  |
| Amulet of the Devout, +2 | `F2459B` | Wondrous |  |
| Aquatic Wave-Swept Weapon | `553055` | Weapon | pick a weapon |
| Arcane Chatelaine | `36FC51` | Wondrous |  |
| Arcane Grimoire, +2 | `47F159` | Wondrous |  |
| Arcanist’s Bestiary | `DB8F2A` | Wondrous |  |
| Armor of Resistance (Acid) | `211DB1` | Armor | pick an armor |
| Armor of Resistance (Cold) | `DC0BDB` | Armor | pick an armor |
| Armor of Resistance (Fire) | `B1CEA4` | Armor | pick an armor |
| Armor of Resistance (Force) | `518485` | Armor | pick an armor |
| Armor of Resistance (Lightning) | `EEDC40` | Armor | pick an armor |
| Armor of Resistance (Necrotic) | `9DF2DA` | Armor | pick an armor |
| Armor of Resistance (Poison) | `43BCEB` | Armor | pick an armor |
| Armor of Resistance (Psychic) | `552198` | Armor | pick an armor |
| Armor of Resistance (Radiant) | `E90F1F` | Armor | pick an armor |
| Armor of Resistance (Thunder) | `744453` | Armor | pick an armor |
| Armor of Vulnerability (Bludgeoning) | `566E59` | Armor |  |
| Armor of Vulnerability (Piercing) | `62AE6F` | Armor |  |
| Armor of Vulnerability (Slashing) | `0F0622` | Armor |  |
| Armor, +1 | `F92E16` | Armor | pick an armor |
| Arrow-Catching Shield | `816C61` | Shield | pick a shield |
| Bag of Beans | `FF098A` | Wondrous |  |
| Bead of Force | `D46117` | Wondrous |  |
| Bellows of Strangulation | `089184` | Wondrous |  |
| Belt of Dwarvenkind | `1B9A43` | Wondrous |  |
| Belt of Giant Strength (Hill Giant) | `B6748F` | Wondrous |  |
| Berserker Axe | `9D0C12` | Weapon | pick a weapon |
| Blood Amulet | `785160` | Wondrous |  |
| Bloodwell Vial, +2 | `C56D31` | Wondrous |  |
| Boots of Levitation | `D261F6` | Wondrous |  |
| Boots of Speed | `F7B793` | Wondrous |  |
| Bowl of Commanding Water Elementals | `4C2D97` | Wondrous |  |
| Bracers of Defense | `F3166D` | Wondrous |  |
| Brazier of Commanding Fire Elementals | `1707F8` | Wondrous |  |
| Cape of the Mountebank | `4B050B` | Wondrous |  |
| Censer of Controlling Air Elementals | `532105` | Wondrous |  |
| Chattering Staff of Skulls | `2422B8` | Staff |  |
| Chime of Opening | `600630` | Wondrous |  |
| Cloak of Displacement | `D6688E` | Wondrous |  |
| Cloak of the Bat | `B149BB` | Wondrous |  |
| Cube of Force | `6FD0B1` | Wondrous |  |
| Daern's Instant Fortress | `DF3560` | Wondrous |  |
| Dagger of Venom | `4F8D50` | Weapon |  |
| Dimensional Shackles | `F4DF36` | Wondrous |  |
| Dissuader | `52B7CA` | Staff |  |
| Dragon Slayer | `097503` | Weapon | pick a weapon |
| Dragonhide Belt, +2 | `753E99` | Wondrous |  |
| Dream Weaver | `F9DB07` | Wondrous |  |
| Elixir of Health | `EB41F7` | Potion |  |
| Elven Chain | `B93D20` | Armor |  |
| Feather Token (Anchor) | `B323E9` | Wondrous |  |
| Feather Token (Bird) | `E1D07E` | Wondrous |  |
| Feather Token (Fan) | `B3107E` | Wondrous |  |
| Feather Token (Swan Boat) | `49CB8A` | Wondrous |  |
| Feather Token (Tree) | `191773` | Wondrous |  |
| Feather Token (Whip) | `34744E` | Wondrous |  |
| Figurine of Wondrous Power (Bronze Griffon) | `F81C05` | Wondrous |  |
| Figurine of Wondrous Power (Ebony Fly) | `0260BF` | Wondrous |  |
| Figurine of Wondrous Power (Golden Lions) | `3F3F25` | Wondrous |  |
| Figurine of Wondrous Power (Ivory Goats) | `1FDD82` | Wondrous |  |
| Figurine of Wondrous Power (Marble Elephant) | `0B042A` | Wondrous |  |
| Figurine of Wondrous Power (Onyx Dog) | `13BED8` | Wondrous |  |
| Figurine of Wondrous Power (Serpentine Owl) | `F3BF88` | Wondrous |  |
| Flame Tongue | `EF90A9` | Weapon | pick a weapon |
| Flowering Blossom Rod | `B71AE3` | Rod |  |
| Folding Boat | `5D2F72` | Wondrous |  |
| Gem of Seeing | `23A8D9` | Wondrous |  |
| Giant Slayer | `B09DBB` | Weapon | pick a weapon |
| Glamoured Studded Leather | `4665AD` | Armor |  |
| Golden Harper Pin | `34F85F` | Wondrous |  |
| Helm of Teleportation | `55D182` | Wondrous |  |
| Heward's Handy Haversack | `2BE7C9` | Wondrous |  |
| Horn of Blasting | `935AE8` | Wondrous |  |
| Horn of Valhalla (Brass) | `E60FF6` | Wondrous |  |
| Horn of Valhalla (Silver) | `142510` | Wondrous |  |
| Horseshoes of Speed | `00CB4A` | Wondrous |  |
| Instrument of the Bards (Canaith Mandolin) | `2E1FDC` | Wondrous |  |
| Instrument of the Bards (Cli Lyre) | `E568E1` | Wondrous |  |
| Ioun Stone (Awareness) | `AEA52B` | Wondrous |  |
| Ioun Stone (Protection) | `F32727` | Wondrous |  |
| Ioun Stone (Reserve) | `DBFADC` | Wondrous |  |
| Ioun Stone (Sustenance) | `65FD02` | Wondrous |  |
| Iron Bands of Bilarro | `366A07` | Wondrous |  |
| Mace of Disruption | `10C44D` | Weapon |  |
| Mace of Smiting | `D8AA8F` | Weapon |  |
| Mace of Terror | `C9298F` | Weapon |  |
| Mage Breaker | `2642B0` | Weapon |  |
| Mage’s Manacle | `70891B` | Wondrous |  |
| Mantle of Spell Resistance | `3F80E2` | Wondrous |  |
| Moon Sickle, +2 | `F78B07` | Weapon |  |
| Namer’s Needle | `15EA02` | Weapon |  |
| Necklace of Fireballs | `C54040` | Wondrous |  |
| Necklace of Prayer Beads | `80CA34` | Wondrous |  |
| Oil of Etherealness | `643E3A` | Potion |  |
| Periapt of Proof against Poison | `1C5B09` | Wondrous |  |
| Portable Hole | `5AF52C` | Wondrous |  |
| Potion of Clairvoyance | `FC0FCF` | Potion |  |
| Potion of Diminution | `E0386B` | Potion |  |
| Potion of Gaseous Form | `83402F` | Potion |  |
| Potion of Giant Strength (Fire Giant) | `AD6062` | Potion |  |
| Potion of Giant Strength (Frost Giant) | `63F66F` | Potion |  |
| Potion of Giant Strength (Stone Giant) | `F7B12B` | Potion |  |
| Potion of Healing (Superior) | `FDB255` | Potion |  |
| Potion of Heroism | `1DA183` | Potion |  |
| Potion of Invulnerability | `166999` | Potion |  |
| Potion of Mind Reading | `9FC653` | Potion |  |
| Prismatic Rune | `C6728A` | Wondrous |  |
| Rhythm-Maker's Drum, +2 | `278075` | Wondrous |  |
| Ring of Animal Influence | `A63CC3` | Ring |  |
| Ring of Evasion | `68597E` | Ring |  |
| Ring of Feather Falling | `23F806` | Ring |  |
| Ring of Free Action | `BD3D51` | Ring |  |
| Ring of Protection | `04F316` | Ring |  |
| Ring of Resistance (Acid) | `96084B` | Ring |  |
| Ring of Resistance (Cold) | `5C32CD` | Ring |  |
| Ring of Resistance (Fire) | `DF0E70` | Ring |  |
| Ring of Resistance (Force) | `2D2C90` | Ring |  |
| Ring of Resistance (Lightning) | `9A2CE9` | Ring |  |
| Ring of Resistance (Necrotic) | `C66411` | Ring |  |
| Ring of Resistance (Poison) | `97591A` | Ring |  |
| Ring of Resistance (Psychic) | `F23F86` | Ring |  |
| Ring of Resistance (Radiant) | `FBCE30` | Ring |  |
| Ring of Resistance (Thunder) | `C1B33B` | Ring |  |
| Ring of Spell Storing | `A69184` | Ring |  |
| Ring of X-ray Vision | `A5DDC2` | Ring |  |
| Ring of the Ram | `2F91A4` | Ring |  |
| Robe of Eyes | `2A0ACE` | Wondrous |  |
| Rod of Rulership | `0D9B83` | Rod |  |
| Rod of the Pact Keeper, +2 | `966EC3` | Rod |  |
| Rope of Entanglement | `D1F355` | Wondrous |  |
| Scholar’s Anchoring Bangle | `2B5497` | Wondrous |  |
| Scroll of Protection (Aberration) | `18574E` | Scroll |  |
| Scroll of Protection (Beast) | `8F86CD` | Scroll |  |
| Scroll of Protection (Celestial) | `6969CD` | Scroll |  |
| Scroll of Protection (Elemental) | `369EE3` | Scroll |  |
| Scroll of Protection (Fey) | `135010` | Scroll |  |
| Scroll of Protection (Fiend) | `B1AF3E` | Scroll |  |
| Scroll of Protection (Plant) | `94BF78` | Scroll |  |
| Scroll of Protection (Undead) | `F01040` | Scroll |  |
| Secret Keeper’s Circlet | `960224` | Wondrous |  |
| Shield of Missile Attraction | `5DB086` | Shield | pick a shield |
| Shield, +2 | `CEBA71` | Shield | pick a shield |
| Spell Duelist’s Trophy | `E55FFD` | Wondrous |  |
| Staff of Charming | `CFF274` | Staff |  |
| Staff of Healing | `E8308B` | Staff |  |
| Staff of Swarming Insects | `57D0E2` | Staff |  |
| Staff of Withering | `7589CA` | Staff |  |
| Staff of the Woodlands | `7952B3` | Staff |  |
| Stone of Controlling Earth Elementals | `7B610B` | Wondrous |  |
| Sun Blade | `CE9E0A` | Weapon |  |
| Sword of Life Stealing | `533341` | Weapon | pick a weapon |
| Sword of Wounding | `68CB08` | Weapon | pick a weapon |
| Tarnished Idol of Good Fortunes | `5A2FF5` | Wondrous |  |
| Ten Keyholes Dagger | `F53CF2` | Weapon |  |
| Tentacle Rod | `B6EE47` | Rod |  |
| Vicious Weapon | `87E170` | Weapon | pick a weapon |
| Wand of Binding | `702BE9` | Wand |  |
| Wand of Enemy Detection | `5BEADA` | Wand |  |
| Wand of Fear | `EDF355` | Wand |  |
| Wand of Fireballs | `351DF1` | Wand |  |
| Wand of Lightning Bolts | `1DECAA` | Wand |  |
| Wand of Paralysis | `88C307` | Wand |  |
| Wand of Slumber | `1E55D9` | Wand |  |
| Wand of Teeth | `322038` | Wand |  |
| Wand of Wonder | `2A93B3` | Wand |  |
| Wand of the War Mage, +2 | `B2EA0E` | Wand |  |
| Weapon, +2 | `7EA352` | Weapon | pick a weapon |
| Wings of Flying | `909753` | Wondrous |  |
| Wraps of Unarmed Power, +2 | `0A0E1D` | Wondrous |  |

### Very rare

| Item | Code | Kind | Pick |
|---|---|---|---|
| Ammunition of Slaying (Aberration) | `394B36` | Ammunition | pick ammunition |
| Ammunition of Slaying (Beast) | `E1CB08` | Ammunition | pick ammunition |
| Ammunition of Slaying (Celestial) | `1DD7BB` | Ammunition | pick ammunition |
| Ammunition of Slaying (Construct) | `F83BE0` | Ammunition | pick ammunition |
| Ammunition of Slaying (Dragon) | `26C885` | Ammunition | pick ammunition |
| Ammunition of Slaying (Elemental) | `C564FB` | Ammunition | pick ammunition |
| Ammunition of Slaying (Fey) | `720E6A` | Ammunition | pick ammunition |
| Ammunition of Slaying (Fiend) | `C2C9FF` | Ammunition | pick ammunition |
| Ammunition of Slaying (Giant) | `F72640` | Ammunition | pick ammunition |
| Ammunition of Slaying (Humanoid) | `407E54` | Ammunition | pick ammunition |
| Ammunition of Slaying (Monstrosity) | `D1B88A` | Ammunition | pick ammunition |
| Ammunition of Slaying (Ooze) | `42CD90` | Ammunition | pick ammunition |
| Ammunition of Slaying (Plant) | `AB8712` | Ammunition | pick ammunition |
| Ammunition of Slaying (Undead) | `1A34F1` | Ammunition | pick ammunition |
| Ammunition, +3 | `03F278` | Ammunition | pick ammunition |
| Amulet of the Devout, +3 | `CFF5C2` | Wondrous |  |
| Amulet of the Planes | `BE8E1C` | Wondrous |  |
| Animated Shield | `8BEE02` | Shield | pick a shield |
| Arcane Grimoire, +3 | `8CEAAD` | Wondrous |  |
| Armor, +2 | `D5062C` | Armor | pick an armor |
| Ascendant Wave-Swept Weapon | `9B6BF2` | Weapon | pick a weapon |
| Bag of Devouring | `92D6F4` | Wondrous |  |
| Belt of Giant Strength (Fire Giant) | `A74890` | Wondrous |  |
| Belt of Giant Strength (Frost Giant) | `77387F` | Wondrous |  |
| Belt of Giant Strength (Stone Giant) | `3B27FF` | Wondrous |  |
| Bloodwell Vial, +3 | `26D9F4` | Wondrous |  |
| Candle of Invocation | `1AD2E7` | Wondrous |  |
| Carpet of Flying (3 by 5 ft) | `5B8088` | Wondrous |  |
| Carpet of Flying (4 by 6 ft) | `534EB2` | Wondrous |  |
| Carpet of Flying (5 by 7 ft) | `B7A097` | Wondrous |  |
| Carpet of Flying (6 by 9 ft) | `5642CE` | Wondrous |  |
| Cloak of Arachnida | `FCE3D2` | Wondrous |  |
| Crystal Ball | `302C6E` | Wondrous |  |
| Dancing Sword | `0CE08F` | Weapon | pick a weapon |
| Demon Armor | `B51A34` | Armor |  |
| Dragon Scale Mail (Black) | `D89B60` | Armor |  |
| Dragon Scale Mail (Blue) | `15080E` | Armor |  |
| Dragon Scale Mail (Brass) | `0D4CCC` | Armor |  |
| Dragon Scale Mail (Bronze) | `4A4671` | Armor |  |
| Dragon Scale Mail (Copper) | `2A5DF7` | Armor |  |
| Dragon Scale Mail (Gold) | `0249F8` | Armor |  |
| Dragon Scale Mail (Green) | `BFA761` | Armor |  |
| Dragon Scale Mail (Red) | `6596EB` | Armor |  |
| Dragon Scale Mail (Silver) | `AAE412` | Armor |  |
| Dragon Scale Mail (White) | `45BB6C` | Armor |  |
| Dragonhide Belt, +3 | `7681F2` | Wondrous |  |
| Dwarven Plate | `8FAFB7` | Armor |  |
| Dwarven Thrower | `AF2A0C` | Weapon |  |
| Efreeti Bottle | `0DAFA8` | Wondrous |  |
| Figurine of Wondrous Power (Obsidian Steed) | `4B1420` | Wondrous |  |
| Frost Brand | `66D43B` | Weapon | pick a weapon |
| Golden Idol of Good Fortunes | `C4F1FF` | Wondrous |  |
| Helm of Brilliance | `2DCC85` | Wondrous |  |
| Horn of Valhalla (Bronze) | `B49910` | Wondrous |  |
| Horseshoes of a Zephyr | `DEE99F` | Wondrous |  |
| Instrument of the Bards (Anstruth Harp) | `5332D4` | Wondrous |  |
| Ioun Stone (Absorption) | `888D08` | Wondrous |  |
| Ioun Stone (Agility) | `BC84A1` | Wondrous |  |
| Ioun Stone (Fortitude) | `4E551F` | Wondrous |  |
| Ioun Stone (Insight) | `F83835` | Wondrous |  |
| Ioun Stone (Intellect) | `0A72CE` | Wondrous |  |
| Ioun Stone (Leadership) | `2D9287` | Wondrous |  |
| Ioun Stone (Strength) | `E0A25C` | Wondrous |  |
| Manual of Bodily Health | `FC46E6` | Wondrous |  |
| Manual of Gainful Exercise | `BF6BBB` | Wondrous |  |
| Manual of Golems | `A26141` | Wondrous |  |
| Manual of Quickness of Action | `5F7D5F` | Wondrous |  |
| Many Keyholes Dagger | `430183` | Weapon |  |
| Mirror of Life Trapping | `0FF69A` | Wondrous |  |
| Moon Sickle, +3 | `8A8311` | Weapon |  |
| Nine Lives Stealer | `BC8A9D` | Weapon | pick a weapon |
| Nolzur's Marvelous Pigments | `CE0158` | Wondrous |  |
| Oathbow | `075182` | Weapon |  |
| Oil of Sharpness | `C047B5` | Potion |  |
| Potion of Flying | `B1BCA5` | Potion |  |
| Potion of Giant Strength (Cloud Giant) | `7E1846` | Potion |  |
| Potion of Healing (Supreme) | `9988B0` | Potion |  |
| Potion of Invisibility | `B71DDE` | Potion |  |
| Potion of Longevity | `86184D` | Potion |  |
| Potion of Speed | `A4E0BE` | Potion |  |
| Potion of Vitality | `568AA4` | Potion |  |
| Pulverizing Staff of Skulls | `209959` | Staff |  |
| Rhythm-Maker's Drum, +3 | `81E49D` | Wondrous |  |
| Ring of Regeneration | `C39E49` | Ring |  |
| Ring of Shooting Stars | `7323E3` | Ring |  |
| Ring of Telekinesis | `F6C171` | Ring |  |
| Robe of Scintillating Colors | `E205F3` | Wondrous |  |
| Robe of Stars | `C81D5D` | Wondrous |  |
| Rod of Absorption | `3847A8` | Rod |  |
| Rod of Alertness | `773A50` | Rod |  |
| Rod of Security | `C7479A` | Rod |  |
| Rod of the Pact Keeper, +3 | `5C92E7` | Rod |  |
| Scimitar of Speed | `882C8E` | Weapon |  |
| Shield, +3 | `54FA78` | Shield | pick a shield |
| Somniferous Blossom Rod | `E84B4C` | Rod |  |
| Spellguard Shield | `E1EEED` | Shield | pick a shield |
| Staff of Fire | `30FA02` | Staff |  |
| Staff of Frost | `651C95` | Staff |  |
| Staff of Power | `076176` | Staff |  |
| Staff of Striking | `3FA542` | Staff |  |
| Staff of Thunder and Lightning | `6601B6` | Staff |  |
| Sword of Sharpness | `2B0AA8` | Weapon | pick a weapon |
| Tome of Clear Thought | `F346A5` | Wondrous |  |
| Tome of Leadership and Influence | `42076F` | Wondrous |  |
| Tome of Understanding | `6F1B83` | Wondrous |  |
| Tramontane Armor | `264286` | Armor | pick an armor |
| Wand of Polymorph | `E0B6D6` | Wand |  |
| Wand of the War Mage, +3 | `710D9B` | Wand |  |
| Weapon, +3 | `458D28` | Weapon | pick a weapon |
| Workshop Wrecker | `5B2D55` | Wondrous |  |
| Wraps of Unarmed Power, +3 | `685A4A` | Wondrous |  |

### Legendary

| Item | Code | Kind | Pick |
|---|---|---|---|
| Apparatus of Kwalish | `1D47C0` | Wondrous |  |
| Armor of Invulnerability | `78759F` | Armor |  |
| Armor, +3 | `B01815` | Armor | pick an armor |
| Belt of Giant Strength (Cloud Giant) | `957BD8` | Wondrous |  |
| Belt of Giant Strength (Storm Giant) | `29CB3A` | Wondrous |  |
| Cloak of Invisibility | `FE4DAD` | Wondrous |  |
| Crystal Ball of Mind Reading | `998A1F` | Wondrous |  |
| Crystal Ball of Telepathy | `6B2406` | Wondrous |  |
| Crystal Ball of True Seeing | `6999B7` | Wondrous |  |
| Cubic Gate | `08BBCA` | Wondrous |  |
| Deck of Many Things | `D02173` | Wondrous |  |
| Defender | `E2FB2E` | Weapon | pick a weapon |
| Diamond Staff | `141A00` | Staff |  |
| Efreeti Chain | `F9A193` | Armor |  |
| Grave Reaper | `B66EF6` | Weapon |  |
| Hammer of Thunderbolts | `ECF557` | Weapon |  |
| Holy Avenger | `C469D9` | Weapon | pick a weapon |
| Holy Symbol of Ravenkind | `3F1664` | Wondrous |  |
| Horn of Valhalla (Iron) | `20C63C` | Wondrous |  |
| Instrument of the Bards (Ollamh Harp) | `279BCE` | Wondrous |  |
| Ioun Stone (Greater Absorption) | `F3E6EA` | Wondrous |  |
| Ioun Stone (Mastery) | `E2D09D` | Wondrous |  |
| Ioun Stone (Regeneration) | `ED6DA0` | Wondrous |  |
| Iron Flask | `81A24B` | Wondrous |  |
| Luck Blade | `A2992E` | Weapon | pick a weapon |
| Plate Armor of Etherealness | `E3E05D` | Armor |  |
| Potion of Giant Strength (Storm Giant) | `147BEC` | Potion |  |
| Ring of Djinni Summoning | `347CF3` | Ring |  |
| Ring of Elemental Command (Air) | `CE7A75` | Ring |  |
| Ring of Elemental Command (Earth) | `F8B863` | Ring |  |
| Ring of Elemental Command (Fire) | `8CEC2B` | Ring |  |
| Ring of Elemental Command (Water) | `A6C478` | Ring |  |
| Ring of Invisibility | `02A369` | Ring |  |
| Ring of Spell Turning | `9DA68C` | Ring |  |
| Ring of Three Wishes | `EBCBB8` | Ring |  |
| Robe of the Archmagi | `2670D0` | Wondrous |  |
| Rod of Lordly Might | `E24751` | Rod |  |
| Rod of Resurrection | `24E4D8` | Rod |  |
| Scarab of Protection | `2D9F1B` | Wondrous |  |
| Sovereign Glue | `9C2E0C` | Wondrous |  |
| Sphere of Annihilation | `465374` | Wondrous |  |
| Staff of the Magi | `5A58EC` | Staff |  |
| Sunsword | `68D169` | Weapon |  |
| Talisman of Pure Good | `317D1F` | Wondrous |  |
| Talisman of Ultimate Evil | `2FAFF4` | Wondrous |  |
| Talisman of the Sphere | `0B74AA` | Wondrous |  |
| Tome of the Stilled Tongue | `9EDC5D` | Wondrous |  |
| Universal Solvent | `4714FE` | Wondrous |  |
| Vorpal Sword | `3CD3CD` | Weapon | pick a weapon |
| Well of Many Worlds | `80E063` | Wondrous |  |

### Artifact

| Item | Code | Kind | Pick |
|---|---|---|---|
| Axe of the Dwarvish Lords | `250189` | Weapon |  |
| Blackrazor | `126B4C` | Weapon |  |
| Book of Exalted Deeds | `05F81E` | Wondrous |  |
| Book of Vile Darkness | `D08D31` | Wondrous |  |
| Calimemnon Crystal | `24BB9D` | Focus |  |
| Demonomicon of Iggwilv | `BC741A` | Wondrous |  |
| Eye of Vecna | `F567CF` | Wondrous |  |
| Hand of Vecna | `E1DAEC` | Wondrous |  |
| Orb of Dragonkind | `51F0C1` | Wondrous |  |
| Queen Ehlissa’s Marvelous Nightingale | `5DABAD` | Wondrous |  |
| Sword of Kas | `A33CBA` | Weapon |  |
| Universal Pantograph | `31288E` | Wondrous |  |
| Wand of Orcus | `A5D82A` | Weapon |  |
| Wave | `2236E5` | Weapon |  |
| Whelm | `5EB6B7` | Weapon |  |

### Other

| Item | Code | Kind | Pick |
|---|---|---|---|
| Tome of Strahd | `D3F966` | Wondrous |  |

## Gear, weapons and armor

| Item | Code | Kind |
|---|---|---|
| Acid | `036754` | Consumable |
| Alchemist's Fire | `E06CFA` | Consumable |
| Alchemist's Supplies | `863519` | Tool |
| Antitoxin | `0BC990` | Consumable |
| Arcane Focus (Crystal) | `E1B956` | Focus |
| Arcane Focus (Orb) | `27BB72` | Focus |
| Arcane Focus (Rod) | `CC97E1` | Focus |
| Arcane Focus (Staff) | `8CDF5B` | Focus |
| Arcane Focus (Wand) | `7112F6` | Focus |
| Arrow | `359A02` | Ammunition |
| Backpack | `E7BE50` | Container |
| Bagpipes | `341D8C` | Tool |
| Ball Bearings | `DCF65F` | Gear |
| Barrel | `BB5238` | Container |
| Basic Poison | `C18921` | Consumable |
| Basket | `26B109` | Container |
| Battleaxe | `96164B` | Weapon |
| Bedroll | `9C89E9` | Gear |
| Bell | `F4A90B` | Gear |
| Blanket | `3BD31A` | Gear |
| Block and Tackle | `45272C` | Gear |
| Blowgun | `383AF7` | Weapon |
| Blowgun Needle | `16F12A` | Ammunition |
| Bones of St. Andral | `7071FB` | Quest |
| Book | `EB6CE9` | Gear |
| Breastplate | `06F717` | Armor |
| Brewer's Supplies | `6C2837` | Tool |
| Bucket | `6E851E` | Container |
| Bullseye Lantern | `F28AC8` | Light |
| Burglar's Pack | `A66B1D` | Pack |
| Calligrapher's Supplies | `52BA7F` | Tool |
| Caltrops | `65DC3F` | Gear |
| Candle | `3FD12A` | Light |
| Carpenter's Tools | `0A045F` | Tool |
| Cartographer's Tools | `D45C6E` | Tool |
| Chain | `4ACB8D` | Gear |
| Chain Mail | `D6E2FB` | Armor |
| Chain Shirt | `A84239` | Armor |
| Champagne du le Stomp | `794667` | Consumable |
| Chest | `DBE377` | Container |
| Climber's Kit | `20559F` | Gear |
| Club | `43F8D3` | Weapon |
| Cobbler's Tools | `35DFFD` | Tool |
| Coffin | `F073BA` | Gear |
| Component Pouch | `23A430` | Gear |
| Cook's Utensils | `34C9A2` | Tool |
| Costume | `94DE84` | Clothing |
| Crossbow Bolt | `3AA0A7` | Ammunition |
| Crossbow Bolt Case | `DD1F08` | Container |
| Crowbar | `472746` | Gear |
| Dagger | `0F7C71` | Weapon |
| Dart | `9E5CBB` | Weapon |
| Diamond | `9A9C6A` | Gear |
| Diamond Dust | `B87577` | Gear |
| Dice Set | `95EFA2` | Tool |
| Diplomat's Pack | `ED047A` | Pack |
| Disguise Kit | `D467CE` | Tool |
| Dragonchess Set | `A32572` | Tool |
| Dream Pastry | `CF411B` | Consumable |
| Druidic Focus (Sprig of Mistletoe) | `A6977B` | Focus |
| Druidic Focus (Wooden Staff) | `EC621A` | Focus |
| Druidic Focus (Yew Wand) | `544A2A` | Focus |
| Drum | `1BA7FA` | Tool |
| Dulcimer | `2E06D6` | Tool |
| Dungeoneer's Pack | `05B512` | Pack |
| Entertainer's Pack | `40617F` | Pack |
| Explorer's Pack | `7F76F2` | Pack |
| Fine Clothes | `22CE7F` | Clothing |
| Firearm Bullet | `9ECD2D` | Ammunition |
| Flail | `016164` | Weapon |
| Flask | `747576` | Container |
| Flute | `5346D3` | Tool |
| Forgery Kit | `B04A4A` | Tool |
| Glaive | `93DD76` | Weapon |
| Glass Bottle | `C8B2C3` | Container |
| Glassblower's Tools | `586C89` | Tool |
| Gold Dust | `07835D` | Gear |
| Goodberry | `814342` | Consumable |
| Grappling Hook | `3F9C66` | Gear |
| Greataxe | `5B7DF9` | Weapon |
| Greatclub | `D24535` | Weapon |
| Greatsword | `B15E0D` | Weapon |
| Halberd | `59BFBF` | Weapon |
| Half Plate Armor | `797841` | Armor |
| Hand Crossbow | `D51B06` | Weapon |
| Handaxe | `CC1045` | Weapon |
| Healer's Kit | `5D873A` | Consumable |
| Heavy Crossbow | `047416` | Weapon |
| Herbalism Kit | `505239` | Tool |
| Hide Armor | `AF678D` | Armor |
| Holy Symbol (Amulet) | `B2D1F9` | Focus |
| Holy Symbol (Emblem) | `E31D3E` | Focus |
| Holy Symbol (Reliquary) | `B958C1` | Focus |
| Holy Water | `15DD20` | Consumable |
| Hooded Lantern | `A3E760` | Light |
| Horn | `1E57E8` | Tool |
| Hunting Trap | `BC7D3C` | Gear |
| Incense | `BC35AF` | Gear |
| Ink | `35F1F3` | Gear |
| Ink Pen | `38A3E9` | Gear |
| Iron Attic Key | `A090B2` | Quest |
| Iron Pot | `419764` | Container |
| Iron Spike | `48E07A` | Gear |
| Jade Dust | `D0AF64` | Gear |
| Javelin | `3210E4` | Weapon |
| Jeweler's Tools | `9FF9E2` | Tool |
| Jug | `A9B624` | Container |
| Ladder | `825345` | Gear |
| Lamp | `6B56B9` | Light |
| Lance | `4576E1` | Weapon |
| Leather Armor | `519063` | Armor |
| Leatherworker's Tools | `62B8D2` | Tool |
| Light Crossbow | `1D7BD1` | Weapon |
| Light Hammer | `904E7E` | Weapon |
| Lock | `19A6C5` | Gear |
| Longbow | `0E3BE3` | Weapon |
| Longsword | `14D16A` | Weapon |
| Lute | `5EFED1` | Tool |
| Lyre | `6D688A` | Tool |
| Mace | `6BA092` | Weapon |
| Magnifying Glass | `B40760` | Gear |
| Manacles | `6CE750` | Gear |
| Map | `F86EA2` | Gear |
| Map or Scroll Case | `C6851D` | Container |
| Mason's Tools | `58F9D3` | Tool |
| Maul | `FF6FD8` | Weapon |
| Mirror | `E18177` | Gear |
| Morningstar | `5609A6` | Weapon |
| Musket | `AD5062` | Weapon |
| Navigator's Tools | `B5D8E0` | Tool |
| Net | `FAEAA4` | Gear |
| Oil | `FD1AE7` | Consumable |
| Onyx | `2AE314` | Gear |
| Padded Armor | `03E824` | Armor |
| Painter's Supplies | `1E4238` | Tool |
| Pan Flute | `4980BC` | Tool |
| Paper | `AFD648` | Gear |
| Parchment | `C44D57` | Gear |
| Pearl | `672E96` | Gear |
| Perfume | `36E426` | Consumable |
| Pike | `C74915` | Weapon |
| Pistol | `416AB1` | Weapon |
| Plate Armor | `CF1446` | Armor |
| Playing Card Set | `7B46DA` | Tool |
| Poisoner's Kit | `3175CA` | Tool |
| Pole | `17D4B3` | Gear |
| Portable Ram | `67F2BA` | Gear |
| Potion of Healing | `D5E5CA` | Potion |
| Potter's Tools | `CB0F2C` | Tool |
| Pouch | `58A3C5` | Container |
| Priest's Pack | `BD66AF` | Pack |
| Purple Grapemash No. 3 | `1B2A78` | Consumable |
| Quarterstaff | `5AA2AC` | Weapon |
| Quiver | `22E501` | Container |
| Rapier | `45E26C` | Weapon |
| Ration | `905FF6` | Consumable |
| Red Dragon Crush | `F41649` | Consumable |
| Ring Mail | `456CBA` | Armor |
| Robe | `7C5EBF` | Clothing |
| Rope | `CD501C` | Gear |
| Ruby Dust | `9D4C0D` | Gear |
| Sack | `94EF92` | Container |
| Salt and Silver | `1C00D7` | Gear |
| Scale Mail | `46510C` | Armor |
| Scholar's Pack | `250B00` | Pack |
| Scimitar | `3D6B3D` | Weapon |
| Shawm | `128F16` | Tool |
| Shield | `36379E` | Shield |
| Shortbow | `C31AEF` | Weapon |
| Shortsword | `192587` | Weapon |
| Shovel | `24E167` | Gear |
| Sickle | `3E18C5` | Weapon |
| Signal Whistle | `4787CA` | Gear |
| Sling | `8275F1` | Weapon |
| Sling Bullet | `E2C1DC` | Ammunition |
| Smith's Tools | `D5F5BE` | Tool |
| Spear | `C0DA4C` | Weapon |
| Spell Scroll (Cantrip) | `DB4D91` | Scroll |
| Spell Scroll (Level 1) | `19D570` | Scroll |
| Spellbook | `4909D3` | Gear |
| Splint Armor | `BC784D` | Armor |
| Spyglass | `BEDA84` | Gear |
| String | `15A6E5` | Gear |
| Studded Leather Armor | `8DE8B4` | Armor |
| Tent | `D887EE` | Gear |
| The Dursts' Spellbook | `F01BC3` | Gear |
| Thieves' Tools | `631EA6` | Tool |
| Three-Dragon Ante Set | `194343` | Tool |
| Tinderbox | `D87796` | Gear |
| Tinker's Tools | `667596` | Tool |
| Torch | `7E3759` | Light |
| Traveler's Clothes | `7D40AB` | Clothing |
| Trident | `33866D` | Weapon |
| Vial | `EE58D8` | Container |
| Viol | `DC2224` | Tool |
| War Pick | `F3FA69` | Weapon |
| Warhammer | `43173B` | Weapon |
| Waterskin | `ABFB7C` | Container |
| Weaver's Tools | `0E8EB3` | Tool |
| Whip | `2501BF` | Weapon |
| Woodcarver's Tools | `CC9D34` | Tool |
