# Dialogue and Narrator files (ADR 0008)

Conversations, the Narrator, party interjections and quest beats are plain-text `.dialogue` files under
`narrative/` (plan §5.4, §5.7). `story/` parses and runs them; `tools/data/validate_dialogue.py` checks them in
`make validate` (every node a jump names exists, every flag read is set somewhere and registered in
`data/flags/<region>.json`, every speaker, item, quest, check and encounter exists).

The format is our own, close in spirit to the Dialogue Manager addon the plan first named, so writers can learn it in
a minute and the validator can read it without Godot.

## Files

- `narrative/<region>/<npc_or_scene>.dialogue` — conversations. Start a conversation at a node: `death_house/rose_thorn:start`.
- `narrative/narrator/<region>.dialogue` — Narrator lines keyed by trigger (below).
- `narrative/banter/<region>.dialogue` — party banter while exploring.

## Grammar (one statement per line; indentation is ignored; `#` starts a comment)

```
~ node_id                          A node. Ids: lower_snake_case, unique in the file.
Speaker: Text                      A line. Speaker = an npc id from data/npcs (shown by its name and portrait),
                                   "Narrator", or "Player" (the character currently speaking for the party).
Speaker [mood]: Text               Picks a portrait expression (neutral, smile, angry, afraid, sad, sly).
* Option text -> node              A player option. Options collected after the last line form one menu.
* [Persuasion DC 14] Text -> ok_node | fail_node
                                   A skill check option. It rolls in the open with the speaking character's
                                   bonus (Advantage and Heroic Inspiration apply). Skills: any of the 18, or an
                                   ability (Strength ... Charisma). "| fail_node" may be left out (then failure
                                   goes to ok_node with check.last = false).
* [if <condition>] Text -> node    Shown only when the condition holds.
* [Cleric] Text -> node            Shown only if a party member is a Cleric; that character speaks it. Also
                                   [Elf], [Criminal] (background) and [tag:blunt].
-> node                            Jump. "-> END" ends the conversation; "-> file:node" jumps to another file.
if <condition>                     Conditional block, closed by "endif" ("elif <condition>" and "else" allowed).
set flag_id                        Sets a flag to true. "set flag_id = 3", "set flag_id = \"string\"",
                                   "set flag_id += 1".
quest quest_id stage_id            Moves a quest to a stage (data/quests/<id>.json).
give item_id [qty]                 Puts items in the speaking character's pack (or the party stash if full).
take item_id [qty]                 Removes items.
gold +25 / gold -10                Party money in gp.
attitude npc_id friendly           Sets an NPC's attitude (hostile, indifferent, friendly; 2024 Influence).
xp milestone                       Milestone advancement: every party member may level up (plan §5.6).
sacrifice                          The player picks a living party member, who dies for good and leaves the
                                   party (StoryState.fallen keeps their name). Skipped if only one is alive.
tarokka draw                       Draws Madam Eva's reading (once per playthrough; docs/contracts/campaign.md).
tarokka read tome [speaker]        Turns the card for a slot (tome, symbol, sword, ally, enemy): a notice with
                                   the card, then the verse spoken by `speaker` (default madam_eva).
shop                               Opens the shop of the NPC being spoken to; the conversation resumes after.
join ireena / leave ireena         A story ally joins or leaves the party as a guest (ADR 0010).
check Skill DC n -> ok | fail      A check with no choice (e.g. a passive moment). Uses the best party member.
interject <selector>: Text         A party member matching the selector says Text, if one is present (the first
                                   match in marching order): class:rogue, species:elf, background:criminal,
                                   tag:blunt, name:tamsin_tealeaf. Write class/species lines so any such character
                                   could say them; use name: for a pregen's own voice.
combat encounter_id                Ends the conversation and starts a fight from the location's encounters.
narrate trigger_key                Plays a Narrator trigger (below) inline.
```

## Conditions

`flag.<id>` (truthy), `not flag.<id>`, `flag.<id> == 3` / `!= >= <= > <`, `class:cleric`, `species:elf`,
`background:acolyte`, `tag:pious`, `item:holy_symbol_amulet` (anyone carries it), `quest.<id> == stage_id`,
`attitude.<npc> == friendly`, `visited:<location_id>`, `night`, `day`, `hour >= 20`, `tarokka.drawn`,
`tarokka.sword == swords_3`, `tarokka.sword.region == vallaki`, `tarokka.ally.npc == ezmerelda`, `guest:ireena`,
`spell:speak_with_dead` (an exploring spell the party cast is still running),
`gold >= 25` (the party's purse), `level >= 3`
(the lowest character level in the party), `check.last` (the last check succeeded), joined with `and`, `or`, `not`
and parentheses.

`gold -N` never takes the purse below zero: guard a purchase with `[if gold >= N]` and offer a "can't afford" line.

## The Narrator

The Narrator speaks in second person, present tense, one or two sentences (plan §5.7, docs/voice/narrator.md).
In `narrative/narrator/<region>.dialogue`, each node is a trigger and each `|` line is one variant:

```
~ enter:death_house_foyer
| The door shuts behind you with a satisfied click.
| [class:rogue] {name} notes the hinges: oiled. Someone wanted this door to open for you.
cooldown 0

~ combat:crit
| [class:fighter] Steel answers steel, and steel wins.
| The blow lands like a verdict.
cooldown 3
```

- `{name}` is the acting character's first name, `{target}` the target's name.
- A variant with a `[condition]` prefix is only eligible when it holds; the most specific eligible variants win
  (conditioned before plain), and the game avoids repeating a variant until the others have played.
- `cooldown n` (minutes outside combat, rounds in combat): the trigger won't play again sooner. `once` plays it only
  the first time.

Trigger keys the game sends: `enter:<location_or_area_id>`, `examine:<prop_id>`, `search:<prop_id>`,
`check:<skill>:success|failure` (and `check:<skill>:<prop_id>:success|failure`), `trap:<trap_id>:found|triggered`,
`rest:short`, `rest:long`, `dream:<id>`, `combat:start`, `combat:crit`, `combat:nat1`, `combat:fall`,
`combat:kill`, `combat:victory`, `death:<character>`.

## Example

```
~ start
Ismark [weary]: Strangers, in Barovia. Either a miracle or a mistake.
interject class:cleric: I've been called both. Usually by the same priest.
* Who are you? -> who
* [Insight DC 12] He's afraid of something. -> afraid | afraid_missed
* [if flag.read_strahd_letter] We read the burgomaster's letter. -> letter
* Goodbye. -> END

~ afraid
Narrator: His smile holds, but his hand never leaves his sword hilt.
set ismark_fear_noticed
-> who
```
