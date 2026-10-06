# Party management (core flow 4 of 4)

Status: **approved by the owner 2026-10-06 ("Looks good")** · Owner role: Character and Party UX · Plan §5.2, §5.6 "Party management"
Engine: `Character` sheet values and breakdowns, `Creature.effects / active_conditions / resources`,
`Character.spend_hit_die / finish_short_rest / finish_long_rest / known_spells / spellcasting`, `PartyCoverage`.

## What this screen must do

- Show the whole party at a glance, and every detail of one character, with every number explained.
- Make the player the director of everyone: the four party members and any story guest. Guests are directed in
  combat like the party but their level and gear come from the story.
- Run rests and spell preparation, and track the lingering things Barovia does to people.

## Party overview (`pm_01_overview`)
![Party overview](wireframes/pm_01_overview.svg)

Four columns plus the guest slot: portrait, class and level, Hit Points bar (Bloodied called out in words), Hit
Point Dice, spell slots, class resources (Second Wind, Channel Divinity ...), conditions with remaining time,
exhaustion, attunements, and the ⬆ level-up badge. Below: the **party skill table** (best character per skill,
Expertise starred), from `PartyCoverage`.

## Character sheet (`pm_02_sheet`)
![Character sheet](wireframes/pm_02_sheet.svg)

Laid out like Baldur's Gate 3's sheet (owner request 2026-10-06: "just a wall of text, really unreadable"), in three
columns so the numbers that matter are always on screen:
- **Hero** (left): portrait chips for the party along the top; the portrait in a gilt frame, name, class and origin;
  the Hit Points bar (Bloodied, Unconscious, Stable or Dead in words, temporary HP in moonlight, death saves when down);
  the Armor Class shield and plaques for Initiative, Speed and Proficiency Bonus; then Hit Point Dice, passive
  Perception, Insight and Investigation, senses, load, size, Heroic Inspiration and Exhaustion.
- **Abilities** (middle): six medallions (modifier large, score on a plaque) with each saving throw under it, and the
  18 skills in two columns with marks for proficient, Expertise and untrained.
- **Tabs** (right): Actions (attacks, spellcasting DC and attack, slots as lozenges, resources with their recharge),
  Features · Spells · Equipment · Effects · Notes. Q/E switch tabs, ←/→ switch character.
- Every number's tooltip lays its `Breakdown` out line by line; long rules text (features, spells, items, conditions)
  lives in tooltips, and the page keeps to names, one-line summaries and tags (Action, Bonus Action, Reaction,
  Concentration, Ritual, Always prepared). Drawn pieces are in `UiParts` (ui/common/ui_parts.gd).
- **Features**: grouped by class (with subclass), species, background and feats; each with how it's used, its level
  or source, its summary, and the full text on hover; `implemented: text` features are tagged "Rules text only".
  Below them, armor, weapon, tool and language training and Weapon Mastery.
- **Spells**: per level, with slots as lozenges in the header; each spell shows casting time, range and what it does
  ("120 ft · 2d10 Fire · Dex save"), and a Cast control when it can be cast outside a fight (`FieldCasting`).
- **Equipment**: worn and wielded slots with their AC or damage, attunement, the pack, load and the purse, and a way
  to the full inventory screen.
- **Active Effects**: every condition, spell and item effect with its source, what it does and its remaining
  duration (`Effect.describe_duration()`), including ended Concentration effects greyed for a turn so the player
  sees what just dropped.
- **Lingering effects** specific to Barovia (Amber Temple dark gifts, lycanthropy, Strahd's charm, curses, the mists'
  madness) live here too, tagged "Story".

## Formation and rests (`pm_03_formation_and_rests`)
![Formation and rests](wireframes/pm_03_formation_and_rests.svg)

- **Marching order**: drag to reorder; the leader (★) walks first and can be switched any time (Tab or 1-4 in
  exploration). Each row shows what matters for order: passive Perception, Stealth, darkvision. Formations: Column,
  Pairs, Wedge, Spread. A tip appears when the best spotter is at the back.
- **Short Rest**: per character, spend Hit Point Dice one at a time with on-screen dice (roll + Con, minimum 1:
  `spend_hit_die`), and a list of what comes back on finishing (Second Wind +1, Channel Divinity +1, Arcane
  Recovery's slot levels to choose).
- **Long Rest**: camp scene with the interruption risk for the region and time, watch order, and what finishing
  restores (all HP and Hit Point Dice, slots, features, Exhaustion −1), then spell preparation.

## Spell preparation (`pm_04_spell_preparation`)
![Spell preparation](wireframes/pm_04_spell_preparation.svg)

Per character: "7 of 7" counter, always-prepared domain spells marked ★ and not counted, Ritual and Concentration
tags, spells above the character's slots greyed with the reason, and saved **loadouts** (Exploring, Dungeon crawl,
Undead hunt). Wizards prepare from their spellbook; the screen notes that they can cast spellbook Rituals unprepared.
2024 limits: Clerics, Druids and Wizards change any number; Paladins and Rangers replace one spell and Wizards one
cantrip (unpick it, then pick the new one; the rest lock once it's used). The limit counts from the list the Long Rest
ended with, so closing and reopening the screen doesn't give another swap. Opened from the Rest screen's "Change
prepared spells" button after an uninterrupted Long Rest.

## States

| State | What the player sees |
|---|---|
| Character at 0 HP | portrait greyed, "Unconscious · Death saves ✓✓ ✗" |
| Dead | portrait faded, "Dead" and the ways back (Revivify within 1 minute ...) |
| Guest present | fifth column "Guest: directed by you in combat; level and gear come from the story" |
| Rest unavailable | "Can't rest: enemies nearby" or "needs at least 1 Hit Point" |
| Interrupted rest | what was gained (a Short Rest's benefits after 1 hour of a Long Rest) |
| Controller | LB/RB tabs, LT/RT character, A on a number opens its breakdown |

## Acceptance

- Engine (Phase 1, passing): breakdowns for every sheet number, effects with durations and Concentration, conditions,
  death saves, Hit Point Dice, rests restoring resources and slots, known spells with their sources.
- Phase 3: rest screens drive the engine end to end; a UX review at the milestone exit.
