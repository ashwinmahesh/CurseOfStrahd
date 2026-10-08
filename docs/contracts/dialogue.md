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
                                   "Narrator" (art/portraits/narrator.png), or "Player" (the character currently
                                   speaking for the party). A roll shows the portrait of whoever makes it.
Speaker [mood]: Text               Picks a portrait expression (neutral, smile, angry, afraid, sad, sly).
Speaker [away]: Text               The speaker turns their back on the other side for this line (busts,
                                   docs/ui/busts.md); with a mood: [sad, away]. On a Narrator line [away] turns
                                   the one being spoken to and [away:party] the party's speaker, until they speak.
* Option text -> node              A player option. Options collected after the last line form one menu.
* [Persuasion DC 14] Text -> ok_node | fail_node
                                   A skill check option. It rolls in the open with the speaking character's
                                   bonus (Advantage and Heroic Inspiration apply). Skills: any of the 18, or an
                                   ability (Strength ... Charisma). "| fail_node" may be left out (then failure
                                   goes to ok_node with check.last = false).
                                   A failed Persuasion, Intimidation, Deception, Performance or Insight option is
                                   spent (owner rule, 2026-10-06): it never shows again, in this conversation or
                                   later (saved). So a menu must never depend on one such check: give another way
                                   on (another skill, an offer, a price, a fight, or simply moving on). Where it
                                   fits the scene, failure should cost something: a cooler `attitude`, a flag that
                                   closes a door or raises a price, a fight, an alarm, lost time or gold.
* [if <condition>] Text -> node    Shown only when the condition holds.
* [Cleric] Text -> node            Shown only if a party member is a Cleric; that character speaks it. Also
                                   [Elf], [Criminal] (background), [tag:blunt] and [knows:remove_curse] (a spell that character can cast
                                   now; the option text should name it).
appear <npc> [at <id>]             The npc steps onto the map for this scene: beside the door, prop, container or exit
                                   with that id, or a few squares from the party. Gone when the conversation ends.
vanish <npc>                       ...or before, here (he melts into mist at the gate).
-> node                            Jump. "-> END" ends the conversation; "-> file:node" jumps to another file.
if <condition>                     Conditional block, closed by "endif" ("elif <condition>" and "else" allowed).
set flag_id                        Sets a flag to true. "set flag_id = 3", "set flag_id = \"string\"",
                                   "set flag_id += 1".
quest quest_id stage_id            Moves a quest to a stage (data/quests/<id>.json).
give item_id [qty]                 Puts items in the speaking character's pack (or the party stash if full).
                                   "give item_id to name:thistle" puts it in that party member's pack instead.
take item_id [qty]                 Removes items.
gold +25 / gold -10                Party money in gp.
attitude npc_id friendly           Sets an NPC's attitude (hostile, indifferent, friendly; 2024 Influence).
xp milestone                       Milestone advancement: every party member may level up (plan §5.6).
sacrifice                          The player picks a living party member, who dies for good and leaves the
                                   party (StoryState.fallen keeps their name). Skipped if only one is alive. The
                                   last option backs out ("No one. Not this."): check.last is false after it, true
                                   after a pick, so the node can return to its menu.
tarokka draw                       Draws Madam Eva's reading (once per playthrough; docs/contracts/campaign.md).
tarokka read tome [speaker]        Turns the card for a slot (tome, symbol, sword, ally, enemy): a notice with
                                   the card, then the verse spoken by `speaker` (default madam_eva).
shop                               Opens the shop of the NPC being spoken to; the conversation resumes after.
services                           Opens the services of the NPC being spoken to (a temple's spells, an inn's
                                   rooms; story/services.gd); the conversation resumes after.
join ireena / leave ireena         A story ally joins or leaves the party as a guest (ADR 0010).
time +60 / time until 12           Time passes in the scene (minutes), or until the given hour comes round.
respec                             The player picks a party member to rebuild from level 1 in the creator (they
                                   keep their belongings and level back up with milestones; a prebuilt hero keeps
                                   their look). Skipped when the owner switched respec off (pause menu). The last
                                   option ("Never mind") and the creator's Back both leave check.last false;
                                   a finished rebuild leaves it true.
check Skill DC n -> ok | fail      A check with no choice (e.g. a passive moment). Uses the best party member.
interject <selector>: Text         A party member matching the selector says Text, if one is present (the first
                                   match in marching order): class:rogue, species:elf, background:criminal,
                                   tag:blunt, name:thistle, knows:remove_curse (can cast it now). Write
                                   class/species lines so any such character could say them; use name: for a
                                   pregen's own voice.
combat encounter_id                Ends the conversation and starts a fight from the location's encounters.
narrate trigger_key                Plays a Narrator trigger (below) inline.
cutscene cutscene_id               A full-screen picture (data/cutscenes/<id>.json, docs/ui/cutscenes.md) under the
                                   lines that follow, which read as captions on it; the box comes back over it for
                                   options and notices. Skipped when none of its pictures' conditions hold.
                                   "cutscene end" takes it away (so does the conversation's end).
end_game                           Ends the campaign (ADR 0014): the ending whose condition holds is played
                                   when the conversation closes (docs/contracts/campaign.md Endings).
approve thistle +3 kip_smudgewick -2: You freed the wolves
                                   Companion approval (docs/story/approval.md): each companion id with a signed
                                   change (-20 to +20), then an optional reason after a colon, written as the
                                   companion's memory of what the party did. Only companions travelling in the party
                                   react; each statement counts once a playthrough. Shows a notice.
inspire name:thistle: spoke her mind
                                   Heroic Inspiration for playing in character (F15): the first party member the
                                   selector picks earns it (name:, class:, background:, species:, tag:), or everyone
                                   with `inspire party`. Once a playthrough. Shows a notice.
```

## Conditions

`flag.<id>` (truthy), `not flag.<id>`, `flag.<id> == 3` / `!= >= <= > <`, `class:cleric`, `species:elf`,
`background:acolyte`, `tag:pious`, `item:holy_symbol_amulet` (anyone carries it), `quest.<id> == stage_id`,
`attitude.<npc> == friendly`, `visited:<location_id>`, `night`, `day`, `hour >= 20`, `tarokka.drawn`,
`tarokka.sword == swords_3`, `tarokka.sword.region == vallaki`, `tarokka.ally.npc == ezmerelda`, `guest:ireena`,
`spell:speak_with_dead` (an exploring spell the party cast is still running), `at:vallaki_st_andrals` (where the party is), `option:respec` (the owner's
switch), and `interject guest:ireena: Text` for a story ally travelling with the party,
`approval.thistle >= close` (a companion's approval tier, compared by rank, so `<= strained` is Strained or worse;
or a number), `attention >= marked` (Strahd's attention: a number or a tier from data/strahd/attention.json, F9),
`gold >= 25` (the party's purse), `level >= 3`
(the lowest character level in the party), `leader:name:thistle` (the one speaking for the party matches the selector
after `leader:`; `name:thistle and not leader:name:thistle` is Thistle when she isn't the one speaking), `check.last` (the last check succeeded), joined with `and`, `or`, `not`
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
- Voice-over (ADR 0013): a line is voiced by its exact text, so a line holding `{name}`, `{leader}` or `{target}`
  is never voiced, and editing a voiced line leaves it silent until `make voice` records it again.
- A variant with a `[condition]` prefix is only eligible when it holds; the most specific eligible variants win
  (conditioned before plain), and the game avoids repeating a variant until the others have played.
- `cooldown n` (minutes outside combat, rounds in combat): the trigger won't play again sooner. `once` plays it only
  the first time.

Trigger keys the game sends: `enter:<location_or_area_id>`, `examine:<prop_id>`, `search:<prop_id>`,
`check:<skill>:success|failure` (and `check:<skill>:<prop_id>:success|failure`), `trap:<trap_id>:found|triggered`,
`rest:short`, `rest:long` (and `rest:long:<location or region>` first), `dream:<id>`, `combat:start`, `combat:crit`, `combat:nat1`, `combat:fall`,
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
