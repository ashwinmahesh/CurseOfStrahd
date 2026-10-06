# Travel map, minimap and ways out

Owner ask (2026-10-06): the map screen should look like a real map, there should be a minimap of the current area in
the top right of the HUD that moves with the party, and the ways out of an area to another region should be obvious.

## Travel map (`ui/screens/travel_screen.gd`)

- The art is one illustrated parchment sheet of the whole valley, `art/ui/map/barovia.png` (2528×1696, 3:2, generated
  at 2K; manifest id `travel_map_barovia`). It has no roads and no text: the game inks the known roads and the place
  names on top, so they stay sharp at any zoom and only show what the party knows.
- The map panel is 1152×768 at zoom 1 (the whole valley). It opens zoomed in on the known places (at most 1.6×);
  the wheel zooms up to 2.4×, dragging pans, and the art always covers the panel. A click on a place picks it.
- A place's `pos` in `data/travel/barovia.json` is a fraction of the art (x right, y down). Put new places on their
  landmark in the art:

| Landmark on the art | pos |
|---|---|
| Gates of Barovia (the two knight statues) | 0.93, 0.50 |
| Village of Barovia (between its two clusters of houses) | 0.775, 0.51 |
| Ivlis Crossroads (the gallows by the river) | 0.64, 0.53 |
| Tser Falls (the pool at the foot of the falls) | 0.60, 0.44 |
| Tser Pool (the dark pond among the Vistani wagons) | 0.53, 0.49 |
| Vallaki (the walled town on the lake shore) | 0.32, 0.48 |
| Castle Ravenloft (on its pillar of rock) | 0.695, 0.73 |
| Walled hill town at the far left (Krezk) | 0.075, 0.51 |
| Small village with a church, upper left (the abbey, or another hamlet) | 0.07, 0.36 |
| Ruined mansion, top centre (Argynvostholt) | 0.455, 0.23 |
| Windmill on a hill, upper right (Old Bonegrinder) | 0.69, 0.24 |
| Wayside cross on the road east of Vallaki | 0.42, 0.48 |
| Lake Zarovich (middle of the water) | 0.22, 0.39 |

  Keep places between 0.05 and 0.95: the mist covers the edges (a test checks it).
- Roads are drawn as dashed ink with a slight bow; the chosen route is solid crimson with each leg's hours on a tag.
  The party's place has a pulsing crimson mark; the destination's name sits on a crimson plaque. At night the sheet
  gets a moonlit wash.

## Minimap (`ui/exploration/minimap.gd`)

- Top right of the exploration HUD, above the location's name and the clock; hidden with the HUD in combat and
  conversations, so it never covers the combat HUD.
- Drawn from the location's grid rows (16 px a square, mipmapped, shown at 9 px a square): open ground in parchment,
  `#` as trees in the wilds, roofs in towns and walls indoors, with an inked edge; low cover, rough ground and water.
  Doors are drawn as they stand now; a secret door nobody has found shows as wall.
- North up, centred on the leader's token. Marks: the party (the leader in gold), guests, people here, doors into
  buildings (small lamps) and roads to other regions (gold arrows; on the rim pointing the way when beyond the
  edge; pewter while shut). A pale wedge shows which way the camera looks. The wheel zooms (6 to 16 px a square)
  and a click walks the party there.

## Ways out (`ui/exploration/exit_signs.gd`)

- A way out is a road to another region when it leads onto the travel map or, from outdoors, to another outdoor
  location. Doors into buildings are left to the hover hint and the minimap.
- Each road out gets a glowing square, three chevrons on the ground marching toward it and a plaque with its label
  and destination ("Into the village · Village of Barovia"; a road onto the map says "Opens the travel map"), with
  an arrow pointing off the map. Shut ways are drawn dim and say "not yet". An open way out that's off the screen
  gets a smaller plaque at the edge of the play area (clear of the party cards, the minimap, the Narrator and the
  buttons), its arrow pointing toward it.
- It's a screen-space overlay on the HUD layer, so it stays crisp, the palette pass never touches it and it sits on top
  of whatever the world assets put at the exit. Ground marks stay off squares where the party stands.
