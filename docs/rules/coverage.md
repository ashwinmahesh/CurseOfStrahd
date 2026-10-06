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
| Heroic Inspiration | character.gd (Resourceful); encounter.gd reroll | partial: reroll offered on a missed attack roll; saves and checks [Phase 3] | test_combat_encounter |
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
| Knocking a creature out | — | not started | [Phase 3] |
| Critical Hits: roll damage dice twice | resolution/attack_resolver.gd | tested | test_attacks |

## Rules Glossary: conditions (data/conditions)

| Rule | Code | Status | Test |
|---|---|---|---|
| Blinded, Charmed, Deafened | data + creature.gd | partial (sight/hearing/charmer checks: Phase 2-3) | test_conditions |
| Exhaustion (−2 per level to D20 Tests, −5 ft, death at 6, Long Rest −1) | data + creature.gd | tested | test_conditions |
| Frightened | data; Turn Undead fleeing in ai_brain.gd | partial (Disadvantage always on, see deviations; can't-approach only for AI) | test_conditions, test_combat_spells |
| Grappled (Speed 0) | data + encounter.gd | tested (Speed 0, escape, other-target Disadvantage); dragging: deviations | test_conditions, test_combat_encounter |
| Incapacitated (no actions, breaks Concentration) | data + creature.gd | tested | test_conditions |
| Invisible | data + encounter.gd can_see | tested (hidden creatures, attacks either way) | test_conditions, test_combat_encounter |
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
| Extra Attack doesn't stack across classes | encounter.gd attacks_per_action (highest wins) | implemented | — |
| Unarmored Defense from two classes: pick one | character.gd armor_class (best formula) | implemented | — |
| Epic Boons, levels 19-20 | data | data | [Phase 5] |
| Respec at Madam Eva | — | not started | [Phase 4] |

## Classes (Phase 1: Fighter, Rogue, Cleric, Wizard; Phase 4: the other eight; all 48 PHB subclasses)

| Rule | Code | Status | Test |
|---|---|---|---|
| Class tables, features 1-20, resources by level | data/classes | tested to level 11, the Phase 5 cap (the Phase 1 classes level by level against the hand-worked sheets; one character of every class at 8, 9, 10 and 11) | test_reference_party, test_data_integrity, test_classes, test_levels_8_to_11 |
| All 48 PHB subclasses, features 3-20 | data/subclasses | tested to level 11 (every subclass built and levelled with nothing left to choose; every feature to 11 has rules text) | test_data_integrity, test_levels_8_to_11 |
| Fighter: Fighting Style, Second Wind uses, Weapon Mastery count, Action Surge, Extra Attack | data + engine + combat/features.gd | tested | test_reference_party, test_combat_encounter |
| Champion: Improved/Superior Critical, Remarkable Athlete | data | tested | test_attacks, test_reference_party |
| Battle Master: Superiority Dice, maneuvers, Student of War | data + features.gd, feature_actions.gd, reactions.gd | tested: every combat maneuver (hit riders, Bonus Action maneuvers, Parry, Riposte, Precision Attack, Commander's Strike, Ambush); Commanding Presence and Tactical Assessment are checks (Phase 3) | test_feature_combat, test_level_up |
| Subclass features in combat (all 16 subclasses, levels 3-18) | features.gd, feature_actions.gd, reactions.gd, spell_caster.gd | implemented; tested for Battle Master, Light, War, Diviner, Abjurer, Soulknife (list in the spell and ability audit log). Out of combat: War Bond, Blessing of the Trickster's duration, Psi-Bolstered Knack, Psychic Whispers, Spell Thief, Versatile Trickster, Improved War Magic, Relentless | test_feature_combat |
| Class features in combat: Tactical Shift, Indomitable, Studied Attacks, Cunning Strike and Devious Strikes, Evasion, Reliable Talent, Elusive, Stroke of Luck, Divine Strike, Divine Intervention | features.gd, feature_actions.gd | implemented; Tactical Shift, Cunning Strike tested | test_feature_combat |
| Eldritch Knight / Arcane Trickster spellcasting tables | data + engine | tested | test_level_up |
| Rogue: Expertise, Sneak Attack, Cunning Action, Steady Aim, Thieves' Cant | data + combat/features.gd | tested | test_reference_party, test_combat_encounter |
| Cleric: Divine Order, Channel Divinity uses, domain spells always prepared | data + engine | tested | test_reference_party |
| Life Domain: Disciple of Life | data + engine | tested | test_reference_party |
| Wizard: spellbook (6 + 2 per level), prepared from the book, Scholar, Evocation Savant | data + engine | tested | test_reference_party, test_spellcasting |
| Barbarian, Bard, Druid, Monk, Paladin, Ranger, Sorcerer, Warlock: tables, resources, choices to level 7 (P4-01) | data/classes, data/subclasses, character.gd | tested: Hit Points, slots, resources and choices worked by hand at level 7 | test_classes |
| Every class at levels 8 to 11 (P5-01): Ability Score Improvement at 8 (and Rogue 10), Proficiency Bonus 4 from 9, 5th-level slots at 9 and 6th at 11 (full casters), 3rd at 9 (half casters), third casters' tables, Pact Magic at level 5 from 9 and a third slot at 11, Extra Attack and Fighter's Two Extra Attacks, cantrips' third die at 11, Rage count and Rage Damage +3, Sneak Attack, Martial Arts d10 and Focus, Unarmored Movement +20, Bardic die d10, Wild Shape forms (CR 1, Fly), Channel Divinity, Lay On Hands, Favored Enemy, Sorcery Points, Metamagic and invocation counts, Expertise at 9 (Bard, Ranger), Battle Master and Psionic dice | data + character.gd, spellcasting.gd | tested: one character of each class worked by hand at 8, 9, 10 and 11, a Sorcerer 6 / Warlock 5 | test_levels_8_to_11, test_reference_party |
| Magical Secrets (Bard 10): prepared spells from the Bard, Cleric, Druid and Wizard lists, counting as Bard spells | character.gd `spell_list` modifiers | tested (see deviations) | test_levels_8_to_11 |
| Mystic Arcanum (Warlock 11, 13, 15, 17): a level 6-9 Warlock spell cast once per Long Rest without a slot, never prepared | character.gd (`granted` spell choices), spell_caster.gd free casts | tested (see deviations) | test_levels_8_to_11 |
| Contact Patron (Warlock 9), Fey Reinforcements' free Summon Fey (Ranger 11) | data (spell grants and their uses) | implemented (Contact Other Plane's automatic success is narrative). In a fight a spell both prepared and granted is offered as the prepared one, so Summon Fey's free casting waits for the audit | test_levels_8_to_11 |
| Nature's Ward (Land 10: Poisoned immunity, Resistance by land), Aura of Courage (the paladin's own Frightened immunity), Fiendish Resilience (a Resistance chosen after rests), Beguiling Defenses' Charmed immunity, Thought Shield's Psychic Resistance, Guarded Mind's Psychic Resistance | data (modifiers, `at_class_level`) | tested | test_levels_8_to_11 |
| Tireless (Ranger 10): uses, a Short Rest removes a level of Exhaustion; Celestial Resilience (Warlock 10): Temporary Hit Points after a rest | character.gd finish_short_rest, _rest_temp_hp; combat/class_features.gd (the Magic action) | tested; Celestial Resilience's share for five others and the Magical Cunning trigger are the rest screen's [Phase 5] | test_levels_8_to_11 |
| Unarmored Defense (Barbarian, Monk, Dance, Draconic), Fast Movement, Unarmored Movement, Roving, Danger Sense, Feral Instinct, Aura of Protection (own saves) | data + creature.gd (speed and Advantage `when`) | tested | test_classes |
| Jack of All Trades | creature.gd skill_bonus | tested | test_classes |
| Martial Arts die and Dexterity for Unarmed Strikes and Monk weapons | weapon_profile.gd, character.gd martial_arts_die | tested (the Bonus Action strike: combat side of the new classes) | test_classes |
| Pact Magic: slots by Warlock level, one slot level, Short Rest recovery, kept apart from multiclass Spellcasting slots, prepared spells up to the slot level | character.gd pact_magic, choice_options.gd | tested | test_classes |
| Eldritch Invocations with prerequisites (level, another invocation, a damaging cantrip), Pact of the Tome spells, Agonizing Blast | choice_options.gd invocation_problem, character.gd | tested | test_classes |
| Metamagic options, Expertise (Bard, Ranger), Fighting Style or Blessed/Druidic Warrior, Primal Order, Elemental Fury, Magical Discoveries, Weapon Mastery counts | data + character.gd | tested | test_classes, test_data_integrity |
| Wild Shape known forms (CR and Fly Speed by Druid level, Circle Forms) | character.gd beast_forms_for | tested (count capped by the bestiary, deviations) | test_classes |
| Free casts from class features (Favored Enemy column, Paladin's Smite, Faithful Steed, Star Map, Steps of the Fey) | character.gd granted spells | tested | test_classes |
| Multiclassing into every class: prerequisites, proficiencies (skills, instruments), Hit Points | level_up_controller.gd, character.gd | tested | test_classes, test_reference_party |
| The eight new classes in combat to level 7: Rage (Resistance, Rage Damage, Advantage, no spells or Concentration, lasting while you attack or force saves), Reckless Attack, Instinctive Pounce; Martial Arts strike, Flurry of Blows, Patient Defense, Step of the Wind, Uncanny Metabolism, Deflect Attacks, Stunning Strike, Empowered Strikes; Lay On Hands, Channel Divinity, Aura of Protection; Bardic Inspiration, Font of Inspiration, Countercharm; Wild Shape (keeping the druid's mind and Hit Points), Wild Companion, Wild Resurgence, Primal Strike; Innate Sorcery, Font of Magic, Metamagic, Sorcery Incarnate; Tireless, Roving; invocations (at-will spells, Pact of the Blade, Thirsting Blade, Eldritch Smite, Lifedrinker, Repelling Blast, Eldritch Spear, Devil's Sight, Fiendish Vigor) | combat/class_features.gd, shape_change.gd, features.gd, reactions.gd | tested: Rage, Reckless Attack, Flurry of Blows, Stunning Strike, Patient Defense, Step of the Wind, Deflect Attacks, Lay On Hands, Aura of Protection, Bardic Inspiration, Wild Shape, Innate Sorcery, Font of Magic, invocations | test_class_combat |
| Their 32 subclasses to level 7: Berserker (Frenzy, Mindless Rage), Wild Heart (Bear, Eagle, Wolf; Aspect of the Wilds), World Tree (Vitality of the Tree, Branches of the Tree), Zealot (Divine Fury, Warrior of the Gods, Fanatical Focus); Lore (Cutting Words), Valor (Combat Inspiration, Extra Attack), Glamour (Mantle of Inspiration, Beguiling Magic, Mantle of Majesty), Dance (Agile Strikes, Inspiring Movement, Tandem Footwork); Land (Land's Aid), Moon (Circle Forms, Improved Circle Forms), Sea (Wrath of the Sea), Stars (Starry Form, Cosmic Omen); Open Hand, Shadow, Elements, Mercy; Devotion, Glory, Ancients, Vengeance (Channel Divinity options and level 7 auras, Inspiring Smite, Smite of Protection, Relentless Avenger); Hunter, Beast Master (Primal Companion), Gloom Stalker, Fey Wanderer; Draconic, Wild Magic (condensed surge table), Aberrant, Clockwork (Restore Balance, Bastion of Law); Fiend, Archfey (Steps of the Fey, Misty Escape), Celestial (Healing Light, Radiant Soul), Great Old One | combat/class_features.gd | implemented, with Psionic Sorcery, Psychic Spells, Awakened Mind and Clairvoyant Combatant, Pact of the Chain's familiars (Familiar Strike, Investment of the Chain Master), Gift of the Protectors and Gaze of Two Minds; tested: Colossus Slayer, Cutting Words, Psionic Sorcery, Psychic Spells, Pact of the Chain. Natural Recovery is rest-time | test_class_combat |
| The new classes' level 8-11 features in combat: Brutal Strike, Relentless Rage; Abjure Foes; Acrobatic Movement (no walls or liquids to run on yet); Celestial Resilience's share for others; Retaliation, Battering Roots, Zealous Presence, Moonlight Step, Stormborn, Flurry of Healing and Harm, Improved Shadow Step, Stride of the Elements, Fleet Step, Bestial Fury, Fey Reinforcements without Concentration, Superior Hunter's Prey, Stalker's Flurry's Sudden Strike and Mass Fear, Roving Aim, Beguiling Defenses' Reaction, Eldritch Hex, Thought Shield's reflected damage, Guarded Mind's ending of Charmed and Frightened, Spell Breaker's Bonus Action Dispel Magic | data (`implemented: text`; resources for their uses are in the data) | not started [the spell and ability audit] | — |
| Already in combat at 8-11: Indomitable, Tactical Master, Two Extra Attacks, Divine Intervention, Heightened Focus, Self-Restoration, Aura of Courage, Radiant Strikes, Tireless, Improved Cunning Strike, Heroic Warrior, Eldritch Strike, Twinkling Constellations, Magical Ambush, Soul Blades, Supreme Sneak, The Third Eye, Illusory Self, Stalker's Flurry (2d8), Dreadful Strikes (1d6 at 11), Lifedrinker | combat/ | implemented (the Phase 1 classes' since Phase 2; tested where the rows above say) | — |

## Feats, equipment, spells

| Rule | Code | Status | Test |
|---|---|---|---|
| Feats: 10 origin, 43 general, 10 fighting style, 12 epic boons | data/feats + features.gd, feature_actions.gd, reactions.gd | implemented in combat (Lucky, Interception, Protection, Sentinel, Polearm Master, War Caster, Great Weapon Master, Sharpshooter, Spell Sniper, Crossbow Expert, Crusher, Piercer, Slasher, Mage Slayer, Heavy Armor Master, Shield Master, Defensive Duelist, Dual Wielder, Two-Weapon Fighting, Tavern Brawler, Unarmed Fighting, Healer, Durable, Charger, Speedy, Skulker, Telekinetic, Poisoner, Elemental Adept, Keen Mind and Observant Bonus Actions, boons); rest-time and social parts are Phase 3; `make validate` checks every "engine" label | test_feature_combat, test_attacks |
| Species actions: Breath Weapon, Draconic Flight, Giant Ancestry, Large Form, Relentless Endurance, Adrenaline Rush, Healing Hands, Celestial Revelation, Stonecunning; saves against conditions (Dwarven Resilience, Fey Ancestry, Brave) | feature_actions.gd, spell_caster.gd | tested: Breath Weapon, Fire's Burn, Relentless Endurance, Healing Hands, Dwarven Resilience | test_feature_combat |
| Weapon properties, Finesse, Versatile, Thrown, Range | resolution/weapon_profile.gd | tested | test_attacks |
| Weapon Mastery properties | encounter.gd, features.gd | tested: all eight (Cleave in test_feature_combat); Push and Topple can be held back from the class tab | test_combat_encounter, test_feature_combat |
| Armor: light/medium/heavy AC, Strength requirement, Stealth Disadvantage | character.gd | tested | test_reference_party, test_attacks |
| Armor and Shield without training | character.gd gear_d20_sources, armor_class | implemented | — |
| Unarmed Strike (1 + Str) | weapon_profile.gd | implemented | — |
| Carrying capacity by size and Powerful Build | creature.gd carrying_capacity | implemented | — |
| Spell slots (full, half, third, multiclass) | magic/spellcasting.gd | tested (to level 11 by class) | test_spellcasting, test_levels_8_to_11 |
| Spell save DC and spell attack | character.gd | tested | test_reference_party |
| Cantrip scaling at 5/11/17; upcasting | magic/spellcasting.gd | tested (11 in test_levels_8_to_11) | test_spellcasting, test_levels_8_to_11 |
| Prepared spells, always-prepared spells, spellbook | character.gd | tested | test_reference_party |
| Ritual casting | data (ritual flags) | data | [Phase 3] |
| Components and focuses | spell_caster.gd | partial: Verbal (can't speak, reveals the hidden), armor training; Material and focuses assumed carried | test_combat_spells |
| Areas of effect | grid.gd area_cells, spell_caster.gd | tested (sphere, cube, cone, line, emanation from a creature or a placed object, wall; walls block) | test_combat_grid, test_combat_spells, test_new_spells |
| 256 spells (every 2024 PHB spell of levels 0-4 on the eight caster lists, plus Etherealness and Plane Shift for the Night Hag) | data/spells, spell_caster.gd, spell_zones.gd, spell_specials.gd, summon_blocks.gd, shape_change.gd | tested: every spell of levels 0-4 with combat rules is cast (smites on a weapon hit) and must change the fight; the rest are exploration (detection, communication, rituals, travel) and say so on the hotbar | test_spell_sweep, test_spell_recipes, test_combat_spells, test_new_spells |

## Combat (Phase 2: combat/, ADR 0007)

| Rule | Code | Status | Test |
|---|---|---|---|
| Initiative: Dexterity check, surprise = Disadvantage, identical monsters share a roll, ties | encounter.gd start | tested | test_combat_encounter |
| Turn order, rounds, the action economy (Action, Bonus Action, Reaction, movement, one free object interaction) | encounter.gd, combatant.gd | tested | test_combat_encounter |
| Grid movement: 5 ft squares, diagonals 5 ft, no corner cutting, Difficult Terrain double, climbing | grid.gd | tested | test_combat_grid |
| Moving through creatures (allies, Incapacitated, Tiny, two sizes different; enemy squares are Difficult Terrain); can't end in an occupied square | encounter.gd _occupancy_for | tested | test_combat_encounter |
| Halfling Nimbleness, Naturally Stealthy, Luck | encounter.gd, d20_test.gd reroll_ones | tested (Nimbleness, Luck through the suite) | test_combat_encounter |
| Prone: Disadvantage to attack, Advantage within 5 ft / Disadvantage beyond against it, standing costs half Speed, crawling double | encounter.gd, action_catalog.gd | tested | test_combat_encounter, test_action_catalog |
| Opportunity Attacks (leaving reach of a creature that can see you; Disengage; forced movement doesn't provoke) | encounter.gd _walk, _provokers | tested | test_combat_encounter |
| Reactions: one per round, prompts for the player with per-reaction rules | encounter.gd, reaction_request.gd | tested | test_combat_encounter, test_combat_ai |
| Attack rolls: every Advantage/Disadvantage source, cover, long range, ranged attacks in melee, unseen attackers and targets, Heavy | encounter.gd attack_situation | tested | test_combat_encounter |
| Cover: Half +2, Three-Quarters +5, Total untargetable; creatures give Half; Dex saves add cover | grid.gd cover_between, spell_caster.gd | tested | test_combat_grid, test_combat_encounter |
| Critical Hits, automatic crits against Paralyzed/Unconscious within 5 ft | encounter.gd | tested | test_combat_encounter |
| Standard actions: Attack, Dash, Disengage, Dodge, Help (attack), Hide, Search, Study, Ready (attacks), Magic, Utilize (Healer's Kit), Influence | encounter.gd, action_catalog.gd | tested (Influence has no target in the arena; readied spells: deviations) | test_combat_encounter, test_action_catalog |
| Grapple and Shove with Unarmed Strike; escape | encounter.gd | tested | test_combat_encounter |
| Two-weapon fighting (Light) and Nick | encounter.gd offhand_attack | tested | test_combat_encounter |
| Thrown weapons leave the hand; ammunition used up | encounter.gd | tested | test_combat_encounter |
| Death Saving Throws on the creature's turn, stabilizing (Medicine DC 10 or Healer's Kit) | encounter.gd death_save, stabilize | tested (rules in test_death_saves) | test_death_saves, test_combat_arena_scene |
| Savage Attacker, Sneak Attack once per turn (any turn) | encounter.gd, features.gd | tested | test_combat_encounter |
| Spellcasting in combat: casting time vs the action economy, one slot-spell per turn, free castings, Concentration, range and line of effect, upcasting | spell_caster.gd | tested | test_combat_spells |
| Spell attacks, saves (damage rolled once, half on success), healing (Disciple of Life), buffs, repeated saves | spell_caster.gd | tested | test_combat_spells |
| Spell secondary effects: pushes and pulls (farthest first), lingering areas (Spirit Guardians, Cloud of Daggers, Web, Grease, Entangle, Fog Cloud, Darkness, Silence, Stinking Cloud, Sleet Storm, Gust of Wind), spell objects (Spiritual Weapon, Flaming Sphere, Dancing Lights, Mage Hand), sustained actions (Witch Bolt, Vampiric Touch, Dragon's Breath, Produce Flame), effect durations and triggers, repeated saves, escape checks, summons (Summon Fey/Undead), teleports, Haste and Slow, Mirror Image, Blink, Invisibility ending, cast-time choices, readied spells, Command's five words | spell_caster.gd, spell_zones.gd | tested | test_spell_recipes, test_combat_spells |
| Channel Divinity: Turn Undead (Sear Undead), Divine Spark, Preserve Life | features.gd | tested | test_combat_spells |
| Monster stat blocks in combat: attacks, Multiattack choices, timed riders with exceptions, real grapples, save actions, Recharge, drains, swarms, flyers, Parry, auras, sunlight, Lightning Absorption, Incorporeal Movement, Loathsome Limbs, lycanthropy, spellcasting | encounter.gd, monster_actions.gd | tested | test_monster_actions, test_combat_encounter |
| Enemy AI: pack_hunter, brute, mindless, cowardly, skirmisher, swarm, spellcaster, support; obeys Command, Fear, Crown of Madness, Calm Emotions | ai/ai_brain.gd | tested | test_combat_ai, test_arena_fight, test_monster_actions |
| Encounter XP budget (2024 DMG) | tools/data/validate_data.py | tested by make validate | — |
| Mounted combat: mounting and dismounting (half Speed), a controlled mount carrying its rider and limited to Dash, Disengage and Dodge, falling off when the mount is moved or drops | encounter.gd mount, dismount, _forced_mount_check; combat_view.gd | tested | test_new_spells |
| Spells of levels 5-9 in combat: summons (Celestial, Dragon, Fiend, Animate Objects), Swift Quiver, Eyebite, Bigby's Hand's four hands, Telekinesis, Conjure Elemental, Cloudkill and Incendiary Cloud drifting, three-save Contagion and Flesh to Stone, Otto's saving action, Harm, Heal, Sunbeam's sunlight, Circle of Power, Globe of Invulnerability, Antilife Shell, Wall of Force and Stone; the Power Words, Divine Word, Mass Heal, Prismatic Spray and Wall, Maze, Forcecage, Time Stop, Reverse Gravity, True Polymorph, Shapechange, Animal Shapes, Delayed Blast Fireball, Storm of Vengeance, Tsunami, Earthquake, Conjure Celestial, Regenerate, Antimagic Field, Holy Aura, Fire Storm and Meteor Swarm's several areas | high_magic.gd, mid_magic.gd, spell_caster.gd, spell_zones.gd, summon_blocks.gd | tested; the spell sweep casts every combat spell of every level (6-9 with stat-block numbers) | test_high_magic, test_spell_sweep |
| Class features of levels 8-11 in combat: Brutal Strike, Relentless Rage, Abjure Foes, Acrobatic Movement, Roving Aim, Retaliation, Battering Roots, Zealous Presence, Moonlight Step, Stormborn, Beguiling Defenses, Eldritch Hex, Thought Shield, Flurry of Healing and Harm, Improved Shadow Step, Stride of the Elements, Fleet Step, Bestial Fury, Superior Hunter's Prey, Fey Reinforcements, Stalker's Flurry, Guarded Mind, Spell Breaker | class_features.gd, features.gd, encounter.gd, spell_caster.gd | tested: Brutal Strike, Relentless Rage, Abjure Foes, Zealous Presence, Thought Shield, Spell Breaker, Moonlight Step | test_class_combat |
| Light, darkness and obscurement in combat | encounter.gd can_see / light_at, spell_zones.gd | implemented: map light (bright/dim/dark), Darkvision, Blindsight and Truesight, light from spells, magical Darkness, Heavily Obscured areas, sunlight | test_spell_recipes |

## Exploration and rests (Phase 3: world/exploration, story/, ADR 0008, ADR 0009)

| Rule | Code | Status | Test |
|---|---|---|---|
| Passive Perception notices traps (within 10 ft) | location_view.gd _check_traps | tested | test_exploration |
| Search (Wisdom (Perception)) finds traps, hidden objects and secret doors | location_view.gd search | tested | test_exploration |
| Thieves' Tools (2024): Dexterity check + Proficiency Bonus with the tools, Advantage with Sleight of Hand too; pick a lock or disarm a trap | location_view.gd _unlock, _disarm | implemented | test_exploration |
| Forcing a lock: Strength (Athletics) | location_view.gd _unlock | deviated (DC + 2, see deviations) | test_exploration |
| Traps: save, damage (half on a success), condition | location_view.gd _spring_trap | implemented | — |
| Stealth and surprise: a sneaking party's lowest Stealth against each enemy's passive Perception | location_view.gd _stealth_surprise | implemented | — |
| Short Rest: spend Hit Point Dice (roll + Con, minimum 1), short-rest features | rest_screen.gd, character.gd | tested | test_party_screens |
| Long Rest: all Hit Points, Hit Point Dice, slots and features; interruption | rest_screen.gd | implemented (interruption: deviations) | — |
| Ability checks in conversation (any skill or ability, the speaking character's bonus, Advantage sources) | story/dialogue_runner.gd | tested | test_story |
| Milestone levelling | story/story_state.gd, level_up_screen.gd | tested | test_story, test_party_screens |
| Saves outside combat and at the start of each round; effects and Concentration saved | core/save_system.gd, combat/encounter_snapshot.gd | tested | test_exploration, test_story |
| Casting outside combat: healing and helpful spells, slots, lasting effects and Concentration | story/field_casting.gd (through SpellCaster) | tested | test_party_screens |
| Frightened: can't willingly move closer to a visible source | encounter.gd reachable_for | tested (strict reading, deviations) | test_combat_encounter |
| Flying creatures move at their Fly Speed | combatant.gd speed | implemented (no altitude, deviations) | test_phase3_exit |
| Heroic Inspiration and Tactical Mind after a failed check (conversations) | story/check_aids.gd | tested; exploration checks and saves outside combat [Phase 5] | test_story |
| Light, Darkvision and obscurement affecting checks and attacks | combat (audit); location_view.gd passes the hour, map light, lamps and lantern into fights | tested | test_exploration |
| Exploring spells (Light, Detect Magic, Find Traps, others as `spell:` conditions); Ritual casting (+10 minutes, no slot) | story/field_casting.gd, location_view.gd apply_spell_effect | tested (Light, Find Traps); the rest record their duration for the story to read | test_exploration |
| Arcane Recovery | rest_screen.gd | tested | test_party_screens |
| Changing prepared spells after a Long Rest | ui/screens/prepare_screen.gd (the class's `swap_prepared`) | tested | test_party_screens |
| Attunement (three items, requirements, a Short Rest) and magic item modifiers | character.gd attune, item_modifiers | tested | test_classes |
| Buying and selling (shop markup, sell rate, stock) | story_state.gd shop_*, shop_screen.gd | tested | test_campaign |
| Travel (hours on the road), random encounters (day and night chances), day and night | story/travel.gd, game_root.gd travel | tested | test_travel |
| Guests fighting under the player's control | location_view.gd guest_members, combat side guest | tested | test_exploration |

## Not started (later phases)

Influence and NPC attitudes as a rule (attitudes exist in the story; haggling is written into dialogue for now);
the new classes' level 8-11 features in combat (listed under Classes; the spell and ability thread); magic items' own powers beyond modifiers
(Phase 5, with the treasures).
