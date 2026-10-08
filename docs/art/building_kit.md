# The building kit (W7: real architecture)

Date: 2026-10-07 · Improvement Ideas W7, the surfaces and architecture lane. Owner direction (W1): HD-2D, A's
effects in B's tone; the reference frames are `art/generated/look_targets/*_ab.png`.

Towns were textured boxes under a gabled slab: a painted timber pattern on a box, no beams, sills, eaves or footings.
They are now put together from a kit of Blender modules in their region's style, the way a modular kit works in any
3D game: each face of a house is a module, and the corners, roof, gables and chimney are modules too.

| Style | Where | What it is |
|---|---|---|
| timber | the Village of Barovia, Old Bonegrinder's hill, the Wizard of Wines, Van Richten's tower (board theme `village`) | Barovian half-timbering: dark oak posts, sill beam, mid rail and wall plate, braces, St Andrew's crosses and chevrons over cracked plaster with brick showing (`interior/plaster_wall`), a fieldstone footing, deep thatch on small houses and slate on grand ones, casements with plank shutters |
| clapboard | Vallaki (theme `vallaki`) | lapped painted boards (each house its own colour from `paints`), corner boards, frieze and skirt boards, cased windows with a pediment, a pedimented door case, steep slate roofs with carved bargeboards; the town's border is a palisade of sharpened logs |
| stone | Krezk, the Abbey, Argynvostholt, the castle's outer yards (theme `shrine_yard`) | coursed stone with quoins, a chamfered plinth, a string course and an eaves cornice, dressed window surrounds with keystones, a round-arched door; Krezk's wall is the tall wall with merlons |
| church | the house that holds a church's doors (the village church, St. Andral's) | dressed stone with a tall plinth, buttresses and angle buttresses, a corbel table under the eaves, lancet windows with Y-tracery and hood moulds, a very steep slate roof, parapet gables with kneelers and a cross (a rose window on a wide one), and a bell tower over the doors: clasping buttresses, a belfry of louvred lancets, a corbelled parapet and a slated spire |

The style comes from `art/sprites/props/catalog.json` `building_kit`: a place's own, else its board theme's. A place
or theme not named keeps the plain boxes (none are left).

**Interiors** take a style too (`building_kit.interiors`, by the start of the place's id, else the board theme):
`castle` for every room of Castle Ravenloft, `amber` for the Amber Temple, `church`, `dungeon`, `manor` (the Death
House, the mansions) and `timber` (inns, shops, houses, attics). In that style:

- **Pillars.** A lone wall square inside a room (no wall beside it) is a pillar instead of a block
  (`BuildingKit.pillar`, asked by `ArenaBoard._wall`): the castle's carved piers (a stepped plinth, a shaft clustered
  with colonnettes, a blind arch on each face of the upper block, gargoyle heads, iron sconces of candles), a church's
  round column with its base and capital, a dungeon's stacked rough blocks, a wooden post braced four ways, the Amber
  Temple's black octagonal shafts veined with amber light. They stand about 2.3 high, taller than the cut-away walls,
  and fade when they hide the party, as the trees do.
- **Wall faces.** Every open face of a cut-away wall gets the style's coping along its cut top (a moulded stone band,
  a dark wood rail, an oak plate, rough capstones), and where no panelling covers it the style's face: the castle's
  blind arcade on colonnettes over a plinth course, a church's plinth and string course (`ModelPiece.dress_wall`).

## Rooms that sit in the world (W8, `world/look/interior_walls.gd`)

In the Modern look (`building_kit.interiors.full_walls`), a room's walls stand a full storey instead of the cut-away
height: 3.0 in the castle and the Amber Temple, 2.8 in a church, 2.5 in a manor, 2.4 in a dungeon, 2.3 in a timber
house (`InteriorWalls.HEIGHTS`; a place in `interiors.outside` can set its own `height`). `ArenaBoard._wall` hands
every wall square of an interior or dungeon to `BuildingKit.interior_wall`, which makes it one of:

- **A pillar**, as before (a lone wall square).
- **A room wall** (a wall square with a room beside it): one node on its square holding a full storey (the wall, its
  dark cap, the style's coping and faces, panelling at full height, a wainscot texture mapped over the taller wall)
  and its cut-away version, hidden.
- **A block** (the middle of a thick wall): the cut-away height, capped dark.
- **Outside** (wall reached from the map's edge through solid wall): the ground the building stands on, one slab
  reaching 10 squares past the map, in the style's `ground` or the place's own (the Death House's floors stand over
  the village cobbles, a storey lower per floor: `below`); the outer walls of an upper floor run down to it. A
  dungeon's outside stays rock.
- **A doorway's header**: the wall over a doorway between two wall squares, from the door's height to the storey's.

Each frame the board's cut-away (`TownBuilder.cut_away`, through a building entry `{"interior": true}`) asks each
room wall whether there's floor just past it, looking away from the camera, within 7 squares of the party
(`InteriorWalls.cut`): those walls squash down to the cut-away height and their cut version takes over; the rest
stand, so the far walls frame the party's room and rooms further off keep their walls. A header goes down with either
wall beside it. Turning the camera turns which walls are down. The rules grid, line of sight and the Classic look are
unchanged.

## Castle Ravenloft from outside (W19, `world/look/castle_builder.gd`)

In the Modern look the castle's outside places are built as the castle, not as stone houses: the gates (the
drawbridge, the gatehouse, the courtyard and the keep's front), the overlook and the roofs among the spires. Target
frames: `art/generated/look_targets/castle_gates_ab.png` and `castle_bridge_ab.png`. Placements are per place in the
catalog (`building_kit.castle.places`); the maps' squares are unchanged.

- **Curtain walls** (every wall square in the place's `rect`) stand 6 high: the ashlar body, a battered foot under a
  roll moulding on each face over the ground, and at the top a parapet carried out on three stepped corbels per face
  (machicolations) with a merlon and two crenels per square, some with crossbow loops. Faces carry crossbow loops
  and stepped buttresses by their square's hash.
- **The keep** (`keeps` rects) stands 10.5 high with lancet windows in two storeys (some lit) between buttresses.
  `blocks` add more of it past the map's edge (behind the overlook).
- **Towers** (`towers`): round, a battered foot, a shaft with loops, a corbelled crenellated top, and a slated spire
  (a cone, or a taller needle). `from` above 0 is a turret rising out of the keep; below 0, out of the drop beside the
  roofs.
- **Gates**: every run of up to three open squares through a wall gets a pointed arch of dressed voussoirs on jamb
  shafts, the wall going on over it with its battlements (`kit_castle_gate_w*_d*`); a door hung there (the portcullis)
  stands in the arch with no frame of its own. A gap in a wall too low for an arch stays open.
- **Low walls**: `parapets` rects make the cliff road's edge a low coped wall; `heights` rects give walls their own
  height (a raised roof's parapet). A piece under 2.5 high is never cut away.
- **The chasm**: wherever the land meets the void, rock faces (`kit_cliff_*`) fall 21 below the edge into the mist,
  leaning out a little as they go; a `bridges` rect (the drawbridge) gets beams and cross-timbers under it instead. On
  the roofs (`cliffs` false) the void is the drop off the roof, the castle's masonry going on down under every square
  beside it.
- **Cut away**: the walls come in pieces of 4 x 4 squares, each tower and gate its own; a piece in the way of the
  party, or of the squares beside it or just past it, squashes down to its foot (1.25, coped) and comes back when it's
  clear, so the party and the squares round it are always in view. The walls are buildings to the board, so props on
  them (the keep's windows, its crest) hang on their faces and go with them.

`TownBuilder.plan` hands the gates and the overlook (yard boards) to `CastleBuilder.plan`; the roofs (a dungeon
board) reach it through `BuildingKit.interior_wall`. Captures: `KIT_NO_CASTLE=1` shows the stone houses as before.

## How a house is put together (`world/look/town_builder.gd`, `world/look/building_kit.gd`)

TownBuilder still finds the houses in the map's `#` squares as before (docs/art/set_dressing.md). For each house:

- **Faces.** Every side of every edge square is a face. It gets a lower module (footing, sill beam, mid rail and the
  lower panel's timbers) and an upper module (the upper panel and the wall plate), picked by the square, so a house is
  always built the same way. Faces over open ground get a window on every third one, as before: a dark casement, a
  lit one (candlelight; the marker in `board.windows` has meta `lit`) or one with its shutters closed.
- **Doors.** A door hung on a face (an exit's door, by `SetDressing._hang`) calls `TownBuilder.face_taken`: the face
  becomes a door bay (jambs, a head beam, a step) and the leaf is sized to the opening (0.8 x 1.9). Anything else hung
  there takes the window's place.
- **Corners** are posts, quoins or corner boards; the **core** behind the modules is the style's wall texture
  (`cores`), so the plaster or stone shows between the timbers.
- **Height.** Houses are 2.2 to 2.9 units to the eaves. Lower modules are never stretched; upper modules, corners and
  the space over a door are stretched above their own pivot, so footings, sills and doors stay their real size.
- **Roof.** One module per square along the ridge for the house's span (1 to 12 squares), an end module over each
  gable (the verge and its barge board), the framing of each gable's triangle, and the triangle itself in the core.
  Thatch has a rounded eave, a saddle and a rolled ridge; slate has ridge tiles, a fascia board and rafter feet.
- **Chimney.** The stack is a box (the chimney smoke finds it), the cap and pot are a module.
- **Merged.** The walls and the roof are each one mesh, one surface per material (`BuildingKit.merge`), so a village
  costs a few dozen draws, not thousands.
- **Cut away.** A house between the camera and the party squashes down and is replaced by its low band: a ring of
  wall 0.5 high, capped dark like the cut-away interiors, round a floor of boards, with its footing.

Yard walls are the kit's too: a stone arm from each square's middle toward each neighbouring wall or gate, a capped
pier where the wall turns, ends or branches, and a gate pier each side of a gateway (gates there hang between them,
with no box frame). A town wall (catalog `town_walls`, Krezk's 2.6) is the tall wall with merlons. Vallaki's
palisade is one mesh for the whole border (`TownBuilder.palisade`, asked by `ArenaBoard._wall`).

## Making and changing the modules (`blender/building_kit.py`)

    blender -b --python blender/building_kit.py -- [--only kit_timber_low_b ...] [--preview captures/kit.png]
    make import

It reuses `blender/models_3d.py`'s pieces, materials and export, writing `art/models/kit/*.glb` and
`art/models/kit/manifest.json` (each module's part, size, materials, a roof's span and rise, the colour a house
repaints, and the kit's constants). A wall module is one square's face, 1 unit wide, standing on the wall face: Blender
-Y (Godot +Z) points out of the house and the origin is the bottom middle of the face. Surfaces use palette colours
and the existing texture sets; the HD surfaces (W4) will give the kit its own painted materials.

Checks: `tests/integration/test_building_kit.gd` (every module TownBuilder asks for exists with real materials, the
village is built of kit houses with door bays and lit windows, a house cuts away to its footing, the churches are
stone with their towers, Vallaki is clapboard behind its palisade and Krezk is stone inside its tall wall, and lone
wall squares are pillars in the castle, the church and the Death House's dungeon; the Death House's upper floor has
full walls over the street a storey down, headers over its doorways, and its north wall stands or is cut away as the
camera turns). Captures, before and after:

    make capture SCENE=res://tools/capture/kit_capture.tscn NAME=kit/after FRAMES=10   # KIT_SHOTS=village_close,...

## Not done yet

- Interior door surrounds per style.
- The castle's walls have no wall walk you can stand on, and the chasm's depth is drawn, not fallen into (lane 3's
  `drop_ft`). The keep has no roof of its own past its battlements.
- Full walls have no ceilings or upper floors over them; a room's walls are full height whatever the room's size.
- Lights at the pillars' sconces and the lit windows (W5's, in the light lane): the window markers in `board.windows`
  carry meta `lit`, and the sconces are at 1.35 on two faces of each castle pier.
- The kit's own HD materials (W4): timber, plaster, thatch and stone painted at 2K with normal and roughness maps.
- Houses are still rectangles; an L-shaped block is two houses with their own roofs.
