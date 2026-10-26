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

### The tent style (`addons/dnd_core/world/look/tent_walls.gd`, `addons/dnd_core/world/look/charm.gd`)

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
  (a deep piece is squeezed to stay in its square), so nothing disappears into the leaning canvas. (On a room's thin
  walls it is negative, the face lying back inside the wall square: docs/art/building_kit.md, "Thin walls".)
- **Standing.** In the Modern look the canvas stands full height on every side and fades where it hides the party, as a room's walls do (`SeeThrough`, docs/art/building_kit.md); with `interiors.cut_away` on, the
  canvas toward the camera drops to 1.15 instead (`InteriorWalls.cut`). Classic builds it at 1.15 only, with no charms
  or roof.

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

- **Lived-in rooms** (`addons/dnd_core/world/look/furnish.gd`, catalog `furnish`). Besides what its data names, each room gets what a
  room of its kind holds, matched on words in its name like the room styles, else by the board theme: kitchens herbs
  drying, jars, sacks, baskets and barrels; bedrooms pictures, mirrors, pegs, trunks and candles; libraries portraits
  and book stacks; cells chains, shackled skeletons and bones; attics cobwebs and sheeted furniture; taprooms a stag's
  head, notices, barrels; chapels and crypts candles and bones. A piece goes on about one free wall face in
  `wall_every` and on about one free square along a wall in `floor_every`, never two side by side, never in a corner
  (pieces on two walls would meet), never beside a door, an exit, a spawn, a light or a person, and never on a wall
  square that holds one of the location's own things or beside a building-sized piece. No floor piece stands in a
  flight of small steps up a 5 ft rise (`ArenaBoard.stepped`, 2026-10-17). Every pick comes from the square, so a
  place is furnished the same way every time; the board places them after its own dressing.
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
  (low_cover_rooms "servants' hall", where the servant rule had stood beds on it). The burned halls are furnished from the
  furnish set `burned` (fallen beams, charred furniture, ash heaps, rubble; the west gallery's `burned_gallery` adds
  fallen frames) where the hall rule had laid rugs and armchairs among the knights.
- **The upper floor:** the knights' dormitory has the house's boards and wainscot (the barracks rule had given it cellar
  brick), Sir Godfrey's "plain room" and the commander's "bare room" are plain boards and plaster or stone with only
  their own things, the hall of heroes keeps to its statues, and the dragon's study has a chair too big for a man.
- **Van Richten's tower:** crates of holy water and bundles of stakes in the hunter's storeroom (`holy_water_crate`,
  `stake_bundle`, and a furnish "hunter" rule along its walls), the workroom's long table buried in maps, notes,
  candle stubs and small skulls (`map_table`), and the lantern room's copper nails in a spiral across its stone floor
  (`nail_spiral`, `span: [3, 3]`; a floor piece's `span` now centres it like a standing one), with no armchairs.

### The west

- **Baba Lysaga's hut:** drawings of the same boy on every wall, strings of onions and mushrooms in the kitchen, a
  mobile of little bones over the cradle, and the table laid for more guests than she ever has. Her hearth burns
  green: the location light's `color` ("bile") and the hearth prop's `flame` ("bile", SetDressing.FLAME_TINTS).
- **Marina's vault:** candles and rose petals (furnish set `tended_vault`), where the crypt rule had strewn bones: it's
  kept "the way you keep a promise".
- **Mount Baratok:** the hut and study are stone (place_looks `keep`), not parquet and panelling; the bed of furs is in
  the hut; the study's wall is covered in chalk and a stack of rubbed-out slates stands in the corner (`slate_stack`),
  with the study's books but no rug (set `library_bare`).
- **The werewolf den:** cave rock in every chamber (place_looks `keep`; the pen had nursery wallpaper and the shrine
  church flags), straw, furs and bones round the great cave and the mouth (set `den`), straw beds in the pen, Kiril's
  bed of furs, chains in Emil's alcove, Zuleika's real bed, candle stubs at the shrine, the scratched tally.
- **Tsolenka's tower:** a grey cloak on every peg in the vestibule (`cloak_pegs`), and the captain's room is stone with
  a narrow bed and the watch log on a desk.

### The Amber Temple

- Every room keeps the temple's black stone and amber (place_looks `keep`): the room words had given the library
  parquet and panelling, the guardrooms brick and the halls marble.
- The great hall has its own area id and line (`amber_great_hall`): it shared `great_hall` with the Vallaki mansion
  and played its bunting and the Baron's chair.
- The halls hold rubble, broken stone heads, drifted snow, bones and pilgrims' candles (set `amber_hall`) where the hall
  rule had laid rugs and red armchairs; the hall of echoes and the reading room are frozen desks, lecterns and books
  (low_cover_rooms "hall of echoes" and "reading room", set `frozen_reading`); the stacks are books chained to their
  shelves (`chained_bookcase`); the warden's study is buried in pinned notes (set `buried_study`); the wardens' cells
  each hold a cot; the vault of offerings is heaped with coins, crowns, swords and toys (`offering_pile`, set
  `offerings`); the guardroom and the sanctum have cold braziers (`brazier_cold`; the sanctum's had been lit green).
- The Look Plan (vault "Amber Temple Look Plan.md", 2026-10-18), built in steps:
  - Each room has its own light by colour (frost-blue vestibule, guardrooms, cells and sanctum, a violet fill in the great
    hall, honey at its pillars and down the nave, green flameskull points in the library) and the halls hold no snow lumps
    or statue heads; the vestibule, guardrooms, cells and hall of echoes lie on frosted flags (an area's `floor` with
    `raised: true`, since the doors' ledge stands 25 ft up); rock, not a snowfield, lies round the three inside maps
    (building_kit `ground.amber`; the doors keep their snow); the library and the vaults have their own moods and dust.
  - The black stone is polished: its texture-manifest `material` has a `gloss` (a cap on roughness after the ORM map),
    so the party and the glow mirror in it.
  - The temple's lights are the `amber` kind (Atmosphere.LIGHT_KINDS, LightFlicker.STYLES): one slow swell about every
    five seconds, no flutter, no shadow.
  - The great hall's added mood and amber lights are marked `visual: true`: painted only, no light zone in a fight (the Patrina
    series fell from 5 in 8 to 3 when they were light zones on that dark map; LocationFights._light_the_fight skips them).
  - The amber is `AmberGlow` (world/look/amber_glow.gd, shaders/world/amber.gdshader), built in code in the Modern finish
    (Classic keeps the lying box): the catalog id's `case` picks `vestige` (upright, two squares tall, lit from inside by
    a light that breathes and the glass follows), `cracked`, `sleeper` (lying, under the vaults), `hollow` (the Thirst's
    empty sarcophagus, lying across the squares of cover it covers, the largest block of all), `plinth` (the empty
    plinth, frost ring, scrape marks toward the nearest exit) and `block` (the cottage-sized block of amber in the Eye's
    chamber, broken open from the inside). A case stands on its prop's '=' squares and changes no rule.
  - Every vestige's block holds a dark silhouette (art/amber_shapes.json: the game-icons.net outlines, CC BY 3.0, artists on
    the Credits screen, composed into art/textures/amber/shapes/ by `make vestige_shapes`), softened by depth, with a touch
    of its own (gold flecks, rising bubbles, a twitch, cracks, glints, stars, sparks, a ring, an orbiting plane, a lightless core).
  - The temple answers (AmberGlow.refresh, a few times a second from LocationView._process): a block is `waiting` (it
    breathes, brighter as the party comes within five squares), `speaking` (its vestige's `vestige_<name>` line is on
    screen: it flares and pulses, LocationView.set_speaking, and the conversation camera leans to the block,
    TalkCamera.open's `prop_id`), `attending` (its conversation is open while another voice speaks), `sated` (a party
    member carries its `gift_of_<name>`: held low and still, the shape sharper) or `sealed` (`flag.amber_temple_sealed`:
    dark brown glass, no light, the shape faint; a sealed temple opens dark). The looks are AmberGlow.LOOKS.
  - Each vestige calls to the party once as it comes near, before anyone touches the amber: a prop's `approach: 3`, `call`
    and `call_when` (the location data), played by `LocationNpcs._check_calls` from the step's cell events
    (`LocationWalk._check_cell_events`), the `~ <name>_call` nodes of narrative/amber_temple/vestiges.dialogue. Drafted by
    Gemini and edited (docs/story/drafts/amber-calls/); unvoiced.
  - The faceless god (`FacelessGod`, world/look/faceless_god.gd; Modern only): the great hall's 2 x 2 block of wall is a
    `wall_styles` entry with `plinth: true`, drawn as three steps of the temple's black stone (the squares still block);
    the statue prop (`span: [2, 2]`, facing south, the catalog's `god: true`) stands on the top step (SetDressing.place),
    a void (shaders/world/faceless_void.gdshader) takes the place of its face with a violet corona turning slowly round
    it, shown while the camera looks at its front, and a cold shaft (sun_shaft.gdshader) falls onto its hands and the
    offerings at its feet, where six pilgrims' candles (`candle_cluster` props) burn.
  - The vaults' small things (AmberGlow, step 10): the hollow's crimson thread (shaders/world/amber_thread.gdshader) rises out
    of the dead amber into the dark, faint always and bright once the party has read the hollow (flag `amber_thread_seen`,
    set in amber_temple/vosk:hollow_ok); the honey-glow doors (catalog `honey_doors`, 2.1 high) are two amber panes with a
    light on both sides, dark once the temple is sealed (AmberGlow.dress_door, from SetDressing.door); the heaps of the vault
    of offerings glint (addons/dnd_core/shaders/world/glint.gdshader, AmberGlow.dress_place); and the sanctum's cold braziers flare
    violet (SetDressing.FLAME_TINTS `violet`) while the fight with Vosk (`vosk_unmasked`) is on.
  - Small motion (AmberMotion, world/look/amber_motion.gd, step 11): the hall of echoes is the cold room, its desks' candles
    burn frost-blue (SetDressing.tint_candles, FLAME_TINTS `frost`) and so do their lights, but for Patrina's clear desk, where
    paper flakes fall over her book (a particle sheet); in the library Vosk's cup steams and Exethanter's pinned notes stir;
    Yrrga's eye moves in its block toward the leader (Case.set_gaze); and in the vaults amber seeps from the weeping crack
    (shaders/world/amber_seep.gdshader), when the crack shows.
  - The model of Castle Ravenloft on the table in Exethanter's study (`castle_model` prop at (23,3), CastleModel, world/look/
    castle_model.gd): the castle's own kit pieces (crenellated wall tops, round towers with spires, the gate, the keep's lit
    windows) merged into one mesh at 0.022 on a plain table; Classic keeps the table's picture. Its examine line
    (`examine:castle_model`) was drafted by Gemini (docs/story/drafts/amber-castle-model/); unvoiced.
  - The colossi at the doors (AmberColossus, world/look/amber_colossus.gd, shaders/world/amber_colossus.gdshader, step 8; the
    entrance map, Modern only): the Sentinel stands on a dais, the prop `sentinel_dais` (`span: [2, 2]`, one foot of the temple's
    black stone with an amber seam round its top edge and a top the snow does not whiten, the warmth of the amber). The NPC
    entries say they stand `on` it (LocationNpcs._seat: the middle of its top, the piece's `seat`); the rules' grid is unchanged.
    Its eyes (`SentinelEyes`) are a light of the `amber` kind and a soft halo at head height over wherever the figure stands
    (a person on the dais, or its foe in a fight, `Eye.follow`): they breathe while it watches, flare with each line it speaks
    (`view.speaking` is `amber_sentinel`), sink to an ember once `sentinel_stilled`, and go out with `sentinel_destroyed`, when
    the dais (`sentinel_dais_cracked`) lies broken in two with its cracks glowing and six `amber_shards` props round it. As
    a conversation with it opens, it turns its head to the leader (`dialogue_requested`), and looks out over the valley again
    once nobody has spoken for a few seconds. The dead twin (`cracked_colossus`) is the prop's `tint` (a multiplied colour,
    ModelPiece.tint) of dark amber, with three shards of amber at its feet drawn in code (a prop on a neighbouring square would
    shrink its building-sized model, ModelPiece.big_fit). The doors give a warm wedge of light across the snow (`DoorsWedge`,
    stronger by night) and the four cut icicle sprites hang from their lintel (`DoorsIcicles`). The eyes' light and halo are
    not map `lights`, so a fight's light zones and vision are unchanged.
  - The Sentinel steps down (StepDown, addons/dnd_core/world/combat/step_down.gd, addons/dnd_core/shaders/world/stomp_ring.gdshader, step 9): its four entries in the
    doors' encounters draw the foe as the colossus (`art: amber_sentinel`, 30 ft by CombatToken.HEIGHTS) and say it is the person
    at the doors (`steps_down: {npc: amber_sentinel}`). Walking onto the ledge (`sentinel_stops_you`) hid nothing, so the standing
    colossus and the plain golem were on the board together (shown by capture before the fix); now however the fight starts
    LocationFights._step_down hides the person and the foe's token takes their place on the dais, and, with motion on,
    CombatView.begin plays the beat before the boss entrance and the opening: the camera comes in on it (CameraRig's shot fields)
    while its eyes flare and a crack runs round the dais (LocationView.stepping_down, AmberColossus), it strides to its start
    square in two or three footfalls (a tween of the token alone: the Encounter had it there all along), each landing with a
    jolt of the camera, a burst of snow (StepPuffs `stomp`) and a ring of it along the ground. About a second and a half, never
    past 1.8 s; headless runs, stills and motion off cut straight to the square. The stat block stays the Amber Golem's
    (Large, 2 x 2): only the picture is 30 ft, so the fight bands do not move. Any figure drawn taller than 4.5 units
    (CombatToken.TALL) is drawn at 55% where it hides a figure of the party's behind it on the screen.
  - The temple's found traps glow (TrapGlow, addons/dnd_core/world/look/trap_glow.gd, from TrapSight.dress; addons/dnd_core/shaders/world/trap_glow.gdshader): the
    line of warding glyphs pulses runes along the floor, the faceless god's gaze is a slow violet ring of light on the
    squares it looks at, the frost vent breathes pale wisps. They go with the trap when it is disarmed; Modern only.
  - The paid art (Look Plan P1 to P3, six Gemini sheets, 2026-10-18, about $0.70; Ashwin's typed yes in the thread): two surfaces,
    `amber/violet_marble` (the great hall, its ring and the hall of vestiges: area `floor`) and `amber/glazed_wall` (the ring
    and the hall of vestiges: area `walls`); two decal sheets, `wall_seeps` (amber running down the glazed walls) and
    `floor_temple` (frost rime, scrapes and frost dust in the cold rooms by the catalog's `clutter.places` rules for the three
    inside maps; its gold arc, four of them turned a quarter each, is the inlaid ring in the ring of amber, AmberMotion._inlay);
    two prop sheets: the copper pact ledger (the sanctum's lectern, with a low copper light and glints), a dish of offering candles
    (two of the god's pilgrim candles), amber shards and a standing shard (by the Eye's broken block), and four icicle pieces
    (hung from the doors' lintel, see the colossi below).

### Caves (the werewolf den, Ghakis's lair, the drowned library)

- Their rock is no longer a block a square: it is drawn by `Caves` over a smooth, rounded, wandering contour (set_dressing
  doc "Caves, not rooms"; the vault's Natural Maps Plan I2). The den's caves and the lair are `cave: true`; the library,
  cut into rock and walled in masonry, is `cave: "hewn"` (a smoother face, less lean and stone) and has a ring of rock three squares wide round its hall so its outline has rock to swell into (Ashwin chose it 2026-10-19: every square of its data is three more each way), and its stacks of shelves stay shelves. The
  lair's keepers' post stays built (`built_areas: ["keepers_post"]`) until B2 bends it. The Amber Temple's deep (`amber_deep`)
  was the owner's own pass and has the look only if he says so.
- The grid, the squares' heights, the doors and every prop are as before; a wall with something hung on it stays
  straight where it hangs.

### Castle Ravenloft

- The guest bedroom is the yellow room its text describes: `interior/wallpaper_yellow`, the green damask recoloured
  (tools/art/recolour_swatch.py, then make textures and tools/art/build_surfaces.py; no image generation), on a carpet.
- Heads on the trophy room's walls; torn banners in the Mad Dog's crypt; the jester's crypt's plaster painted with
  juggling balls gone the colour of bruises (`jester_plaster`); carved faces down the hall of faces, which keeps to its
  candelabra and stone heads (set `stone_gallery`) where the hall rule had laid a rug and armchairs; portraits of guests
  in the guests' hall; the east turret post's two suits of armour; candle stubs in the chapel.
- The cells have straw, a bucket and chains (set `prison_cells`), the larders' guardroom pallets along its walls
  (`guard_pallets`), the spires' cauldron room herbs, pots, sacks and bones (`cauldron_room`) instead of armchairs, and
  Rahadin's room only its cot, ledger and racks of curved swords.
- Wall pieces go on the walls the camera faces (north and east): the ones nearest it show only their backs.

Rooms are never left barren (coordinator, 2026-10-08): a room its text calls bare keeps only its own things, but a
ruined or wrecked one is furnished from a set of its own debris (`furnish: "<set>"` names one of the catalog's furnish
`sets`, which may give their own fill rates).

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
it stands toward the camera (cut away only with `interiors.cut_away` on), Classic keeps it low, and her things are the models the narration names; the inn's
stable yard is earth and straw inside board walls, with stalls, horses, a trough, hay and tack, and no tavern furniture.
