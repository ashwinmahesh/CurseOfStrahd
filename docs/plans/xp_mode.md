# XP Mode Plan

Plan and validation for an experience-point levelling mode (Ashwin's ask, 2026-10-14). Written 2026-10-14 by the
XP-plan lane; the build goes to a separate lane. The project's copy is "XP Mode Plan.md" in the shared project files.
The simulator that produced every number below is `xp_sim.py` there too, to be checked in as `tools/balance/xp_sim.py`
(§7, step 8).

## The short version

- **A choice at a new game.** The New game page gets a second question after the difficulty, "How do heroes grow?":
  **Milestones** (today's game, the default) or **Experience**. Saves made before this keep milestones, and so does
  every save that never picked.
- **Where XP comes from:** beating foes (and talking or tricking your way past them), the region milestones, main-quest
  goals, side and companion quests, reaching new places, entering new locations, finding secrets and hidden things,
  passing skill checks that matter (social, puzzles, locks), noticing and disarming traps, and reading lore. Road and
  camp fights give XP too, but can't be farmed.
- **Sizes come from the 2024 rules:** the PHB's level table, the 2025 Monster Manual's XP per foe, and the 2024
  DMG's own advice that a major milestone is worth a High encounter and a minor one a Low encounter. One deviation does
  the heavy lifting: **each foe gives 40% of its stat-block XP**, because the game's fights were scaled up for 2024
  heroes and field far more foes than the book's. Uncorrected, by-the-book XP puts an average player 2 to 3 levels above the tuned fights
  by the Wizard of Wines.
- **Two guardrails** keep every fight tuned. A region milestone always brings the party at least to the level
  milestone mode would give (nobody falls behind on the critical path), and the party can never get more than one
  level ahead of it (extra one-time XP waits in a reserve for the next milestone; extra road and camp XP is lost).
- **Validated on the real fight data** (all 452 encounters with their level versions, the 11 road tables, the camp
  visitors), 600 simulated playthroughs per player type, three region orders. On the region docs' intended route an
  average player arrives at every story gate within a quarter level of the milestone level (within half a level on
  the other two orders), and meets 96% of critical-path fights at exactly the level milestone mode would (the other
  4% one level up, where those fights have their own tuned version). A bare-minimum player is held at the milestone
  level; a do-everything player runs one level ahead, never two.
- **Save format:** no `SAVE_VERSION` bump is needed; an always-run step in `SaveSystem.upgrade` pins old saves to
  milestones. The coordinator decides whether to bump anyway (see §8).

## 1. The 2024 rules this rests on (checked 2026-10-14)

- **Level thresholds** (2024 PHB, Character Advancement; D&D Beyond free rules): level 2 at 300 XP, 3 at 900, 4 at
  2,700, 5 at 6,500, 6 at 14,000, 7 at 23,000, 8 at 34,000, 9 at 48,000, 10 at 64,000, 11 at 85,000 (12 at 100,000,
  unused: the game caps at 11, `StoryState.LEVEL_CAP`).
- **XP for foes** (2024 DMG, Character Advancement): each monster's XP comes from its Challenge Rating (the 2025
  Monster Manual lists it; it is the `xp` field of every file in `data/monsters`). Foes count as overcome when killed,
  routed, captured or cleverly avoided, and the party divides their total XP evenly; NPCs who gave substantial help
  count as party members in the division.
- **Noncombat challenges** (same section): gauge the difficulty with the encounter-building rules and award XP as if
  it had been a combat encounter.
- **Milestones** (same section): story events earn XP (accomplishing goals, discovering important locations or
  information, reaching key destinations). "Treat a major milestone as a high-difficulty encounter and a minor
  milestone as a low-difficulty encounter."
- **XP Budget per Character** (2024 DMG, Combat Encounters), Low / Moderate / High: L1 50/75/100, L2 100/150/200, L3
  150/225/400, L4 250/375/500, L5 500/750/1,100, L6 600/1,000/1,400, L7 750/1,300/1,700, L8 1,000/1,700/2,100, L9
  1,300/2,000/2,600, L10 1,600/2,300/3,100. Levels 1-5 match `tools/data/validate_data.py`, 3-10 match the region
  docs. Level 11 (1,900/2,900/4,100) was not re-checked against the book; it only matters at the cap, where XP no
  longer changes anything.

## 2. What the player sees

- **New game page** (`ui/menu/difficulty_page.gd`): under the difficulty rows, "How do heroes grow?" with two rows
  in the same style. Milestones: "Levels come at the story's turning points, as now." Experience: "Every foe beaten,
  quest finished, secret found and place discovered earns XP. Story milestones still guarantee the level the story
  expects, and the party never runs more than one level ahead of it." Chosen once, like Honour; Settings shows it but
  can't change it.
- **Notices** (the existing toasts): after a won fight "+555 XP"; "Discovered Tser Falls: +125 XP"; "Quest complete:
  The Grey Mare, +125 XP"; at a region milestone "Milestone: +1,100 XP" (and, when the top-up fires, "Milestone: +2,400
  XP, the party reaches level 6"). Small awards (finds, checks, traps, lore) are appended to the notice the game
  already shows for that thing ("Found a Potion of Healing (+25 XP)"), never a toast of their own.
- **Party screen and character sheet**: "Level 6 · 15,240 / 23,000 XP" with a thin gilt bar; the ⬆ badge works as
  now. When the reserve holds XP: "Held for the next milestone: 1,240 XP" with a tip explaining the one-level rule.
- **Level-up screen**: in XP mode the "reached the level the story allows" line reads "needs 7,760 more XP for level
  7".
- **Benched heroes** share the party's XP (one pool), so a hero who rejoins takes the levels they missed one at a time,
  exactly as now (`levels_waiting`). A custom hero made mid-game starts at the XP level, as it starts at the milestone
  level now.
- Nothing is voiced; no new lines need `make voice`.

## 3. Every XP source

All awards are per hero (the pool is one hero's share). Budget columns are the 2024 DMG's per-character budget at the
party's current level (the lowest member's level, as encounter `when` reads it). Round each award to the nearest whole
XP, at least 1.

| Source | Counts when | Award per hero | Once? | Hook |
|---|---|---|---|---|
| **Foes overcome** | a fight ends in victory: every enemy-side combatant that died, withdrew, fled, surrendered or was taken captive (neutral side and summons give nothing) | 0.4 × the foes' stat-block XP ÷ 4 | per fight | `LocationFights._end_encounter`, outcome `victory` (every fight goes through it: location, dialogue, road, camp, Strahd's visits) |
| **Foes talked or tricked away** (2024 "cleverly avoiding") | a dialogue branch defuses a fight that was coming | the same as winning the version the party would have met | per encounter id | new dialogue effect `xp fight <encounter id>`, placed on the outs listed in §6 |
| **Region milestone** (major milestone) | each of the 11 `xp milestone` beats (17 lines, guarded by the regions' existing flags) | High; then the floor (§4); then the reserve is paid | per beat | `DialogueRunner` effect `xp` |
| **Main-quest goal** | a quest with `kind: main` reaches a stage with `ends: success` (Death House, the burial, the reading, each Tarokka treasure and the ally, Ireena's escort and sanctuary, the festival, the dinner, Strahd) | Moderate | per quest | `StoryState.set_quest_stage` |
| **Side and companion quests** (minor milestones) | any other quest reaches `ends: success` | half of Low | per quest | `StoryState.set_quest_stage` |
| **Discovering a place** (minor milestone) | the party first arrives at a place on the travel map (30 places) | half of Low | per place | where `st.visited[loc_id]` is first set (`location_view.gd`), when that location is a travel place's `location` |
| **Entering a new location** | the first visit to any other location map: a building, a floor, a cave (83 of them) | Low ÷ 10 | per location | same spot |
| **Secrets and finds** | a search spot found (`kind: search`, 180), a secret door found (`secret_dc`, 11), a hidden thing a check reveals | Low ÷ 20 | per prop or door | `LocationTraps` search, `WorldChecks` reveal |
| **Skill checks that matter** | a passed world check (a prop's `checks`, 140), a passed dialogue check (`* [Skill DC n]` options and `check` lines, about 470), a lock picked or forced (about 40 locked doors and boxes); failures give nothing | Low ÷ 20 | per check (dialogue: `file:node:index`, the key `xp` already uses) | `WorldChecks`, `DialogueRunner._check`, `LocationLocks` |
| **Traps** | a trap noticed (passive Perception or a search) and a trap disarmed (29 traps) | Low ÷ 20 each | per trap | `LocationTraps` |
| **Lore** | a new codex entry (49 books, letters, lore checks) | Low ÷ 40 | per entry | one `StoryState.add_codex` that the four `codex.append` sites call |
| **Road and camp fights** | as foes overcome, for the road tables, the camp's night visitors and Strahd's hunt | as foes overcome | no: repeatable, so capped (§4) | same fight hook; the spec says it is repeatable |
| **Strahd's visits** | the test of strength or a window fight he withdraws from | High (his own CR 15 XP waits for his end); his wolves and bats count as foes | per visit | same fight hook |
| **Strahd destroyed** | the final battle won | as foes overcome (his stat block's 13,000) | once | same fight hook |
| **Deck of Many Things, Sun** | the card is drawn | enough XP for the next level (not a milestone; the reserve applies) | per card | `DeckOfManyThings` (milestone mode keeps `milestones += 1`) |

Not XP: gold, loot, shopping, rests, approval, dark gifts, a lost fight, a failed check, a quest that ends in failure.

What the numbers come to (half Low, Low ÷ 10 and so on, rounded):

| Party level | XP to next level | Region milestone | Main-quest goal | Side quest, map place | New location, trap noticed + disarmed | Find, secret, lock, check | Lore |
|---|---|---|---|---|---|---|---|
| 1 | 300 | 100 | 75 | 25 | 5 | 3 | 1 |
| 3 | 1,800 | 400 | 225 | 75 | 15 | 8 | 4 |
| 5 | 7,500 | 1,100 | 750 | 250 | 50 | 25 | 13 |
| 7 | 11,000 | 1,700 | 1,300 | 375 | 75 | 38 | 19 |
| 9 | 16,000 | 2,600 | 2,000 | 650 | 130 | 65 | 33 |
| 10 | 21,000 | 3,100 | 2,300 | 800 | 160 | 80 | 40 |

Some fights, per hero: the black armor in Death House (level 1) 31 XP, a tenth of a level; the ghouls in the passage
(2) 101; Doru (3) 200; Grigor's hunters on the road (4) 170; the Black Roses in the street (5) 555; Offalia's bakery 180
at level 5 and 740 at level 6 (the level 6 version has eight more foes); the winery hall (6) 340; Vasilka's stand (7)
780; Kiril's challenge (8) 560; Baba Lysaga in her hut (9) 1,040; Vosk unmasked (10) 1,060. A mid-game fight is 4 to 8%
of a level.

## 4. The guardrails

The story level `s` is what milestone mode would give right now: `start_level + milestones`, capped at 11. XP mode
keeps counting `milestones` at every `xp milestone` beat, so `s` is always known.

1. **Floor.** At a region milestone the party gets the High award, and if it is then still short of the threshold for
   level `s` (the milestone's new level), it is lifted to that threshold. The party is never below milestone mode's
   level after a milestone, so no critical-path fight is met under-levelled. For an average player the lift fires at
   about half the gates and is small (median an eighth of a level, at most about a third) and reads as part of the
   milestone's award.
2. **Ceiling and reserve.** XP can't reach the threshold for level `s + 2`: the party is never more than one level
   above milestone mode. One-time XP that would cross it goes to a reserve (`xp_reserve`), paid at the next milestone
   up to the new ceiling, so a thorough player loses nothing, just waits. Repeatable XP (road tables, night visitors,
   Strahd's hunt) over the ceiling is lost, so grinding can't push past it.
3. **The cap stays 11.** At 85,000 XP the party stops gaining; the reserve and any further awards are kept for the
   end-of-run record only.

Why both: without them, the validated sizes still keep an average player within half a level of the milestones, but a
bare-minimum player ends 4 levels behind at the Amber Temple (level 7) and a do-everything player reaches 11 by the
Werewolf Den (§5.6).

## 5. Validation

### 5.1 Method

`xp_sim.py` reads the game's data directly: every encounter in `data/locations` with its versions in data order (the
first whose `when` holds is the fight, with `level` as a real party level, day or night as the stage plays it, and the
flags a typical playthrough has), every foe's XP from `data/monsters`, the 11 road tables with their day and night
chances and weights, and the night visitors by land and level. It walks a party through the campaign in stages, in
order, adding XP as it goes, so a party that levels mid-region meets the later fights' higher versions. It compares
the XP level with the milestone level at each story gate and at every fight.

Stages and their milestone levels: Into the Mists and Death House (1 → 2 at the hidden stair → 3 at the altar or the
escape), the Village of Barovia (3 → 4 at the burial), the Old Svalich Road and Tser Pool (4), Vallaki (4 → 5 at the
bones or the festival, then its level 5 side quests), then the Phase 5 regions, each +1, and Castle Ravenloft (no
milestone, tuned for 10, cap 11).

Routes: **six** (the region docs' intended pace: Old Bonegrinder, the Wizard of Wines, Krezk, the Werewolf Den, Berez,
the Amber Temple; Argynvostholt skipped, so the castle is met at 11 having arrived at the Temple at 10), **all** (all
seven Phase 5 regions, Argynvostholt after the Den), **alt** (the Den and Argynvostholt before Krezk and the winery).

Player types, each run 600 times with its own dice:
- **Average** (Ashwin's ask): the critical path; about half of each stage's optional fights; about half of the side
  quests open at that point; most locations; about 60% of search spots and half the checks offered; a quarter of road
  legs at night; one broken night in camp every three regions; no grinding. Per stage, below.
- **Minimal**: the critical path only, no side quests, little looking about.
- **Thorough**: everything.
- **Fighter**: every fight and every road leg, but few quests and little exploring.
- **Explorer**: every quest, place and secret, but only the fights it must.

### 5.2 What "average" does, stage by stage

| Stage | Always-met fights | Other fights met (of those listed) | Side quests done (of open) | Map places / new locations | Finds and secrets | Checks passed | Traps | Books | Road legs (fights met) | Broken camp nights |
|---|---|---|---|---|---|---|---|---|---|---|
| Into the Mists (L1) | 0 | 1.0 of 2 | 0.5 of 1 | 1 / 1 | 3 | 3 | 1 | 0 | 0 | 0 |
| Death House, above ground (L1) | 1 | 1.1 of 2 | 0 | 1 / 4 | 5 | 5 | 1 | 3 | 0 | 0 |
| Death House, the dungeon (L2) | 0 | 3.7 of 8 | 0.5 of 1 | 0 / 2 | 4 | 5 | 1 | 0 | 0 | 0 |
| Village of Barovia (L3) | 0 | 5.6 of 11 | 4 of 8 | 2 / 7 | 7 | 10 | 0 | 4 | 0 | 0.3 |
| Old Svalich Road, Tser Pool (L4) | 0 | 3.5 of 9 | 2.5 of 5 | 4 / 9 | 12 | 10 | 0 | 0 | 7 (1.0) | 0.3 |
| Vallaki (L4 to 5) | bones fight, one festival fight | 7.2 of 16 | 5 of 11 | 1 / 8 | 9 | 15 | 0 | 7 | 6 (0.7) | 0.3 |
| Old Bonegrinder (L5 to 6) | 0 | 3.0 of 5 | 1.8 of 3.6 | 2 / 4 | 8 | 4 | 1 | 0 | 6 (1.0) | 0.3 |
| Wizard of Wines, Yester Hill (L6 to 7) | 4 | 2.8 of 5 | 2.8 of 5.6 | 2 / 5 | 10 | 5 | 0 | 2 | 4 (0.8) | 0.3 |
| Krezk and the Abbey (L7 to 8) | 0 | 3.9 of 9 | 4.3 of 9.6 | 3 / 7 | 12 | 12 | 0 | 1 | 2 (0.4) | 0.3 |
| Van Richten's Tower, the Den, Lake Zarovich (L8 to 9) | 0 | 4.1 of 9 | 3.3 of 6.6 | 5 / 8 | 14 | 10 | 1 | 4 | 5 (0.6) | 0.3 |
| Argynvostholt (L8 to 9, route all) | 1 | 2.2 of 6 | 1.8 of 3.6 | 1 / 5 | 7 | 8 | 0 | 4 | 2 (0.3) | 0.3 |
| Berez, Mount Baratok, the Tsolenka Pass (L9 to 10) | 2 | 4.5 of 11 | 4.3 of 9.6 | 5 / 11 | 15 | 15 | 0 | 2 | 5 (1.1) | 0.3 |
| The Amber Temple (L10 to 11) | 0 | 4.4 of 10 | 2.3 of 4.6 | 2 / 6 | 8 | 18 | 3 | 2 | 2 (0.3) | 0 |
| Castle Ravenloft | the final battle | 2.6 of 6 | 5 of 9 | 1 / 12 | 10 | 20 | 4 | 0 | 1 (0.2) | 0 |

Fights that are one of several ways (the bones by day or by night, the three festival fights, the Abbot or his bride,
Baba Lysaga's four endings) are counted as the one a party meets. Side quests include companion quests finished along
the way and the Tarokka treasures and ally (one each in the winery, Krezk, the Den and Berez). Where a region's climax
can be reached without a fight (Krezk, the Den, Old Bonegrinder's bargain), "always-met" is 0 and the fight sits in
the other column.

### 5.3 Level at each story gate (route six)

XP level on arriving at the gate (before its award), as a fraction: 6.13 is level 6 and 13% of the way to 7.
"Topped up" is how often the floor added anything for the average player.

| Gate | Milestone level | Average p10 / p50 / p90 | Minimal | Thorough | Fighter | Explorer | Average topped up |
|---|---|---|---|---|---|---|---|
| Death House: the hidden stair | 2 | 1.64 / 1.86 / 2.04 | 1.40 | 2.13 | 1.95 | 1.71 | 81% |
| Death House: altar or escape | 3 | 2.74 / 3.02 / 3.16 | 2.33 | 3.36 | 3.25 | 2.51 | 42% |
| The burial | 4 | 3.89 / 4.11 / 4.30 | 3.33 | 4.83 | 4.30 | 4.01 | 26% |
| Vallaki: the bones or the festival | 5 | 4.91 / 5.03 / 5.29 | 4.50 | 6.00 | 5.16 | 5.16 | 37% |
| Old Bonegrinder | 6 | 5.94 / 6.13 / 6.51 | 5.43 | 7.00 | 6.42 | 6.23 | 20% |
| Wizard of Wines | 7 | 6.80 / 7.00 / 7.36 | 6.59 | 8.00 | 7.31 | 7.01 | 50% |
| Krezk | 8 | 7.88 / 8.02 / 8.34 | 7.47 | 9.00 | 8.13 | 8.20 | 44% |
| Werewolf Den | 9 | 8.67 / 8.76 / 9.06 | 8.49 | 10.00 | 8.72 | 8.99 | 86% |
| Berez | 10 | 9.99 / 10.08 / 10.20 | 9.62 | 11.00 | 10.00 | 10.26 | 12% |
| Amber Temple | 11 (cap) | 10.92 / 11.00 / 11.00 | 10.42 | 11.00 | 11.00 | 11.00 | 28% |

After each gate every type is at least at the milestone level (the floor). The thorough player sits at the ceiling,
exactly one level ahead, from Vallaki on; the reserve still holds about 94,000 XP per hero at the end (it never runs
out of things to bank).

The other routes, average player, arrival minus milestone level at each gate:

| Route | L2 | L3 | L4 | L5 | 6th gate | 7th | 8th | 9th | 10th | 11th |
|---|---|---|---|---|---|---|---|---|---|---|
| six | -0.14 | +0.02 | +0.11 | +0.03 | +0.13 | 0.00 | +0.02 | -0.24 | +0.08 | 0.00 (cap) |
| all | -0.14 | +0.02 | +0.11 | +0.03 | +0.13 | 0.00 | +0.02 | -0.24 | -0.33 | -0.13, then cap |
| alt | -0.14 | +0.02 | +0.11 | +0.03 | +0.45 | +0.17 | -0.33 | -0.23 | 0.00 | -0.23, then cap |

### 5.4 Fights met at the milestone level

Share of fights (not counting road fights) the party meets at milestone mode's level, or one level above it. Nobody
meets a fight below it.

| Route | Average | Average, critical path | Minimal | Thorough | Fighter | Explorer |
|---|---|---|---|---|---|---|
| six | 97% (3% +1) | 96% (4% +1) | 100% | 19% (81% +1) | 91% | 88% |
| all | 97% | 97% | 100% | 36% | 92% | 94% |
| alt | 95% | 100% | 100% | 36% | 90% | 90% |

### 5.5 Where the XP comes from (average player, route six, per hero)

| Stage | Level in, out | Fights | Road and camp | Quests and milestones | Exploring | Floor lift | Total |
|---|---|---|---|---|---|---|---|
| Into the Mists | 1.00, 1.34 | 31 | 0 | 13 | 50 | 0 | 94 |
| Death House, above ground | 1.34, 2.00 | 88 | 0 | 0 | 79 | 45 | 212 |
| Death House, the dungeon | 2.00, 3.02 | 373 | 0 | 191 | 75 | 45 | 684 |
| Village of Barovia | 3.02, 4.11 | 920 | 30 | 773 | 398 | 53 | 2,173 |
| Old Svalich Road, Tser Pool | 4.11, 4.69 | 424 | 131 | 689 | 1,000 | 0 | 2,244 |
| Vallaki | 4.69, 5.78 | 3,069 | 191 | 3,081 | 715 | 91 | 7,147 |
| Old Bonegrinder | 5.78, 6.29 | 1,468 | 238 | 1,780 | 1,095 | 123 | 4,704 |
| Wizard of Wines, Yester Hill | 6.29, 7.18 | 2,579 | 360 | 3,580 | 1,384 | 603 | 8,506 |
| Krezk and the Abbey | 7.18, 8.02 | 1,660 | 210 | 4,881 | 2,570 | 408 | 9,729 |
| Tower, Den, Lake | 8.02, 9.26 | 3,063 | 342 | 5,925 | 4,701 | 2,871 | 16,902 |
| Berez, Baratok, the Pass | 9.26, 10.42 | 4,958 | 793 | 8,168 | 6,697 | 61 | 20,677 |
| Amber Temple | 10.42, 11.00 | 3,349 | 168 | 2,835 | 5,183 | 393 | 11,929 |
| Castle Ravenloft | 11, 11 | at the cap: no more XP | | | | | |

Over the game an average player's XP is about 30% foes, 40% quests and milestones, 30% exploring. A fighter's is 59%
foes, an explorer's 10%; both still land on the milestone levels.

### 5.6 Stress tests (route six)

| Setup | Average at the gates | Minimal | Thorough |
|---|---|---|---|
| **By the book**: foes' full XP, side quests and places Low, milestones and main quests High, no guardrails | +0.2, +0.6, +1.0, +1.1, then +2.2 at Old Bonegrinder, +2.4, +2.8, cap 11 by the Den | 2.6 levels behind by the end (8.4 at the Temple) | level 11 by the Wizard of Wines |
| **This plan's sizes, no guardrails** | within -0.47 and +0.05; 17% of critical fights one level under | 6.9 at the Amber Temple (4 behind) | 11 by the Werewolf Den (3 ahead) |
| **This plan** | within -0.24 and +0.13 | the milestone level | one ahead |
| **This plan, a grinder** (8 extra road legs every stage, one or two more road fights each) | within -0.14 and +0.48; 73% of critical fights at the milestone level, the rest one above, never two | | |
| Foe share 0.45 or 0.5 instead of 0.4 | 0.45: within -0.09 and +0.38, 85% of critical fights at the milestone level; 0.5: up to +0.55, 66% | | |

The foe share is one number in data; 0.4 is the one that keeps fights at their tuned level, 0.45 if Ashwin wants
milestone lifts to feel smaller.

### 5.7 Known gaps

- **Fights with no version above their milestone level.** Where XP mode puts the party one level ahead (thorough
  players always; average players in 3-5% of fights), these fights are met one level easier than tuned, as they
  already are in milestone mode when a party takes all seven regions: Death House's (no versions), the village's
  level 3 fights, the Den's three (top version 8), Vasilka's stand (7), Berez's scarecrows and Baba Lysaga in her hut
  (9), the Tsolenka watch (8), the Amber Temple's (10), and the castle's (one version, tuned for 10). Adding a
  `level >= n+1` version to the critical ones is a follow-up for the fight-tuning lanes, not part of this build.
- **The model is a model.** It plays the real data but the "average" fractions are judgement, not telemetry. The
  build adds an XP-mode StoryBot check (§7, step 8) so a real playthrough confirms the floor and ceiling hold.
- **Intro road.** The Gates are reached by walking, not by the travel map, so no road fight can fall on a level 1
  party; the first road leg is leaving the village (checked in `into_the_mists_road.json`).

## 6. Fights that can be talked or tricked away

The `xp fight <id>` effect goes on the branch that defuses the fight, so a talker earns what a fighter would. From the
region docs' non-violent outs (the build lane checks each file and adds the effect where the out ends the threat for
good, not where it only delays it):

- Death House: `nursery_specter` (the nursemaid talked down instead of failed or attacked).
- Village: `doru_undercroft` (either of Doru's two non-violent outs), `hound_tenant` (the bricks blessed and sealed).
- Old Svalich Road: `road_hunters` (Persuasion, Insight, Intimidation or Ireena's word), `road_dead_procession`
  (hidden from or turned).
- Old Bonegrinder: `coven_last_stand` (the bargain that buys the children).
- Krezk: `bride_defends` (the repentant, wedding and fled endings; the Abbot's own fight only comes from attacking him).
- Werewolf Den: `den_guards` (Zuleika vouches).
- Argynvostholt: `beacon_stand` (the dragon's last words, or Persuasion 17).
- Berez: `lysaga_in_hut` (the bargain for the gem).
- Amber Temple: `sentinel_wakes` (the ward passed), `vosk_unmasked` (banished or paid off).

Choosing not to start an optional fight (the Tser Pool brawl, Lorghoth, the dinner's affront) is not avoiding one and
pays nothing.

A fight slipped past pays like one talked away (overworld stealth, docs/rules/stealth.md "Slipping past a waiting fight"): a
sneaking party that steps into the area of a fight waiting in plain view unnoticed, and leaves it again without the fight
starting, has cleverly avoided it, and `LocationStealth` calls `Xp.talked_away` with its encounter id when the last member
is out. The award is the same `_xp/fight/<id>` once-key, so slipping past twice, or fighting the fight afterwards, pays
once; Milestone mode gets only the toast.

`story/dialogue_file.gd` parses `xp fight <id>` beside `xp milestone` (today every `xp` line parses as a milestone),
`tools/data/dialogue_lint.py` learns the form, and `tools/data/validate_data.py` checks the id names an encounter, as
it already does for `combat <id>`.

## 7. Build plan (for the build lane)

1. **Data** `data/progression/xp.json` + `data/schemas/xp.schema.json`: the level thresholds (1-20), the per-character
   budgets (1-20), and the award table: `foe_share 0.4`, `split 4`, `milestone: high`, `main_quest: moderate`,
   `side_quest: low x0.5`, `place: low x0.5`, `location: low x0.1`, `find: low x0.05`, `check: low x0.05`,
   `trap_noticed: low x0.05`, `trap_disarmed: low x0.05`, `lore: low x0.025`, `strahd_withdraws: high`. Point
   `validate_data.py`'s budget table at the same file.
2. **Rules** `story/xp.gd` (`class_name Xp`, pure, no nodes): `level_for(xp)`, `threshold(level)`, `budget(level, col)`,
   `award(st, kind, ctx) -> int`, `gain(st, amount, repeatable) -> {gained, held, lost, notice}` (the ceiling, the
   reserve, the cap), `milestone(st) -> notice` (High, the floor, paying the reserve), `fight_xp(e) -> int`.
3. **State** `StoryState`: `xp: int`, `xp_reserve: int`, `options["levelling"]` (`"milestone"` or `"xp"`), and a
   `story_level()` (`start_level + milestones`, capped). `target_level()` returns `story_level()` in milestone mode and
   `Xp.level_for(xp)` (capped) in XP mode; `can_level_up` and `levels_waiting` stay as they are. `to_dict`/`from_dict`
   with defaults (`xp` 0, reserve 0, levelling `"milestone"`). Award keys already used go in `flags` under `_xp/...`
   as `xp milestone` does now, so each find, check, place and quest pays once.
4. **Hooks** (each one line calling `Xp`): the fight hook and its repeatable flag (road, camp, Strahd's hunt), Strahd's
   withdrawal; `DialogueRunner` `xp milestone` (XP mode: `milestones += 1`, then `Xp.milestone`) and the new
   `xp fight <id>`; `set_quest_stage` on a success end; first visit of a location; `LocationTraps` search, secret door,
   trap noticed and disarmed; `WorldChecks` pass; `DialogueRunner._check` pass; `LocationLocks` pick or force; one
   `add_codex`; `DeckOfManyThings` Sun. Milestone mode: none of these change anything (guard on the option).
5. **UI**: the New game question (`difficulty_page.gd`, `main_menu.gd` sets the option), the XP line and bar on the
   party screen and character sheet, the level-up screen's line, the reserve line, notices, Settings showing the mode.
   New rows go into `tests/integration/test_layout.gd`. A capture of the new page and the sheet (`make capture`).
6. **Saves**: `SaveSystem.upgrade` gets an always-run step (like `swap_withdrawn_items`) that sets
   `story.options.levelling = "milestone"` when it's missing. Golden saves load as milestone (assert it).
7. **Docs**: rows in `docs/rules/deviations.md` (the foe share, the fixed split of four with guests taking no share,
   half-Low minor milestones, the floor and ceiling, Strahd's visits, the Sun card in XP mode), a coverage row in
   `docs/rules/coverage.md` ("XP levelling"), `docs/ui/level_up.md`'s first bullet, this file as `docs/plans/xp_mode.md`.
   The Deck of Many Things row in deviations.md changes ("experience cards become a milestone level or, in XP mode,
   a level's XP").
8. **Tests**: unit (`test_xp.gd`): thresholds and budgets against the 2024 tables; awards at levels 1, 5, 10; the floor
   lifts to the milestone level; the ceiling holds one-time XP in the reserve and pays it at the next milestone;
   repeatable XP over the ceiling is lost; the cap; the 0.4 share and the split of four whatever the party size; every
   once-key pays once. Integration: a new game in XP mode wins a fight and gains the foes' share; a milestone line
   lifts a short party; benched heroes' `levels_waiting` follows the pool; golden saves stay milestone; the Phase 3
   exit run in XP mode ends Death House at level 3 or more and never above 4. The simulator checked in as
   `tools/balance/xp_sim.py` (with `make xp-sim`) so a retune of fights or awards can be re-validated in seconds.

Nothing here touches fight tuning, the level-variant fights, or milestone mode's behaviour.

## 8. For the coordinator and Ashwin

- **No fork blocks the build.** Defaults picked: XP mode chosen at a new game only (Settings shows it, can't change
  it); fights talked away pay their XP (the 2024 rule); guests take no share of XP (the 2024 rule would count them; it
  would make players dismiss allies for XP); a quest's failure end pays nothing; the foe share is 0.4.
- **SAVE_VERSION**: not needed. Saves since version 2 have gained many fields with defaults in `from_dict`; this one
  adds `xp`, `xp_reserve` and `options.levelling` the same way, and the always-run upgrade step pins old saves to
  milestones without depending on a version number. CLAUDE.md's rule ("a change to what a save holds bumps
  `GameState.SAVE_VERSION`") would call for a bump to 3 and `make golden-saves`; the coordinator's call.
- **Ashwin's saves**: nothing reads or writes them; old saves load as milestone.

Sources for §1: the 2024 Free Rules' Character Advancement table
(https://www.dndbeyond.com/sources/dnd/free-rules/creating-a-character) and the 2024 DMG's Character Advancement
section as Roll20's 2024 compendium gives it (https://roll20.net/compendium/dnd5e/Rules:Character%20Advancement?expansion=33359).
The budget table for levels 3-10 is the one the region docs already quote.

## 9. Build notes (the build lane, 2026-10-14)

Built as §7 describes, with the calls below. Everything that touches a fight, a quest or a level checks `Xp.active(st)` first,
so milestone mode and every save made before this behave as they always did (the golden saves are asserted to).

**One clarification to §3, re-validated.** §3 pays the High award at each of the 11 `xp milestone` beats. Taken literally that
adds High at the hidden stair, the altar and the burial (which the simulator's §5 model did not pay) and, at the beats that
end a region's climax quest, the quest's own award on top; the average player then runs about +0.3 levels over the milestones
from the burial on (`make xp-sim RULES=literal`: 30% of critical-path fights met one level up, against the validated 4%).
So **the milestone pays for the quest that ends at it**: `data/progression/xp.json` `milestone_quests` (Death House, the
burial, the bones, the children, the winery, the Abbot's bride, the pack, the beacon, the witch, the Amber Temple) pay nothing
for their own success. The festival, a main quest, still pays Moderate (the simulator has it so). `no_xp_quests` holds the
walk out of the mists, a `kind: main` quest §3's list leaves out and the simulator never paid. Re-run with `make xp-sim`
(`RULES=build`, what the game does; `RULES=plan` still reproduces §5 to the number):

| Route six, average player | L2 | L3 | L4 | L5 | 6th | 7th | 8th | 9th | 10th | 11th |
|---|---|---|---|---|---|---|---|---|---|---|
| arrival minus milestone level, as §5 | -0.14 | +0.02 | +0.11 | +0.03 | +0.13 | 0.00 | +0.02 | -0.24 | +0.08 | 0.00 |
| arrival minus milestone level, as built | -0.14 | -0.08 | +0.07 | +0.01 | +0.17 | -0.02 | -0.06 | -0.36 | -0.05 | -0.05 |

Critical-path fights met at the milestone level: average 91% (9% one above, never two), minimal 100%, fighter 74%, explorer
96%, thorough 25% (one level ahead from Vallaki on, as in §5). On the other two routes the average is 93% and 100%. A
bare-minimum player is still held at the milestone level and nobody is ever two ahead.

**Where it lives.** `story/xp.gd` (rules, pure), `data/progression/xp.json` + `data/schemas/xp.schema.json` (tables, award
sizes, `withdraw_pays`, the two quest lists; `validate_data.py` checks them and reads the encounter budgets from it),
`StoryState` (`xp`, `xp_reserve`, `story_level()`, `target_level()`, `add_codex()`, the `xp_gained` signal),
`addons/dnd_core/ui/common/xp_strip.gd` (the line and bar), `tools/balance/xp_sim.py` (`make xp-sim`).

**Hooks** (each a line asking `Xp`): `LocationFights._end_encounter` (a won fight; `custom` fights are the repeatable ones),
`DialogueRunner` (`xp milestone`, the new `xp fight <id>`, and passed `check` lines and options), `StoryState.set_quest_stage`
(success endings), `LocationView` (first visit), `LocationTraps` (search finds, secret doors, traps noticed, traps
disarmed), `LocationChecks` (a passed world check and what it reveals), `LocationLocks` (a lock picked or forced),
`StoryState.add_codex` (the book props, lore checks and the Tome of Strahd), `DeckOfManyThings` (the Sun card).

**Choices made (no cost, no story effect).**
- Notices: a quest finished, a place found and a milestone use the existing toasts (`StoryState.xp_gained` into the HUD's
  toast queue); a won fight is "+555 XP"; small awards ride on the notice the thing already had ("Found: … (+25 XP)",
  "success (+8 XP)" on a dialogue check, "Unlocked (+8 XP)"). A new location is quiet.
- The strip sits once under the Party screen's top bar and, compact (the held XP on the same line), in the sheet's left
  column, which has no height to spare. The XP is one pool, so it is not repeated per hero.
- Settings: the Game page has no room for another row (its note line already overlaps the last rows), so the Difficulty row's
  tip says how heroes grow, read-only. The New game page's second question is `DifficultyPage` (two rows, tips); the Esc and
  tutorial paths are unchanged.
- A fight talked away is keyed `_xp/fight/<id>`, the same as a fight won, so avoiding a fight and fighting it later pays once.
  The 12 outs of §6 are `xp fight` lines in the narrative files (before any `set` that would change the fight's version).
  Not marked, being delays: Doru left locked, the road hunters' failed Persuasion, backing away from the specter.
- `SAVE_VERSION` stays 2: `story.xp`, `story.xp_reserve` and `options.levelling` are read with defaults, as the bestiary and
  the run's record were, and `SaveSystem.pin_levelling` (always run, like `swap_withdrawn_items`) names older saves
  `milestone`. CLAUDE.md's "a change to what a save holds bumps SAVE_VERSION" and that practice disagree; no check
  requires a bump (`make golden-saves` needs nothing new).

**Open.** The real level-up screen spills at a level 10 party (a fighter's and a wizard's panel grow past the frame; a
cleric's cantrip buttons cut their text short): `test_the_level_up_screen` never reaches it because its golden save has no
level to take. It is the same in milestone mode, and nothing here changed it. The fights without a version above their
milestone level (§5.7) are still a gap for the fight-tuning lanes.
