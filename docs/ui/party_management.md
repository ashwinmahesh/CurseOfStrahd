# Party management (core flow 4 of 4)

Status: **approved by the owner 2026-10-06 ("Looks good")** · Owner role: Character and Party UX · Plan §5.2, §5.6 "Party management"
Engine: `Character` sheet values and breakdowns, `Creature.effects / active_conditions / resources`,
`Character.spend_hit_die / finish_short_rest / finish_long_rest / known_spells / spellcasting`, `PartyCoverage`.

## What this screen must do

- Show the whole party at a glance, and every detail of one character, with every number explained.
- Make the player the director of everyone: the party (up to four) and any story guest. Guests are directed in
  combat like the party but their level and gear come from the story.
- Run rests and spell preparation, and track the lingering things Barovia does to people.

## Party overview (`pm_01_overview`)
![Party overview](wireframes/pm_01_overview.svg)

A column per party member (up to four) plus the guest slot: portrait, class and level, Hit Points bar (Bloodied called out in words), Hit
Point Dice, spell slots, class resources (Second Wind, Channel Divinity ...), conditions with remaining time,
exhaustion, attunements, and the ⬆ level-up badge. Below: the **party skill table** (best character per skill,
Expertise starred), from `PartyCoverage`.

## Who travels (roster screen)

Added by the owner (2026-10-06, 2026-10-07). The roster is the six companions (character_creation.md, Start) plus the
custom hero if there is one. Up to four (`StoryState.PARTY_CAP`) travel; the rest wait at camp (`StoryState.bench`),
where they don't fight, speak or level. **Change who travels** on the party overview opens the roster screen, outside
fights and conversations only; it shows when someone is at camp or the party has room. Party cards have **Send to
camp** (never the last one on the road); camp cards have **Bring along** (while there's room) and **Swap in**, then
"<name> takes this place" on the party member to replace. The world swaps the figures as soon as the party changes.

Levels missed at camp wait (owner, 2026-10-07): a benched member keeps their level, and their card shows
"▲ A level up waiting" or "▲ 2 level ups waiting" (`StoryState.levels_waiting`, the party's milestone level minus
theirs). Once they're back in the party, **Level up** opens the level-up screen, which reopens for the next level
until they've caught up, so every choice is the player's.

## Create a character (party overview)

Added by the owner (2026-10-07): a custom character can be created from the party screen at any time. They go
through the whole creator, start at level 1, and can go straight to the level-up screen to match the party. A game
has up to four custom characters at once.

**Create a character** (a quill) sits beside **Change who travels** above the party cards, with a "Custom
characters N of 4" pill on the left. It opens the creator in hero mode (character_creation.md, Start) titled
"Create a character": every step, the paper doll, and a party strip with the party they'll join. Names already in
the company and portraits other custom characters wear are taken (each custom character's portrait is also the id
its sprite is known by). **Join the company** adds them at level 1 with full Hit Points (`StoryState.recruit`, which
also gives them an id nobody in the company has): to the party while it has room, then the party overview opens with
"▲ 4 level ups waiting" on their card and **Level up** lit; with the party full, to camp, and the roster screen opens
with them picked to swap in. **Back** (or Escape on the first step) returns to the party overview.

"Match the party" is the party's milestone level (`StoryState.target_level`, the level the party is levelled to), as
for a member back from camp: the level-up screen says "Level 2 for Mira; 3 more wait after it, up to the party's
level 5" and reopens for each level until they're caught up.

Four custom characters at once (`StoryState.CUSTOM_CAP`), counting everyone in the roster, at camp or travelling,
and the hero made at the start. With four, the button stays but is off, and the reason is written beside it (as it
is mid-fight or mid-conversation, when it's off too). Custom characters save and load with the game like everyone in
the roster and keep the look the player made; older saves without any load as before.

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
  restores (all HP and Hit Point Dice, slots, features, Exhaustion −1), then spell preparation. While one can't start
  (enemies remain somewhere in the building or dungeon, or the last ended under 16 hours ago; story/rest_rules.gd)
  its button is off and the card says why in words, with the time left, so the pad reads it too; the Short Rest stays.

## Spell preparation (`pm_04_spell_preparation`)
![Spell preparation](wireframes/pm_04_spell_preparation.svg)

Per character: "7 of 7" counter, always-prepared domain spells marked ★ and not counted, Ritual and Concentration
tags, spells above the character's slots greyed with the reason, and saved **loadouts** (Exploring, Dungeon crawl,
Undead hunt). Wizards prepare from their spellbook; the screen notes that they can cast spellbook Rituals unprepared.
2024 limits: Clerics, Druids and Wizards change any number; Paladins and Rangers replace one spell and Wizards one
cantrip (unpick it, then pick the new one; the rest lock once it's used). Weapon Mastery is on the same screen:
Barbarians and Fighters swap one kind, Paladins, Rangers and Rogues any. The limit counts from the list the Long Rest
ended with, so closing and reopening the screen doesn't give another swap. Opened from the Rest screen's "Change
prepared spells" button after an uninterrupted Long Rest.

## States

| State | What the player sees |
|---|---|
| Character at 0 HP | portrait greyed, "Unconscious · Death saves ✓✓ ✗" |
| Dead | portrait faded, "Dead" and the ways back (Revivify within 1 minute ...) |
| Guest present | fifth column "Guest: directed by you in combat; level and gear come from the story" |
| Rest unavailable | the place's own "You can't rest here" line; for a Long Rest only, "Enemies still prowl this place" or "the next can start in 7 hours 30 minutes" on its card |
| Interrupted rest | what was gained (a Short Rest's benefits after 1 hour of a Long Rest) |
| Controller | LB/RB tabs, LT/RT character, A on a number opens its breakdown |

## Acceptance

- Engine (Phase 1, passing): breakdowns for every sheet number, effects with durations and Concentration, conditions,
  death saves, Hit Point Dice, rests restoring resources and slots, known spells with their sources.
- Phase 3: rest screens drive the engine end to end; a UX review at the milestone exit.
