# Hidden nods and hidden achievements (the easter-egg plan, 2026-10-18)

Status: package E1 built 2026-10-18 · not yet seen by the owner. Each later package adds its own section below, so the
appends don't collide. Every nod is a wink in our own words: no outside name, quote, art or sound goes into the game,
and nothing sits in a cutscene, a main conversation or a serious scene. Hidden achievements show as "A secret" until
earned, and there is no setting to switch them off.

## E1: hidden achievements and fight counts

Code: `core/achievements.gd` (the list, `hidden_defs`, `check_story`, `note_fight`, `for_fight`, `for_story_fight`),
`story/fight_tally.gd` and `story/run_stats.gd` (the counts), `combat/object_fire.gd` (the burst counters),
`ui/screens/achievements_panel.gd` (draws what `Achievements.all()` hands it), `world/game_root.gd` (`_refresh` calls
`check_story`). Data: `data/achievements/<package>.json` (schema `data/schemas/achievements.schema.json`),
`data/flags/eggs_engine.json`. Tests: `tests/unit/test_achievements_hidden.gd`. Validator: `tools/data/validate_data.py`
(`achievement_checks`, the engine flags) and `tools/data/story_reach.py`.

### The hidden achievements

One data file per package, so the packages don't collide: `{"id": "<package>", "achievements": [{id, name, text, hidden,
when}]}`. They come after the sixteen in `Achievements.LIST` and before the endings' own. `Achievements.all()` hands a
hidden, unearned one out as `Achievements.HIDDEN_NAME` ("A secret") with `HIDDEN_TEXT` ("Hidden until it is earned."),
so the Achievements panel (and anything else that lists them) can't give one away; once earned the row shows its own
name and how it is earned, with the date. The ending's list and the toast ("Achievement: <name>") name an achievement
only once it is earned. The wiki's achievements page reads `Achievements.LIST` only, so it lists none of them.

A package earns its achievements one of two ways:

- **In code.** Add the id to `Achievements.for_fight` (any fight, Skirmish included), `for_story_fight` (a story fight,
  with the run's counts) or `for_ending`.
- **With a `when`.** A story condition (docs/contracts/dialogue.md: flags, items, quests, visited places...). The game
  calls `Achievements.check_story` from `GameRoot._refresh`, which runs whenever the party's state may have changed, and
  every hidden achievement with a `when` that now holds is earned once and toasted. `make validate` reads a `when`'s
  flags like any condition's (registered, and set somewhere).

An id is unique across every file, `Achievements.LIST` and the endings' `ending_<id>`, and so is a name
(`achievement_checks`). A capture run earns none, as ever.

### The three E1 earns

| Id | Name | Earned by |
|---|---|---|
| `a_little_push` | A Little Push | On a hero's own turn, a foe goes over the edge of a map's open drop (`FightTally`: `pushed_over`). |
| `spark_and_barrel` | Spark and Barrel | One burst barrel of lamp oil hurts two foes or more (`ObjectFire.most_foes_hit`). |
| `knocked_not_killed` | Knocked, Not Killed | Ten foes knocked out with the Knock Out rule over one playthrough (`RunStats` `knocked_out`). |

The first two are earned in any fight, Skirmish too; the third is the run's, so a story one.

### The counts

All read from the combat log once a fight is over, as the rest of `FightTally` is (a fight saved and loaded mid-way
keeps only the log's last 40 lines, as for every stat):

- `knocked_out`: "X knocks Y out (1 Hit Point...)" credits X, when Y is on the enemy side. A knocked-out foe lives, so it is
  no longer also counted as a kill by the hero whose blow came before it (the line comes before the blow's own hit line).
  `RunStats.HERO_KEYS` adds it to each hero's record and the party's totals.
- `pushed_over`: "Y goes over the edge" on the enemy side, credited to whoever's turn the last "X's turn" line says, when
  that is a hero or guest. A shove, a spell's push or a flyer's fall all count. A hero going over, or a push on a
  foe's turn, counts for no one.
- `improvised`: the attack roll of a thrown improvised weapon, its label ending "(improvised)" (a chair, a crate, a stool,
  a thing lying about). A thrown weapon from the ground is thrown as itself and doesn't count.
- `ObjectFire.bursts` and `most_foes_hit` count in the fight's `e.objects.fire`: the barrels that burst, and the most
  enemy-side creatures one burst hurt (a chain of barrels is one burst each).

### Side flags (`data/flags/eggs_engine.json`)

`Achievements.watch` calls `note_fight` when a story fight ends and it sets, in the run's story flags and never cleared:
`eggs_pushed_over_edge`, `eggs_barrel_burst` (any burst, whoever it caught) and `eggs_threw_furniture`. Later packages
read them in dialogue (the camp's banter about a thrown chair, the castle gargoyle that has heard of pushers). The
registry marks them `"set_by": "engine"`: `make validate` and the story-reach walk then count a flag set by the game, and
refuse a dialogue that tries to set one. No save version changes: flags and run stats are free-form already.
