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
- `narrative/banter/guest_<npc>.dialogue` — a guest's own lines while travelling with the party (story/banter.gd): one
  line a node, named for when it may play: `quest_` and `place_` on entering an area (their own story's first),
  `fight_` on the first step after a won fight (now and then), `idle_` after a long quiet walk. Each plays once.

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
                                   goes to ok_node with check.last = false). Before a skill's roll, whoever in the
                                   party can cast Guidance is offered it (a `guidance` beat the game's screen
                                   answers with answer_guidance(); story/guidance_offer.gd), as before `check`.
                                   A failed Persuasion, Intimidation, Deception, Performance or Insight option is
                                   spent (owner rule, 2026-10-06): it never shows again, in this conversation or
                                   later (saved). So a menu must never depend on one such check: give another way
                                   on (another skill, an offer, a price, a fight, or simply moving on). Where it
                                   fits the scene, failure should cost something: a cooler `attitude`, a flag that
                                   closes a door or raises a price, a fight, an alarm, lost time or gold. `make
                                   validate` enforces it (tools/data/fail_routes.py): walk the conversation with every
                                   roll failed, and a side quest's stage must still be reachable; a choice between
                                   two endings is fine, and an exception goes in that file's ALLOWED with its reason.
* [if <condition>] Text -> node    Shown only when the condition holds.
* [ends:<quest>] Text -> node      Choosing it closes that quest (the next lines move it to an ending). The menu draws a
                                   broken seal in the Failed pill's rose on the option, its tooltip and the line under the
                                   menu say "Ends <quest name>" (addons/dnd_core/ui/dialogue/dialogue_ui.gd, QuestEndMark). Several may
                                   stand together: `[ends:a] [ends:b]`. `[ends:<quest> if <condition>]` marks it only while
                                   the condition holds (use it where the same option closes the quest in some states and not
                                   others: `[ends:the_dancing_bear if flag.tser_pool_brawl_won]`); a quest that has ended
                                   already is never marked. A menu whose every option closes the same quests (two or more
                                   options) is a story beat, not a choice, and wears no seals (DialogueRunner.MARK_UNIFORM_MENUS). A walk-away that starts one of the quest's `closes` rules may carry
                                   it too. Side Quest Failure Plan rule 4: no failure the player couldn't have seen coming.
                                   `make validate` enforces it (tools/data/option_ends.py): follow each option to the next menu
                                   (jumps and `check` lines, optimistic about `if`s; a roll takes its success branch only, since
                                   a failed roll never closes a quest), and an option that reaches a side or companion quest's
                                   failure ending without the tag, or that carries a tag and reaches none of that quest's
                                   endings, fails. Main-story quests are left alone; an exception goes in that file's ALLOWED.
* [Cleric] Text -> node            Shown only if a party member is a Cleric; that character speaks it. Also
                                   [Elf], [Criminal] (background), [tag:blunt] and [knows:remove_curse] (a spell that character can cast
                                   now; the option text should name it).
appear <npc> [at <id>]             The npc steps onto the map for this scene: beside the door, prop, container or exit
                                   with that id, or a few squares from the party. Gone when the conversation ends.
vanish <npc>                       ...or before, here (he melts into mist at the gate).
lead <npc> to <where>              The party follows <npc> to <where> (docs/story/leads_and_guests.md). <where> is a door,
                                   prop, container, exit or area id on this map (the figure walks there and the party's
                                   figures follow in marching order, a click or Esc skips the walk), or `x,y` (that square),
                                   or another place: a location id, `location_id` or `location_id:spawn` (a prompt asks
                                   "Follow now" or "Come back later"; following walks to the way out, changes place and
                                   brings <npc> beside the party, and the conversation carries on there until it ends,
                                   when they step out of the scene like anyone `appear` brought). `check.last` says whether
                                   the party went (always true on this map). Nothing moves a flag: put the `set`s that must
                                   wait for the party behind `if check.last`, and keep the conversation's way out on both
                                   branches (declining leaves the NPC where they are, to be asked again). A lead into a
                                   place that fights on arrival must have its flags set first (Zuleika's pact does).
-> node                            Jump. "-> END" ends the conversation; "-> file:node" jumps to another file.
if <condition>                     Conditional block, closed by "endif" ("elif <condition>" and "else" allowed).
set flag_id                        Sets a flag to true. "set flag_id = 3", "set flag_id = \"string\"",
                                   "set flag_id += 1". "set flag_id = now" stamps the game minute into the flag, the
                                   start of a clock that `days_since.flag_id` counts from (register it as an int).
                                   Setting it again restarts the clock: guard with `if not flag.flag_id` to keep the first.
quest quest_id stage_id            Moves a quest to a stage (data/quests/<id>.json). The notice says how it moved:
                                   "Quest failed: X" into a stage that ends in failure, "Quest complete: X" into one that
                                   ends in success (with its XP in Experience mode), else "Journal updated: X". A quest at
                                   a failure ending moves only to the stages that ending names in `then` (a comeback);
                                   any other `quest` line for it is ignored (docs/story/side_quests.md, How a side quest fails).
give item_id [qty]                 Puts items in the speaking character's pack (or the party stash if full).
                                   "give item_id to name:thistle" puts it in that party member's pack instead.
take item_id [qty]                 Removes items.
gold +25 / gold -10                Party money in gp.
attitude npc_id friendly           Sets an NPC's attitude (hostile, indifferent, friendly; 2024 Influence).
xp milestone                       Milestone advancement: every party member may level up (plan §5.6). In XP levelling it
                                   also pays the High award, lifts the party to the story's level and pays what the ceiling
                                   held back (story/xp.gd).
xp fight <encounter id>            A fight a conversation put an end to for good (talked down, tricked, bargained away):
                                   in XP levelling it pays what winning that fight would, once. Put it before any `set`
                                   that changes which version of the fight the party would have met (its `when`). Nothing
                                   in milestone mode.
sacrifice                          The player picks a living party member, who dies for good and leaves the
                                   party (StoryState.fallen keeps their name). Skipped if only one is alive. The
                                   last option backs out ("No one. Not this."): check.last is false after it, true
                                   after a pick, so the node can return to its menu.
reading draw                       Draws Madam Eva's reading (once per playthrough; docs/contracts/campaign.md).
reading read tome [speaker]        Turns the card for a slot (tome, symbol, sword, ally, enemy): a notice with
                                   the card, then the verse spoken by `speaker` (default madam_eva).
reading give <place>               Hands the party the treasures the campaign's reading hid at that place
                                   (CampaignModule.take_from). (Renamed from `tarokka ...` when the engine moved into
                                   dnd_core: the engine names no campaign, the module decides what a reading is.)
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
move location[:spawn]             The party goes to a location's spawn ("move vault" is its default spawn, as for an exit
                                   that names none), also another spawn of the map it is in: a trap's drop from cell to
                                   cell. Like `combat` it ends the conversation, so `time +n` and the Narrator's lines
                                   come before it and nothing after it in the node runs. Once the conversation has closed
                                   the party goes as through an exit, behind the same loading cover, and the place does
                                   what it does for any arrival: its `enter:` Narrator line (a flag set before the move
                                   can pick a variant), its autosave, a fight whose area they land in. The location is a
                                   data/locations id (not a travel place); `make validate` fails on one that does not
                                   exist or a spawn it does not have. Not for camp talks.
narrate trigger_key                Plays a Narrator trigger (below) inline.
cast speak_with_dead               The one speaking for the party casts an exploring spell in the scene (story/
                                   field_casting.gd): as a Ritual when it is one, else a feature's free casting or their
                                   lowest slot; if they can't, whoever in the party can, who then speaks. check.last
                                   says whether it worked, and a notice says what it cost or why not. A casting still
                                   running (cast from the character sheet) needs no new one. Put it behind an option
                                   tagged [knows:<spell>], with an [if spell:<spell>] option for that earlier casting.
reveal oak_raven_hoard             A hidden find (a search prop in a location, docs/story/found_magic_items.md) shows
                                   itself as if searched out: someone told the party where it is (a Tip). A notice,
                                   once; nothing if it was found already. A trap's id works the same way: the trap
                                   shows as found (someone warned of it), unless it was found or dealt with already.
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
`background:acolyte`, `tag:pious`, `item:holy_symbol_amulet` (anyone carries it; `item:spell_scroll_level_1` and `item:spell_scroll_cantrip` mean any Spell Scroll of that level, since a scroll is always carried as a particular spell, and `take spell_scroll_level_1` takes one), `quest.<id> == stage_id`,
`quest_days.<id> >= 3` (whole days since the quest last moved to its current stage; false before the quest begins),
`days_since.<flag> >= 2` (whole days since the flag was stamped with `set <flag> = now`; false while it hasn't been),
`attitude.<npc> == friendly`, `visited:<location_id>`, `night`, `day`, `indoors` (the party's map is under a roof or
a dungeon; a night's line written for sleeping behind walls carries it, so a camp out of doors skips it), `hour >= 20`,
`tarokka.drawn`,
`tarokka.sword == swords_3`, `tarokka.sword.region == vallaki`, `tarokka.ally.npc == ezmerelda`, `guest:ireena`,
`spell:speak_with_dead` (an exploring spell the party cast is still running), `at:vallaki_st_andrals` (where the party is), `region:castle_ravenloft` (anywhere in that region), `option:respec` (the owner's
switch), and `interject guest:ireena: Text` for a story ally travelling with the party,
`approval.thistle >= close` (a companion's approval tier, compared by rank, so `<= strained` is Strained or worse;
or a number), `attention >= marked` (Strahd's attention: a number or a tier from data/strahd/attention.json, F9),
`gifted:liriel_dawnsong` (that hero, by pregen id, has taken a dark gift), `fallen:thistle` (that hero is lost for good: the
altar beneath Death House or the Deck of Many Things), `gold >= 25` (the party's purse), `level >= 3`
(the lowest character level in the party), `leader:name:thistle` (the one speaking for the party matches the selector
after `leader:`; `name:thistle and not leader:name:thistle` is Thistle when she isn't the one speaking),
`hero_named:vesper` (any party member is called that, whoever is speaking: it reads the name a player typed for a custom
hero; case doesn't matter, the whole name or its first word will do, so `vesper` is "Vesper Brightwater", and `_` stands
for a space: `hero_named:vesper_brightwater`; use it only for a variant or a wink, never to gate the story),
`check.last` (the last check succeeded), joined with `and`, `or`, `not`
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
- `[once]` / `[once and <condition>]` on a variant: that one line plays a single time a playthrough (remembered in the
  save, by its text), then drops out and the trigger's other lines carry on. Until it has played, and while its
  condition holds, it comes before every other line (conditioned ones too), so a one-off plays as soon as its moment
  comes; with several unplayed at once, one of them is picked and the rest wait their turn. It is the way to give a
  trigger a one-off line without silencing the trigger afterwards, which is what the node-level `once` does. `once` only leads the brackets; `[flag.x and once]` and
  `[once or flag.x]` are errors (`make validate`).

```
~ rest:long:some_inn
| [once and flag.some_flag] A line that plays one time, once the flag is set.
| [once] A line that plays one time, the first time the trigger fires.
| A plain line, which carries on after both.
```

Trigger keys the game sends: `enter:<location_or_area_id>`, `examine:<prop_id>`, `search:<prop_id>`,
`check:<skill>:success|failure` (and `check:<skill>:<prop_id>:success|failure`), `check:unlock:success|failure` (a lock
picked or forced; `check:unlock:stubborn` instead of the failure at the fifth failed try at one lock, `check:unlock:at_last`
instead of the success when a lock gives after five; both `once`, in narrator/death_house.dialogue), `trap:<trap_id>:found|triggered`,
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
