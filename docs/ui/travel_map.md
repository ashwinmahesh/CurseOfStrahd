# Travel map, minimap and ways out

Owner ask (2026-10-06): the map screen should look like a real map, there should be a minimap of the current area in
the top right of the HUD that moves with the party, and the ways out of an area to another region should be obvious.

## Travel map (`ui/screens/travel_screen.gd`)

- The art is the whole valley painted as the land itself in the game's gothic tone (dark moorland, near-black pines,
  grey-green mist rolling in from the edges, the castle in a red glow, after the title art; no paper or parchment),
  `art/ui/map/barovia.png` (2528×1696, 3:2, generated at 2K; manifest id `travel_map_barovia`). It has no roads and no
  text: the game draws the known roads and the place names on top, so they stay sharp at any zoom and only show
  what the party knows.
  Overlay colours follow the rest of the UI: names in vellum with a dark outline, roads as bone dashes, the route in
  bright red on a dark halo, hours on black tags with a gilt edge.
- The map panel is 1152×768 at zoom 1 (the whole valley). It opens zoomed in on the known places (at most 1.6×);
  the wheel zooms up to 2.4×, dragging pans, and the art always covers the panel. A click on a place picks it. Zoomed
  in, only the places in view get marks and names. Names go below, above, beside or at a corner of their mark,
  wherever they're clear of other names, marks and hour tags.
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
| Krezk (the walled hill town at the far left) | 0.075, 0.48 |
| Abbey of St. Markovia (the small village with a church, upper left) | 0.07, 0.36 |
| Argynvostholt (the ruined mansion, top centre) | 0.455, 0.23 |
| Old Bonegrinder (the windmill on a hill, upper right) | 0.69, 0.24 |
| The Wizard of Wines (the vineyard and winery by Vallaki's west wall) | 0.235, 0.54 |
| Yester Hill (the hill crowned with standing stones below Krezk) | 0.152, 0.578 |
| The Ruins of Berez (the drowned village and the hut on a stump, south of Vallaki) | 0.289, 0.663 |
| Mount Baratok (the tallest peak, above the lake) | 0.174, 0.147 |
| Van Richten's Tower (the black tower on an island in a tarn at the mountain's foot) | 0.158, 0.254 |
| The Werewolf Den (the cave mouth above the lake's north shore) | 0.249, 0.239 |
| The Tsolenka Pass (the bridge over the gorge and its guard tower) | 0.374, 0.171 |
| The Amber Temple (the temple front with two amber statues, high on the peak) | 0.411, 0.139 |
| Wayside cross on the road east of Vallaki | 0.42, 0.48 |
| Lake Zarovich (middle of the water) | 0.22, 0.39 |

  Keep places between 0.05 and 0.95: the mist covers the edges (a test checks it).
- Every place so far has its picture on the art. A new one without a picture gets it painted in: a section of the map
  is cut out, Gemini paints the landmark inside a marked circle, and only that spot is blended back into the full art
  (art/generated/map/barovia_{west,north,south}_* are the passes so far). Ask the map thread for it.
- A road can take a `via` list of points (fractions of the art, like `pos`) to go round a lake or a mountain:
  `"via": [[0.2, 0.53]]` takes the Krezk road along the south shore of Lake Zarovich; the roads from Vallaki to the
  werewolf den and Mount Baratok go round the lake's east shore the same way. The map draws a smooth curve
  through them; without `via` a road is a gently bowed line.
- Roads are drawn as dashes with a slight bow; the chosen route is solid red with each leg's hours on a tag.
  The party's place has a pulsing crimson mark; the destination's name sits on a crimson plaque. At night the sheet
  gets a moonlit wash.

## Minimap (`ui/exploration/minimap.gd`)

- Top right of the exploration HUD, above the location's name and the clock; hidden with the HUD in combat and
  conversations, so it never covers the combat HUD.
- Drawn from the location's grid rows (16 px a square, mipmapped, shown at 9 px a square) in gothic tones: grey
  ground outdoors with `#` as dark pines in the wilds and blood-dark roofs in towns, dark planks and black walls with a
  gilt edge indoors;
  low cover, rough ground and water.
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
- A way out inside the map (the abbey's garden gate) gets the square and the plaque but no chevrons or arrow.
- It's a screen-space overlay on the HUD layer, so it stays crisp, the palette pass never touches it and it sits on top
  of whatever the world assets put at the exit. Ground marks stay off squares where the party stands.
