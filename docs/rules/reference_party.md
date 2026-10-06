# Reference party: hand-worked character sheets, levels 1 to 5

Phase 1's exit test (plan §10) builds these four characters through `CharacterBuilder` and levels them with
`LevelUpController`, then compares every number below. The numbers here were worked out by hand from the 2024
PHB rules, not read back from the engine. The builds are the pregenerated party in `data/pregens/`, so the
same four characters are what a player gets from "Pregenerated party" on the Start screen.

Fixture with the same numbers: `tests/fixtures/reference_party.json`. Test: `tests/integration/test_reference_party.gd`.

## Rules used (2024 PHB)

| Rule | Where | Formula |
|---|---|---|
| Ability modifier | Ability Scores and Modifiers | floor((score − 10) / 2) |
| Background increases | Step 3, "Adjust Ability Scores" | +2 and +1, or +1/+1/+1, to the background's three abilities, max 20 |
| Proficiency Bonus | Character Advancement table | +2 at levels 1-4, +3 at 5-8 |
| Level 1 Hit Points | Level 1 Hit Points by Class | Hit Die maximum + Con modifier |
| Later Hit Points | Fixed Hit Points by Class | fixed value (die/2 + 1) or the roll, + Con modifier, minimum 1 |
| Con changes | Gaining a Level | a Con modifier change applies to every level retroactively |
| Armor Class | Equipment, Armor table | light: base + Dex; medium: base + Dex (max 2); heavy: base; Shield +2 |
| Saving throw / skill | D20 Tests, Proficiency | ability modifier + PB if proficient; Expertise doubles PB |
| Passive Perception | Rules Glossary | 10 + Wisdom (Perception) bonus |
| Initiative | Combat | Dexterity modifier (+PB with Alert) |
| Weapon attack | Equipment | ability modifier + PB; Finesse uses Str or Dex; damage adds the same modifier |
| Spell save DC / attack | Spells | 8 + ability modifier + PB / ability modifier + PB |
| Spell slots | Class tables | Cleric and Wizard: 2 / 3 / 4-2 / 4-3 / 4-3-2 at levels 1-5 |
| Cantrip damage | Spell descriptions | extra die at character level 5 |

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

## Also checked

- Multiclassing (2024): Hedda at level 5 may add Fighter (Strength 14 meets "Strength or Dexterity 13", and her
  Wisdom 18 meets the Cleric's 13) but not Wizard ("Intelligence 13, you have 10").
- Spell slots for a Fighter (Eldritch Knight) 3 / Wizard 2: caster level ⌊3/3⌋ + 2 = 3 → 4 and 2 slots. A
  single-class Eldritch Knight 4 uses its own table: 3 level 1 slots.
