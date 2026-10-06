# Combat view and controls

Status: **draft, waiting for owner sign-off** (added at the owner's request, 2026-10-06) · Owner role: UI/UX ·
Plan §5.3 · Built in Phase 2 · Layout inspired by Baldur's Gate 3's turn-based combat screen (initiative strip on
top, party on the left, hotbar and End Turn at the bottom, log on the right), drawn in our palette and style.

## What this screen must do

- Make a 2024 turn readable at a glance: whose turn it is, what they have left (Action, Bonus Action, Reaction,
  movement), what each option will do, and the odds, before the player commits.
- Keep the player in charge of every party member and guest (plan pillar 2). The game never acts for them; it only
  asks (reaction prompts) or follows rules the player set ("auto when it turns a hit to a miss").
- Show the dice and the math for every roll (plan §5.3 "visible dice and math").

## Layout (`cb_01_combat_view`)
![Combat view](wireframes/cb_01_combat_view.svg)

1. **Initiative strip** (top center): round number and portraits in turn order; the active creature is larger with a
   candle frame; enemies have red frames, the party gold, guests moonlight blue; a thin HP bar under each (enemies
   show Bloodied and dead states, not exact HP). Hover a portrait to highlight the creature on the field.
2. **Party frames** (left): the four party members and any guest, with HP bars, conditions as named chips (Prone,
   Poisoned, Bless ◎ for Concentration) and the level-up badge. Click or Tab to switch the controlled character on
   their turn or to inspect them otherwise.
3. **Combat log** (right): every roll as one readable line (`D20Test.describe()`, `DamageResult.describe()`),
   Narrator lines in italics (plan §5.7, rare and short in combat), warnings in amber. Click a line for the full
   math (see cb_03).
4. **Hotbar** (bottom): the active character's portrait with HP and AC; the action economy as shapes plus words
   (Action ●, Bonus Action ▲, Reaction ◆; greyed when spent) and a movement bar ("20 / 30 ft"); tabs (Common,
   class name or Spells, Items, Passives); slots colored by what they cost (Action green, Bonus Action ember,
   Reaction plum, free slate) and labelled with their numbers ("Greatsword +7 · 2d6+4", "Second Wind 3 left").
   Every PHB action is on Common: Attack, Dash, Disengage, Dodge, Help, Hide, Influence, Magic, Ready, Search,
   Study, Utilize, plus Grapple and Shove (Unarmed Strike options) and Jump. Extra Attack shows "2 attacks per
   Attack action".
5. **End Turn**: a large round button (Space, or hold Y). If the character still has unspent Action or movement, the
   first press shows "End turn with Action unused?".

On the field: the 5 ft grid appears in combat; hovering the floor shows the movement path with feet used and left,
and warns before a step that provokes an Opportunity Attack ("leaves Wolf's reach"), naming the creature. Hovering
a creature shows the **target tooltip**: hit chance and the d20 needed, damage with average, mastery effects (Graze
on a miss), Advantage/Disadvantage with their sources, cover, and what the party knows of its defenses.

## Targeting and areas (`cb_02_targeting`)
![Targeting](wireframes/cb_02_targeting.svg)

- Spells and area attacks preview their template on the grid (sphere, cone, cube, line, emanation) from the spell
  data, with every creature inside listed: save and DC, the chance each fails, expected damage, and whether it would
  likely drop.
- **Friendly fire** is called out in red with what happens to the ally; it never blocks (the player decides).
- Upcasting: the slot pips beside the tooltip pick the slot level and update the numbers (Fireball 8d6 → 9d6).
- Concentration: casting a second Concentration spell warns that the first one ends, naming it.

## Reactions, roll details and the controller (`cb_03_reactions_and_controls`)
![Reactions and controls](wireframes/cb_03_reactions_and_controls.svg)

1. **Reaction prompt**: the trigger in plain words with the numbers ("hits Silvain: 15 vs AC 11"), what the reaction
   would change ("AC 16, so this attack misses"), its cost, and Cast / Skip. "Next time" sets a per-character rule
   for that reaction: Ask (default), Never, or an automatic condition such as "auto when it turns a hit to a miss"
   (plan §5.3: a rule the player sets, not AI judgment). Opportunity Attacks, Shield, Counterspell, Uncanny Dodge,
   Parry and Riposte all use this prompt.
2. **Roll details**: any log line opens the whole calculation, with dice, Advantage sources, every modifier, damage
   dice before and after Great Weapon Fighting, Resistances, and mastery effects.
3. **Controller**: LB opens a radial menu (Attacks, Spells, Class, Items, Common, Move, End Turn, Inspect); the right
   stick picks, A confirms. The bottom panel lists the full mouse, keyboard and controller map.

## States

| State | What the player sees |
|---|---|
| Party member's turn | hotbar active; portrait enlarged in the strip; camera eases to them |
| Enemy or neutral turn | hotbar dimmed with "Wolf's turn"; the log narrates; reactions can still prompt |
| Out of an action type | its shape greyed; slots that need it greyed with the reason ("Bonus Action used") |
| Slot unavailable | greyed with why ("No level 3 slots left", "Needs a free hand", "Incapacitated") |
| Movement preview | path, feet used and left, Opportunity Attack warnings, difficult terrain shown as doubled cost |
| Targeting | template on the grid, creatures listed with chances; Esc/B cancels |
| Reaction pending | modal prompt; the turn pauses; a timer is never used |
| Character at 0 HP | frame greyed; on their turn the hotbar shows the Death Saving Throw button and the tally |
| Combat start | "Roll Initiative" banner, surprise explained per creature; the 5 ft grid fades in |

## Engine hooks

Phase 1 already provides the numbers and text: `WeaponProfile` (attack and damage breakdowns, crit range, mastery),
`AttackResolver.weapon_attack` (roll, Advantage sources, Critical Hits, Prone and Paralyzed targets, damage through
defenses), `Character.spell_preview` (spell dice, bonuses, save DC), `D20Test.describe()` and
`DamageResult.describe()` for the log, `Creature.d20_sources` for Advantage explanations, and conditions and effects
for the chips. Phase 2 adds the turn manager (initiative, action economy), the grid, line of sight and cover, area
templates, hit-chance math, the reaction system and the hotbar's action catalog.

## Acceptance (Phase 2)

- A scripted fight (the plan's wolves-and-zombies arena) is playable with mouse and keyboard only and with the
  controller only.
- Every hotbar slot, tooltip and log line shows numbers that match the rules engine.
- No party member ever acts without the player choosing it or a rule the player set.
