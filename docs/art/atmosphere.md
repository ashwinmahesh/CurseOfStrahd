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
| Builds the mood for a location and runs it (sun, sky, contact shadows, water, time-of-day blends, lightning) | `world/look/atmosphere.gd` (`Atmosphere`) |
| The land around the map and over its empty squares: hills, forest, roads and lakes running on | `world/look/atmosphere_land.gd` (`AtmosphereLand`) |
| The Modern look's trees and plants (docs/art/plants.md) | `world/look/flora.gd` (`Flora`), `art/plants/` |
| The Modern look's shaped ground: the walked ground's hollows and ruts, banks under the woods | `world/look/ground_relief.gd` (`GroundRelief`) |
| What lies past the edge when the camera tilts up: the mountains, Castle Ravenloft on its crag, Lake Zarovich | `world/look/vista.gd` (`Vista`), `art/vistas/`, `shaders/atmosphere/vista*.gdshader` |
| The land lane's before-and-after shots: trees and plants, ground, vistas | `tools/capture/land_capture.tscn` |
| Weather: leaves, rain, snow, wisps, dust, crows, chimney smoke, embers, lit windows | `world/look/atmosphere_weather.gd` (`AtmosphereWeather`) |
| Mist, the Mists' wall, cloud shadows, ground patches, grade, vignette, then outlines and the palette snap | `shaders/post/strahd_post.gdshader` |
| Water, forest trees (one MultiMesh), leaves, rain, splashes, motes, crows, smoke | `shaders/atmosphere/` |
| Art QA: a place at each time of day from the game camera, with frame times | `tools/art/preview/atmosphere_preview.tscn` |
| The renderer by graphics preset: anti-aliasing, shadow maps, how many lamps cast shadows | `world/look/graphics.gd` (`Graphics`) |
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
| `high_snow`, `blizzard` | Mount Baratok, the Amber Temple's approach; Tsolenka Pass and the Amber Temple road | snowfields, a blue-white grade; a blizzard driving almost sideways |
| `lake_zarovich`, `lakeside` | Lake Zarovich, Van Richten's tower | moving water running on past the map's edge, mist on the lake |
| `berez` | Berez and the marsh track | marsh-mud land, still bog water, green-yellow will-o'-wisps after dark, a bone-coloured grade |
| `tser_pool`, `vistani_camp`, `tser_falls` | the Vistani camps, Tser Falls | sparks over the fires, fireflies; steep hills and thick mist at the falls |
| `wizard_of_wines`, `bonegrinder`, `argynvostholt`, `werewolf_den`, `yester_hill` | those places | rain and crows over the vines; crows over the windmill; a cold dead grade and pale wisps; rock; a sick green grade and many crows |
| `ravenloft`, `ravenloft_roofs` | the castle's gates, overlook and roofs | a storm: hard rain, lightning flashes, crows, the sky of blood at dusk; on the roofs, a gale |
| `ravenloft_halls`, `ravenloft_chapel`, `ravenloft_court`, `ravenloft_spires`, `ravenloft_larders`, `ravenloft_crypt` | the castle's main floor, chapel, Court of the Count, spires, larders, catacombs | candlelit cold halls with dust in the air; a bone-dust chapel; crimson for the brides' court; moonlit spires with lightning at the windows; a sick green below the kitchens; a cold, still mist on the crypt floors |
| `indoors`, `tavern`, `eva_tent`, `chapel`, `crypt`, `cave`, `death_house`, `death_house_crypt`, `amber_temple`, `haunted` | rooms, taverns, Madam Eva's tent, churches, dungeons, caves, Death House, the Amber Temple, Argynvostholt's halls | warm firelit taverns, purple tent light, cold moonlit churches, mist lying on dungeon floors |

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
- **Water.** In the Modern finish (W14, `shaders/world/lit_water.gdshader`) water deepens smoothly from the shore,
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
- **Washing lines.** A mood's `lines` (world/look/washing_line.gd) strings a line between two posts with the week's
  wash pegged out on it in muted palette colours, swaying: Barovia's back yards (lane 28, "an actual village"). With
  `"kind": "bunting"` it is a high festival string of little pennants with no posts, in Vallaki's yellow by default.
  Lines are built outdoors only. Krezk's yards have washing lines too.
- **The Mists on the map.** A `fog_bank` prop (the road out of the Mists, the road east of the village) is a bank
  of soft, camera-facing puffs (world/look/mist_bank.gd, shaders/world/mist_puff.gdshader) in the Mists' grey, not a
  drawn cloud; the screen pass's Mists wall (a mood's `mists_edge`) has a soft, billowing edge with slow puffs of light
  and shade in it and only a faint ink line (lane 28: it read as a flat slab from far out).
- **Smoke at a point.** Weather `{"kind": "smoke", "at": [[x, y, z]]}` puts a chimney plume anywhere: Old
  Bonegrinder's pipe.
- **Waterfalls.** A mood's `falls` (world/look/waterfall.gd) pours a river over an edge: a curved sheet of falling
  water in the place's water colours, white streaks racing down it, foam at the lip and spray at the foot where the
  mist swallows it. Tser Falls has one over its gorge (its empty squares are a drop, `surround.void`).
- **Cloud shadows** drift over the ground; broad light and dark patches break up the ground texture so it doesn't
  read as tiles.
- **Contact shadows** (Godot's SSAO) ground props, walls and houses.
- **Weather**, by mood: dead leaves; rain slanting on the wind with rings where it lands; snow drifting or driving
  in a blizzard; will-o'-wisps and fireflies after dark; dust hanging in shut-up rooms; crows circling overhead;
  chimney smoke bent by the wind; sparks over open fires; candlelight spilling from lit windows after dark;
  lightning flashes in a storm (and through the castle's spire windows).
- **The world's weather** (lane 4's F12, `story/weather.gd`): outdoors, a place's mood is dressed for the weather
  the world has now (`Weather.dress_mood`: its own rain and snow give way to the weather's, fog thickens its mist), and
  when the weather turns during a stay, `Atmosphere.refresh_weather()` (LocationClock calls it) rebuilds the rain and
  snow and resets the mist and the wet or snowy surfaces at once.
- **Weather on surfaces** (W12, Modern; `shaders/world/weather_surface.gdshaderinc`, the global uniforms `world_wet`,
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

Improvement Ideas W11. On an outdoor wild map (ArenaBoard.WILD) the ground people walk on is drawn as one shaped
skin instead of flat squares, with shallow hollows. It never rises above the squares' floor level and is never deeper
than `GroundRelief.DEEPEST`, so tokens, grid overlays and spell templates still stand on the same 5 ft grid
(`floor_y`/`cell_center` are untouched; real heights are F4's), and it settles flat round any square drawn flat (a
prop's, a door's, an exit's, a raised one, water). The board's own floor boxes there stop drawing themselves (render
layers 0; `ArenaBoard.floor_box`, `floor_material`); a trap's square keeps its box, so a pit still opens it. Under the
map's woods (tree squares) the ground rises into banks with mounds on them, and the land past the edge starts on the
banks and settles into its hills. The trees and plants stand on all of it. Towns keep their streets, rooms and yards
their floors, and Classic stays flat. `GroundRelief.roads()` lays the shortest walks between the map's ways out; the
surfaces lane's wheel-rut decals (W10) follow them.

Hidden until found: the skin, the banks and the map's ground plants leave out squares HiddenAreas hides
(AtmosphereLand's HiddenWatch redraws them when a secret door is found).

A place is built on every arrival, so all of it is worked out on one coarse grid of points (two a square), from
distance fields over flat arrays, and indexed into a few meshes; and since a place comes out the same every time, what
a build works out (the land's fields and mesh, the relief, the trees, the plants) is kept for the newest eight places
and drawn again from that on the next visit. `AtmosphereLand.build_ms` says what each phase took.

    make capture SCENE=res://tools/capture/land_capture.tscn NAME=land/clay FRAMES=10 \
      LAND_SHOTS=crossroads LAND_CLAY=1     # the shaped ground in plain clay; LAND_NO_RELIEF=1 for without

## The sky in the Modern finish

Improvement Ideas W13, the sky half. Where the tilted camera looks out past everything (see Vistas below), the screen
pass draws Barovia's sky (`strahd_post.gdshader` `sky_colour`, set by `Atmosphere._apply_sky` by the time of day,
outdoors only): a gradient from the land's haze at the horizon up to the place's sky colour, a low ceiling of cloud
drifting with the mood's cloud wind (never clear: at least 60% cover), lit from beneath towards the moon or the low
sun, and the moon on the key light's bearing, low enough to be seen (`MOON_HEIGHT`), a disc glowing through thin cloud
at night, paler at dusk and dawn, only a brighter patch by day (`MOON_SHOWS`). The mist past everything thins toward
the horizon instead of painting the gaps between far trees, and as the camera tilts the depth of field and the
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
- **Lake Zarovich** stretching away from the places near it (Vallaki, the lake shore, Van Richten's tower, the
  werewolf den, the Wizard of Wines).

They draw after the screen pass, in a blended pass (`Look.POST_PRIORITY` draws first), so the land's fade into the
haze doesn't swallow them while nearer land, trees and houses still hide them; each frame they take the haze colour the
screen pass gives the far land (`land_color`), so they sit in the same air at every hour. In play they lie past the
camera's far plane and cost nothing; the far plane opens out as the camera tilts. While tilted, leaves and wood within
`near_fade` units of the camera thin away (`foliage.gdshader`, `bark.gdshader`).

    make capture SCENE=res://tools/capture/land_capture.tscn NAME=land/tilt FRAMES=10 \
      LAND_SHOTS=village_tilt,road_tilt,crossroads_tilt,vallaki_tilt,krezk_tilt   # LAND_NO_DOF=1: without the far blur

Not done: the sky above the ridges is the screen pass's haze until the sky half of W13 (lane 6); the far blur of the
depth of field softens the vistas when tilted.

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
| Depth of field blur | very low | low | medium |

A spatial upscaler on Low, not a temporal one (MetalFX temporal, FSR 2): those work over time like TAA and would
blur and smear the sprites.

**What things cost** (paired on/off timings at 1080p on High, `LOOK_BENCH=pairs`, and the P3 probe's, both with the
Mac under heavy load, so the sizes are rough and the order holds): the sun's shadows are the biggest single cost,
since each split draws the scene's shadow casters again (forest roads most of all: their trees); a level floor square
casting a shadow was a third of the village's frame (they no longer do: nothing stands under one); then the lamps and
their shadows, the screen pass (its mist noise now comes from a texture, 1 to 2 ms cheaper outdoors), MSAA, light
bounced off walls and the depth of field. Contact shadows, reflections, glow, haze and SMAA are cheap.

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
  hold steady. The nearest few flames that cast shadows sway a little with their flicker, so their shadows stir
  (`CandleFlicker`, meta `sway`; 2 on High and Medium).
- **Strength by kind** (Modern): hearths throw half again as much light and reach further, candles, lamps and
  torches a little more, and the party's lantern less, so a room's own lights lead (the target frames).
- **Kit and prop flames**: candles and flames modelled into the building kit's pieces (the castle piers' sconces)
  light the room around them; the flames are found in the piece's own mesh (`Atmosphere._light_kit_flames`), and
  floor-level stubs and flames beside the location's own lights are left alone. Likewise the 3D props' fires and
  candles (hearths, braziers, campfires, torches, candelabras: their `flame` and `candle` sockets in
  art/models/manifest.json; `_light_model_flames`), unless the location's own light stands within a square.
- **Indoor shade** (Modern) is filled a little by cool moonlight from unseen windows, readable blue-grey rather than
  black (`INDOOR_TONE`: the ambient leans to moon blue and the moon key light is stronger).
- **Windows indoors** are the moon or the day coming in: the key light's colour, steady, with a spot light over the
  wall beside the window down across the room (casting shadows) and a glowing cone of dusty haze along it
  (`shaders/world/light_shaft.gdshader`), hung on the window's light so they hide with it.

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
