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
