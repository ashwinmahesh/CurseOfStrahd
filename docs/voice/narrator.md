# The Narrator — voice and style guide

The unseen storyteller who speaks for the world (plan §5.7). Lines live in `narrative/narrator/<region>.dialogue`,
keyed by triggers (docs/contracts/dialogue.md). This guide is for every writer who adds Narrator lines.

## Who the Narrator is

An old gothic storyteller who has watched a great many adventurers walk into Barovia and very few walk out. They are
not the party's enemy and not its friend. They are fond of the party the way a gravedigger is fond of the weather:
with interest, without illusions. They never gloat over a failure and never cheer a success. They notice.

## The rules

1. **Second person, present tense.** "You step inside." Never "the party steps inside", never past tense.
   When a line is about one character, use `{name}`: "{name} catches the glint first."
2. **One or two sentences.** The second sentence is usually the turn: the irony, the dread, the joke.
3. **Ominous, dryly funny, never cruel.** The world is cruel; the Narrator isn't. Laugh at the house, the dark,
   the situation, never at the player for a bad roll or a death.
4. **No facts the party hasn't earned.** The Narrator describes what the characters can perceive. Hidden things are
   revealed only by a successful check (`check:` triggers) or an earned discovery.
5. **No modern slang, no winks at the player, no game terms.** Not "HP", not "roll", not "level". Dice results are
   described as what happened in the world: "Your fingers find the catch" rather than "you passed".
6. **Concrete senses over adjectives.** A smell, a sound, a temperature. "Cold" is a word; "your breath fogs indoors"
   is a scene.
7. **Death House is scary first.** In the scariest places (Death House, the Abbey, the Amber Temple) the humor gets
   thinner and drier, and some lines carry no joke at all. Silence is a tool.
8. **Combat is fast.** Combat lines (`combat:*`) are one sentence, under 15 words, and rare (`cooldown` 3+ rounds).
9. **Variety.** Common triggers get two or more variants. Add `[class:...]`, `[species:...]`, `[background:...]`,
   `[tag:...]` or `[name:...]` variants so the world reacts to who is acting; remember the engine prefers an
   eligible conditioned variant over plain ones, so condition only what is genuinely specific.
10. **Respect the dead.** The Narrator can be wry about a corpse's furniture choices, never about the corpse.

## Triggers and how to write each

| Trigger | Length | Notes |
|---|---|---|
| `enter:<location>` | 1-2 sentences | First sight of a place. Set a mood and one detail worth walking toward. Use `once` for rooms; use a `cooldown` for whole floors that the party re-enters, so story flags can change the line later. |
| `enter:<area>` | 1-2 sentences | A room. One sensory detail, one hint of what to examine. |
| `examine:<prop>` | 1-2 sentences | What the object is, and what it implies. The second sentence is the payoff. |
| `search:<prop>` | 1 sentence | The moment of finding the hidden thing. |
| `check:<skill>:<prop>:success/failure` | 1 sentence | What the check *showed* (or failed to). A failure is never a dead end in the prose: it tells the player the world was not kind this time. |
| `trap:<id>:found/triggered` | 1 sentence | Found: the tell that gave it away. Triggered: the moment of impact, not the damage number. |
| `rest:short/long` | 1-2 sentences | The texture of resting somewhere unsafe. |
| `combat:*` | 1 short sentence | A crit, a natural 1, a fall, a kill. No gloating. |
| `death:<character>` | 2 sentences | Sincere. No joke. |

## Sample lines

**Locations**
- `enter:` "The road narrows, the trees lean closer, and the fog behind you thickens like a door swinging shut."
- `enter:` "The hall smells of beeswax and old smoke. Somebody kept this house beautifully, right up until they didn't."
- `enter:` "The stair winds down inside the walls, and the walls are warm. Houses are not supposed to be warm."
- `enter:` (after a dark choice) "The house is quiet now. It has the stillness of something that has been fed."

**Examine and search**
- `examine:` "A portrait of a handsome family. The painter gave everyone kind eyes; you suspect that was a commission."
- `examine:` "A crib, freshly made, with a blanket folded around nothing at all."
- `search:` "Behind the third shelf, your fingers find a seam that the dust has been politely ignoring."
- `examine:` (letter) "The handwriting is beautiful. The kind of beautiful that takes centuries of practice."

**Check results**
- `check:perception:success` "There: the floorboard ahead sits a finger's width too high. Something waits beneath it."
- `check:perception:failure` "The room keeps its secrets. It has had a great deal of practice."
- `check:insight:success` "The smile holds, but the eyes never leave the door. Whatever she fears is behind you."
- `check:arcana:failure` "The sigils mean something. They are very sure of it, even if you aren't."
- `[class:rogue]` `check:investigation:success` "{name} finds the catch where any decent burglar would have hidden it."

**Rests**
- `rest:short` "You sit with your backs to the wall. The wall, to its credit, stays a wall."
- `rest:long` "You sleep in shifts. Every watch hears the same footsteps upstairs, and every watch decides not to mention it."

**Combat moments**
- `combat:crit` "The blow lands like a verdict."
- `combat:nat1` "The house, somewhere, approves."
- `combat:fall` "{name} goes down, and the dark leans in to look."
- `combat:kill` "It stops. This time, it stays stopped."
- `combat:victory` "The silence that follows is yours. Keep it as long as you can."

**Death** (`death:<character>`)
- "{name} is gone. The house does not mark it, but you will, every time you count to four."

## Things the Narrator never does

- Tells the player what to feel ("you are terrified"). Show the cold; let them be terrified.
- Repeats an NPC's line or explains a joke.
- Uses "suddenly". Things in Barovia were always going to happen.
- Comments on game systems, saves, menus or the player's real-world choices.
