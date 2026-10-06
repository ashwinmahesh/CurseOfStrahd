# Rules coverage matrix (2024 PHB)

This matrix, not anyone's impression, decides whether a rule is done (plan §3). Statuses:
**tested** (engine + unit test) · **implemented** (engine, not yet under test) · **data** (content entered, its
system arrives later) · **partial** (the non-positional part is tested; the rest needs the combat grid) ·
**deviated** (see deviations.md) · **not started**. Phase in brackets = where the rest lands.

Tests live in `tests/unit/` and `tests/integration/`; names below are files.

## Playing the Game: D20 Tests and proficiency

| Rule | Code | Status | Test |
|---|---|---|---|
| Ability scores and modifiers | model/abilities.gd | tested | test_abilities |
| Proficiency Bonus by level and by CR | model/abilities.gd | tested | test_abilities |
| D20 Test: meet the DC/AC to succeed | resolution/d20_test.gd | tested | test_d20_test |
| Advantage / Disadvantage (don't stack, cancel) | d20_test.gd, creature.gd d20_sources | tested | test_d20_test, test_conditions |
| Natural 20 / 1 only matter on attack rolls | d20_test.gd | tested | test_d20_test |
| Skills and default abilities (18) | abilities.gd | tested | test_abilities |
| Expertise (double PB) | creature.gd skill_rank, character.gd | tested | test_reference_party |
| Saving throw proficiency | character.gd | tested | test_reference_party |
| Passive scores (+5/−5) | creature.gd passive_score | tested | test_abilities, test_reference_party |
| Initiative = Dexterity check, Alert adds PB | creature.gd initiative_bonus | tested | test_reference_party |
| Heroic Inspiration | character.gd (Resourceful) | implemented | [Phase 2: spending it] |
| Bonus/penalty dice on D20 Tests (Bless, Bane) | creature.gd roll_d20 | tested | test_effects |
| Automatic failure (Paralyzed etc.) | creature.gd roll_d20 | tested | test_conditions |

## Playing the Game: damage, healing, death

| Rule | Code | Status | Test |
|---|---|---|---|
| Hit Points, maximum, Bloodied | creature.gd | tested | test_damage |
| Damage order: bonuses, Resistance, Vulnerability; Immunity | creature.gd take_damage_parts | tested | test_damage |
| Resistance/Vulnerability don't stack | creature.gd | tested | test_damage |
| Several damage types in one instance | creature.gd take_damage_parts | tested | test_damage, test_attacks |
| Temporary Hit Points: absorb first, don't stack | creature.gd | tested (engine keeps the higher; see deviations) | test_damage |
| Healing can't exceed maximum | creature.gd heal | tested | test_damage |
| Monsters die at 0 HP | creature.gd | tested | test_damage |
| Massive Damage | creature.gd | tested | test_damage |
| Falling Unconscious at 0 HP | creature.gd | tested | test_damage |
| Death Saving Throws (10+, nat 1, nat 20, 3/3) | creature.gd roll_death_save | tested | test_death_saves |
| Damage at 0 HP = failure (crit = 2) | creature.gd | tested | test_damage |
| Stabilizing, Stable creatures | creature.gd stabilize | tested | test_death_saves |
| Knocking a creature out | — | not started | [Phase 2] |
| Critical Hits: roll damage dice twice | resolution/attack_resolver.gd | tested | test_attacks |

## Rules Glossary: conditions (data/conditions)

| Rule | Code | Status | Test |
|---|---|---|---|
| Blinded, Charmed, Deafened | data + creature.gd | partial (sight/hearing/charmer checks: Phase 2-3) | test_conditions |
| Exhaustion (−2 per level to D20 Tests, −5 ft, death at 6, Long Rest −1) | data + creature.gd | tested | test_conditions |
| Frightened | data | partial (line of sight: Phase 2) | test_conditions |
| Grappled (Speed 0) | data | partial (other-target Disadvantage, dragging: Phase 2) | test_conditions |
| Incapacitated (no actions, breaks Concentration) | data + creature.gd | tested | test_conditions |
| Invisible | data | partial (who can see whom: Phase 2) | test_conditions |
| Paralyzed, Petrified, Stunned, Unconscious | data + creature.gd | tested (auto-crit within 5 ft) | test_conditions, test_attacks |
| Poisoned, Restrained | data | tested | test_conditions |
| Prone (attackers within 5 ft Advantage, else Disadvantage) | data + attack_resolver.gd | tested | test_attacks |
| Condition immunity | creature.gd | tested | test_conditions, test_effects |

## Effects, durations and Concentration

| Rule | Code | Status | Test |
|---|---|---|---|
| Effects with source, modifiers, conditions, duration | model/effect.gd | tested | test_effects |
| Same effect doesn't stack (most potent, then most recent) | creature.gd all_modifiers | tested (potency is approximate; see deviations) | test_effects |
| Durations: rounds, start/end of turn, minutes, hours, rests | effect.gd | tested | test_effects |
| Concentration: one at a time, ends linked effects | model/concentration.gd | tested | test_effects |
| Concentration save after damage (DC 10 or half, max 30) | creature.gd | tested | test_damage, test_effects |
| Concentration ends when Incapacitated or dead | creature.gd | tested | test_conditions |

## Creating a Character and Level Advancement

| Rule | Code | Status | Test |
|---|---|---|---|
| Standard Array, Point Cost (27), Random 4d6 drop lowest | progression/ability_scores.gd | tested | test_character_builder |
| Background ability increases (+2/+1 or +1/+1/+1, max 20) | character.gd, choice_options.gd | tested | test_character_builder |
| Background skills, tool, origin feat, equipment A/B | character.gd | tested | test_data_integrity |
| Species traits, sizes, lineages, species spells at 3 and 5 | character.gd | tested | test_reference_party |
| Languages: Common + 2 standard | character.gd | tested | test_character_builder |
| Level 1 Hit Points; later levels fixed or rolled, minimum 1 | character.gd max_hp_breakdown | tested | test_reference_party, test_level_up |
| Constitution changes apply retroactively; Tough | character.gd | tested | test_reference_party, test_level_up |
| Class features by level, subclass at 3 | character.gd | tested | test_data_integrity |
| Ability Score Improvement or feat; feat prerequisites | choice_options.gd | tested | test_character_builder |
| Starting equipment and auto-equip | character.gd | tested | test_data_integrity |
| Multiclass prerequisites (new class and current classes) | level_up_controller.gd | tested | test_level_up, test_reference_party |
| Multiclass proficiencies, Hit Points, Proficiency Bonus | character.gd | tested | test_level_up |
| Multiclass spell slots; third casters alone round up | magic/spellcasting.gd | tested | test_spellcasting, test_level_up |
| Extra Attack doesn't stack across classes | modifiers (highest wins) | implemented | [Phase 2 attack action] |
| Unarmored Defense from two classes: pick one | character.gd armor_class (best formula) | implemented | — |
| Epic Boons, levels 19-20 | data | data | [Phase 5] |
| Respec at Madam Eva | — | not started | [Phase 4] |

## Classes (Phase 1: Fighter, Rogue, Cleric, Wizard and all 16 subclasses)

| Rule | Code | Status | Test |
|---|---|---|---|
| Class tables, features 1-20, resources by level | data/classes | tested to level 5 | test_reference_party, test_data_integrity |
| All 16 PHB subclasses, features 3-18 | data/subclasses | tested to level 5 | test_data_integrity |
| Fighter: Fighting Style, Second Wind uses, Weapon Mastery count, Action Surge, Extra Attack | data + engine | tested (numbers); actions: Phase 2 | test_reference_party |
| Champion: Improved/Superior Critical, Remarkable Athlete | data | tested | test_attacks, test_reference_party |
| Battle Master: Superiority Dice, maneuvers, Student of War | data | tested (choices, dice); maneuvers in combat: Phase 2 | test_level_up |
| Eldritch Knight / Arcane Trickster spellcasting tables | data + engine | tested | test_level_up |
| Rogue: Expertise, Sneak Attack dice, Thieves' Cant | data | tested (numbers); Sneak Attack trigger: Phase 2 | test_reference_party |
| Cleric: Divine Order, Channel Divinity uses, domain spells always prepared | data + engine | tested | test_reference_party |
| Life Domain: Disciple of Life | data + engine | tested | test_reference_party |
| Wizard: spellbook (6 + 2 per level), prepared from the book, Scholar, Evocation Savant | data + engine | tested | test_reference_party, test_spellcasting |
| Other 8 classes | — | not started | [Phase 4] |

## Feats, equipment, spells

| Rule | Code | Status | Test |
|---|---|---|---|
| Feats: 10 origin, 43 general, 10 fighting style, 12 epic boons | data/feats | data (numeric parts tested: Tough, Alert, Defense, Archery, Dueling, GWF) | test_attacks, test_reference_party |
| Weapon properties, Finesse, Versatile, Thrown, Range | resolution/weapon_profile.gd | tested | test_attacks |
| Weapon Mastery properties | data | data (who can use them is tested) | [Phase 2 effects] |
| Armor: light/medium/heavy AC, Strength requirement, Stealth Disadvantage | character.gd | tested | test_reference_party, test_attacks |
| Armor and Shield without training | character.gd gear_d20_sources, armor_class | implemented | — |
| Unarmed Strike (1 + Str) | weapon_profile.gd | implemented | — |
| Carrying capacity by size and Powerful Build | creature.gd carrying_capacity | implemented | — |
| Spell slots (full, half, third, multiclass) | magic/spellcasting.gd | tested | test_spellcasting |
| Spell save DC and spell attack | character.gd | tested | test_reference_party |
| Cantrip scaling at 5/11/17; upcasting | magic/spellcasting.gd | tested | test_spellcasting |
| Prepared spells, always-prepared spells, spellbook | character.gd | tested | test_reference_party |
| Ritual casting | data (ritual flags) | data | [Phase 3] |
| Components and focuses | data | data | [Phase 2] |
| Areas of effect | data | data | [Phase 2 grid] |
| 173 spells of levels 0-3 for the Phase 1 classes | data/spells | data | — |

## Not started (later phases)

Actions in combat, Opportunity Attacks, Reactions, cover, movement and terrain, surprise (Phase 2); exploration,
social interaction and Influence, travel, light and vision, hiding (Phase 3); the other eight classes, magic items
and attunement (Phases 4-5).
