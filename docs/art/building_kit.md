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
  and stand solid when they hide the party, opening round it as the walls do (below, "Walls in the party's way").
- **Wall faces.** Every open face of a cut-away wall gets the style's coping along its cut top (a moulded stone band,
  a dark wood rail, an oak plate, rough capstones), and where no panelling covers it the style's face: the castle's
  blind arcade on colonnettes over a plinth course, a church's plinth and string course (`ModelPiece.dress_wall`).

## Rooms that sit in the world (W8, `addons/dnd_core/world/look/interior_walls.gd`)

In the Modern look (`building_kit.interiors.full_walls`), a room's walls stand a full storey instead of the cut-away
height: 3.0 in the castle and the Amber Temple, 2.8 in a church, 2.5 in a manor, 2.4 in a dungeon, 2.3 in a timber
house (`InteriorWalls.HEIGHTS`; a place in `interiors.outside` can set its own `height`). `ArenaBoard._wall` hands
every wall square of an interior or dungeon to `BuildingKit.interior_wall`, which makes it one of:

- **A pillar**, as before (a lone wall square).
- **A room wall** (a wall square with a room beside it): one node on its square holding a full storey (the wall, its
  dark cap, the style's coping and faces, panelling at full height, a wainscot texture mapped over the taller wall);
  with `interiors.cut_away` on, its cut-away version too, hidden.
- **A block** (the middle of a thick wall): the walls' full height, capped dark (the cut-away height with
  `interiors.cut_away` on).
- **Outside** (wall reached from the map's edge through solid wall): the ground the building stands on, one slab
  reaching 10 squares past the map, in the style's `ground` or the place's own (the Death House's floors stand over
  the village cobbles, a storey lower per floor: `below`); the outer walls of an upper floor run down to it. A
  dungeon's outside stays rock.
- **A doorway's header**: the wall over a doorway between two wall squares, from the door's height to the storey's.
- **A doorway's frame** (W7): on each side of a doorway that opens into a room, the style's doorway on the face of
  the walls beside it: `kit_<style>_doorway`, the jambs (oak posts with knee braces; a manor's moulded architrave on
  plinth blocks; the castle's dressed jambs with colonnettes; a church's two recessed orders; a dungeon's rough
  blocks; the Amber Temple's black jambs veined with amber), and `kit_<style>_doorway_head` over them (a pegged oak
  lintel; an architrave head, frieze and cornice; a pointed arch under a hood mould; a lancet of two orders; a cracked
  lintel slab; a black lintel lit along its length). The head is part of the wall over the doorway, which stands set
  back behind it (with `interiors.cut_away` on, the jambs stay as the walls cut away and the head goes with that wall). A door hung there has no plain frame (`InteriorWalls.frames`), and
  a secret door nobody has found shows no doorway until it's found (`InteriorWalls.show_frame`). Not framed: a side
  that runs on between walls the same way (a corridor under the wall over it), and a gap between free-standing walls
  (the Amber Temple's book stacks) unless a door hangs in it.

### Thin walls (Natural Maps Plan I1, `InteriorWalls`; owner 2026-10-19)

"We don't need to draw our real world maps as a battle grid": a wall is not a whole square thick. The catalog's
`interiors.thin_walls` (`inset` 0.35; `not`: the starts of the place ids it leaves out, the caves, which are I2's) sets
each side of a wall square that faces a room back into the square by that much, so a wall between two rooms stands
1 - 2 x 0.35 = 0.3 of a square (about a foot and a half) thick and the rooms read bigger. The rules grid is untouched.

- **The solid** (`InteriorWalls._solid`): the square less a band along each side with a room beside it, and less a corner
  where only the diagonal square is open (a room's inside corner), as boxes: a run is one 0.3 wide box, a wall's end
  0.3 x 0.65, an outside corner 0.65 x 0.65, a T its three arms. A wall with no room beside it, diagonals included,
  stays a whole block (thick masonry, the outer mass); an upper floor's outer walls still run down to the street.
- **Doorways** keep the wall running on to the opening's edge (`InteriorWalls.doorway`: one open square between two
  walls that opens into a room), so the opening is still a square wide; the wall over it (`_header`) is as thin as the
  walls beside it, and the jambs and head stand on the set-back faces (`_frame`). Over a corridor the header runs across
  to the set-back faces.
- **The floor runs on** to the new face: each band left of a square gets a floor piece in the floor of the open square it
  lies beside (`InteriorWalls.finish`, called by `ArenaBoard._build` once every floor is built; recorded with the wall
  square's scenery, so a prop that takes the square or an undiscovered room hides them too).
- **What stands on a wall follows the face**: `ArenaBoard.wall_inset` is negative on such a board (a tent's canvas stays
  positive) and pieces ask `ArenaBoard.wall_inset_at(wall, normal)` for the wall square's own side: models hung on a
  wall (`ModelPiece.hang`), furniture backed onto it (`ModelPiece.stand`, `SetDressing._against_wall`), 2D wall pieces
  (`SetDressing._hang`), a secret door's disguise and bookcase faces, and wall decals (`Clutter._spots`). A doorway's
  side (the wall runs to the grid line) and a lone pillar answer 0. A face much shorter than a square (a wall's end, or
  the last square before it) takes no decor (`Furnish`, `_hang` picks another face when it can) and furniture there
  stays on the grid line: two pieces pressed against the two faces of one wall's end would meet inside it.
- **Modules on a shorter face**: the style's coping is stretched to the face's length (`ModelPiece.dress_wall`,
  `InteriorWalls.face_span`; it carries on round a room's inside corner into the notch), and the face module (a
  whole square wide) is left off.
- **Not**: tents (their canvas), Castle Ravenloft's roofs (`CastleBuilder` claims them), natural ground (a hill's floors
  aren't flat), the caves, and the Classic look, which keeps its low whole-square walls.

Every wall stands its full storey from every heading, and one between the camera and the party opens a window round
the party (below, "Walls in the party's way"; owner 2026-10-17: "walls collapse down when looking from certain angles
... I don't like this behavior"). With the catalog's `interiors.cut_away` on, each frame the board's cut-away
(`TownBuilder.cut_away`, through a building entry `{"interior": true}`) asks each room wall whether there's floor just
past it, looking away from the camera, within 7 squares of the party (`InteriorWalls.cut`): those walls squash down to
the cut-away height and their cut version takes over; the rest stand. A header goes down with either wall beside it.
The rules grid, line of sight and the Classic look are unchanged.

## Walls in the party's way (`addons/dnd_core/world/look/see_through.gd`)

Owner, 2026-10-17: walls dropping to a stub as the camera turned (the Tsolenka guard tower, the Amber Temple) and
Castle Ravenloft's big walls going see-through whole ("they are in opaque view but it looks really weird") are gone.
Every wall, house, castle piece, town wall, pillar, tower and statue stands whole and solid from every heading, and a
piece that hides the party (or whoever the camera follows) fades to the trees' opacity (transparency 0.72, 28% opaque)
over a quarter of a second while it does, and comes back to solid when it no longer does. Owner, 2026-10-19: "remove the
weird visual effect where we get an x-ray if a player is blocked by an object, and instead use the opacity change": the
oval window that was cut in whatever stood nearer the camera than the party (its rim dithered, the party showing through
it) is gone, and no shader cuts a hole any more.

- **What fades**: pieces marked by `SeeThrough.mark` (they join the group `see_fade`): houses and Castle Ravenloft (the
  board marks every building when it's built, and `TownBuilder._kit_walls` a house's rebuilt walls), an interior's
  walls, headers, blocks and tent canvas (`InteriorWalls`, `TentWalls`), pillars, a town wall three men high, pieces
  hung on walls (`ArenaBoard.attach_to_building`), a building-sized piece standing in for a house (the windmill, the
  bell tower, Van Richten's tower) and catalog pieces with `see_through: true` (the Amber Temple's colossus, the faceless
  statue, Baba Lysaga's hut, the wicker effigy). Floors, furniture, props and figures never fade; trees and rocks fade
  the same way (`ArenaBoard.fade_occluders`); a waist-high yard wall hides nobody and stays whole. A house's walls and
  its roof are one piece each, so they fade whole; an interior's walls fade a square at a time.
- **Which are in the way**: one `SeeThrough` node per view (`LocationView`) looks, about every 0.05 s while the camera
  or the party moves, for the marked pieces crossed by a sight line from the camera to the figure the camera is on (feet,
  chest, head, either side) and to the rest of the party while exploring (`LocationView._party_feet`): on a boss making an
  entrance (`CameraRig.cutaway_focus`), else whoever the camera follows (the leader exploring, the one acting in a
  fight), else where the camera looks. A piece wider than `SeeThrough.LARGE` (a house's walls, a castle wall) counts
  only where one of its faces is crossed (its mesh's triangles), not whenever the party is inside the box round it. A line
  stops just short of the figure, so a wall it stands against doesn't hide it. Nothing beside or behind the party fades.
- **How**: `GeometryInstance3D.transparency` (shadows stay), which every world shader keeps; the Amber Temple's tall
  blocks, whose shader has an alpha of its own, fade by their material's `see_fade` uniform (`SeeThrough.mark_glass`).
- `tools/capture/look_capture.gd` has shots with the party behind a house, a guardroom wall and a courtyard
  (`behind_house`, `behind_house_wide`, `behind_guardroom`, `behind_guardroom_wall`, `behind_courtyard`).
- `tools/capture/walls_capture.gd` shoots any place with the party on a named square from all four headings
  (`WALLS_SPOTS`, `WALLS_LOAD` for a bug report's save.json).

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
- **Cut away** (only with the catalog's `building_kit.cut_away` on; off since the owner's call on 2026-10-13, so the
  walls stand, and a piece in the way fades, above): the walls come in pieces of 4 x 4 squares, each tower and gate its own; a piece in the way of the
  party, or of the squares beside it or just past it, squashes down to its foot (1.25, coped) and comes back when it's
  clear, so the party and the squares round it are always in view. The walls are buildings to the board, so props on
  them (the keep's windows, its crest) hang on their faces and go with them.

- **The wall walk** (W7, catalog `walks: true`): on the gates, the gate wall's inner row each side of the gatehouse is
  a walk 30 ft up that the rules stand on, reached from the courtyard by stairs of 5 ft steps: built raised squares
  in the map (raised floor digits with elevation stacked on them, so Classic draws them as raised floor). In the
  Modern look the castle draws them in its own stone, a paved top with a coping on each edge over lower ground, no
  face between the walk and the wall top beside it, and they cut away with the wall pieces they belong to. Each 5 ft
  step of the stairs has a short flight of small steps up its face from the square below (owner 2026-10-15,
  Stairs.flight), part of the same cut-away piece.
- **The keep's roof** (W7): a steep slated roof inside the battlements, the kit's stone roof along the keep's long
  side half a square in from its faces, with an ashlar gable at each end; it hides with the keep when the keep is in
  the way.

`TownBuilder.plan` hands the gates and the overlook (yard boards) to `CastleBuilder.plan`; the roofs (a dungeon
board) reach it through `BuildingKit.interior_wall`. Captures: `KIT_NO_CASTLE=1` shows the stone houses as before.

## How a house is put together (`addons/dnd_core/world/look/town_builder.gd`, `addons/dnd_core/world/look/building_kit.gd`)

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
- **Cut away** (only with the catalog's `building_kit.cut_away` on: the owner turned it off on 2026-10-13, "why do
  buildings shrink down ... when I get near them? Same things with walls. Lets disable this effect", so houses stand,
  and one in the way fades, above; it went see-through whole until 2026-10-17).
  A house between the camera and the party squashes down and is replaced by its low band: a ring of wall 0.5 high,
  capped dark like the cut-away interiors, round a floor of boards, with its footing.

**L-shaped buildings** (W7). A block of wall that isn't a rectangle is split into rectangles as before, but they are
one building: every part takes the main part's height (the biggest), roof and paint and stands on the lowest ground
of any of them; no face, window or corner post where two parts meet; a wing whose end stands wholly against a part
whose ridge crosses it runs its roof on into that part, to half a square short of its ridge, with no gable at that
end, made flatter where it must be so its ridge stays under the other roof (`TownBuilder._butts`); and the parts are
cut away together. The Abbey of St. Markovia and Argynvostholt have such blocks; kit_capture's `l_houses` shot shows
two made-up L's.

Yard walls are the kit's too: a stone arm from each square's middle toward each neighbouring wall or gate, a capped
pier where the wall turns, ends or branches, and a gate pier each side of a gateway (gates there hang between them,
with no box frame). A town wall (catalog `town_walls`, Krezk's 2.6) is the tall wall with merlons; it rings a walled
town at the map's edge too, where an open village thins into pines (`TownBuilder.walled`, `ArenaBoard._town_wall`),
stands on ground of its own, and fades when it hides the party, as the houses do. Vallaki's palisade is one mesh for the
whole border (`TownBuilder.palisade`, asked by `ArenaBoard._wall`).

## Natural shapes (natural maps B1, `addons/dnd_core/world/look/building_bend.gd`)

Owner, 2026-10-19: "We can give buildings natural shapes instead of their straight lines. Natural edges can bend into a
square the party can stand on." (the vault's Natural Maps Plan, rule 4 and package B1). In the Modern look no building is
ruler-straight: `BuildingBend` is one smooth displacement of a building's points, worked out when it is built.

- **What bends.** The whole footprint is turned a couple of degrees off the grid (a little more at the eaves), walls lean a
  few degrees and bow along their length, the long walls' top plate dips with the ridge, the roof sags like a swayback (up
  to 0.9 on a long roof), its ridge bows sideways and is turned further than the eaves, its slopes rise and fall (the
  roof is overhead, so it reaches up to `ROOF_MAX` 0.45 sideways at the ridge, over the middle of the building, where
  the walls stay inside the quarter square; stiffer styles bend their roofs less, by the amount to the power 1.5), corners drift off true at the footing, a timber house flares out toward its eaves, the roof ridge sags toward its middle (more on a long roof), the eaves and the top
  plate wave up and down, and the chimney leans with the roof under it. Yard walls and a town wall lean and wander and
  have an uneven coping, a palisade's logs each lean their own way with uneven tops, and building-sized props (the
  cottage, Baba Lysaga's hut, the windmill: catalog `models3d.bend`, `ModelPiece.instance_bent`) bend as houses do.
- **How far.** A wall never moves more than its style's reach sideways: a quarter of a square (rule 2: a wall is taller than
  a token's knee, so a token in the middle of the square beside it and its ring stay clear), and for timber walls half a
  square (Ashwin's pick, 2026-10-19, so there a wall may stand at the middle of the square beside it): catalog
  `building_kit.bend.reach`. The field itself is held a little under it (0.2 for a quarter, 0.36 for a half), so a module
  bent whole stays inside. Per style, catalog `building_kit.bend`: `styles` (timber 1, clapboard 0.95, stone
  0.7, church 0.5), `places` (Castle Ravenloft's outer yards 0, the Abbey and Argynvostholt 0.8) and `overhang`. The
  field is seeded by the place and the building, so a place comes out the same every time and no two houses lean alike.
  The Classic look and the rules grid are untouched.
- **How.** Only vertices move: no new art, so a window, a door bay or a beam goes with its wall. A house's wall modules
  go whole (`BuildingBend.fold`: the module's placement takes the bend to first order about its middle, a few field
  evaluations a module, so a village's 200,000 wall points cost nothing); the roofs, the core, the gables made in code,
  the palisade and the props have their points moved (`bent`). Both are in `BuildingKit.merge` (`bend`, `at`,
  `whole_modules`). A house's field is smooth over a square (waves ten squares long) so folding stays within a few
  hundredths. The whole L-shaped building shares one bend, so its wings still meet where they did, and the core and each
  gable end are cut into small pieces to bow with the walls.
- **Hung pieces follow the wall.** A sign, a lantern, a window light or a door's leaf hung on a bent house goes to the
  bent point, turned and tilted with the wall (`TownBuilder.follow_bend`, from `face_taken`; `BuildingBend.frame`); a gate
  in a bent yard wall too (`follow_yard`). An arm of a yard wall that meets a house reaches a little way into it, and
  runs a little long, so a bent house leaning away from it leaves no gap.
- **Kept.** A bent roof (with its gable frames and chimney cap) and Vallaki's palisade are the heaviest meshes (40,000 and
  50,000 points), so `BuildingKit.merge` keeps them per place (`keep` key, the newest 90, `BuildingKit.forget`): a
  first arrival costs up to about a tenth more than before, a repeat arrival is back to what it was. `tools/capture/bend_time`
  times both.
- **Not bent.** Castle Ravenloft (CastleBuilder), interiors (B2 will), the Classic look, tents, ground-level props.
  `kit_capture` takes `KIT_NO_BEND=1` for the same shots ruler-straight.

## Making and changing the modules (`blender/building_kit.py`)

    blender -b --python blender/building_kit.py -- [--only kit_timber_low_b ...] [--preview captures/kit.png]
    make import

It reuses `blender/models_3d.py`'s pieces, materials and export, writing `art/models/kit/*.glb` and
`art/models/kit/manifest.json` (each module's part, size, materials, a roof's span and rise, the colour a house
repaints, and the kit's constants). A wall module is one square's face, 1 unit wide, standing on the wall face: Blender
-Y (Godot +Z) points out of the house and the origin is the bottom middle of the face. Surfaces use palette colours
and the existing texture sets; the HD surfaces (W4) will give the kit its own painted materials.

Checks: `tests/integration/test_building_bend.gd` (a bend never moves a point past the limit, is the same every time and
differs by place, `bent` agrees with `apply`, each style bends by its amount, the village's houses are bent and stay near
their boxes, a bent wall reaches no more than a quarter square past the straight one, pieces hung on a bent house stand
where they did on the straight one, yard walls and palisades, building-sized props), and
`tests/integration/test_building_kit.gd` (every module TownBuilder asks for exists with real materials, the
village is built of kit houses with door bays and lit windows, a house cuts away to its footing, the churches are
stone with their towers, Vallaki is clapboard behind its palisade and Krezk is stone inside its tall wall all round,
and lone wall squares are pillars in the castle, the church and the Death House's dungeon; the Death House's upper
floor has full walls over the street a storey down, headers over its doorways, and its north wall stands or is cut
away as the camera turns). Captures, before and after:

    make capture SCENE=res://tools/capture/kit_capture.tscn NAME=kit/after FRAMES=10   # KIT_SHOTS=village_close,...

## Not done yet

- Full walls have no ceilings or upper floors over them, by choice (W7, 2026-10-09): the approved interior frames
  show rooms open from above, and a ceiling would hide the party. A room's walls are full height whatever its size.
- Lights at the pillars' sconces and the lit windows (W5's, in the light lane): the window markers in `board.windows`
  carry meta `lit`, and the sconces are at 1.35 on two faces of each castle pier.
- The kit's own HD materials (W4): timber, plaster, thatch and stone painted at 2K with normal and roughness maps.
