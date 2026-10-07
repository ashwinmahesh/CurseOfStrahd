# Run stats and achievements (N8)

Status: built 2026-10-07 (lane 18 of Improvement Ideas.md) · not yet seen by the owner
Code: `story/fight_tally.gd` (one fight, from its combat log), `story/run_stats.gd` (the run, kept in
`StoryState.run_stats` and saved with the game), `story/achievements.gd`, `ui/screens/achievements_panel.gd`, and the
tally on `ui/screens/ending_screen.gd`. Hooks: `world/game_root.gd` (each story fight, `RunStats.watch`),
`world/combat/combat_arena.gd` (Skirmish results), `ui/skirmish/skirmish_screen.gd` (the achievements button).
Capture: `make capture SCENE=res://scenes/game.tscn NAME=ending ARGS="--ending=strahd_destroyed"` (shots 6 and 7).

## What's counted

Every story fight, when the player goes on from its banner, is read from its combat log (`FightTally`): for each hero,
kills (the last blow before a death), Critical Hits, natural 20s and 1s on any d20 (attacks, saves, checks, Death
Saving Throws), hits and misses, damage dealt and taken, the hardest blow, falls to 0 Hit Points and deaths. The run
adds them up per hero (by character id, so a hero at camp keeps theirs), with fights won, rounds, and the foes defeated
by kind and by creature type. Gold is read at each fight's end and at the ending: what came in between two readings
counts as found, what went out as spent (a new game's 10 gp is the first reading).

## Where it shows

- **The End** lists the achievements the run earned and has **The company's tally**: a row per hero (the party, those
  at camp, and anyone lost for good) with every count, then the road (fights won and rounds, gold found, spent and
  left, the hardest blow, the foes defeated most, the fallen) and every achievement.
- **The achievements button** on the Skirmish screen (above Back to the title) lists all of them, earned ones lit
  with their date. The title has no row of its own for them (it's full).
- A story fight's achievements are toasted as they're earned; a Skirmish fight's show on its results.

## Achievements

Local only, kept in `achievements.json` beside the saves (so test runs keep their own), across playthroughs and apart
from any one save; captures earn none. Sixteen from play (First Blood, Fortune Favours, Deadly Aim, Cursed Dice, Hunter
of the Night, Wolfsbane, Rest in Peace, Overwhelming Force, Not a Scratch, Last One Standing, Not Today, Burgomaster's
Purse, None Left Behind, Proving Grounds, Against All Odds, Dress Rehearsal) and one for each ending
(`ending_<id>`, from data/endings). The list and what earns each are in `Achievements.LIST` and its `for_*` functions.
