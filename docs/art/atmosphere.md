# Atmosphere: how a place looks as a whole

Date: 2026-10-06 · Owner challenge: make the world and its stages look far richer, using what Godot 4 can do.
Owner rules kept: no grain or dither, character sprites stay clear, gothic tone, region exits obvious, hidden areas
hidden until found.

Props, floor and wall textures and their placement belong to set dressing (docs/art/set_dressing.md). This covers
everything around them: light and shadow, mist and fog, the land past the map's edge, weather and the colour grade.

## Where it lives

| Piece | File |
|---|---|
| Each place's mood: light per time of day, mist, clouds, grade, weather, land around the map | `art/atmosphere/moods.json` |
| Builds the mood for a location and runs it (sun, sky, contact shadows, surround, weather, time-of-day blends) | `world/look/atmosphere.gd` (`Atmosphere`) |
| Mist, the Mists' wall, cloud shadows, ground patches, grade, vignette, then outlines and the palette snap | `shaders/post/strahd_post.gdshader` |
| Trees of the surrounding forest (one MultiMesh), falling leaves, chimney smoke | `shaders/atmosphere/` |
| Art QA: a place at each time of day from the game camera, with frame times | `tools/art/preview/atmosphere_preview.tscn` |

`LocationView` makes one `Atmosphere` and hands it the camera and the screen pass; `update_daylight()` tells it the
time of day. A mood is picked by location id (`places`), else by map theme (`themes`), else the outdoor or indoor
default. A mood can be `like` another and change only what differs.

## What it adds

- **Light by time of day.** Day is an overcast silver-grey, dusk a low warm sun under a violet sky, night a cold
  moon from the other side, dawn a rose light. The key light moves (long shadows at dusk and dawn). A change of time
  blends over three seconds instead of snapping.
- **Ground mist.** A layer over the ground that the view ray is marched through, so it lies in the low places and
  shifts with the camera. It gathers by the trees and in brambles and thins in clearings (a mask built from the
  map), drifts with the wind in streaks and thin wisps, and comes out in three or four flat bands like the rest of the
  cel look. Lanterns, fires and lit windows light the mist around them.
- **The Mists.** On the opening road the wall of the Mists stands at the east edge, where the party came in: a flat
  pale wall with an inked, slowly billowing edge, kept a square clear of the map.
- **The land beyond the map.** Ground runs on past the edge, forest thins into the distance (the near trees fade
  like the board's own when they stand in front of the party), the road runs on out of every way out, and the far
  land sinks into the sky colour in flat steps. No place floats in a void any more.
- **Cloud shadows** drift over the ground; broad light and dark patches break up the ground texture so it doesn't
  read as tiles.
- **Contact shadows** (Godot's SSAO) ground props, walls and houses.
- **Weather.** Dead leaves drift down through the view in the woods and the village; smoke curls from every
  village chimney, bent by the wind; after dark the lit windows spill candlelight on the street.
- **Grade.** Each time of day maps brightness through its own shadow and light colours, so a scene keeps to one
  family of hues; strongly coloured light (a lantern, a fire) keeps more of its own colour. A vignette sinks the
  screen's edges towards `void`.

All of it happens before the palette snap, so it comes out in palette colours with no dithering. Character sprites
draw after the screen pass, so mist never covers them and they stay crisp.

## Rules for new places

- Give an outdoor place a mood (or let its theme's mood cover it); indoor places use `indoors` unless they need
  their own (a crypt, the Amber Temple).
- Colours are palette names only.
- A `mists_edge` side only where nothing leads out (it covers that edge completely).
- Anything a mood adds that belongs to one square (a window's light, a chimney's smoke) hangs on the board's house,
  so HiddenAreas hides it with the house.

## Checking a place

    __CFBundleIdentifier=org.godotengine.godot caffeinate -du make capture \
      SCENE=res://tools/art/preview/atmosphere_preview.tscn LOCATION=village_of_barovia NAME=atmo FRAMES=20 \
      ARGS="--times=day,dusk,night,dawn --at=20,12" < /dev/null

`--overview` frames the whole map, `--uncapped --compare` also times and shoots it with the atmosphere's extras off,
`--set=mist_strength:0.8` tries a value. `caffeinate -du` keeps the display awake: a sleeping display hands back
stale frames.
