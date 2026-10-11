# Skill checks in the world

Owner ask (2026-10-09, repeated 2026-10-11): more skill checks outside fights and conversations. Before this, only
Perception and Investigation (Search), Sleight of Hand (pockets), Stealth, Athletics (forcing a door, a pit) and thieves'
tools had uses out there, which left Nature, Arcana, Acrobatics and most of the rest with nothing to do between
conversations. Goal: every skill has real uses in the world.

## How it works (story/world_checks.gd, world/exploration/location_checks.gd)

A prop, door or chest in a location can carry `checks` (data/schemas/location.schema.json, `$defs/check`). Each one:

- **Shows on the right-click menu** of its thing: "Read the claw marks (Survival DC 13: Thistle +5 with Advantage, 80%)".
  The tooltip says who helps and how. The thing's hover name (and its Alt plate) adds the skills it still offers,
  "Examine Clawed walls (Survival)", and a left click on it says "Right-click it to try Survival".
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

(The first batch follows with its own section per region.)
