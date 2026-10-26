# Atmosphere: how a place looks as a whole

Date: 2026-10-06 · Owner challenge: make the world and its stages look far richer, using what Godot 4 can do.
Owner rules kept: no grain or dither, character sprites stay clear, gothic tone, region exits obvious, hidden areas
hidden until found.

Props, floor and wall textures and their placement belong to set dressing (docs/art/set_dressing.md). This covers
everything around them: light and shadow, mist and fog, water, the land past the map's edge, weather and the colour
grade.

## Where it lives

| Piece | File |
|---|---|
| Each place's mood: light per time of day, mist, clouds, grade, water, weather, land around the map | `art/atmosphere/moods.json` |
| Builds the mood for a location and runs it (sun, sky, contact shadows, water, time-of-day blends, lightning) | `addons/dnd_core/world/look/atmosphere.gd` (`Atmosphere`) |
| The land around the map and over its empty squares: hills, forest, roads and lakes running on | `addons/dnd_core/world/look/atmosphere_land.gd` (`AtmosphereLand`) |
| The Modern look's trees and plants (docs/art/plants.md) | `addons/dnd_core/world/look/flora.gd` (`Flora`), `art/plants/` |
| The Modern look's shaped ground: the walked ground's hollows and ruts, banks under the woods | `addons/dnd_core/world/look/ground_relief.gd` (`GroundRelief`) |
| What lies past the edge when the camera tilts up: the mountains, Castle Ravenloft on its crag, Lake Zarovich | `addons/dnd_core/world/look/vista.gd` (`Vista`), `art/vistas/`, `shaders/atmosphere/vista*.gdshader` |
| The land lane's before-and-after shots: trees and plants, ground, vistas | `tools/capture/land_capture.tscn` |
| Weather: leaves, rain, snow, wisps, dust, crows, chimney smoke, embers, lit windows | `addons/dnd_core/world/look/atmosphere_weather.gd` (`AtmosphereWeather`) |
| Mist, the Mists' wall, cloud shadows, ground patches, grade, vignette, then outlines and the palette snap | `addons/dnd_core/shaders/post/screen_pass.gdshader` |
| Water, forest trees (one MultiMesh), leaves, rain, splashes, motes, crows, smoke | `shaders/atmosphere/` |
| Art QA: a place at each time of day from the game camera, with frame times | `tools/art/preview/atmosphere_preview.tscn` |
| The renderer by graphics preset: anti-aliasing, shadow maps, how many lamps cast shadows | `addons/dnd_core/world/look/graphics.gd` (`Graphics`) |
| The world look's before-and-after shots, with frame times and a cost bench | `tools/capture/look_capture.tscn` |

`LocationView` makes one `Atmosphere` and hands it the camera and the screen pass; `update_daylight()` tells it the
time of day. A mood can be `like` another and change only what differs.

## Which mood a place gets

Most specific first: the location's id in `places`; the longest of `prefixes` its id starts with (the castle's
parts); its region in `regions` (`"<region>"` for its outdoor maps, `"<region>/indoors"` for the rest); its map theme
in `themes` (the same way); else `outdoors` or `indoors`. A new map in a known region or theme gets that mood without
anyone touching this file.

| Mood | Places | What it brings |
|---|---|---|
| `svalich_woods`, `svalich_road`, `crossroads` | the Svalich Woods, the opening road (with the Mists' wall), the crossroads | the base: overcast day, violet dusk, blue night; ground mist, falling leaves; crows at the gallows |
| `barovia_village` | the Village of Barovia | thicker mist in the streets, chimney smoke, lit windows, a few crows |
| `vallaki` | Vallaki | steady rain with splashes, smoke, lit windows, a greyer day |
| `krezk`, `abbey`, `white_sun` | Krezk, the Abbey, the Pool of the White Sun | mountain scree and hillsides, light snow (heavier at the Abbey), a cold grade |
| `high_snow`, `blizzard` | Mount Baratok's ledge road and the Tsolenka pass, the Amber Temple's approach and road | snowfields, a blue-white grade; a blizzard driving almost sideways |
| `baratok_heights` | Mount Baratok (its own place mood; the trail and the pass keep `high_snow`) | the brightest day in the valley: ivory sun against moon-blue shade, thin mist and cloud, snow that lies on a grey or foggy day too (`lying_snow` 0.7: the floor is dark scree and only snow on it makes it white), a rose dusk and moonlit blue night, the land falling away past the edge (`surround.rise` -8: ridges, Van Richten's tower and the Abbey show when the camera tilts to the horizon), smoke at the hut's chimney; its own plant set `baratok` and horizon style (a flora set with no `styles` entry in vistas.json gets the woods' green ridges) |
| `lake_zarovich`, `lakeside` | Lake Zarovich, Van Richten's tower | moving water running on past the map's edge, mist on the lake |
| `berez` | Berez and the marsh track | marsh-mud land, still bog water, green-yellow will-o'-wisps after dark, a bone-coloured grade |
| `tser_pool`, `vistani_camp`, `tser_falls` | the Vistani camps, Tser Falls | sparks over the fires, fireflies; steep hills and thick mist at the falls |
| `wizard_of_wines`, `bonegrinder`, `argynvostholt`, `werewolf_den`, `yester_hill` | those places | rain and crows over the vines; crows over the windmill; a cold dead grade and pale wisps; rock; a sick green grade and many crows |
| `ravenloft`, `ravenloft_roofs` | the castle's gates, overlook and roofs | a storm: hard rain, lightning flashes, crows, the sky of blood at dusk; on the roofs, a gale |
| `ravenloft_halls`, `ravenloft_chapel`, `ravenloft_court`, `ravenloft_spires`, `ravenloft_larders`, `ravenloft_crypt` | the castle's main floor, chapel, Court of the Count, spires, larders, catacombs | candlelit cold halls with dust in the air; a bone-dust chapel; crimson for the brides' court; moonlit spires with lightning at the windows; a sick green below the kitchens; a cold, still mist on the crypt floors |
| `indoors`, `tavern`, `eva_tent`, `chapel`, `crypt`, `cave`, `death_house`, `death_house_crypt`, `amber_temple`, `haunted` | rooms, taverns, Madam Eva's tent, churches, dungeons, caves, Death House, the Amber Temple, Argynvostholt's halls | warm firelit taverns, purple tent light, cold moonlit churches, mist lying on dungeon floors |

## Each region's own look in the Modern finish

The vault's "Region Variety Plan.md" (owner, 2026-10-12: "every place doesn't look the same"). Every mood a region
uses carries a `modern` block, laid over it in the Modern finish only (`Atmosphere._dressed`), so the frozen Classic
look is untouched. In it each region has its own daylight, dusk, dawn and some nights (key and ambient light, sky, far
haze, mist colour and strength), its own shade (`tone`), its own mist shape, its own weather pieces (leaves in its
colours, wisps by day at Argynvostholt) and two new keys:

- `ground_tint`: a surface's texture multiplied by a hex colour for this place (`Look.set_surface_tints`, set as each
  place is built; surfaces the last place tinted go back to white): mossy grass in the woods, straw on the moor, ochre
  at the camps, rust scree at the werewolf den.
- `lying_wet` (beside `lying_snow`): ground that never dries whatever the sky does: Vallaki's streets, the spray round
  Tser Falls, the winery.
- `ground_swap`: the region's own ground in place of a surface on its maps (`Atmosphere.region_surface`, asked by
  ArenaBoard for its floor and raised ground), with `surround.ground` for the land past the edge: moss in the woods,
  leaf litter at Tser Pool and the Vistani camp, heath at Old Bonegrinder and on the moor, tilled earth between the
  winery's vines, shingle on the lake shore, red scree at the werewolf den (the `wild/*` sets, docs/art/textures.md).

The regions: the Mists' edge (today's pale grey, kept on purpose), the woods (`woods`: deep green shade, warm light
through the trees), the village (sepia mud, warm windows), Old Bonegrinder (heath, bruised shade), Tser Pool and the
Vistani camps (autumn and firelight), Tser Falls (spray), the crossroads (gallows violet), Vallaki (wet blue), the lake
(steel blue), the winery (wine-dark), Yester Hill (sick yellow-green), Krezk (high and clear), the Abbey (bruised
steel), Argynvostholt (spectral silver), the werewolf den (rust), Berez (green bog fog), the moor (straw and grey),
the high snow (clearest, pink at dusk), Mount Ghakis (grey rock, `ghakis`), Tsolenka (white-out) and the Amber
Temple's doors (`amber_approach`: a warm glow in the cold). Their plants are art/plants/flora.json's sets of the same
names (docs/art/plants.md). tests/integration/test_region_looks.gd keeps every region's daylight its own.

    make capture SCENE=res://tools/capture/region_capture.tscn NAME=region-variety/after FRAMES=10 \
      REGION_HOURS=12,18 REGION_BEFORE=/abs/folder   # one place per region; the folder holds main's moods.json, flora.json

### Indoors (the plan's part two)

Every indoor place has a look of its own too (41 looks for 59 places; none is left on the bare `indoors` mood): its
`modern` block gives the shade and the fill that lights it in place of the shared moon blue (`tone`'s `ambient_tint`
and `ambient_mix` over `INDOOR_TONE`), the room's light and mist (`times.any`), its motes (`dust` with `indoors`), and
`flame_tint` {colour, mix, energy}: the place's candles, lamps, torches and fires lean to its colour (`_tint_flame`;
the party's lantern, magic and windows keep theirs). `lying_wet` and `lying_snow` now apply indoors in the Modern
finish. The lairs stand out: the dragon's under Mount Ghakis (`dragon_lair`: blood-red shade, embers and glowing ash,
cave rock), the lich's undercroft and drowned library (`drowned`: sick green glyph light, wet floors, slimed brick),
the Eye Below (`eye_below`: amber walls and black stone, gold from below, a violet bruise in the shade). Their floors
and walls are catalog `place_looks` with `keep`, and a dungeon's halls and galleries stay stone (`theme_rooms`).
tests/integration/test_indoor_looks.gd.

## What it adds

- **Light by time of day.** Day is an overcast silver-grey, dusk a low warm sun under a violet sky, night a cold
  moon from the other side, dawn a rose light. The key light moves (long shadows at dusk and dawn). A change of time
  blends over three seconds instead of snapping. Indoors the map's light level (bright, dim, dark) scales it.
- **Ground mist.** A layer over the ground that the view ray is marched through, so it lies in the low places and
  shifts with the camera. It gathers by the trees, over empty ground and in brambles and thins in clearings, on
  roads and over water (a mask built from the map), drifts with the wind in streaks and thin wisps, and comes out in
  three or four flat bands like the rest of the cel look. Lanterns, fires and lit windows light the mist around them.
  Indoors a thin, slow mist lies on dungeon and crypt floors, and the dark around the rooms stays clear.
  Owner report (2026-10-08, lane 28): the mist was there but too thin to see, so the outdoor base now lies lower
  (under head height) and thicker, plain to see by day and in drifting wisps; it lies thick on the roads out of a
  place (mist `roads`), lighter in a town's streets (mist `strength`, Barovia's village and the towns like it), and
  the world's weather scales it (data/weather: fog half as heavy again, rain and storms a little).
- **The Mists.** On the opening road the wall of the Mists stands at the east edge, where the party came in: a flat
  pale wall with an inked, slowly billowing edge, kept a square clear of the map.
- **The land beyond the map.** Ground runs on past the edge and rises into hills, forest thins into the distance
  (the near trees fade like the board's own when they stand in front of the party), the road runs on out of every
  way out, a lake that meets the edge runs on past it, and the far land sinks into the sky colour in flat steps.
  Empty squares inside a map (Krezk's approach, the Abbey's road) are hillside too, unless the mood says they are a
  drop (`"void": "drop"`: the castle's roofs and chasms, Tsolenka's gorge). No tree of the land stands within two
  squares of anywhere people can walk.
- **Water.** In the Modern finish (W14, `addons/dnd_core/shaders/world/lit_water.gdshader`) water deepens smoothly from the shore,
  small ripples drift with the current and bend the light, so the moon and the lamps leave glints on it and the
  reflections waver, the sky's light lies on it more at a glancing angle, soft broken foam laps along the shore, and
  rain rings it in wet weather (W12). In Classic, lakes, rivers, pools and marsh drift in two layers of the water texture, deeper water darker, foam
  lapping along the shore, thin highlight lines riding the current and the sky's light on the surface. Water keeps
  its own colours through the grade (it marks itself in the normal buffer for the screen pass), so a lake never
  turns the colour of the road. A row of the map's frame trees standing across a lake becomes open water (the rules
  still wall the edge off). A mood's water can be still and dark (lane 28, owner report 2026-10-08: "Tser Pool is
  black and perfectly still"): `ripples` (0 for none), `texture` (how much of the water texture's colour shows),
  `reflect` (how much of the sky it shows), and `map` / `map_edge` for its colour on the minimap. The crossroads'
  Ivlis is the colour of strong tea, Lake Zarovich behind the Vistani camp black.
- **Light off the water** (Modern, Visual Polish Plan 12): moving water throws wavering threads of light onto what
  stands beside it, jetties, banks, quays and walls, strongest just above the surface and on faces turned toward it,
  fading within about a square of the shore and a couple of units up (the screen pass's `caustics`, over the water's
  own mask, in the water's glint colour). Still water throws none: a mood's water `caustics` sets the strength, else it's
  `Atmosphere.CAUSTICS` when the water ripples and 0 when it doesn't (Tser Pool). Thick mist (Lake Zarovich at dusk)
  swallows most of it; it shows best by night. The threads are two layers of the screen pass's own ridged noise
  (four noise reads) over a shore mask (`Atmosphere.shore_mask`: one filtered read), about 0.3 ms at 3440 x 1440 at
  the lake under heavy load. `LOOK_OFF=caustics` in look_capture for without.
- **Washing lines.** A mood's `lines` (addons/dnd_core/world/look/washing_line.gd) strings a line between two posts with the week's
  wash pegged out on it in muted palette colours, swaying: Barovia's back yards (lane 28, "an actual village"). With
  `"kind": "bunting"` it is a high festival string of little pennants with no posts, in Vallaki's yellow by default.
  Lines are built outdoors only. Krezk's yards have washing lines too.
- **The Mists on the map.** A `fog_bank` prop (the road out of the Mists, the road east of the village) is a bank
  of soft, camera-facing puffs (addons/dnd_core/world/look/mist_bank.gd, addons/dnd_core/shaders/world/mist_puff.gdshader) in the Mists' grey, not a
  drawn cloud; the screen pass's Mists wall (a mood's `mists_edge`) has a soft, billowing edge with slow puffs of light
  and shade in it and only a faint ink line (lane 28: it read as a flat slab from far out).
- **Smoke at a point.** Weather `{"kind": "smoke", "at": [[x, y, z]]}` puts a chimney plume anywhere: Old
  Bonegrinder's pipe.
- **Waterfalls.** A mood's `falls` (addons/dnd_core/world/look/waterfall.gd) pours a river over an edge: a curved sheet of falling
  water in the place's water colours, white streaks racing down it, foam at the lip and spray at the foot where the
  mist swallows it. Tser Falls has one over its gorge (its empty squares are a drop, `surround.void`).
- **Cloud shadows** drift over the ground; broad light and dark patches break up the ground texture so it doesn't
  read as tiles.
- **Contact shadows** (Godot's SSAO) ground props, walls and houses.
- **Weather**, by mood: dead leaves; rain slanting on the wind with rings where it lands; snow drifting or driving
  in a blizzard; will-o'-wisps and fireflies after dark; dust hanging in shut-up rooms; crows circling overhead;
  chimney smoke bent by the wind; sparks over open fires; candlelight spilling from lit windows after dark;
  lightning flashes in a storm (and through the castle's spire windows).
- **Lightning in the rain** (lane 28, owner 2026-10-09: "in rain, we can also have lightning effects happen sometimes
  (with a lighting change) and associated thunder"). A weather kind's `look.strikes` {"every": [min, max]} seconds
  reaches an outdoor place's mood (Weather.dress_mood): rain strikes every 40-100 s, a storm every 9-22 s; a mood's own
  `lightning` (the storm over the castle) strikes every 7-16 s. A strike (Atmosphere.strike) lights the scene and the
  figures cold for an instant, sky included, flickers once half the time and fades within a fraction of a second; a
  long frame doesn't swallow it. Outdoors a bolt comes down beyond the map's edge in front of the camera
  (LightningStrike, FxKit's jagged beam), and thunder follows: a crack and a roll a fraction of a second after a close
  strike, a lower, softer roll seconds after a far one (art/audio.json `thunder_near`, `thunder_far`, `thunder_crack`:
  the CC0 thunder roll and the CC-BY boom pack). Nothing strikes while a cutscene plays.
- **The world's weather** (lane 4's F12, `story/weather.gd`): outdoors, a place's mood is dressed for the weather
  the world has now (`Weather.dress_mood`: its own rain and snow give way to the weather's, fog thickens its mist), and
  when the weather turns during a stay, `Atmosphere.refresh_weather()` (LocationClock calls it) rebuilds the rain and
  snow and resets the mist and the wet or snowy surfaces at once.
- **Weather on surfaces** (W12, Modern; `addons/dnd_core/shaders/world/weather_surface.gdshaderinc`, the global uniforms `world_wet`,
  `world_snow`, `world_time` and `world_sky` that Atmosphere sets from the mood's weather outdoors): rain darkens and
  glosses everything and its colour deepens, puddles gather in the low places of level ground, ringing with drops and
  holding the sky's light, and the sun and moon leave almost no highlight under rain cloud, so wet stone glistens in
  the lamps; snow settles on roofs, ledges and wall tops even when light, and lies on the ground in drifts that join
  up as it gets heavier (Krezk patchy, the Abbey half covered, the mountains white). A mood's `lying_snow` (0..1)
  keeps that much on the ground in any weather: Krezk, its pool and the Abbey keep a patchy cover when the sky is clear (lane
  28). The party leaves footprints (decals with a dip and, in mud, standing water) where the ground takes them: snow
  once it lies (`SNOW_GROUND`), mud, marsh and bare earth, grass and roads in the rain; a print every `STRIDE`, the
  last `MAX_PRINTS` kept. The pathfinder steers round difficult ground, so prints in mud are rarer than in snow.
- **Grade.** In the Modern finish (W16) the shade takes the place's own cool colour and loses some of its colour while
  lamplight keeps its warm one, so light pools warm against cool, dark shade (the chosen direction: A's effects in
  B's tone): night blue by default, blue-grey on an overcast day, deep night blue indoors; a mood's `tone` gives
  its own (Berez, Yester Hill, crypts and the castle larders sick green, the brides' court crimson, the castle's
  storm bruise purple, a tavern warm peat, the snows moon blue) and can change how much colour the shade keeps, how
  deep its blacks go and how much ambient light fills it (`Atmosphere.MODERN_TONE`, `DAY_TONE`, `INDOOR_TONE`). In
  Classic each time of day maps brightness through its own shadow and light colours, so a scene keeps to one
  family of hues; strongly coloured light (a lantern, a fire) keeps more of its own colour. Greys stay on the grey
  ramp in the palette snap where the mood asks (`keep_greys`), so a pale grey fades without a muddy brown ring. A
  vignette sinks the screen's edges towards `void`.

All of it happens before the palette snap, so it comes out in palette colours with no dithering; every weather piece
is an opaque, hard-edged shape for the same reason. Character sprites draw after the screen pass, so mist never covers
them and they stay crisp. On this Mac, Vallaki in the rain, the castle's storm and the Tsolenka blizzard all hold the capture's 120 fps cap at
1600 x 900 with it on, the same as with it off (`--uncapped --compare`).

## Ground with shape in the Modern finish

Improvement Ideas W11, then Natural Maps plan N2. On every outdoor map (not an outdoor dungeon map: the Amber Temple's
doors, Daern's roof, the tower roofs and the castle's spires keep their built floors, nor a board with no place) the
ground people walk on is drawn as one shaped skin instead of flat squares, with shallow hollows. It never rises above the
squares' floor level and is never deeper than `GroundRelief.DEEPEST`, so tokens, the battle grid and spell templates still
stand on the same 5 ft grid (`floor_y`/`cell_center` are untouched; real heights are F4's), and it settles flat round any
square drawn flat (a prop's, a door's, an exit's, a raised one, water). The board's own floor boxes there stop drawing
themselves (render layers 0; `ArenaBoard.floor_box`, `floor_material`); a trap's square keeps its box, so a pit still
opens it. Under the map's woods (tree squares) the ground rises into banks with mounds on them, and the land past the edge
starts on the banks and settles into its hills. The trees and plants stand on all of it. Paving (cobbles, flags, a
courtyard) and the squares props stand on are part of the skin but flat; towns keep their streets, rooms and the
built floors (boards, tiles, black stone) keep theirs, and Classic stays flat. `GroundRelief.roads()` lays the shortest
walks between a wild map's ways out; the surfaces lane's wheel-rut decals (W10) follow them.

**Blended ground (N2).** The skin and the banks are one mesh (`Ground`) in one material, `Look.blend_ground`
(`addons/dnd_core/shaders/world/lit_world_blend.gdshader`), which draws up to four of the place's surfaces (the most used squares'
floors, the difficult ground and an area's floor among them, and always the woods' bank ground) and melts them into each
other at their edges instead of meeting on a square's: no square tile of mud, drift, flags or bank shows. A control map
(`GroundRelief._control_map`, one texel a square, a channel for each surface) says which surface each square is; the
shader reads it between the squares' middles, so the weights ramp over a square, breaks the edges up with noise (they
wander about a fifth of a square) and steepens them so each surface stays itself over most of its ground. A square of
difficult ground (mud, drifts, litter: the surface whose squares are mostly `~`) must still read as one, so its middle 60%
is always its own surface, and it spills into the squares round it, up to half a square, as natural edges do; every other
square keeps its middle quarter. Each layer is exactly what its square's floor was (the same tile and variants, normal and
ORM maps, tint, way of taking light and macro patches, read off the floor's own material), so a place looks the same where
the surfaces don't meet, and weather (rain, puddles, snow) is the same code as lit_world.gdshader's. Footprints and step puffs
ask the ground what shows at the point they are (`GroundRelief.surface_at`) rather than what the square's floor was.

Hidden until found: the skin, the banks and the map's ground plants leave out squares HiddenAreas hides
(AtmosphereLand's HiddenWatch redraws them when a secret door is found).

A place is built on every arrival, so all of it is worked out on one coarse grid of points (two a square), from
distance fields over flat arrays, and indexed into one mesh; and since a place comes out the same every time, what
a build works out (the land's fields and mesh, the relief and its blend, the trees, the plants) is kept for the newest eight
places and drawn again from that on the next visit. `AtmosphereLand.build_ms` says what each phase took.

    make capture SCENE=res://tools/capture/land_capture.tscn NAME=land/clay FRAMES=10 \
      LAND_SHOTS=crossroads LAND_CLAY=1     # the shaped ground in plain clay; LAND_NO_RELIEF=1 for without
    make capture SCENE=res://tools/capture/natural_ground.tscn NAME=natural/ground FRAMES=10 \
      NG_SHOTS="amber_temple_road:14,6:9"   # a close-up of a place's ground (natural maps plan)

## Natural shores in the Modern finish

(Natural Maps plan N3, `addons/dnd_core/world/look/shores.gd`.) A map's water squares used to be 1 x 1 boxes at -0.18 beside ground at 0:
a pond was a square cut out of the land with a kerb round it, a lake a staircase. In the Modern look the edge of the
water is one smooth contour per place. It is the signed distance from the water squares' outline (positive over the
water), blurred so convex corners round off, moved about by noise seeded by the place (smooth over two squares or so),
and kept near the grid line: out over a water square by up to 0.45 where the water is wide enough to spare it (a
one-square stream keeps its banks), in over a walkable square by up to 0.28, and never nearer than 0.2 to the middle of
a walkable square, so a token in the middle of a square and its ring stay dry and level (the ground there is within a
hair of the floor). A square a build, a prop or a paved floor stands on (not drawn by the shaped ground, or kept flat)
is never reached into. A bank raised above the water (more than 0.35 above the floor beside it) is a pit's rim: Krezk's
pool lies in a 5 ft pit, Van Richten's lake and the crossroads stream have banks too. There the water's edge moves out
into the water squares by 0.65 of a unit of the rim's height above 0.3 (at most 0.8 of a square) and the bank slopes down
over them, from half the rim's height at the grid line (what the natural ground makes of it there) to the water, so the
rim is a rounded slope and not a kerb wall, and the pool looks smaller than its squares by about that much (they stay
water to the rules). Rims higher than 2 units are cliffs (N6) and keep the board's own face.

The ground follows the contour. `GroundRelief` (one line in `_heights`, `shore.lower`) lowers its grid points along it: a
short bank down to the board's water level (`Shores.WATER_Y`, -0.13) at the contour with a slope of 0.9, then a shelf
under the water, so the water plane (the board's own water boxes under the water squares, and a skirt of water under the
walkable squares beside them, `Shores.dress`) meets the ground where the contour says and no kerb shows. The water
squares beside land (`Shores.water_squares`) are drawn by the shaped ground too (kind `SHORE`, in the ground of the
squares beside them), so land can reach out over them. On natural ground the squares beside water, up to a 10 ft bank,
count as rolling with their water neighbours (`ArenaBoard.rolling`, Modern only), which is what lets the skin draw
most shores at all. The water shader's mask (`water_mask`, one texel per third of a square) is made from the contour, so
the shore foam and the depth colour follow it; it is 0 on land and 0.125 at the contour, rising to 1 about 3.5 squares
out. Cosmetic only: water squares stay water and walkable squares walkable to the rules. The Classic look keeps its
squares (`Shores.on()`; `Shores.off` is for before shots).

Worked out once per place (flat arrays over the water's bounding box, kept like GroundRelief's). Checked by
`tests/integration/test_shores.gd`.

## The battle grid in the Modern finish

Natural Maps plan N1 (Ashwin, 2026-10-19: "we don't need to draw our real world maps as a battle grid. It can look like a
real natural map that we just overlay a grid on top afterwards"). The Modern look paints no grid into its ground:
`Look.cel_textured`'s `grid` argument (the faint line round each square on top faces) only draws in Classic, which
is frozen, and `lit_world.gdshader` has no grid at all. The grid is a layer laid over the land instead,
`BattleGrid` (`addons/dnd_core/world/combat/battle_grid.gd`, `addons/dnd_core/shaders/fx/battle_grid.gdshader`, `GridOverlay.lines`):

- **What it is.** One mesh per board, made the first time it is wanted and kept with the board. Every square a creature
  can stand in (not a wall, a tree, water or the void, nor a square of a hidden room) is a patch lying 0.012 above the
  ground a creature stands on (0.03 on natural ground), the four triangles round its middle on a slope
  (`ArenaBoard.corner_height`, so it follows slopes, steps and cliffs corner by corner), and the shader draws a line
  along its border: a pale core with a dark soft edge, never thinner than a pixel, drawn half by each of two squares
  so a crossing is one line deep. It lies under the fight's marks (path, goal, rings, area edge).
- **When.** Ashwin, 2026-10-19: "we don't need to show the grid in combat it is unnecessary ... maybe it could be a
  button the player holds". So by default (*Held*, Settings, Game; `GameSettings.battle_grid`) the lines show while the
  Show the battle grid key is held (`show_grid`, B; Settings, Keys), in a fight and exploring (on a controller, exploring: the names
  trigger held, `explore_grid`, which moves with it in Settings, Keys, Controller; in a fight every button is taken, so the
  radial wheel's last wedge, Battle grid, latches it on until it is picked again, `CombatView._latch_grid`):
  they fade in round the creature whose turn it is (its movement plus two squares, at least 8 and at most 14, fading out
  over the last 2.5; an Invisible foe's turn leaves them where they were, as it leaves the camera; round the party's leader
  when exploring, `ExploreGrid`) and over the whole map while the camera is in the tactical view (O), easing with the
  camera. *In fights* shows them on their own through every fight, *Always* on their own when exploring too, *Never* not
  even held. Classic has none to lay: its grid stays painted in its ground and the setting does nothing there (the row's
  note says so).

## The sky in the Modern finish

Improvement Ideas W13, the sky half. Where the tilted camera looks out past everything (see Vistas below), the screen
pass draws Barovia's sky (`screen_pass.gdshader` `sky_colour`, set by `Atmosphere._apply_sky` by the time of day,
outdoors only): a gradient from the land's haze at the horizon up to the place's sky colour, a low ceiling of cloud
drifting with the mood's cloud wind (never clear: at least 60% cover), lit from beneath towards the moon or the low
sun, and the moon on the key light's bearing, low enough to be seen (`MOON_HEIGHT`), a disc glowing through thin cloud
at night, paler at dusk and dawn, only a brighter patch by day (`MOON_SHOWS`). The mist past everything thins toward
the horizon instead of painting the gaps between far trees, and as the camera tilts the depth blur and the
vignette ease off so the sky and the vistas stay clear. Drawn in the screen pass, so it costs nothing in play, where
the camera never sees above the horizon.

## Vistas in the Modern finish

Improvement Ideas W13, the vista half (owner pick, 2026-10-07: "tilt up when zoomed out"). At its fixed 40° the play
camera never sees the horizon, so past its farthest zoom the wheel tilts it toward the horizon over four more steps
(`CameraRig.horizon`, eased by `horizon_shown`): it comes down to just over the treetops and roofs and its pitch rises
to -8°, so it looks out over the party, low in the frame, to what lies past the map's edge across the top. Zooming
back in undoes the tilt first. Play zoom is unchanged, a distance a tool sets never tilts it, and Classic (frozen)
never tilts.

What it sees (`Vista`, built with the land in the Modern finish, placed from `art/vistas/vistas.json`):
- **The mountains round the valley**: a ring far past the map painted as four ridges by `vista.gdshader`, the
  farthest palest, with light along the crests, snow on the high peaks and a fringe of spruce on the nearer ridges.
  Each set of plants (`art/plants/flora.json`) has its own range: rounded forested hills round the Svalich woods,
  tall snowy peaks at Krezk and the Abbey, white ones by Mount Baratok, low hills over the marsh at Berez.
- **Castle Ravenloft on its crag**, a painted backdrop (`art/vistas/castle_ravenloft.png`, Gemini with
  `art/prompts/vista_preamble.txt`, cut out by `tools/art/build_vistas.py`) at its true bearing from each place on
  the travel art, smaller and deeper in the haze the farther off, its foot sunk in the mist, its lit windows warm.
  Never seen from the castle's own maps.
- **Each region's own landmark** (the vault's Region Variety Plan, 2026-10-12), painted the same way
  (`tools/art/vista_recipes.json`, `python3 tools/art/build_vistas.py [--generate]`): Mount Ghakis with the Amber
  Temple's glow, Mount Baratok, the Abbey on its crag, Krezk on its cliff, Vallaki's palisade, Argynvostholt's beacon
  tower, Yester Hill's stones and tree, Old Bonegrinder's windmill and Van Richten's tower on its island (vistas.json
  `landmarks`). A place sees the nearest four within each one's `within`, never one standing in front of another
  (`Vista.SPREAD`), never its own (closer than `near`: a mountain isn't seen from its slopes).
- **Where the camera looks.** The tilted camera only ever looks along a diagonal (north-east, north-west, south-west,
  south-east), and its frame reaches about 24 degrees either side on a 16:10 screen (27 on 16:9), so a landmark due
  north, east, south or west of a place was never in view. Each landmark and the castle stand where they are when the
  camera frames them there, else turned into the arc it frames round the nearest diagonal (`Vista.IN_VIEW`, 18
  degrees either side), on their own side of it; one that would stand in front of another stands just past it while
  room is left in that arc (`Vista.on_skyline`, 2026-10-13). A landmark's `from` lays a place's own `bearing`, `far`,
  `height` or `sink` over its numbers where that place's map knows better than the travel art (`Vista.seen_from`):
  the Abbey, due north of Krezk on the travel art, stands north-north-east of Krezk and the Pool of the White Sun, up
  the mountain Krezk's track climbs, its crag above the far ridges (owner ask, 2026-10-13; right at Krezk's gate the
  slope hides it), and Krezk south-south-west of the Abbey, down its switchback, lifted a little (`sink` -3) so its
  walls and roofs show over the rim of the Abbey's land, which would otherwise hide a village lying below it.
- **Lake Zarovich** stretching away from the places near it (Vallaki, the lake shore, Van Richten's tower, the
  werewolf den, the Wizard of Wines).

They draw after the screen pass, in a blended pass (`Look.POST_PRIORITY` draws first), so the land's fade into the
haze doesn't swallow them while nearer land, trees and houses still hide them; each frame they take the haze colour the
screen pass gives the far land (`land_color`), so they sit in the same air at every hour. In play they lie past the
camera's far plane and cost nothing; the far plane opens out as the camera tilts. While tilted, leaves and wood within
`near_fade` units of the camera thin away (`foliage.gdshader`, `bark.gdshader`).

    make capture SCENE=res://tools/capture/land_capture.tscn NAME=land/tilt FRAMES=10 \
      LAND_SHOTS=village_tilt,road_tilt,crossroads_tilt,vallaki_tilt,krezk_tilt   # LAND_NO_DOF=1: without the depth blur

Not done: the sky above the ridges is the screen pass's haze until the sky half of W13 (lane 6).

## Edges, shadows and the graphics presets in the Modern finish

The Modern finish (Improvement Ideas W2, W17) sets the renderer by a graphics preset, `Graphics` (Low, Medium, High;
GameSettings `graphics`, High by default; `Graphics.LABELS` for the Settings row), applied as each place opens and at
once when it changes (`Graphics.set_preset`). Classic keeps the renderer it was frozen with (owner, 2026-10-07): no
anti-aliasing, the sun in two splits, no lamp shadows. The bar is 60 frames a second at 1080p on the owner's Mac
Mini (Apple M6) on High.

| | Low | Medium | High |
|---|---|---|---|
| Anti-aliasing | FXAA | SMAA | MSAA 2x and SMAA |
| 3D resolution | 75%, MetalFX spatial upscale (FSR 1 off the Mac) | full | full |
| Sun and moon shadow map | 2048, 2 splits, hard | 4096, 2 splits, soft (PCSS) | 4096, 2 splits, soft |
| Lamps casting shadows (nearest the party) | 2 | 6 | 8 |
| Lamp shadow atlas | 2048 | 4096 | 8192 |
| Shadow filtering | soft low | soft medium | soft high |
| Flames whose shadows sway | none | 2 | 2 |
| Reflections on polished and wet floors (screen-space, steps) | none | 32 | 56 |
| Contact shadows (SSAO) | low, half size | medium, half size | high, half size |
| Characters cast shadows (W6) | no | yes | yes |
| Light bounced off walls (SSIL) | off | off | medium |
| Volumetric haze (light shafts, lamp glow in the air) | off (window cones stay) | 48 cells | 64 cells |

A spatial upscaler on Low, not a temporal one (MetalFX temporal, FSR 2): those work over time like TAA and would
blur and smear the sprites.

**What things cost** (paired on/off timings at 1080p on High, `LOOK_BENCH=pairs`, and the P3 probe's, both with the
Mac under heavy load, so the sizes are rough and the order holds): the sun's shadows are the biggest single cost,
since each split draws the scene's shadow casters again (forest roads most of all: their trees); a level floor square
casting a shadow was a third of the village's frame (they no longer do: nothing stands under one); then the lamps and
their shadows, the screen pass (its mist noise now comes from a texture, 1 to 2 ms cheaper outdoors), MSAA, light
bounced off walls. Contact shadows, reflections, glow, haze and SMAA are cheap.

**Bounce light outdoors (W18, tried and left off).** Godot's real-time global illumination (SDFGI, the only kind that
needs no baking) was tried in place of the screen-space bounce (SSIL) on outdoor maps, 2026-10-07: in the village it
cost about 4.7 ms a frame more at 1080p (paired timing) and on the forest road about the same as SSIL, and the
pictures showed little difference beyond darker tree interiors and eaves. It stays off; `LOOK_SDFGI=1` in
look_capture turns it on to try again (after W17's 60 fps check, or if the land gets big open slopes the screen
can't see round).

**The frame meter.** F3 shows frames a second, the average and slowest frame of the last half second and the preset
in the top left corner, orange when over the 60 fps budget (`FrameMeter`, GameSettings `frame_meter`; Graphics puts
it on the window).

- **Edges.** MSAA smooths 3D edges; SMAA then smooths the ink lines the screen pass draws round them, which MSAA can't
  reach. Neither blurs the character sprites (TAA would).
- **The sun's shadows** reach only as far as the camera sees, in splits packed round the ground in view, so they
  follow the zoom and a square near the party gets about four times the detail it had. The sun and moon have a size
  (`Atmosphere.SUN_SIZE`, Godot's PCSS), so a shadow is sharp where a post meets the ground and softer at its far end.
- **Surfaces** take the light like painted 3D in Modern (highlights, relief, roughness per surface: docs/art/textures.md
  "How a surface takes the light"). The flat sky colour isn't reflected (`reflected_light_source` off): it laid a grey
  sheen over everything; floors reflect what's on screen instead.
- **Lamp shadows.** Lanterns, hearths, braziers, candles, lit windows, the party's lantern and spell lights all can
  cast shadows; every quarter second the nearest to the party get the preset's budget. A light already casting keeps
  its shadow until another is clearly nearer, so shadows don't blink as the party walks, and shadows fade out a
  little past the party. A light with the meta `no_shadow` never casts one.
- **Each light by its kind** (W5, `Atmosphere.LIGHT_KINDS`): a location's lights by their `kind` in its data, lit
  windows from the weather, the party's lantern, flames and spell lights by what they are. Their size sets how soft
  their shadows are (a candle's crisp, a hearth's soft) and how strongly they light the haze; magic lights and windows
  hold steady.
- **Flicker by kind** (Modern; `LightFlicker`, owner's ask 2026-10-09): hearths, campfires and braziers flicker
  hardest, torches nearly as hard, candles gently, lamps, lit windows and the party's lantern barely. Each light
  wavers on its own (a slow swell, a flutter and a fast shiver of smooth noise, each from its own random start, so a
  room never pulses in step) and now and then gutters, dipping fast and reddening as if a draught caught it. Only
  its energy and colour change, never its range, so no shadow map is redrawn for it; and everything it lights flickers
  with it: floors, walls and figures, the light bounced off them, the haze and its glow in the screen pass. Flames
  sway with their flicker too, so the pool of light they throw stirs: every one that casts no shadow (moving it costs
  nothing), and of those that cast one, the nearest few, so their shadows stir (meta `sway`; 2 on High and Medium).
  `LightFlicker.STYLES` holds each kind's numbers. Classic keeps `CandleFlicker`'s old even jitter.
- **Strength by kind** (Modern): hearths throw half again as much light and reach further, candles, lamps and
  torches a little more, and the party's lantern less, so a room's own lights lead (the target frames). Outdoors
  after dark flames burn brighter still (`dark_out`: a fire three and a half times, a torch two and a half, lamps and
  candles half again), or the moon, the sky's fill and the lit mist drown a campfire; they brighten as night falls.
- **Kit and prop flames**: candles and flames modelled into the building kit's pieces (the castle piers' sconces)
  light the room around them; the flames are found in the piece's own mesh (`Atmosphere._light_kit_flames`), and
  floor-level stubs and flames beside the location's own lights are left alone. Likewise the 3D props' fires and
  candles (hearths, braziers, campfires, torches, candelabras: their `flame` and `candle` sockets in
  art/models/manifest.json; `_light_model_flames`), unless the location's own light stands within a square.
- **Soft halos** (Modern, Visual Polish Plan 5): the glow on what burns spreads wide as well as close
  (`Atmosphere.GLOW_LEVELS`: Godot's near level, then two wider and fainter ones), so candles, hearths, lit windows
  and the moon on water wear Octopath's broad soft halo rather than a tight one. About 0.1 ms more than the old glow
  at 3440 x 1440 (`perf_run.py --only effects_fast --effects glow`: 0.8 to 1.2 ms against 0.7 to 1.0).
- **Heat shimmer** (Modern, out of doors; Visual Polish Plan 8): the air wavers above open fires and torches
  (`HeatShimmer`, which `_dress_light` hands each light of kind `fire` or `torch`): a patch of the finished picture
  above the flame is read back and nudged by rising waves (`addons/dnd_core/shaders/post/heat_shimmer.gdshader`), strongest just over
  it and fading out up and to the sides, on a canvas layer over the world and under the HUD. The nearest six fires in
  view shimmer; indoors a hearth's heat goes up its chimney (and the patch bent the wall above it), so rooms get none.
  About 0.03 to 0.12 ms at 3440 x 1440 with a fire in view, nothing otherwise
  (`make capture SCENE=res://tools/capture/shimmer_capture.tscn NAME=shimmer FRAMES=10` prints it and shoots frames).
- **Motes in the light** (Modern, Visual Polish Plan 9): every room has dust in the air (the `indoors` mood's weather,
  `modern_only`, so Classic's rooms stay as they were frozen; the castle's halls, chapel and court keep their own),
  drawn with `addons/dnd_core/shaders/atmosphere/dust_mote.gdshader`: a mote takes no ambient light and no moonlight, only the lamps',
  candles', fires' and window shafts' light at its own spot, shadows included, so it's invisible in the dark and
  glints in a lamp's pool or a window's beam, twinkling as it turns. Twice as many motes as Classic's, since most are
  dark at any moment, and under half the size (`MODERN_DUST_SIZE`), with each light's share capped under the glow's
  threshold so a mote never blooms: owner 2026-10-12, the first version's motes were "annoying dots on the screen".
- **Indoor shade** (Modern) is filled a little by cool moonlight from unseen windows, readable blue-grey rather than
  black (`INDOOR_TONE`: the ambient leans to moon blue and the moon key light is stronger).
- **Windows indoors** are the moon or the day coming in: the key light's colour, steady, with a spot light over the
  wall beside the window down across the room (casting shadows) and a glowing cone of dusty haze along it
  (`addons/dnd_core/shaders/world/light_shaft.gdshader`), hung on the window's light so they hide with it.

## Characters reflected in the Modern finish

Visual Polish Plan 1 (the vault's "Visual Polish Plan.md", 2026-10-09). The world's screen-space reflections can't
show the characters (they draw after the screen pass), so each figure has its own: `SpriteReflection`, a child of its
`DirectionalSprite`, draws the figure upside down under its feet (`addons/dnd_core/shaders/world/sprite_reflection.gdshader`, the crisp
sprite's motion, billboard and light, without its rim) and keeps only the pixels where the surface already drawn there
is level, at the figure's feet height and glossy, read per pixel from the depth and normal-roughness buffers. So open
water and rain puddles (roughness 0.1 and under) show it fully and waver, wet ground, polished marble and tiles show it
fainter and softer and fading sooner below the feet, dry ground (0.45 and over) not at all, and anything standing in
front hides it. It draws after the screen pass and before the floor's rings and the figures (`PRIORITY` 0), casts no
shadow, follows the figure's frame by signal (so it holds while the game is paused) and shows only in the Modern finish
on a preset with reflections (Medium and High). It costs nothing measurable: 0.0 to 0.1 ms a frame at 3440 x 1440 in
the village at night, Vallaki and the castle's main floor (`python3 tools/perf/perf_run.py --only effects_fast
--effects SpriteReflection --size 3440x1440`).

    make capture SCENE=res://tools/capture/look_capture.tscn NAME=look/refl FRAMES=10 \
      LOOK_SHOTS=pool_shore_dusk,village_wet_dusk,castle_hall   # LOOK_OFF=reflections for without
## Sunbeams and moonbeams in the Modern finish

Visual Polish Plan 2 (the vault's "Visual Polish Plan.md", 2026-10-09). Out of doors a few beams of light slant down
where it breaks through gaps in the trees and between the houses (`SunShafts`, built with the place's weather in
`AtmosphereWeather.build`; `addons/dnd_core/shaders/world/sun_shaft.gdshader`): open cones along the key light, soft at the edges, thin
rays drifting across them and motes turning in them, with a soft patch of light where each lands. They fall on open
squares (or water) with 3 to 15 squares of shade in the 5 x 5 round them, at least 5 squares apart, one for every 45
open squares (3 to 9), the same ones every visit. They follow `Atmosphere.sun` as it turns with the time of day (never
leaning flatter than `LOWEST`, so they stand in the air rather than lying across the ground under the play camera),
take its colour, and are brightest at dusk and dawn, fainter through the overcast by day and under the moon
(`PHASE_STRENGTH`); rain leaves a fifth of that and snow half. Like the window shafts they're added over the scene after
the screen pass, so they fade out toward the screen's blurred edges instead of standing sharp there. Hidden squares
(HiddenAreas) get none. Cost at 3440 x 1440: 0.0 to 0.1 ms (`perf_run.py --only effects_fast --effects SunShafts`).

    make capture SCENE=res://tools/capture/look_capture.tscn NAME=look/beams FRAMES=10 \
      LOOK_SHOTS=road_dusk,village_dusk,lake_dusk   # LOOK_OFF=sunbeams for without

## Footstep puffs in the Modern finish

Visual Polish Plan 4 (the vault's "Visual Polish Plan.md", 2026-10-09). Out of doors the party's feet kick something up
every stride or so (`StepPuffs`, built with the place's weather in `AtmosphereWeather.build`): a little tan dust on dry
roads, earth, scree and mud patches (the floor's `surface`, and the roads the shaped ground lays between two ways out),
pale kicked snow where it lies (`Atmosphere.snow_cover` at `SNOW_GROUND` or a snow floor), a spray of droplets in
marsh mud and on any ground in the rain (`Atmosphere.wetness`), nothing on dry grass, cobbles or floors indoors. The
ground is read as the footprints read it. Each kind keeps at most `POOL` small one-shot particle systems and reuses the
oldest; a puff is one small draw while it lasts (under a second). They're sized by their quad: setting the process
material's scale alone didn't change how big they were drawn.

    make capture SCENE=res://tools/capture/puff_capture.tscn NAME=puffs/after FRAMES=10   # LOOK_OFF=puffs: without

## Fronds framing the woods in the Modern finish

Visual Polish Plan 11 (the vault's "Visual Polish Plan.md"). On wild outdoor maps (`ArenaBoard.WILD` themes) whose
land is wooded (the mood's surround `trees` at `ForegroundFraming.WOODED` or more), a few fern fronds grow into the
bottom corners of the screen, out of focus and nearly black, with a faint edge of the key light, swaying a little, as
if the camera looked past them (`addons/dnd_core/world/look/foreground_framing.gd`, `addons/dnd_core/shaders/post/foreground_leaf.gdshader`, the plants'
own leaf cards at a high mipmap). They sit on a canvas layer over the world and under the HUD, never take a click, keep
clear of the middle of the screen where the party stands, and fade out for fights, conversations and other screens and
as the camera tilts to the horizon. Towns, rooms and Classic get none. In dark woods they mostly melt into the dark
corners; they read best by day and at the camps.

    make capture SCENE=res://tools/capture/look_capture.tscn NAME=look/framing FRAMES=10 \
      LOOK_SHOTS=camp_fire,road_dusk   # LOOK_OFF=framing for without

## Rules for new places

- An outdoor place gets its region's or theme's mood; give it its own only when it should feel different. Indoor
  places use their region's or theme's indoor mood, else `indoors`.
- Colours are palette names only (tests/integration/test_atmosphere.gd checks), weather only of the known kinds.
- A `mists_edge` side only where nothing leads out (it covers that edge completely).
- Anything a mood adds that belongs to one square (a window's light, a chimney's smoke, a fire's sparks) hangs on
  that square's piece, so HiddenAreas hides it with the piece.

## Checking a place

    make capture SCENE=res://tools/art/preview/atmosphere_preview.tscn LOCATION=village_of_barovia NAME=atmo \
      FRAMES=20 ARGS="--times=day,dusk,night,dawn --at=20,12"

`--overview` frames the whole map, `--uncapped --compare` also times and shoots it with the atmosphere's extras off,
`--set=mist_strength:0.8` tries a value, `--no-ao` turns contact shadows off. `make capture` draws off screen.

For a change to the light, the materials or the screen pass, shoot the world look's set places before and after:

    make capture SCENE=res://tools/capture/look_capture.tscn NAME=look/after FRAMES=10 [ARGS="--size=1920x1080"]

`LOOK_SHOTS=village_dusk,castle_hall` picks shots, `LOOK_STYLE` and `LOOK_GRAPHICS` pick the finish and preset for
the run, and `LOOK_BENCH=1` (each part of the renderer) or `LOOK_BENCH=presets` times them round after round. Other
work on the Mac makes single frame times noisy; compare parts within one run.
