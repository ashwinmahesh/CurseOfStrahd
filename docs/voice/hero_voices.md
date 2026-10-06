# The custom hero's voices — voice bible

A player-made character who takes one pregenerated companion's place (docs/ui/character_creation.md, hero mode).
Speaker ids `hero_female` and `hero_male`; the player's pick is stored on the character as `build.appearance.voice`,
and a custom character is marked by `build.appearance.custom == true`.

## What they say

The hero has no lines of their own name. They speak the party lines any character matching their build could say:
interjections and banter chosen by `class:`, `background:`, `species:` and `tag:` selectors, and `Player:` lines
when they speak for the party. So every such line needs a clip in both hero voices (the voice thread records party
lines in every voice that could say them).

## How they sound

- **hero_female:** a woman in her late twenties to thirties, a warm, clear mid-range voice with a neutral,
  unplaceable accent (an outsider to Barovia, like the pregens). Steady and adaptable: it has to carry a blunt
  soldier's line, a pious one and a cheeky one equally well, so no strong personality of its own; dry rather than
  dramatic.
- **hero_male:** a man of the same age, a warm baritone, the same neutral outsider's accent and the same
  steady, adaptable delivery.

## Sample line (the creator plays it when the voice is picked)

"I came into this valley by my own road. I mean to leave it by the same one."
