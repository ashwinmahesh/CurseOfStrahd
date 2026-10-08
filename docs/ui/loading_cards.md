# Loading cards

Date: 2026-10-08 · Improvement Ideas G5, lane 20 (Story presentation). No new art: the pictures are cutscene stills.

## What the player sees
Arriving in a new region (and when a game starts or loads), the screen shows that region's establishing picture, the
place's name over it and one tip, while the place settles in behind. It fades after about two and a half seconds, or at
once on a click or any key. Walking between places in the same region shows nothing. With motion off (headless tests,
still captures) no card is shown, so tests and screenshots see the place itself.

## Data
`data/loading/cards.json`: `regions` maps a region to a picture id in `art/cutscenes/` (the cutscene stills, chosen
from scenes the party sees on arrival anyway, so nothing is spoiled), `default` covers regions with no picture of their
own (the castle above the village), and `tips` are short lines in our own words, each checked against the game's
controls (core/input_actions.gd, world/game_root.gd).

## Code
- `ui/screens/loading_card.gd` (`LoadingCard`): the card, `picture_for(region)`, `tips()`, `show_for(parent, loc)`,
  and `cover(parent, loc, hold)` with `lift()` for a card that waits for the place to be built (and goes after
  `MAX_COVER` seconds whatever happens).
- `world/game_root.gd`: `_covered(to, change)` makes a change of place behind the cover (`CARD_MS`, `took_ms`,
  `expected_ms`); `enter_location` stays synchronous and still shows the card itself when the region changes outside a
  cover (`_card_region`).
- `world/exploration/place_preload.gd` (`PlacePreload`): the party's and the place's people's sprite sheets read on
  worker threads while the cover is up.
- `world/exploration/npc_routes.gd`: a walking route's legs are searched once per session and with a growing budget
  (the whole-map search per leg was 0.85 s of Vallaki's build).
- `tools/perf/perf_run.py --only transitions [--cover] [--headless]` times each change of place on a route through
  the village, the Death House, Vallaki and the castle.
