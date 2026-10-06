# Reference party: hand-worked character sheets, levels 1 to 11

Phase 1's exit test (plan §10) builds these four characters through `CharacterBuilder` and levels them with
`LevelUpController`, then compares every number below. The numbers here were worked out by hand from the 2024
PHB rules, not read back from the engine. The builds are the pregenerated party in `data/pregens/`, so the
same four characters are what a player gets from "Pregenerated party" on the Start screen.

Fixture with the same numbers: `tests/fixtures/reference_party.json`. Test: `tests/integration/test_reference_party.gd`.
Levels 6 to 11 (the Phase 5 level cap, ADR 0011) were added in P5-01, with one more character of every class at
levels 8 to 11 (`tests/unit/test_levels_8_to_11.gd`, last section).

## Rules used (2024 PHB)

| Rule | Where | Formula |
|---|---|---|
| Ability modifier | Ability Scores and Modifiers | floor((score − 10) / 2) |
| Background increases | Step 3, "Adjust Ability Scores" | +2 and +1, or +1/+1/+1, to the background's three abilities, max 20 |
| Proficiency Bonus | Character Advancement table | +2 at levels 1-4, +3 at 5-8, +4 at 9-12 |
| Level 1 Hit Points | Level 1 Hit Points by Class | Hit Die maximum + Con modifier |
| Later Hit Points | Fixed Hit Points by Class | fixed value (die/2 + 1) or the roll, + Con modifier, minimum 1 |
| Con changes | Gaining a Level | a Con modifier change applies to every level retroactively |
| Armor Class | Equipment, Armor table | light: base + Dex; medium: base + Dex (max 2); heavy: base; Shield +2 |
| Saving throw / skill | D20 Tests, Proficiency | ability modifier + PB if proficient; Expertise doubles PB |
| Passive Perception | Rules Glossary | 10 + Wisdom (Perception) bonus |
| Initiative | Combat | Dexterity modifier (+PB with Alert) |
| Weapon attack | Equipment | ability modifier + PB; Finesse uses Str or Dex; damage adds the same modifier |
| Spell save DC / attack | Spells | 8 + ability modifier + PB / ability modifier + PB |
| Spell slots | Class tables | Cleric and Wizard: 2 / 3 / 4-2 / 4-3 / 4-3-2 at levels 1-5; 4-3-3 / 4-3-3-1 / 4-3-3-2 / 4-3-3-3-1 / 4-3-3-3-2 / 4-3-3-3-2-1 at 6-11 |
| Cantrip damage | Spell descriptions | extra die at character levels 5 and 11 |

## Ilse Varga: Human Fighter (Champion), Soldier

Standard Array 15/14/13/8/10/12 (Str/Dex/Con/Int/Wis/Cha). Soldier +2 Str, +1 Con. Human: Skillful (Perception),
Versatile (Tough). Soldier: Athletics, Intimidation, Savage Attacker. Fighter skills: Insight, Survival. Fighting
Style: Defense. Masteries: Greatsword, Flail, Javelin (+Spear at 4). Gear: Chain Mail, Greatsword.

| | L1 | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| Str / Dex / Con | 17 / 14 / 14 | same | same | 19 (ASI +2) / 14 / 14 | same |
| PB | 2 | 2 | 2 | 2 | 3 |
| Hit Points | 10 + 2 = 12, Tough +2 = **14** | 12 + (6+2) = 20, Tough +4 = **24** | 28 + 6 = **34** | 36 + 8 = **44** | 44 + 10 = **54** |
| AC | Chain Mail 16 + Defense 1 = **17** | 17 | 17 | 17 | 17 |
| Initiative | Dex **+2** | +2 | +2 (Advantage, Remarkable Athlete) | +2 | +2 |
| Str save | 3 + 2 = **+5** | +5 | +5 | 4 + 2 = **+6** | 4 + 3 = **+7** |
| Con save | 2 + 2 = **+4** | +4 | +4 | +4 | **+5** |
| Athletics | **+5** | +5 | +5 (Advantage) | **+6** | **+7** |
| Passive Perception | 10 + 0 + 2 = **12** | 12 | 12 | 12 | **13** |
| Greatsword | +3 +2 = **+5**, 2d6+3 | same | same | **+6**, 2d6+4 | **+7**, 2d6+4 |
| Critical Hit range | 20 | 20 | **19** (Improved Critical) | 19 | 19 |
| Second Wind / Action Surge | 2 / 0 | 2 / 1 | 2 / 1 | **3** / 1 | 3 / 1 |
| Weapon masteries | 3 | 3 | 3 | **4** | 4 |
| Attacks per Attack action | 1 | 1 | 1 | 1 | **2** |

Stealth is +2 with Disadvantage (Chain Mail).

## Tamsin Tealeaf: Halfling Rogue (Thief), Criminal

Standard Array 12/15/13/14/10/8. Criminal +2 Dex, +1 Con; Alert. Rogue skills: Acrobatics, Deception, Investigation,
Perception (+ Sleight of Hand, Stealth from Criminal). Expertise: Stealth, Sleight of Hand. Gear: Leather Armor,
Shortsword, Shortbow. Level 3 Hit Points are a **rolled 6** (to test the rolled path).

| | L1 | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| Dex / Con / Int | 17 / 14 / 14 | same | same | 19 / 14 / 14 | same |
| Hit Points | 8 + 2 = **10** | 10 + 7 = **17** | 17 + (6+2) = **25** | 25 + 7 = **32** | 32 + 7 = **39** |
| AC | Leather 11 + 3 = **14** | 14 | 14 | 11 + 4 = **15** | 15 |
| Initiative | 3 + Alert 2 = **+5** | +5 | +5 | 4 + 2 = **+6** | 4 + 3 = **+7** |
| Dex save | **+5** | +5 | +5 | **+6** | **+7** |
| Int save | 2 + 2 = **+4** | +4 | +4 | +4 | **+5** |
| Stealth (Expertise) | 3 + 4 = **+7** | +7 | +7 | 4 + 4 = **+8** | 4 + 6 = **+10** |
| Acrobatics | **+5** | +5 | +5 | **+6** | **+7** |
| Passive Perception | **12** | 12 | 12 | 12 | **13** |
| Shortsword (Finesse, Dex) | **+5**, 1d6+3 | same | same | **+6**, 1d6+4 | **+7**, 1d6+4 |
| Sneak Attack | 1d6 | 1d6 | 2d6 | 2d6 | **3d6** |

## Hedda Ironvow: Dwarf Cleric (Life Domain), Acolyte

Standard Array 14/8/13/10/15/12. Acolyte +2 Wis, +1 Cha; Magic Initiate (Cleric): Light, Toll the Dead, Sanctuary
(Wisdom). Dwarf: Darkvision 120, Poison Resistance, Dwarven Toughness (+1 HP per level). Divine Order: Protector.
Cleric skills: Medicine, Persuasion (+ Insight, Religion). Gear: Chain Shirt, Shield, Mace. Level 4: ASI +1 Wis,
+1 Con, which raises the Con modifier to +2 and so adds 1 Hit Point to every earlier level.

| | L1 | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| Con / Wis / Cha | 13 / 17 / 13 | same | same | 14 / 18 / 13 | same |
| Hit Points | 8 + 1 = 9, DT +1 = **10** | 9 + 6 = 15, DT +2 = **17** | 21 + 3 = **24** | 8 + 2 + 3×(5+2) = 31, DT +4 = **35** | 31 + 7 = 38, DT +5 = **43** |
| AC | Chain Shirt 13 + Dex −1 + Shield 2 = **14** | 14 | 14 | 14 | 14 |
| Initiative | **−1** | −1 | −1 | −1 | −1 |
| Wis save | 3 + 2 = **+5** | +5 | +5 | **+6** | **+7** |
| Cha save | 1 + 2 = **+3** | +3 | +3 | +3 | **+4** |
| Medicine | **+5** | +5 | +5 | **+6** | **+7** |
| Passive Perception | 10 + 3 = **13** | 13 | 13 | **14** | 14 |
| Spell save DC | 8 + 3 + 2 = **13** | 13 | 13 | **14** | **15** |
| Spell attack | **+5** | +5 | +5 | **+6** | **+7** |
| Spell slots | 2 | 3 | 4, 2 | 4, 3 | 4, 3, 2 |
| Cantrips / prepared (class) | 3 / 4 | 3 / 5 | 3 / 6 | 4 / 7 | 4 / 9 |
| Channel Divinity | 0 | 2 | 2 | 2 | 2 |
| Sacred Flame | 1d8 | 1d8 | 1d8 | 1d8 | **2d8** |
| Mace | +2 +2 = **+4**, 1d6+2 | same | same | same | **+5**, 1d6+2 |

Healing (Life Domain from level 3, Disciple of Life adds 2 + slot level to slot-powered healing):
- Level 3, Cure Wounds, level 1 slot: 2d8 + Wis 3 + (2+1) = **2d8+6**; level 2 slot: 4d8 + 3 + 4 = **4d8+7**.
- Level 1 (no domain yet), Healing Word: 2d4 + 3 = **2d4+3**. Level 5, Cure Wounds, level 3 slot: 6d8 + 4 + 5 = **6d8+9**.

## Silvain Aster: High Elf Wizard (Evoker), Sage

Standard Array 8/12/13/15/14/10. Sage +2 Int, +1 Con; Magic Initiate (Wizard): Minor Illusion, Shocking Grasp,
Find Familiar (Intelligence). High Elf: Prestidigitation, Detect Magic at 3, Misty Step at 5. Keen Senses:
Perception. Wizard skills: Investigation, Insight (+ Arcana, History). Scholar (level 2): Expertise in Arcana.

| | L1 | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| Int / Con / Dex | 17 / 14 / 12 | same | same | 19 / 14 / 12 | same |
| Hit Points | 6 + 2 = **8** | 8 + 6 = **14** | **20** | **26** | **32** |
| AC | 10 + Dex 1 = **11** (Mage Armor **14**) | 11 | 11 | 11 | 11 |
| Int save | 3 + 2 = **+5** | +5 | +5 | **+6** | **+7** |
| Wis save | 2 + 2 = **+4** | +4 | +4 | +4 | **+5** |
| Arcana | **+5** | 3 + 4 = **+7** (Expertise) | +7 | **+8** | 4 + 6 = **+10** |
| Passive Perception | 10 + 2 + 2 = **14** | 14 | 14 | 14 | **15** |
| Spell save DC | **13** | 13 | 13 | **14** | **15** |
| Spell attack | **+5** | +5 | +5 | **+6** | **+7** |
| Spell slots | 2 | 3 | 4, 2 | 4, 3 | 4, 3, 2 |
| Cantrips / prepared / book picks | 3 / 4 / 6 | 3 / 5 / 8 | 3 / 6 / 10 | 4 / 7 / 12 | 4 / 9 / 14 |
| Spellbook total (with Evocation Savant) | 6 | 8 | 12 | 14 | 17 |
| Fire Bolt | 1d10 | 1d10 | 1d10 | 1d10 | **2d10** |
| Fireball (level 3 slot) | | | | | **8d6**, DC 15 |

## Levels 6 to 11

Level plans (`data/pregens/`): Ilse takes an ASI at 6 (Str +1, Con +1: Str 20, Con 15) and 8 (Con +1, Wis +1: Con 16),
Great Weapon Fighting at 7 (Champion) and a fifth mastery (Longsword) at 10. Tamsin takes Expertise in Acrobatics and
Perception at 6 and ASIs at 8 (Dex +1, Con +1: Dex 20, Con 15) and 10 (Con +1, Wis +1: Con 16). Hedda takes Potent
Spellcasting at 7, an ASI at 8 (Wis +2: 20) and a fifth cantrip at 10. Silvain takes an ASI at 8 (Int +1, Con +1:
Int 20, Con 15), Evocation Savant picks Ice Storm (7), Fire Shield (9) and Vitriolic Sphere (11), and a fifth cantrip at
10. Every level's Hit Points are the fixed value.

**Ilse Varga** (Tough +2 per level; Con +3 from level 8, for every level)

| | L6 | L7 | L8 | L9 | L10 | L11 |
|---|---|---|---|---|---|---|
| PB | 3 | 3 | 3 | 4 | 4 | 4 |
| Hit Points | 54 + 10 = **64** | **74** | 10 + 7×6 + 3×8 + 2×8 = **92** | **103** | **114** | 10 + 60 + 33 + 22 = **125** |
| Str save / Con save | **+8** / +5 | +8 / +5 | +8 / **+6** | **+9** / **+7** | +9 / +7 | +9 / +7 |
| Athletics / Perception | **+8** / +3 | +8 / +3 | +8 / +3 | **+9** / **+4** | +9 / +4 | +9 / +4 |
| Greatsword | 5 + 3 = **+8**, 2d6+5 | same | same | **+9**, 2d6+5 | same | same |
| Attacks per Attack action | 2 | 2 | 2 | 2 | 2 | **3** (Two Extra Attacks) |
| Second Wind / Indomitable / masteries | 3 / 0 / 4 | 3 / 0 / 4 | 3 / 0 / 4 | 3 / **1** / 4 | **4** / 1 / **5** | 4 / 1 / 5 |

AC stays 17, Initiative +2 (Advantage), Critical Hit on 19.

**Tamsin Tealeaf** (Alert; Expertise in Stealth, Sleight of Hand, Acrobatics, Perception)

| | L6 | L7 | L8 | L9 | L10 | L11 |
|---|---|---|---|---|---|---|
| Hit Points | 39 + 7 = **46** | **53** | **60** | **67** | 8 + 6 (rolled) + 8×5 + 3×10 = **84** | 59 + 33 = **92** |
| AC / Initiative | 15 / +7 | 15 / +7 | **16** / **+8** | 16 / **+9** | 16 / +9 | 16 / +9 |
| Dex save / Int save | +7 / +5 | +7 / +5 | **+8** / +5 | **+9** / **+6** | +9 / +6 | +9 / +6 |
| Stealth, Acrobatics (Expertise) | 4 + 6 = **+10** | +10 | **+11** | 5 + 8 = **+13** | +13 | +13 |
| Perception (Expertise) / passive | **+6** / **16** | +6 / 16 | +6 / 16 | **+8** / **18** | +8 / 18 | +8 / 18 |
| Shortsword | +7, 1d6+4 | same | **+8, 1d6+5** | **+9**, 1d6+5 | same | same |
| Sneak Attack | 3d6 | **4d6** | 4d6 | **5d6** | 5d6 | **6d6** |

**Hedda Ironvow** (Dwarven Toughness +1 per level; Con 14)

| | L6 | L7 | L8 | L9 | L10 | L11 |
|---|---|---|---|---|---|---|
| Hit Points | 8 + 25 + 12 + 6 = **51** | **59** | **67** | **75** | **83** | 8 + 50 + 22 + 11 = **91** |
| Wis save / Medicine | +7 | +7 | **+8** | **+9** | +9 | +9 |
| Spell save DC / attack | 15 / +7 | 15 / +7 | **16 / +8** | **17 / +9** | 17 / +9 | 17 / +9 |
| Spell slots | 4, 3, 3 | 4, 3, 3, 1 | 4, 3, 3, 2 | 4, 3, 3, 3, 1 | 4, 3, 3, 3, 2 | 4, 3, 3, 3, 2, 1 |
| Cantrips / prepared | 4 / 10 | 4 / 11 | 4 / 12 | 4 / 14 | **5** / 15 | 5 / 16 |
| Channel Divinity / Divine Intervention | **3** / 0 | 3 / 0 | 3 / 0 | 3 / 0 | 3 / **1** | 3 / 1 |
| Sacred Flame | 2d8 | 2d8 | 2d8 | 2d8 | 2d8 | **3d8** |
| Mace | +5, 1d6+2 | same | same | **+6**, 1d6+2 | same | same |

Cure Wounds: level 5 slot at 9 = 2d8 + 4×2d8 = **10d8**, + Wis 5 + (2 + 5) = **+12**; level 6 slot at 11 = **12d8+13**.
Life Domain spells at 9: Greater Restoration and Mass Cure Wounds join Aura of Life and Death Ward (7).

**Silvain Aster** (Con 14-15, +2; Arcana Expertise from Scholar)

| | L6 | L7 | L8 | L9 | L10 | L11 |
|---|---|---|---|---|---|---|
| Hit Points (+6 a level) | **38** | **44** | **50** | **56** | **62** | **68** |
| Int save / Arcana | +7 / +10 | +7 / +10 | **+8 / +11** | **+9 / +13** | +9 / +13 | +9 / +13 |
| Spell save DC / attack | 15 / +7 | 15 / +7 | **16 / +8** | **17 / +9** | 17 / +9 | 17 / +9 |
| Spell slots | as Hedda's | | | | | |
| Cantrips / prepared / book picks | 4 / 10 / 16 | 4 / 11 / 18 | 4 / 12 / 20 | 4 / 14 / 22 | **5** / 15 / 24 | 5 / 16 / 26 |
| Spellbook total (picks + Evocation Savant) | 19 | 22 | 24 | 27 | 29 | 32 |
| Fire Bolt / Fireball | 2d10 / 8d6 | 2d10 / 8d6 | same | same | same | **3d10** / **11d6** (level 6 slot) |

## Levels 8 to 11: one character of every class

`tests/unit/test_levels_8_to_11.gd` creates a human with Alert in each class (Standard Array, the background's
increases, Ability Score Improvements set by hand, fixed Hit Points) and checks it at levels 8, 9, 10 and 11. Level 11:

| Class (subclass) | Scores | Hit Points | Highlights |
|---|---|---|---|
| Barbarian (Berserker) | Str 19, Dex 13, Con 17 | 12 + 10×7 + 3×11 = **115** | AC 14, Rage 4 at +3 (from 9), Greataxe +8 1d12+4, 2 attacks |
| Bard (Lore) | Cha 20, Dex 16, Con 12 | 8 + 10×5 + 11 = **69** | slots 4-3-3-3-2-1, 16 prepared (one from Magical Secrets), DC 17, Vicious Mockery 3d6, Bardic die d10 |
| Cleric (Life) | Wis 20, Con 14 | 8 + 50 + 22 = **80** | DC 17, Sacred Flame 3d8+5 (Potent Spellcasting), Cure Wounds (6th) 12d8+13, Divine Intervention |
| Druid (Land, arid) | Wis 20, Con 16 | 8 + 50 + 33 = **91** | Nature's Ward (Fire, then Cold for polar), Wall of Stone at 9, Thorn Whip 3d6+5 |
| Fighter (Eldritch Knight) | Str 20, Con 16, Int 15 | 10 + 60 + 33 = **103** | 3 attacks, slots 4-3, DC 14, Greatsword +9 2d6+5, AC 17 |
| Monk (Open Hand) | Dex 20, Wis 16, Con 13 | 8 + 50 + 11 = **69** | AC 18, Speed 50, Focus 11, Unarmed +9 1d10+5 |
| Paladin (Devotion) | Str 18, Cha 18, Con 13 | 10 + 60 + 11 = **81** | slots 4-3-3, Lay On Hands 55, Channel Divinity 3, Aura of Courage, Cha save +12 |
| Ranger (Hunter) | Dex 20, Wis 16, Con 13 | 10 + 60 + 11 = **81** | slots 4-3-3, Longbow +11 1d8+5, Tireless 3, Favored Enemy 4 |
| Rogue (Soulknife) | Dex 20, Con 16 | 8 + 50 + 33 = **91** | Sneak Attack 6d6, 8 Psionic dice (d10), AC 16, Shortsword +9 1d6+5 |
| Sorcerer (Draconic) | Cha 20, Dex 14, Con 14 | 6 + 40 + 22 + 11 = **79** | AC 17, slots 4-3-3-3-2-1, 11 Sorcery Points, 4 Metamagic, Fire Bolt 3d10+5 |
| Warlock (Fiend) | Cha 20, Con 14 | 8 + 50 + 22 = **80** | 3 Pact slots of level 5, 7 invocations, Mystic Arcanum, Fiendish Resilience, Chill Touch 3d10+5 |
| Wizard (Evoker) | Int 20, Con 16 | 6 + 40 + 33 = **79** | slots 4-3-3-3-2-1, 26 book picks (32 spells), Fireball 11d6 (+5 from 10), DC 17 |
| Sorcerer 6 / Warlock 5 | Cha 19, Con 16 | 6 + 20 + 25 + 33 + 6 = **90** | Sorcerer slots 4-3-3 plus 2 Pact slots of level 3, Fire Bolt 3d10 by character level |

## Also checked

- Multiclassing (2024): Hedda at level 5 may add Fighter (Strength 14 meets "Strength or Dexterity 13", and her
  Wisdom 18 meets the Cleric's 13) but not Wizard ("Intelligence 13, you have 10").
- Spell slots for a Fighter (Eldritch Knight) 3 / Wizard 2: caster level ⌊3/3⌋ + 2 = 3 → 4 and 2 slots. A
  single-class Eldritch Knight 4 uses its own table: 3 level 1 slots.
