# Travel map, minimap, ways out, hidden areas, traps and pits

Owner ask (2026-10-06): the map screen should look like a real map, there should be a minimap of the current area in
the top right of the HUD that moves with the party, and the ways out of an area to another region should be obvious.

## Travel map (`addons/dnd_core/ui/screens/travel_screen.gd`)

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
- Which places show (owner decision 2026-10-06, "next stop"; `Travel.known`): places the party has been, places one
  open road from there, and places it has heard of (their `when` holds). A place with no `when` is common knowledge
  only once the party is one road from it; a place with a `when` waits for it, however close. At the gates that's
  the gates and the village; from the village, the crossroads; and so on. The story bot travels the same way, hop
  by hop toward a place it can't see yet.
- Mist covers the rest of the art (addons/dnd_core/shaders/ui/map_fog.gdshader): the land around known places and along known roads
  is clear, and so is the land between them (the known places' outline, widened a little); Castle Ravenloft is seen
  from everywhere in the valley. A place the party doesn't know yet keeps a soft patch of mist over its picture, so
  the land between doesn't give it away. With every place known the whole valley is clear (owner report 2026-10-12:
  a fully explored map was still fog between the places), with only a soft mist at the art's very edge. A place's
  optional `reveal` (a fraction of the art's width, default 0.065) sets how much land clears around it; Lake
  Zarovich, Berez and Mount Baratok clear more. The clearings' edges drift like mist.
- Roads are drawn as dashes with a slight bow; the chosen route is solid red with each leg's hours on a tag.
  The party's place has a pulsing crimson mark; the destination's name sits on a crimson plaque. At night the sheet
  gets a moonlit wash.


## The local area on the map screen (Ashwin, 2026-10-25)

"When you open map there should be a toggle for local area map which shows the full area map with exits named (where they
go)." Wherever the party is in a place (`TravelScreen.area_view`, set by `GameRoot.open_travel`), a toggle at the top of the
side panel switches the map between **Barovia** (the valley, above) and **Local area** (`addons/dnd_core/ui/screens/area_map.gd`):

- The whole place the party is in, drawn from its grid in the minimap's own picture (`addons/dnd_core/ui/exploration/map_image.gd`, which the
  minimap shares), fitted to the panel. The wheel zooms up to 5x the fit and dragging pans; squares behind a secret door nobody
  has found stay dark, as on the minimap.
- Each way out is marked where it is (a gilt arrow off the edge for a road out, a diamond for a door or a gate; pewter while
  it is shut for now) and named on a plaque: what it is, and under it where it goes ("Church", "-> Village Church"; a road that
  opens the travel map says "The map of Barovia"; nothing when the name already says it). Ways out of one name side by side
  (a gate two squares wide) are one plaque. The named parts of the place (`areas` in the location's data) are written faintly
  across it where they are clear of the marks and plaques. The party is marked: the leader a gilt dot with a slow ring.
- The side panel lists every way out (a button each, with the same two lines and "shut for now"); pointing at one, or
  focusing it with the pad, lights it on the map, and a click on a mark or plaque lights it in the list.
- The choice is kept (`GameSettings` "map_area") for the next map opened to look (M); a map opened to set out always opens on
  the valley, where the places are. With no place under the party (the title's screens, tests) there is no toggle.
- The pad: LB/RB (the toggle's tabs) or the D-pad to the toggle switch views; on the area the D-pad steps from way out to way
  out, A lights one, LT/RT zoom, the right stick pans.
- Code: `AreaMap` draws and takes the mouse; `TravelScreen.set_area_mode` and `_show_area_info` hold the two views. Tests:
  `tests/integration/test_area_map.gd`, the pad in `test_pad_screens.gd`. Capture:
  `make capture SCENE=res://tools/capture/area_map_capture.tscn NAME=area_map FRAMES=10` (`ARGS=--locations=a,b`).

## Minimap (`addons/dnd_core/ui/exploration/minimap.gd`)

- Top right of the exploration HUD, above the location's name and the clock; hidden with the HUD in combat and
  conversations, so it never covers the combat HUD.
- Drawn from the location's grid rows (16 px a square, mipmapped, shown at 9 px a square) in gothic tones: grey
  ground outdoors with `#` as dark pines in the wilds and blood-dark roofs in towns, dark planks and black walls with a
  gilt edge indoors;
  low cover, rough ground and water.
  Doors are drawn as they stand now; a secret door nobody has found shows as wall.
- Turned with the camera (owner ask 2026-10-12): up on the minimap is the way the camera looks, and an N on a crimson
  stud rides round the rim pointing north. Centred on the leader's token. Marks: the party (the leader in gold), guests, people here, doors into
  buildings (small lamps) and roads to other regions (gold arrows; on the rim pointing the way when beyond the
  edge; pewter while shut). A pale wedge shows which way the camera looks. The wheel zooms (6 to 16 px a square)
  and a click walks the party there.

## Ways out (`addons/dnd_core/ui/exploration/exit_signs.gd`)

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

## Hidden areas (`addons/dnd_core/world/exploration/hidden_areas.gd`)

- Owner ask (2026-10-06): rooms the party hasn't discovered stay out of sight, in the level view and on the minimap.
- A hidden area is every square that can't be reached from the location's spawns (or where the party stands) without
  going through a secret door (`secret_dc`) nobody has found yet; ordinary doors count as open. Its walls are hidden
  too, except those that also face a square in sight, so the wall the secret door is set in stays. Nothing in the
  data marks an area hidden: drawing a room behind a secret door is enough.
- In the level view its floor, walls, furniture, props, containers, lights and people aren't drawn, and hovering or
  clicking there finds nothing. The minimap leaves it dark (no doors, people or ways out drawn there), and ways out
  inside it get no markers. When the door is found (searching), the room fades in over 0.6 s and comes onto the
  minimap.
- The rules grid is never changed; LocationView adds the HiddenAreas node at the end of `_ready` and asks it in
  `thing_at`.

## Traps (`addons/dnd_core/world/exploration/trap_sight.gd`)

- Owner playtest (2026-10-06): a found trap showed as a red box hiding whatever was there, and traps were only noticed
  within 10 ft.
- A found trap shows its own piece on each of its squares (art/sprites/props, sheets `trap_floor_a` and
  `trap_floor_b`: wolf_trap, broken_boards, spiked_pit, tripwire, floor_glyphs, floor_crack, soot_patch,
  blade_slits; plus the existing ice_patch and snowdrift), picked by a word in the trap's id or label, or by an
  optional `model`. A square that already has a prop (Victor's rune circle) keeps it. Round the squares runs a red
  dashed border just inside their edges, so nothing is covered; the minimap rings noticed traps in red. A trap with no
  piece that fits (a statue's gaze, a chandelier overhead) gets the border alone. Disarming or springing it takes it all
  away.
- Owner playtest (2026-10-08): traps fire when walked onto and nothing disarms them on its own; they stay hidden
  without an explicit Perception check; the party doesn't walk round them; a right-click sets one off, from within
  5 ft. So: nothing is noticed passively. A trap shows nothing at all until a Search (the leader's Wisdom (Perception)
  check, 15 ft; the squares it reached tint the ground for a moment and fade), Find Traps or a Wand of Secrets finds it.
  Paths go straight over a found trap, and stepping on a trap springs it, found or not. Right-click a found trap for
  Set it off (enabled within 5 ft of it, or standing in it: whoever stands in its squares takes it, else it goes off
  on nothing) and Disarm (thieves' tools, the player's choice). A spent trap loses its marks; an open pit stays shown
  and is walked round.
- A trap that goes off on someone (owner todo, 2026-10-17) shows it once the big d20 has been seen: the figure flashes,
  the trap's own effect plays on them (fire, lightning, blades, needles, a falling beam or floor: docs/art/spell_effects.md
  "Traps and falls"), the damage floats over their head as in a fight, and their card on the left shows the new Hit
  Points (it kept the old value until something else refreshed the panel). A pit's fall and its stakes are one number; a
  climb, swim or ritual that fails and hurts does the same.
- A hero a trap throws Prone shows the tag in the party panel and lies there for a couple of seconds, then gets up on
  their own (free: there is no turn to spend standing, docs/rules/deviations.md); the party moving on or acting
  (a step, a menu choice, a Search) stands them at once, and so does a fight starting. A pit's victim climbs out
  instead; a hero at 0 Hit Points waits for healing. Any other condition a trap gives (Poisoned, Frightened...) is a
  lasting effect that runs out with the clock (the trap's `condition_minutes`: a minute for Frightened, ten for
  anything else), in a fight too; it used to stay on the hero for good, long rests and all
  (`EncounterTraps.give_condition`, `LocationCare.stand_up`).
- A noticed trap's border also shows through a wall in front of it as red hatching (addons/dnd_core/shaders/world/xray_mark.gdshader),
  so a trap in a one-square passage still reads from the diagonal camera.

## What was just found (`addons/dnd_core/world/exploration/found_glow.gd`)

- Owner ask (2026-10-13): "When we find something via a perception check, give that thing a glowing orange outline
  so we know what was discovered."
- A hidden find (a search prop), a secret door or a trap that comes to light gets an orange outline
  (`addons/dnd_core/world/look/found_outline.gd`): on a 2D piece, a line hugging its picture with a dark hairline beyond it and a soft
  glow (addons/dnd_core/shaders/world/found_outline_sprite.gdshader, drawn as the sprite's overlay on a quad grown past its edges);
  on a 3D piece, an orange rim over its surfaces and a line round its silhouette (found_rim.gdshader,
  found_outline_mesh.gdshader). A trap's own pieces glow, not its red border (the border alone when it has no piece).
  Orange (candle warmed toward flame, its glow candle) so it isn't the gilt hover glow, a spell area's pale gold edge
  or a fight's rings; drawn after the screen pass, so the classic look's palette snap and ink leave it as it is.
- It pulses as the thing is found (2.4 s), then stays as a steady outline until the party uses the thing (opens it,
  takes it, tries its lock, disarms it: LocationInteraction tells it) or deals with it some other way (the door opened,
  the find taken, the trap sprung or disarmed), or leaves the place. Things found on an earlier visit, or before the
  party got here (a place hint), don't glow. A fight puts the glow away; it comes back after.
- FoundGlow watches the place's `found` and trap states rather than each way of finding, so a Search, a check's
  `reveal`, a conversation and a spell all light what they turn up.

## Pits (`addons/dnd_core/world/exploration/pit_fall.gd`)

- Owner playtest (2026-10-07): the Death House crypt passage's pit is a 10-foot drop, so show the hole and let the
  party climb out; any other pit trap the same way. A trap with `pit_ft` is a pit that deep, and every pit trap has
  one (a test checks any trap that speaks of a pit, a shaft or an oubliette): the Death House crypt passage
  (`passage_pit`, 10 ft, the book's depth) and Castle Ravenloft's open cell N4 (`larders_open_cell_pit`, 40 ft,
  inferred from its 4d6 fall). Falls that leave nobody in a hole stay ordinary traps: rotten floorboards and a beam
  you go through to the knee or waist, the spire's broken step onto the stair below, Argynvostholt's gallery, Old
  Bonegrinder's chute (you come out at the millstone) and the Amber Temple's snow cornice (you catch the rock).
- Found or sprung, the board shows it in 3D: the floor gone, stone sides going down, pale stakes at the bottom, a pale
  lip round the edge with the red border just outside it, and the slab that covered it propped up (found) or hanging
  down inside (sprung). The cut-away walls within two squares come down to their footing so the camera can see in;
  they go back up if it's disarmed. Unnoticed, it shows nothing, as before.
- Springing it: the trap's saving throw. A success catches the edge. A failure falls in: 1d6 bludgeoning per 10 ft
  (2024 falling) plus the trap's own damage (a pit whose own damage is bludgeoning already counts the fall), Prone,
  and at the bottom (the figure goes down; the ring and labels
  stay at the edge, since the camera can't see the bottom of a 10-foot shaft). Who's in a pit is saved with the
  location.
- Climbing out (right-click the character, or click to walk with them leading): with a rope anywhere in the party,
  no check; without one, a DC 15 Strength (Athletics) check, a minute a try. Someone at 0 Hit Points needs the
  rope. The party doesn't drag anyone in a pit along; an open pit is walked round, or jumped where it fills a
  passage.

## Who to talk to (`addons/dnd_core/ui/common/quest_guide.gd`)

- Owner ask (2026-10-12): for the tracked quest, the person to talk to is green on the map, and the journal shows who
  it is.
- QuestGuide finds the people whose conversation, as things stand, moves a quest on from its current stage: from each
  person's dialogue entry in the locations' `npcs`, it walks the dialogue the way DialogueRunner plays it (`if`
  blocks and option conditions checked against the story now, options for party members who aren't there left out,
  both ways of a check) and looks for a `quest <id> <later stage>`. Nothing new in the data: it reads the dialogues
  as written. Conversations at camp don't count; only people standing somewhere do.
- Minimap: the tracked quest's people here get a bigger green mark (on the rim, pointing the way, when off the edge),
  looked at once a second.
- Travel map: a place where one of them is gets a green ring round its mark, and the side panel says "Talk to <name>
  here (tracked quest)."
- Journal: every open quest's card shows "Talk to" with the portrait, name and place of up to three of them.

