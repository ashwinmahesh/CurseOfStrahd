# Skirmish, the Character Lab and the encounter editor (N1, N9)

Status: built 2026-10-07 (lane 18 of Improvement Ideas.md) · not yet seen by the owner
Code: `skirmish/` (rules side: `SkirmishSetup`, `HeroLab`, `SkirmishLibrary`, `SkirmishState`), `ui/skirmish/`
(`SkirmishScreen`, `MapSketch`, `SkirmishResults`), `world/combat/combat_arena.gd` (`CombatArena.skirmish`),
`world/combat/skirmish_field.gd`, `story/fight_tally.gd`. Scene: `scenes/skirmish.tscn`.
Capture: `make capture SCENE=res://tools/capture/skirmish_capture.tscn NAME=skirmish FRAMES=10`.

## What it's for

Testing any build against any monster outside the story: a party of up to four at any level from 1 to 20, any of the
125 stat blocks, any map, then a fight in the real combat view.

## The screen

From the title's **Skirmish and Character Lab**. One frame, four tabs, and the fight's summary on the right (map,
heroes, foes, XP and the 2024 DMG difficulty, **Fight**, Back to the title). The setup stays as it is between visits
and after a fight.

- **Party.** Up to four heroes. Add one at a chosen level: a pregen (its own level plan to 11, the Lab's picks after
  that), a quick hero of any class (the class's recommended scores, background and skills, Human), or one made in the
  hero creator (joins at level 1). Choosing a hero opens the **Lab**: its level one at a time or straight to 1, 3, 5,
  8, 11, 15 or 20 (each level the Lab took can be taken back; a pregen is rebuilt at a lower level), the next level by
  hand on the game's level-up screen (multiclassing too), the sheet and inventory screens, and every item to give
  (a template such as a +1 weapon or a Flame Tongue goes on the weapon or armor the hero holds; weapons go in hand,
  armor and worn items are put on, and items are attuned while a place is free).
- **Foes.** The stat blocks by Challenge Rating with a search; click to add one, up to 20.
- **Field and the encounter editor (N9).** The Phase 2 arena or any location's map, drawn from above with everyone's
  start, day or night outdoors, and who is surprised. The sketch is the editor: choose a stat block from the list
  beside it and click squares to put foes there, or click anyone and then a square to move them; right-click takes a
  foe away or sends a hero back to a filled-in start. Squares that can't be used say why on hover and on a click
  (walls, low cover, water, the place's furniture and doorways, someone already there, a big creature that won't
  fit on one level). Anyone not placed starts where it's filled in, drawn fainter: the party round the place's way
  in, the foes about ten squares off across open ground. Pin everyone keeps the filled-in squares; Clear the squares
  fills them all in again. Doors stand open.
- **Saved.** Save under a name (the same name replaces it), load or delete. Files are JSON in `user://skirmish/`.
  **Use its fight** takes a saved fight (map, hour, surprise, foes and their squares, and the heroes' starting
  squares by order) for the party you have.

## The fight and after

The combat arena scene plays the setup on its map, dressed as the place (its mood, furniture, lamps; the party's
lantern after dark). The Lab's picks (`HeroLab.fill_choices`) prefer legal options without warnings, the 2024 core
books' over others, the Ability Score Improvement feat where a feat is offered, and the highest scores for increases.
When the fight ends, Space goes on to the results: each hero's and foe's damage dealt and taken, kills, Critical Hits,
hits and misses, natural 20s and 1s and falls (read from the combat log by `FightTally`), then Fight again (fresh
dice), Change the setup (Esc), or Back to the title.
