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
- `ui/screens/loading_card.gd` (`LoadingCard`): the card, `picture_for(region)`, `tips()`, `show_for(parent, loc)`.
- `world/game_root.gd`: `enter_location` shows the card when the region changes (`_card_region`).
