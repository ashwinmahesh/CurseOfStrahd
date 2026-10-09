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
  worker threads while the cover is up; and once the party is there, the sheets and portraits of the foes of every
  fight still to come whose condition could come true this visit (`keep_foes`, `could_happen`: night and flag fights
  included, other levels' entries and a final battle the cards put elsewhere left out), held until it leaves, so a
  fight doesn't start by reading them. Holding them costs 90 to 270 MB of video memory in the busiest places.
- `world/exploration/npc_routes.gd`: a walking route's legs are searched once per session and with a growing budget
  (the whole-map search per leg was 0.85 s of Vallaki's build).
- `tools/perf/perf_run.py --only transitions [--cover] [--headless]` times each change of place on a route through
  the village, the Death House, Vallaki and the castle.

## The place's name on arriving

Visual Polish Plan 6 (the vault's "Visual Polish Plan.md", 2026-10-09, after Octopath Traveler 2's area names): when no
loading card is up, `enter_location` shows the place's name near the top of the screen as it fades in from black
(`ui/hud/place_title.gd`, `PlaceTitle`): the display face over a gilt rule, rising a little into view, holding, then
fading away. A card names the place itself, so a new region or a slow change of place shows the card and never the
title over it (`show_for` checks for a `LoadingCard` under the game root). A journey's arrival (`_arrive`) puts the hour
beneath the name instead of the old toast (the toast still says both when a card was shown). It sits over the HUD
(layer 20) and under the menus, the fade from black and the card; it never takes a click, makes way at once for a
conversation or an arrival picture, shows one name at a time, and like the card never shows in headless runs or still
captures without `--motion`.

    make capture SCENE=res://tools/capture/place_title_capture.tscn NAME=place_title FRAMES=10 ARGS="--motion"
