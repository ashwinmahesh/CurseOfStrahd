# Weather (F12, world half)

Barovia's weather is world state: `story/weather.gd` reads data/weather/barovia.json. Fights (obscured squares, Call
Lightning's storm) are lane 2's half and read the same `Weather.now(st)`.

## How it's chosen

Each region has a climate (`regions`; anywhere else is `default_climate`). The weather holds for a six-hour spell
(00-06, 06-12, 12-18, 18-24) and is picked from the climate's weights by the playthrough's seed, the climate and the
spell, so it needs no saving and a reload never changes it. Strahd's attention (F9) multiplies the storm weight
(`storm_by_attention`: marked ×1.5, hunted ×2).

| Climate | Where | Overcast | Fog | Rain | Storm | Snow | Blizzard |
|---|---|---|---|---|---|---|---|
| valley | everywhere else | 4 | 3 | 3 | 1 | | |
| highland | Krezk, the Abbey | 4 | 2 | 1 | 1 | 3 | |
| mountain | Tsolenka Pass, Mount Baratok, the Amber Temple | 2 | 2 | | | 4 | 2 |
| castle | Castle Ravenloft | 2 | 3 | 3 | 3 | | |

## What it does

| Kind | Journeys | Roads (day / night) | Sight in the open |
|---|---|---|---|
| Overcast | | | |
| Fog | | +5% / +5% | Lightly Obscured |
| Rain | | | |
| Storm | ×1.25 | / +5% | Lightly Obscured |
| Snow | ×1.25 | | |
| Blizzard | ×2 | | Lightly Obscured |

- **Journeys** (Travel.route): each leg takes longer by the weather where it sets out.
- **Roads** (Travel.roll): added to the table's chance, with Strahd's attention.
- **Sight** (outdoor locations, outside fights): Disadvantage on a Search (LocationTraps) and -5 to passive Perception
  for noticing traps (TrapSight). docs/rules/deviations.md has the rows.
- **People**: anyone's `when` can read `weather == storm`; the townsfolk who walk the streets go in during a storm.
- **Seeing it come**: in an outdoor location LocationClock narrates each change (a kind's `line`).
- **Open flames** (a kind's `flames_out`: storm, blizzard) are data for the fight half and the look; exploring doesn't
  put out the party's light yet.
- **The look** is lane 6's: Atmosphere dresses a place's mood from `Weather.dress_mood` (the world's rain or snow in
  place of the mood's own, fog thickening the mist), which drives the world_wet and world_snow shader globals.
