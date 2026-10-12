# Skill checks in the world

Owner ask (2026-10-09, repeated 2026-10-11): more skill checks outside fights and conversations. Before this, only
Perception and Investigation (Search), Sleight of Hand (pockets), Stealth, Athletics (forcing a door, a pit) and thieves'
tools had uses out there, which left Nature, Arcana, Acrobatics and most of the rest with nothing to do between
conversations. Goal: every skill has real uses in the world.

## How it works (story/world_checks.gd, world/exploration/location_checks.gd)

A prop, door or chest in a location can carry `checks` (data/schemas/location.schema.json, `$defs/check`). Each one:

- **Shows on the right-click menu** of its thing: "Read the claw marks (Survival DC 13: Thistle +5 with Advantage, 80%)".
  The tooltip says who helps and how. The thing's hover name (and its Alt plate) adds the skills it still offers,
  "Examine Clawed walls (Survival)", its Alt name plate says "Clawed walls · Survival", and a left click on it says
  "Right-click it to try Survival".
- **Is rolled by the party's best hand at it who hasn't tried yet**: the best chance, then the best bonus, then the
  leader. The party walks up first (or tries from where it stands when the thing can't be reached).
- **Gets the 2024 PHB's help before the roll:** another party member proficient in the skill takes the Help action
  (Advantage) unless the check is `alone`; someone who knows Guidance and isn't concentrating on another spell casts it
  (+1d4 on a skill check); Helpful Friend adds its Advantage. A plain ability check (`str`, `dex` ...) takes neither Help
  nor Guidance, since both name a skill. Perception in fog or a storm outdoors has Disadvantage, as a Search does.
- **Rolls on the big d20** (DiceRoll), then the Narrator says how it went: `check:<skill>:<check id>:success` or
  `:failure` in narrative/narrator/<region>.dialogue, else the outcome's `text`.
- **One try each:** a character who fails it has had their try (the owner's rule that failed checks are final); the next
  best who hasn't tried takes the next one. `once`: one try for the whole party (a crumbling ledge, a rune that burns
  out). A success is done for good.
- **Goes away once it's pointless:** a check whose success would only find, disarm, unlock or open what the party
  already found or opened another way (a Search turned up the satchel the climb was for) isn't offered any more.
- **After a failure** the roller can still spend Heroic Inspiration (a new d20), a Lucky Foot (a natural 1 again) or
  Tactical Mind (+1d10) from the same menu (CheckAids). A reroll that succeeds makes the success happen.

## What a result can do (`success`, `failure`)

| Key | Does |
|---|---|
| `items`, `gold` | Given to whoever rolled (gold to the purse). |
| `codex` | `{id, title, text}`: lore in the journal's codex (successes only). |
| `inspiration` | Heroic Inspiration for whoever rolled, passed on if they have it. |
| `heal`, `temp_hp` | Dice of healing for each hurt party member, or Temporary Hit Points for each. |
| `damage`, `damage_type` | Dice of damage to whoever rolled: a fall, a shock, a bite. |
| `minutes` | Time lost on top of the try (a try takes `minutes` on the check, 1 by default). |
| `reveal` | Hidden things found: a search prop, secret door or trap here, or `<location>:<search prop>` somewhere else (a place hint: the hiding place is waiting when the party gets there). |
| `disarm` | Traps here made safe without thieves' tools (a glyph read and unpicked, a wire wedged). |
| `unlock`, `open` | Locks undone; doors opened (a bar lifted from the far side: a shortcut back). |
| `move` | The party crosses to a square: a climb, a leap, a squeeze. |
| `flag` | A side flag, registered in data/flags/world_checks.json: a check never moves the main story. Props and chests whose `when` it makes true come into view at once (a cache that wasn't there). |
| An encounter whose trigger is `check:<id>:success` or `:failure` | Starts when it goes that way (a hornet's nest disturbed). |

`make validate` checks every check's items, reveals, traps, locks, doors, squares, flags and words.

## Writing them

- Successes matter: loot, a shortcut, lore, where something is hidden, a trap or harm avoided. Rewards are things the
  party can use, never common magic items (uncommon up to level 4, rare from level 5, as found_magic_items.md) and
  never dead items; mundane finds are ones the game uses (holy water, antitoxin, oil, a healer's kit, costly spell
  components, potions).
- A failure is never a dead end in the prose and should usually cost something when trying is risky: a fall, a
  burn, lost time, or the chance itself (`once`).
- A thing with checks needs a model with art (docs/art/set_dressing.md); most checks sit on props that were only
  scenery before.
- DCs follow the 2024 DMG: 10 easy, 15 moderate, 20 hard. Most early ones are 12 to 15.
- The Narrator's lines follow docs/voice/narrator.md: one sentence, what the check showed. Lanes leave new lines
  unvoiced; the voice thread voices them.

## Placed checks

Status: ✅ built · ○ planned

### The Village of Barovia (level 3)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Village of Barovia, clawed walls | Read the claw marks (Survival DC 13) | codex: Claw marks on the burgomaster's house | — |
| ✅ | Village of Barovia, old graves | Read the oldest names (History DC 13) | finds a grave dug up and filled in again (Wand of Secrets); codex: The oldest graves in Barovia | — |
| ✅ | Village of Barovia, a roadside shrine | Pray to the Morninglord (Religion DC 12) | Heroic Inspiration | — |
| ✅ | Village of Barovia, collapsed barn | Heave the fallen beams aside (Athletics DC 14) | finds a stash under the fallen beams (Javelin of Lightning) | 1d4 bludgeoning damage |
| ✅ | Village of Barovia, pastry cart | Sniff the pastries (Medicine DC 13) | codex: The pastry cart | loses 60 minutes |
| ✅ | Village of Barovia, castle on the cliff | Recall what's told of the castle (History DC 14) | codex: The castle on the pillar of rock | — |
| ✅ | Village of Barovia, the road east | Study the mists (Arcana DC 14) | codex: The mists | — |
| ✅ | Village of Barovia, a rain barrel | Read the tracks by the barrel (Survival DC 12) | finds something kept dry behind the rain barrel (Oil of Slipperiness) | — |
| ✅ | Village of Barovia, a raven on the lych-gate | Coax the raven down (Animal Handling DC 13) | finds a crack in the lych-gate post (Holy Water) | — |
| ✅ | Village Church, pews | Sing a hymn from the old hymnal (Performance DC 12) | Heroic Inspiration | — |
| ✅ | Village Church, burial niches | Examine the remains in the niches (Medicine DC 13) | finds an old priest in the burial niches (Periapt of Health) | — |
| ✅ | Village Church, altar | Say the dedication over the altar (Religion DC 14) | 1d6 Temporary Hit Points | — |
| ✅ | Burgomaster's Mansion, a map of the valley | Study the burgomaster's map (Survival DC 13) | finds a farmer's cache behind the field wall (Gauntlets of Ogre Power, The River Ivlis Crossroads); codex: The burgomaster's map | — |
| ✅ | Burgomaster's Mansion, portrait of the burgomaster | Recall the Indirovich family (History DC 12) | codex: The Indirovich family | — |
| ✅ | Blood of the Vine, wine casks | Judge the wine (Nature DC 12) | codex: The wizard's wine | — |
| ✅ | Blood of the Vine, hearth | Play for the room by the hearth (Performance DC 13) | 6 gold | — |
| ✅ | The Charcoal-Burners' Hollow, herbs drying | Name the drying herbs (Nature DC 12) | heals 1d6 | — |

### Death House (level 2)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Death House, Ground Floor, a dumbwaiter | Squeeze into the dumbwaiter shaft (Acrobatics DC 13) | finds something in the soot under the dumbwaiter (Driftglobe) | 1d4 bludgeoning damage |
| ✅ | Death House, Ground Floor, sealed jars | Judge what's in the sealed jars (Medicine DC 12) | heals 1d4 | 1d4 poison damage |
| ✅ | Death House, Upper Floor, a bookcase | Read the titles on the odd shelf (History DC 13) | finds the swinging bookcase | — |
| ✅ | Death House, Upper Floor, a standing harp | Play the standing harp (Performance DC 13) | Heroic Inspiration | — |
| ✅ | Death House, Dungeon (Upper Level), scuffs in the dust | Read the scuffs in the dust (Survival DC 13) | finds a covered spiked pit | — |
| ✅ | Death House, Dungeon (Upper Level), the oldest crypt | Read the oldest crypt (History DC 14) | codex: The first of the Dursts | — |
| ✅ | Death House, Dungeon (Upper Level), the well | Climb down the well shaft (Athletics DC 13) | 22 gold | 1d6 bludgeoning damage |
| ✅ | Death House, Dungeon (Upper Level), skeletons in rusty shackles | Give the shackled dead their rites (Religion DC 12) | Heroic Inspiration | — |
| ✅ | Death House, Dungeon (Lower Level), alcoves of strange relics | Sense which relic still holds power (Arcana DC 14) | finds a relic in the niches that isn't bone (Pipes of Haunting) | — |
| ✅ | Death House, Dungeon (Lower Level), wall reliefs | Read the rite in the reliefs (Religion DC 14) | codex: The rite on the walls | — |

### Tser Pool and Tser Falls (level 4)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Tser Pool Encampment, horses | Calm the skittish horses (Animal Handling DC 12) | finds something in the reeds (Elemental Gem (Yellow Diamond)) | — |
| ✅ | Tser Pool Encampment, the bonfire | Dance at the bonfire (Performance DC 12) | Heroic Inspiration | — |
| ✅ | Tser Pool Encampment, a stump stuck with knives | Play the knife game for coin (Sleight of Hand DC 13) | 12 gold | 1d4 slashing damage |
| ✅ | Tser Pool Encampment, a cart with a cracked wheel | Lift the cart off its cracked wheel (Athletics DC 13) | finds a false floor in the broken cart (Bag of Holding) | — |
| ✅ | Tser Pool Encampment, a tree hung with ribbons | Read the knots on the ribbons (Insight DC 13) | finds a Vistani cache under the ribbon tree (Boots of Striding and Springing) | — |
| ✅ | Tser Pool Encampment, a cairn by the water | Read the cairn's oldest marks (History DC 13) | codex: The cairn at Tser Pool | — |
| ✅ | Tser Falls, a stone heaped with tokens | Sense the token that hums (Arcana DC 13) | finds a token that hums (Pearl of Power) | — |
| ✅ | Tser Falls, a claw-marked pine | Climb the claw-marked pine (Athletics DC 13) | finds a satchel snagged high in the pine (Goggles of Night) | 1d6 bludgeoning damage |
| ✅ | Tser Falls, a cairn of names | Speak the names on the cairn (Religion DC 12) | finds a necklace among the names on the cairn (Necklace of Adaptation) | — |

### Vallaki (level 5)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Vallaki, the festival dais | Perform on the festival dais (Performance DC 14) | 20 gold | — |
| ✅ | Vallaki, old Smaranda's herb stall | Pick the real herbs from the dross (Nature DC 15) | Keoghtom's Ointment (uncommon) | — |
| ✅ | Vallaki, the Lake Gate | Read the Lake Gate's carvings (History DC 12) | codex: The founding of Vallaki | — |
| ✅ | Vallaki, churchyard graves | Read the epitaphs (Religion DC 13) | codex: Saint Andral | — |
| ✅ | The Blue Water Inn, a covered cage | Calm the great cat in the cage (Animal Handling DC 15) | Heroic Inspiration | 1d6 slashing damage |
| ✅ | The Blue Water Inn, carving over the door | Read the raven over the door (History DC 13) | codex: The raven over the door | — |
| ✅ | The Vistani Camp, rotten jetty | Walk out to the end of the rotten jetty (Acrobatics DC 13) | 18 gold | 1d4 cold damage |
| ✅ | Wachterhaus, a shrine | Read the shrine's dedication (Religion DC 15) | finds the cult's tithe under the shrine (Rod of Rulership); codex: The shrine in the cellar | — |

### Into the Mists (level 1)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | The Old Svalich Road, a torn carcass | Read the wolf sign by the carcass (Survival DC 12) | finds a hunter's wolf trap; finds a traveller's pack under the carcass (Boots of the Winterlands) | — |
| ✅ | The Old Svalich Road, an old oak with a broad low bough | Climb the oak and look out (Athletics DC 10) | finds a gate guard's sword in the weeds (Weapon of Warning) | — |
| ✅ | The Old Svalich Road, the headless statues | Read the statues' plinths (History DC 12) | finds stone heads in the weeds; codex: The headless statues | — |
| ✅ | The Old Svalich Road, a wayside shrine | Pray at the wayside shrine (Religion DC 11) | Heroic Inspiration | — |

### The Old Svalich Road (level 4)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | The River Ivlis Crossroads, unmarked mounds | Read the disturbed earth (Survival DC 13) | finds a mound that isn't as old as the others (Boots of Elvenkind) | — |
| ✅ | The River Ivlis Crossroads, the bridge parapet | Climb down to the bridge footings (Athletics DC 12) | finds the bridge footings (Potion of Healing) | 1d4 cold damage |
| ✅ | The River Ivlis Crossroads, the road south | Read the tracks on the castle road (Survival DC 14) | codex: The road to the castle | — |
| ✅ | The Svalich Woods, a clawed pine with low branches | Climb the clawed pine and look around (Athletics DC 11) | finds something glinting high in the pine (Ring of Jumping) | 1d6 bludgeoning damage |
| ✅ | The Svalich Woods, a claw-marked pine | Read the claw marks (Survival DC 14) | finds a hunter's boots in the mud (Boots of Speed, The Hills above Lake Zarovich); codex: A werewolf's mark | — |
| ✅ | The Old Svalich Road, a platform up a pine by the road | Climb to the hunters' platform (Athletics DC 12) | 12 gold; codex: The hunters' warning | — |
| ✅ | The Old Svalich Road, a tumbled field wall | Shift the tumbled stones (Athletics DC 13) | finds a gap in the field wall (Gloves of Swimming and Climbing) | — |
| ✅ | The Webbed Gully, older bundles | Cut open the older bundles (Medicine DC 13) | Antitoxin; 20 gold | 1d4 poison damage |

### Old Bonegrinder (level 6)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Old Bonegrinder, the Hill, a dead oak full of ravens | Win the ravens' trust (Animal Handling DC 14) | finds a raven's hoard in the dead oak (Figurine of Wondrous Power (Silver Raven)) | — |
| ✅ | Old Bonegrinder, the Hill, ravens | Scatter the ravens from the bone heap (Intimidation DC 12) | finds a heap of bones (Holy Symbol (Amulet)) | 1d4 piercing damage |
| ✅ | Old Bonegrinder, the Hill, a kitchen garden | Pick through the hags' garden (Nature DC 14) | Antitoxin; codex: The hags' garden | — |
| ✅ | Old Bonegrinder, the Hill, the view from the crag | Scan the lane from the crag (Perception DC 14) | finds something in the ditch (Potion of Gaseous Form, The Miller's Lane) | — |
| ✅ | Old Bonegrinder, the Hill, cart ruts | Follow the cart ruts (Survival DC 12) | codex: Who comes up the hill | — |
| ✅ | The Miller's Lane, a wayside shrine | Pray at the wayside shrine (Religion DC 13) | finds an offering behind the wayside shrine (Potion of Resistance (Poison)) | — |

### The Wizard of Wines (level 6)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | The Wizard of Wines, the well | Climb down inside the well (Athletics DC 13) | finds a rope tied off below the well's lip (Rope of Climbing) | 1d6 bludgeoning damage |
| ✅ | The Wizard of Wines, a dead tree full of ravens | Ask the ravens for their help (Persuasion DC 14) | finds the ravens' hoard in the dead tree (Ring of Feather Falling); codex: The vineyard's ravens | — |
| ✅ | The Wizard of Wines, withered vines | Study the withered vines (Nature DC 14) | finds a druid's cache in the gully (Wand of Paralysis, Yester Hill); codex: The blight on the vines | — |
| ✅ | The Wizard of Wines, the camp fire | Sing with the Martikovs at the fire (Performance DC 13) | Heroic Inspiration | — |

### Vallaki, the mansion and the church (level 5)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | The Burgomaster's Mansion, a circle chalked on the floor | Read the chalk circle (Arcana DC 14) | finds teleportation circle; codex: Victor's circle | — |
| ✅ | St. Andral's Church, the altar | Pray at the saint's altar (Religion DC 13), once his bones are back | 1d8 Temporary Hit Points | — |

### Krezk (level 7)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Krezk, a wayside shrine | Pray at the wayside shrine (Religion DC 13) | finds a tin behind the wayside shrine (Keoghtom's Ointment) | — |
| ✅ | Krezk, a cairn by the track | Read the names on the cairn (History DC 13) | finds something under the cairn by the track (Ring of Warmth) | — |
| ✅ | Krezk, the goat pens | Settle the goats for the herders (Animal Handling DC 13) | Ration | — |
| ✅ | Krezk, the abbey above | Recall what's told of the abbey (History DC 15) | codex: The abbey above Krezk | — |
| ✅ | Krezk, the wall of Krezk | Walk the top of the wall (Acrobatics DC 14) | finds a loose stone low in the wall (Weapon, +1) | 1d6 bludgeoning damage |
| ✅ | Krezk, the burgomaster's house | Listen at the Krezkovs' shutters unseen (Stealth DC 13) | codex: The Krezkovs' grief | one try for the party |

### The Abbey of St. Markovia (level 7)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | The Abbey of St. Markovia, a statue of a woman | Recall Saint Markovia's story (History DC 14) | codex: Saint Markovia | — |
| ✅ | The Abbey of St. Markovia, the bell tower | Climb into the bell tower (Athletics DC 15) | finds a little chime hung inside the great bell (Chime of Opening) | 2d6 bludgeoning damage |
| ✅ | The Abbey of St. Markovia, the barred windows of the wards | Watch through the bars unseen (Stealth DC 14) | finds a child's hidden treasure under the cots (Figurine of Wondrous Power (Golden Lions), The Wards of St. Markovia); codex: The Belviews | one try for the party |
| ✅ | The Abbey Garden, a scarecrow with a stitched mouth | Unpick the scarecrows' binding (Arcana DC 15) | the scarecrows stay on their poles: no fight (garden_sentry waits on flag.abbey_scarecrows_unbound) | — |
| ✅ | The Church of St. Markovia, a small pipe organ | Play the little organ (Performance DC 14) | Heroic Inspiration | — |
| ✅ | The Wards of St. Markovia, a basin and instruments | Study the surgeon's instruments (Medicine DC 14) | finds a false back in the instrument cabinet (Periapt of Proof against Poison); codex: The Abbot's surgery | — |

### Yester Hill (level 7)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Yester Hill, old grave mounds | Read the barrow stones (History DC 14) | finds something in the barrow mound (Amulet of the Devout, +2); codex: The barrows of Yester Hill | — |
| ✅ | Yester Hill, a cairn of bones | Examine the bones in the cairn (Medicine DC 14) | finds something under the bone cairn (Bracers of Archery) | — |
| ✅ | Yester Hill, the view east | Look east from the hilltop (Perception DC 13) | finds something dropped between the vines (Moon Sickle, +1, The Wizard of Wines) | — |

### Argynvostholt (level 8)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Argynvostholt, a well | Climb down to the ledge in the well (Athletics DC 15) | finds something on a ledge down the well (Cube of Force) | 2d6 bludgeoning damage |
| ✅ | Argynvostholt, small headstones | Read the squires' headstones (History DC 14) | finds something left on a squire's grave (Holy Symbol (Emblem)) | — |
| ✅ | Argynvostholt, the frost scar | Study the frost scar (Arcana DC 15) | codex: The frost scar | — |
| ✅ | Argynvostholt, Ground Floor, the chapel altar | Pray at the dragon's altar (Religion DC 15) | finds a reliquary behind the chapel altar (Amulet of the Devout, +2) | — |
| ✅ | Argynvostholt, Ground Floor, armour stands | Shift the armour stands (Athletics DC 14) | finds a sword behind the armour stands (Flame Tongue) | — |
| ✅ | Argynvostholt, Upper Floor, burned bookcases | Search the burned books for a spell (Arcana DC 15) | spell_scroll__dispel_magic | — |
| ✅ | The Beacon Tower, the parapet, facing the valley | Look out over the valley (Perception DC 15) | finds something under the jetty's boards (Ring of Water Walking, Lake Zarovich: the Fishers' Landing) | — |

### Van Richten's Tower (level 8)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Van Richten's Tower, a lookout rock | Watch the lake from the lookout rock (Perception DC 14) | finds a satchel wedged behind the lookout rock (Eyes of the Eagle) | — |
| ✅ | Van Richten's Tower, ezmerelda's campfire | Read the tracks around the camp (Survival DC 14) | finds a tripwire at the wagon step | — |
| ✅ | Van Richten's Tower, jars and bottles | Sort the hunter's remedies (Medicine DC 15) | finds a flask among the jars that isn't labelled (Oil of Etherealness) | — |
| ✅ | Van Richten's Tower, a wall of trophies | Read the trophies (Survival DC 15) | finds a clip behind one of the trophies (Wand of Binding); codex: The hunter's trophies | — |

### The werewolf den (level 8)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | The Hills above Lake Zarovich, a patch of purple flowers | Name the purple flowers (Nature DC 13) | codex: Wolfsbane | — |
| ✅ | The Hills above Lake Zarovich, a heap of bones | Sort through the bones (Medicine DC 14) | 30 gold | — |
| ✅ | The Werewolf Den, bundles of drying herbs | Sort the drying herbs (Nature DC 14) | finds a flask in the drying herbs (Elixir of Health) | — |
| ✅ | The Werewolf Den, kiril's trophies | Read Kiril's trophies (Survival DC 15) | finds a sword among Kiril's trophies (Sword of Wounding) | — |

### Lake Zarovich (level 8)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Lake Zarovich: the Fishers' Landing, a fishers' shrine | Pray at the fishers' shrine (Religion DC 13) | finds something behind the fishers' shrine (Trident of Fish Command) | — |
| ✅ | Lake Zarovich: the Fishers' Landing, a flat rock above the water | Dive from the flat rock (Athletics DC 13) | 25 gold | 1d4 cold damage |
| ✅ | Lake Zarovich: the Fishers' Landing, bluto's rowboat | Swing under the jetty from the boat (Acrobatics DC 13) | finds something under the jetty's boards (Ring of Water Walking) | 1d4 cold damage |

### Mount Baratok and the Tsolenka Pass (level 9)

| | Where | Check | Success | Failure |
|---|---|---|---|---|
| ✅ | Mount Baratok, a cairn on the summit | Unpick the ward round the cairn (Arcana DC 16) | disarms baratok_ward | 2d8 lightning damage; one try for the party |
| ✅ | The Tsolenka Pass, bones on the shelf | Examine the roc's leavings (Medicine DC 15) | finds a traveller the roc dropped (Wings of Flying) | — |
| ✅ | The Tsolenka Pass, carved faces | Read the carved faces (History DC 15) | codex: The watch at Tsolenka | — |
| ✅ | The Tsolenka Pass, a wayside shrine | Pray at the wayside shrine (Religion DC 14) | Heroic Inspiration | — |
| ✅ | The Tsolenka Pass, the gorge | Edge out along the rocks over the gorge (Acrobatics DC 14) | finds a feather as long as a man, caught on the rocks (Feather Token (Bird)) | 2d6 bludgeoning damage |
| ✅ | The Tsolenka Guard Tower, a table with dice | Win a hand at the watch's dice (Sleight of Hand DC 15) | 40 gold | — |
| ✅ | The Tsolenka Guard Tower, the watch roster | Sign the roster as the relief watch (Deception DC 15) | unlocks captains_strongbox; Heroic Inspiration | 1d6 cold damage; one try for the party |
