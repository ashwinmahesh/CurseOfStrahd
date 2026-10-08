# Interiors that look like their descriptions

Date: 2026-10-08 · Owner request: "Add more decorations to the interiors of buildings. They are all kind of plain and
boring. For example madam eva's tent should look like its description (and not have its wall textures be wooden)."
The rule from the outdoor work holds indoors too: what's on screen matches the narration (colours, materials, scale,
landmarks). Each place is dressed from its own summary and narration lines (`narrative/narrator/<region>.dialogue`),
then captured before and after with the location tour.

## Madam Eva's tent (tser_pool_eva_tent)

What the text says: a tent of patched and painted canvas, hung with charms and thick with incense; charms hang from
every rope (bones, bells, little mirrors, a dried bird's foot, a child's tooth), turning slowly to face you; a low
round table with a deck of cards; an iron-bound chest behind her chair; candlelight. Her reading cutscene
(`art/cutscenes/madam_eva_reading.jpg`) sets the colours: dusky violet canvas with stitched patches, a deep red cloth
to the floor, a brass lantern, dripping candles.

| Before | After |
|---|---|
| A tavern room (map theme `tavern`): plaster-and-brick walls with timber coping, plank floor | Map theme `tent`: patched violet canvas on poles, Vistani rugs on the floor (`interior/rug`) |
| A bar counter across the middle, the reading table a plain wooden table | Her low round table under a red cloth, the five cards of a reading laid in a cross, the deck, three candles; floor cushions either side for querents |
| Barrels, a bench, two plain chests | An iron-bound chest, her painted chest, heaped cushions and a trunk in the corners, two lanterns on iron crooks, a brass censer, the brazier and the charm frame |
| Nothing on the walls | A rope along the top of every side with two to four charms per square: painted eyes, bells, bones, little mirrors, a bird's foot, beads, a tooth |
| Nothing to say anyone lives there | Her home around the reading (owner, 2026-10-08: "really make it look like the place where she lives and does her readings"): her bed of quilts and a fur with her shawls on a cord above it and a little mirror, keepsakes, apples; a cooking fire under an iron pot with herbs drying on the wall and a sack of meal; old books and papers either side of her painted chest; candles burning on the floor either side of her; plum wine and bread set out for querents; a travelling trunk |

### The tent style (`world/look/tent_walls.gd`, `world/look/charm.gd`)

A board whose interior style is `tent` (catalog `building_kit.interiors.themes.tent`) hands every wall square to
`TentWalls` instead of building walls (`InteriorWalls.build` asks first, in either look):

- **Canvas.** One sheet per side facing the room: a two-sided mesh in folds (2.5 a square, deeper toward the top),
  leaning in 0.16 over a 2.4-high wall (`InteriorWalls.HEIGHTS.tent`). Where two sides meet at a room corner their
  tops are pulled in to meet. A dark hem runs along the ground.
- **Roof's foot.** Above each sheet the canvas turns in and climbs (0.34 in, 0.3 up), so the walls read as the sides
  of a tent whose roof is above the camera's view.
- **Poles** at every room corner and at every third seam along a wall, leaning with the canvas, lashed with rope.
- **Rope and charms.** A rope along each side's top; charms hang from it on threads, half as big again as life so they
  read from the camera. They turn slowly; the eyes and mirrors turn, very slowly, toward the camera.
- **Behind the canvas** is the camp's ground (`building_kit.interiors.ground.tent`, grass).
- **Pieces stand off the canvas.** The board's `wall_inset` (set by `TentWalls`) is how far in from the wall square's
  face the canvas stands at about chest height; pieces hung on the wall or backed onto it are set that far forward
  (a deep piece is squeezed to stay in its square), so nothing disappears into the leaning canvas.
- **Cut-away.** In the Modern look each side has a full and a cut-away version and joins the room walls' cut-away
  (`InteriorWalls.cut`): the canvas toward the camera drops to 1.15, the far sides stand. Classic builds the cut-away
  version only, with no charms or roof.

### The canvas (`tent/canvas`)

Painted in code by `tools/art/make_canvas_swatch.py` (Pillow, a fixed seed, no image model): panels of dusky violet
and indigo cloth sewn side by side, ragged patches of darker and brighter scraps, coarse dark stitches on every seam
and patch, brushy streaks and faded blotches. `tools/art/build_surfaces.py --only tent/canvas` then makes it an HD
surface set like the painted ones (`surface_recipes.json` entry with `new: true`; seamless tile, normal and ORM maps).

### New pieces (`blender/models_3d.py`, "Interiors" section)

| Model | What it is | Height |
|---|---|---|
| reading_table | low round table, red cloth to the floor in folds, five Tarokka cards in a cross (one face up), the deck, three dripping candles | 2.9 ft |
| cushions | three velvet floor cushions heaped (blood, plum, crimson) with gold tassels | 2.1 ft |
| lantern_stand | brass lantern with glowing glass hanging from an iron crook on three feet | 7.25 ft |
| incense_burner | brass censer on three legs, pierced domed lid, coals glowing | 2.55 ft |
| bedroll | folded quilts, a fur, two pillows and a fringed shawl, its head at the wall | 1.7 ft |
| candle_cluster | seven candles of different heights burning on the floor in pools of wax | 1.55 ft |
| book_stack | three stacks of worn books, scrolls, loose leaves and a candle stub | 1.7 ft |
| cookpot | a ring of stones, glowing coals, an iron pot on a chain under a tripod, a ladle | 3.15 ft |
| basket | a wicker basket of apples and a loaf | 1.5 ft |
| wine_tray | a brass tray with a bottle of plum wine, two cups, bread and cheese | 1.45 ft |
| drying_herbs (wall) | a rail of herb bundles hung head down, a string of garlic, a string of red peppers | 2.25 ft |
| shawl_line (wall) | fringed shawls and scarves on a cord, red, gold, violet and blue | 3.75 ft |

These were modelled first, so their 2D sprites (for Classic and every 2D path) are rendered from the models:
`blender/model_sprites.py` draws each on flat white from the front (and from behind, for pieces with a back), the
renders are kept in `art/generated/props/model_<id>.png`, and `make prop` cuts them out and snaps them to the palette
like a painted prop. No image model was used.

    blender -b --python blender/model_sprites.py -- --only cushions --back cushions --out art/generated/props/_tmp
    make prop SRC=art/generated/props/model_cushions.png ID=cushions HEIGHT=0.43

Then add `mount` and `back` to the new manifest entries, map the art to the model in `models3d.art`, give it `feet`,
and `make models ONLY=...`.

## The Blue Water Inn's stable (vallaki_blue_water_inn, the Stable yard)

Owner report (2026-10-08): "The stable at the Blue Water Inn doesnt resemble a stable at all." What the text says: a
stable yard where a carnival wagon takes up most of the space, and every horse in the stable stands at the far end of
its stall, away from it. It was dressed as the taproom: planks, plaster, tavern tables on its '=' squares, no light.

| Before | After |
|---|---|
| Plank floor, plaster walls, unlit | Packed earth strewn with straw, rough board walls (catalog `rooms`: an area named stable, stall or byre), two lanterns |
| Tavern tables and chairs | Box stalls along the north wall (`stall`, `stall_horse`: plank partitions, posts, manger, hay rack, straw, a bucket), horses in the two at the far west end, away from the wagon; a trough, hay bales, sacks of oats, a rain barrel, a muck cart, tack on the walls (`tack`: saddle, stirrups, bridles, a coil of rope, a horseshoe) |

- **Straw** is a decal rule kept to rooms: a clutter rule's `rooms` (words in an area's name or id) keeps it inside
  those areas (`Clutter._room_rects`), so the yard is strewn with straw and the taproom isn't.
- **Stalls are two squares wide** so a horse stands side on in one. They are building-sized pieces backed onto the wall
  (`big` and `against_wall`); `ModelPiece.stand` now sets such a piece back on its wall face before measuring how
  much room it has, so it only shrinks for things really in its way.
- The horse in a stall is sculpted from the horse's 2D art inside the stall model (`inflate`), so it's one piece.

## Every interior: the sweep (owner, 2026-10-08)

"We want this upgraded interior pattern and audit rolled out to every other interior we have." The audit of all 55
interior and underground maps (282 rooms) and the plan, room by room, are in the vault: Interiors Audit and Plan.md
and Interiors Audit - Room Facts.md. What every room gets:

- **Lived-in rooms** (`world/look/furnish.gd`, catalog `furnish`). Besides what its data names, each room gets what a
  room of its kind holds, matched on words in its name like the room styles, else by the board theme: kitchens herbs
  drying, jars, sacks, baskets and barrels; bedrooms pictures, mirrors, pegs, trunks and candles; libraries portraits
  and book stacks; cells chains, shackled skeletons and bones; attics cobwebs and sheeted furniture; taprooms a stag's
  head, notices, barrels; chapels and crypts candles and bones. A piece goes on about one free wall face in
  `wall_every` and on about one free square along a wall in `floor_every`, never two side by side, never in a corner
  (pieces on two walls would meet), never beside a door, an exit, a spawn, a light or a person, and never on a wall
  square that holds one of the location's own things or beside a building-sized piece. Every pick comes from the
  square, so a place is furnished the same way every time; the board places them after its own dressing.
- **Density** (owner, 2026-10-08: "Can we add more props? For that really lived in feeling. These interiors still look
  really barren"): a piece on about nine in ten free wall faces (`wall_fill`), on about four in five free squares along
  the walls (`floor_fill`, side by side allowed, never in a passage one square wide), and in about a quarter of the open
  middle (`centre_fill`) in small clusters (never on a square with two furnished neighbours), never on the shortest
  ways from the spawn to the doors, exits and people (`Furnish._paths`), so the routes stay clear. A room whose rule
  names a `rug` gets one under its middle (up to 4 by 3 squares, the surface world-mapped over a dark border, flat,
  blocking nothing). Lanterns and candles it puts out (`lit`) give a little light, at most two a room. New pieces for
  it: crate_stack, sack_pile, table_meal and table_books (tables with things on them, also on '=' squares of taverns,
  houses, manors and kitchens), bench, lantern_bracket, floor_books, bucket_brush, shelf_goods. Nothing changes the
  rules grid: a fight's squares are as they were.
- **Room styles read the name first.** `SetDressing.room_rule` matches a rule's words in the area's name before its
  id, so an id's location words don't decide a room ("larders_guardroom" is a guardroom, not a kitchen). A theme can
  have its own rules first (`theme_rooms`: a farmhouse bedroom is plaster and planks), and a place whose look is its
  own (`place_looks` `keep`: a cave, the Amber Temple) isn't restyled room by room.
- **'=' furniture by room** (`low_cover_rooms`): a room's half-cover squares take its own furniture (a kitchen's
  worktables, a dormitory's bunks, a dining room's laid table), with `run` and `wall_run` sets for runs of three or
  more; a place's own set still comes first.
- A wall piece on a '=' square is that square's furniture: the board's own furniture there goes (a stove by the wall
  used to stand over a sideboard).
- **What the narration names**, room by room, in the data, with lights where it mentions candles, lamps or fires.

### The Death House

The den has its stag's head over the hearth and two fur-draped chairs facing the fire; the main hall's hearth has the
longsword over it and a runner on the marble; the entrance a coat stand; the library red velvet drapes, a second deep
chair and books on the floor; the secret study its black-bound books; the servants their second footlocker; the
conservatory gauzy drapes and upholstered chairs; the bathroom its little stove; the nursemaid her writing table; the
nursery a rocking chair and its single candle; the children's room more drawings. Below: black robes on pegs in the
initiates' quarters, bones laid out along the passage, skeletons in shackles round the Darklord's shrine, old meat in
the larder, alcoves of relics in the reliquary, shackles and robes in the prison, the winch in the winch room, and
braziers burning in the antechamber and either side of the altar.

### The Village of Barovia

- **Bildrath's:** a board of prices, lamp oil and candles in rows on the wall (`oil_shelf`), rope coiled to the same
  diameter (`rope_coils`), and by day a customer counting her coppers (Goodwife Viorica).
- **Blood of the Vine:** the casks stacked three high behind the bar (cask racks and two hollow casks). Its narration
  counts four drinkers, so it gets no more people.
- **The burgomaster's mansion:** every outer window boarded (the claw-scored boards), the parlor's small fire, Ireena's
  sword leaning where a hand can find it, a map of the valley in the study (`valley_map`), and the two new candles at
  the coffin's head.
- **Mad Mary's:** the sewing basket and the folded dress by the rocking chair (`sewing_basket`), a shelf of children's
  books in Gertruda's room, and the chair pulled up to the wall in Mary's.
- **The church:** the sunburst over the altar, gone grey with soot, cold candles either side, vestments on pegs in the
  vestry, and by day two people praying in the pews (Old Florin, Goodwife Sorina).

### Vallaki

- **The Blue Water Inn:** a stew pot over the kitchen fire big enough to bathe in (the witch's cauldron bubbled green), beds on the guest rooms' squares
  (they were tavern tables), Rictavio's costume rack, washstand and lute, two regulars at the taproom's tables of an
  evening (Dragan, Oana), and in the yard Rictavio's carnival wagon: its walls painted red with gold trim and wheels
  (location `wall_styles`), a lantern by its steps, where it was a dark block of wall.
- **The burgomaster's mansion:** yellow bunting on the great hall's walls and in Lady Lydia's parlour, the Baron's
  chair, a coat stand and the sign in the foyer, chairs drowned in half-sewn festival cloth in the parlour
  (`festival_cloth`), a basin and a sword in Izek's room, candles in Victor's attic (now attic boards and damp plaster,
  by the new `attic` room rule, where it had the manor's wainscot).
- **St. Andral's:** candelabra either side of the altar dais, the altar cloth folded on a chair, a cot and robes in the
  vestry, and by day an old woman praying in the pews (Old Varvara).
- **The Wachterhaus:** benches facing the cellar shrine where the cult kneels, and candles.
- **Blinsky's:** shelves of toys on three walls (`toy_shelf`).
- **The coffin maker's:** coffin lids leaning on the workshop walls (`coffin_lid`) and Henrik's crucifixes, one over
  his bed and one by his door (`crucifix`).

### Krezk and the Abbey

- **The Krezkovs' house:** Anna's spinning wheel and the bench by the door (they were chairs), the eldest son's carved
  wooden sword on his window sill (`sill_sword`), the willow-bark cups on Ilya's sill (`sill_cups`), and a chair pulled
  up to the burgomaster's bed. The eldest son's room ("kept clean ... hasn't been slept in") and the burgomaster's
  ("a plain bedroom") are left to their own things: an area's `furnish: false` (location schema).
- **The Abbey church:** the great sunburst (it was a heraldic crest), candles along the altar rail until the Abbot is
  broken, vestments on pegs in the sacristy and one white surplice apart (`surplice`); the Abbot's bare cell stays bare
  (`furnish: false`).
- **The wards:** the foundling ward's '=' squares are rows of little cots (catalog `low_cover_rooms` "foundling"; they
  were small stone tombs), the cold infirmary has iron curtain hooks on its walls and nothing else (furnish
  "infirmary", where the hall rule had laid a rug and an armchair), charcoal suns at a child's height down the long
  corridor (`charcoal_suns`), the Belviews' stew pot (`cookpot`), straw and gnawed bones in their kitchen, and the
  surgeon's instruments on a tray (`instrument_tray`).

### Old Bonegrinder and the Wizard of Wines

- **Old Bonegrinder:** flour dusted over the bakery and round the millstone (a `floor_dust` clutter rule kept to rooms
  named bakery or millstone); in the loft, Morgantha's basket of knitting and bowl (`knitting_basket`) and the footstool
  turned toward the cages (`footstool`), and the nest's hollows are straw (`straw_pallet` by low_cover_rooms "nest",
  loose straw by a furnish "nest" rule) where crates and trunks stood.
- **The press house:** the great press over the middle of the floor (spanning its block, with vats round it by
  low_cover_rooms "press floor", where shop counters stood), and tools on pegs inside the door (`tool_rack`).
- **The winery:** the eight great vats, one over each block of the fermenting hall (`great_vat`, `span: [2, 2]`), where
  tavern tables, a rug and armchairs stood (the furnish larder rule now names fermenting, bottling, cask and vintage
  rooms); free-standing racks of empty bottles (`bottle_rack`, also low_cover_rooms "bottling"); cups on hooks in the
  tasting room (`cup_hooks`).
- **The cellar:** casks and cask racks in the cask vaults (low_cover_rooms "cask") where the crypt rules had laid little
  tombs, skulls and bones.

### Argynvostholt and Van Richten's tower

- **Argynvostholt's ground floor:** cold ash underfoot in the burned halls (a dark `floor_dust` clutter rule kept to
  the holt's great hall, entry hall, west gallery and servants' hall), banners rotted to lace over the long table,
  racks of rusted weapons in the armory (`weapon_rack`), fallen frames and torn canvas in the west gallery
  (`fallen_frames`) and portraits turned to the wall (`portrait_turned`), and the servants' table still laid
  (low_cover_rooms "servants' hall", where the servant rule had stood beds on it). The burned halls take no furnishing
  (`furnish: false`): the hall rule had laid rugs and armchairs among the knights.
- **The upper floor:** the knights' dormitory has the house's boards and wainscot (the barracks rule had given it cellar
  brick), Sir Godfrey's "plain room" and the commander's "bare room" are plain boards and plaster or stone with only
  their own things, the hall of heroes keeps to its statues, and the dragon's study has a chair too big for a man.
- **Van Richten's tower:** crates of holy water and bundles of stakes in the hunter's storeroom (`holy_water_crate`,
  `stake_bundle`, and a furnish "hunter" rule along its walls), the workroom's long table buried in maps, notes,
  candle stubs and small skulls (`map_table`), and the lantern room's copper nails in a spiral across its stone floor
  (`nail_spiral`, `span: [3, 3]`; a floor piece's `span` now centres it like a standing one), with no armchairs.

Every piece a '=' square can be dressed as names an object kind in data/objects/kinds.json, so fights can shove, wreck
and hide behind it (tests/unit/test_battle_objects.gd checks the catalog's lists and the interiors' own pieces).

People in public buildings (owner, 2026-10-08: "some buildings could use a few more random people to make more
lively"): townsfolk NPCs on lane 28's pattern (`townsfolk` tag, `hours`, `facing`, portrait = sprite), their lines in
`narrative/<region>/indoor_folk.dialogue`, unvoiced until the voice thread casts them; only where the narration
doesn't count the room's people already.

## Checking it

    make capture SCENE=res://tools/art/preview/location_tour.tscn LOCATION=tser_pool_eva_tent NAME=tent ARGS="--hour=20 --shots=2"
    INTERIORS_LIT=1 INTERIORS_SPOTS='death_house_ground@4,3|death_house_upper@5,4' make capture SCENE=res://tools/capture/interiors_capture.tscn NAME=dh/after FRAMES=10

`tools/capture/interiors_capture.tscn` shoots every interior from above in one run (or `INTERIORS_LOCS`), plus close
shots of `INTERIORS_SPOTS`.

`tests/integration/test_interiors.gd`: the tent is canvas with poles and charms and no house walls, its floor is rugs,
it cuts away toward the camera, Classic keeps it low, and her things are the models the narration names; the inn's
stable yard is earth and straw inside board walls, with stalls, horses, a trough, hay and tack, and no tavern furniture.
