# Strahd's presence across the campaign (Phase 6, P6-03)

ADR 0014 "Strahd's presence" and "The parley". Strahd is the campaign's villain long before the party reaches his
castle: he watches, writes, visits at night, tests the party in a fight he leaves, comes for Ireena where she
shelters, and finally sends his black carriage with an invitation to dinner. Few visits, each one memorable, each
reacting to what the party has done. Voice: docs/voice/strahd.md (courteous, patient, possessive, menacing). All text is
our own words.

## Files

| File | What |
|---|---|
| `data/strahd/visits.json` (schema `data/schemas/strahd_visits.schema.json`) | The visits: trigger, condition, once / cooldown / max, steps |
| `story/strahd_presence.gd` (`StrahdPresence`) | Pure logic: which visit is due, its steps in order, where its foes stand |
| `data/visits/<npc>.json` (schema `data/schemas/ally_visits.schema.json`) | Other characters' visits, the same engine: see "Ally visits" |
| `narrative/strahd/visits.dialogue` | The watcher, the night visit, the test of strength and its parting words |
| `narrative/strahd/letters.dialogue` | The first letter, the invitation and the black carriage |
| `narrative/strahd/ireena.dialogue` | The move against Ireena: the inn, Krezk, St. Andral's |
| `narrative/strahd/final.dialogue` | `strahd/final:parley`, the price he names before the final battle |
| `data/flags/strahd.json` | The flags below |
| `tests/unit/test_strahd_presence.gd` | Triggers, steps, placement, the conversations, the withdraw, the game's hooks, the ally visits and the bot's answer to one |
| `tests/support/ally_visit_answer.gd` (`AllyVisitAnswer`) | The story bot's exit from an ally visit's conversation |

## How a visit works

A visit (data/strahd/visits.json) has:

- **trigger** `on`: `arrive` (the party enters a location by an exit, the travel map or the carriage; not a reload),
  `rest` (a Long Rest finished on the rest screen), `travel` (a leg of a journey ends), or `days` (any of those).
  `days: n` (at least n whole days since the party entered Barovia, `StoryState.day - 1`), `night` (for a rest: the
  rest ran through any of the night), `outdoors`, `at` (location ids), `region`.
- **when**: a story condition (docs/contracts/dialogue.md).
- **once**, **cooldown_hours**, **max**; the file's **gap_hours** (12) keeps visits apart unless a visit is `urgent`.
- **Quiet places**: nothing happens in `quiet_regions` (the castle: its parts give him his lines there; Death House and
  the mists before the valley) or on holy ground in `quiet_at` (St. Andral's, the village church, the Pool of the
  White Sun, the abbey shrine, Madam Eva's tent) unless the visit names the place in `at`.
- **Steps**: `go` (`location[:spawn]`, the party is taken there), `narration`, then a `dialogue` or an `encounter`.
  After the dialogue, the first `then` entry whose `when` holds is the next step. An encounter is fought where the
  party stands (on the road: the road's random-encounter map); monsters without a `cell` are placed on open floor
  about four squares from the leader, reachable, with room for their size. Its `withdraw` block is ADR 0014's
  (`who`, `at_hp_below`, `after_rounds`, `flag`); when the fight is over and not lost, its `after` conversation plays.

Hooks (small calls into StrahdPresence): `world/game_root.gd` (`enter_location` → arrive, `travel` → each leg,
`strahd_after_rest`, and the steps after a conversation and after a fight) and `ui/screens/rest_screen.gd` (calls
`strahd_after_rest` when a Long Rest is done). A rest visit that may come to blows (`StrahdPresence.may_fight`: a
fight of its own or in its `then`) comes before the rest's benefits: story/long_rest.gd asks for it (`find`, which
doesn't mark it) as the night ends, the rest stays broken while he's there, and once his visit is over (his fight
won, or his words had without one) the party sleeps on, an hour more for a fight (the owner, 2026-10-13). A visit
of words only comes after the rest, as before. A visit on the road stops the journey like a road event; the journey
goes on when it's over (`StoryState.travel_resume`). Memory: `StoryState.flags["_strahd"]` (saved with the game).

## The visits

Every visit after the first waits for `strahd_watcher_seen`, so he is first seen, then heard from.

| Visit | Trigger | Condition | Limit | What happens |
|---|---|---|---|---|
| `watcher` | a leg of travel | `burgomaster_buried` or `strahd_met` | once | `strahd/visits:watcher`. A rider in black on a ridge above the road watches the party pass; wave, stare or walk on; bats lift off toward the castle. Ireena warns not to look. Sets `strahd_watcher_seen`. |
| `first_letter` | arriving outdoors, day 3 on | watcher seen | once | `strahd/letters:first`. A Vistani rider hands over a letter sealed with a Z: a host's welcome that knows the ridge, Death House, where Ireena is (with them, at the church, at the inn or in Krezk) and Madam Eva's reading. Burn it or keep it (`strahd_letter_kept`). |
| `night_visit` | a Long Rest through the night, day 4 on | watcher seen | once | `strahd/visits:night`. The one on watch wakes to find him beyond the firelight. Wake the others, ask what he wants, stand before Ireena, hold up a holy symbol, attack (mist), or Insight DC 16 (spent on failure): he looks at the mountains like a prisoner (`strahd_seen_trapped`, a parley line). Sets `strahd_night_visit`. Not on holy ground. |
| `test_of_strength` | a leg of travel at night | watcher seen, party level 7+ | once | `strahd/visits:test`. He walks out of the fog among wolves to see what they can do. Draw steel, or Persuasion DC 18 (spent; failure is the fight anyway): `strahd_test` = fought / talked. Fought: `strahd_test_of_strength` on the road (Strahd and two dire wolves), withdraw at 100 HP or after round 3, flag `strahd_withdrew`; then `test_after`, his words from the fog. |
| `ireena_at_the_inn` | arriving in Vallaki or at the Blue Water Inn, or resting there, at night, day 4 on | watcher seen, `ireena_sanctuary == "inn"`, Ireena not with the party | once, urgent | `strahd/ireena:inn` → the window (below). |
| `ireena_in_krezk` | the same in Krezk or the Krezkovs' house | watcher seen, `ireena_in_krezk`, not with the party | once, urgent | `strahd/ireena:krezk` → the window. |
| `ireena_at_the_church` | the same in Vallaki or St. Andral's | watcher seen, `ireena_sanctuary == "st_andrals"`, not with the party | once | `strahd/ireena:church`. The bell tolls by itself; he calls her from the churchyard gate and cannot come further. Holy ground holds. `strahd_window = "church"`. |
| `invitation` | arriving outdoors | watcher seen, party level 9+, not yet accepted | every 48 hours, up to 3 times, urgent | `strahd/letters:invitation`. A driverless black carriage waits with a dinner invitation that remembers the letter, the night visit and the road. Get in (`strahd_invitation = "accepted"`, 90 minutes pass, the party is taken to `castle_ravenloft_gates`), or decline / tear it up (`declined`; it comes back). Entering the castle never needs it. |

### The window (strahd/ireena)

Ireena stands at her open window, entranced; Strahd waits outside it, standing on nothing. Ways to stop him: raise
the Holy Symbol of Ravenkind (if carried), a Cleric or Paladin stands in the window, Religion DC 15 (a warding
prayer), Persuasion DC 15 (call her back to herself; spent on failure), or go for him (`strahd_window = "fight"`: the
visit's fight `strahd_at_the_window`, Strahd and a swarm of bats where the party stands, withdraw at 120 HP or after
round 2, flag `strahd_withdrew`, then `after_fight`). A failed prayer or plea costs a step (`strahd_window_pull`); at
two steps, or if the party lets her go, she goes with him: `ireena_held_by_strahd`, `strahd_window = "taken"`, and her
place flag is cleared (`ireena_sanctuary = "taken"` or `ireena_in_krezk = false`); a guarding Ismark wakes and joins
the party to bring her back. Saved, she may stay or rejoin the party (`vallaki/ireena:rejoin`, `krezk/ireena:rejoin`).
Taken, she can be found: in the castle chapel she stands at the altar, entranced, and the party wakes her the ways that
stop him at the window (`castle_ravenloft/chapel_ireena`, Story Allies Presence Plan package I5); waking her clears
`ireena_held_by_strahd` and she joins the party. The parley's "upstairs, dressing for dinner" is what he says while she
is still held (and the chapel hides her while the final battle waits there).

### The parley (strahd/final:parley)

Played by the engine before a final battle (ADR 0014). He greets the party and reacts to what they carry (the
Sunsword, the Holy Symbol, the Tome), to a fight he left (`strahd_withdrew`), the window fight, and Ireena (with them,
or upstairs dressing for dinner when he holds her). His price: Ireena given freely (only while she travels with the
party or he holds her), or kneel and serve, or fight. The answer is `strahd_parley`: `fight` (the battle starts),
`yield` (Strahd triumphant) or `ireena` (the bride). Optional lines: "You can't leave this valley either"
(`strahd_seen_trapped`), Insight DC 18 (spent on failure; never needed).

## Ally visits (data/visits/)

The engine also carries other characters' letters and road meetings (the Story Allies Presence Plan, package E1: Ireena's
letters, Izek taking her, Ezmerelda on the road). They are visits in every way above except who they are from and the
three differences below, so a courier's letter or a meeting on the road needs no engine of its own.

**Files.** One per character, `data/visits/<npc id>.json`: `id` (the NPC's id, which is also the file name), `summary` and
`visits`, each visit shaped as in `data/strahd/visits.json` (`data/schemas/ally_visits.schema.json` reuses its visit
definition). Lines go in a dialogue file of the character's own (`narrative/allies/`); the visit only names the
conversation. `StrahdPresence.data()` loads every file there after his visits, in name order, and marks each visit
`ally: true` (`StrahdPresence.is_ally`); the files don't say so, and the schema refuses an `ally` key, so no file can
make a visit Strahd's or the other way round. At an event his visits are asked first, then the allies', file by file.

**How an ally visit differs from his.**

| | His | An ally's |
|---|---|---|
| Hallow, Forbiddance, Private Sanctum, Nondetection (`Wards.hides_from_strahd`) | keep every visit but an `urgent` one away | don't matter: a friend isn't looking for the party through Strahd's eyes |
| His attention tier's `gap` (×0.85 down to ×0.5) | shortens his wait between visits | doesn't: the wait is the file's plain `gap_hours` (12), however much he has noticed |
| `last` visit | starts his wait | starts his wait: the one `last` is shared, so a letter and a vampire never come in the same breath, and either waits after the other |

Everything else is as for his visits: the trigger (`arrive`, `rest`, `travel`, `days`, `night`, `outdoors`, `at`,
`region`), `when`, `once` / `cooldown_hours` / `max`, `urgent` (which ignores the gap for an ally too, so use it for
what truly can't wait), the steps and `then`, a fight's `withdraw`, and the quiet places: `quiet_regions` (the castle,
Death House, the mists) and holy ground in `quiet_at` stay quiet for friends unless the visit's trigger names the place
in `at`. `fires()` is the same function for both. The game root's hooks (`_strahd`, `_strahd_on_road`,
`strahd_after_rest`, the steps after a conversation and a fight) and `LongRest` are unchanged: an ally's visit plays
through them, stops a journey on the road like his, and a rest visit that may come to blows (`may_fight`) breaks the
Long Rest the same way. The memory is the same `StoryState.flags["_strahd"]`, keyed by visit id.

**What `make validate` holds an ally visit to** (`ally_visit_checks`, tools/data/validate_data.py): the file is a
character's (`data/npcs/<id>.json` exists); the visit's id is unique across his file and every ally file (the game
remembers visits by id); it plays a conversation (`dialogue`, so the bot has something to answer); it is limited
(`once`, `max` or a `cooldown_hours` above 0, or it would come at every event); the places in `trigger.at` exist. The
checks every visit gets also cover the allies: conditions parse, conversations and nodes exist, a fight's monsters,
`withdraw` and `after` conversation, a `go` target and its spawn, and the flags the visit reads and sets are
registered. `story_reach` follows an ally visit's conversations as it does his (what a playthrough can reach), and
`make voice` finds a `withdraw.say` in these files too.

**The story bot.** An ally's letter is not a branch of the story the bot walks, so
`StoryBot.converse()` answers a conversation `StrahdPresence.ally_playing` says is an ally visit's by its exit
(`tests/support/ally_visit_answer.gd`): the last option that ends the conversation (`-> END`), else the last whose node
asks nothing more and starts no fight, shop or journey. An option with a skill check is never the exit, and the bot's
usual preferences don't apply inside a letter. The visits it answered are in `StoryBot.ally_visits`. A menu with no
such option is answered the usual way, so every ally conversation should have one (the project rule: every
conversation has an exit). A conversation the bot walks up to itself (a talk, a hub) is answered as before.

**Adding one.** Write the character's file (or add a visit to it), name its conversation, give it a limit, run
`make validate`, and answer it in the phase tests that could reach it (compare with main first: a visit that moves
where the party stands or what time it is can move a fight; close every conversation, since an unanswered letter
leaks an open prompt into logcheck). The first ally files are Ireena's (I3), Izek's (Z1) and Ezmerelda's (M1; `data/visits/ezmerelda.json`: three meetings on the road, words only. A travel leg cannot be told from another by a visit's trigger (`trigger.at` and `region` are empty on the road), so hers are `arrive` and `rest` visits at named open places, each once).

## His attention (F9, data/strahd/attention.json)

A hidden measure of how much he has noticed the party, never shown and never saved: `StrahdPresence.attention(st)`
adds the points of every mark whose condition holds now (his spawn and servants destroyed, the Gulthias tree burned,
the Sunsword, the Holy Symbol or the Tome carried, Ireena at their side, defying or striking him, holding Ireena's
window, refusing his carriage, making him leave a fight). Because it is worked out from the story, a save, an old save
or a mark taken back (he took Ireena after all) always reads true.

| Tier | From | Between visits | Roads (day / night) | What it brings |
|---|---|---|---|---|
| unnoticed | 0 | 12 h | +0 / +0 | |
| watched | 3 | ×0.85 | +0 / +5% | a bat at the shutters at a night's rest (`eyes_at_the_window`); his eyes on four roads (`strahds_eyes`, once each) |
| marked | 7 | ×0.65 | +5% / +10% | a raven with his list of grievances (`letter_of_grievance`); his wolves on the Svalich road, the woods and the vineyard road at night (`strahds_wolves`) |
| hunted | 12 | ×0.5 | +5% / +15% | his spawn and wolves at an outdoor camp at night, without him (`the_hunt`, twice at most, 72 h apart) |

Any condition can read it: `attention >= marked` (a tier) or `attention >= 7` (story/story_conditions.gd). Marks may not
read attention themselves (the validator checks). Lines: narrative/strahd/attention.dialogue.

## Flags (data/flags/strahd.json)

`strahd_watcher_seen`, `strahd_letter_read`, `strahd_letter_kept`, `strahd_night_visit` (woke, shield, warded,
attacked), `strahd_seen_trapped`, `strahd_test` (fought, talked), `strahd_withdrew`, `strahd_window` (symbol, faith,
ward, woke, fight, taken, church), `strahd_window_pull`, `ireena_held_by_strahd`, `strahd_invitation` (accepted,
declined), `strahd_parley` (fight, yield, ireena). Read from other regions: `burgomaster_buried`, `strahd_met`
(set by the night visit if he wasn't met before), `strahd_road_encounter`, `death_house_completed`,
`ireena_sanctuary`, `ireena_in_krezk`, `ismark_guards_ireena`, `ismark_in_krezk`.

## Critical path (test bots)

1. After the burial (`burgomaster_buried`), the first journey on the travel map meets the watcher on the road; any
   answer sets `strahd_watcher_seen`, and the journey goes on.
2. With the party's lowest level at 9 or more, the next arrival at an outdoor location outside the castle and holy
   ground (for example travelling to the Svalich crossroads or the village) plays `strahd/letters:invitation` (if
   the first letter is also due it plays first; the carriage follows at the next arrival, as it is urgent).
3. Choose "Get in.": `strahd_invitation = "accepted"`, and the party arrives at `castle_ravenloft_gates` (spawn
   `default`), where the gates part's dinner reads the flag.
4. Before the final battle the engine plays `strahd/final:parley`: "We came to end you." (fight), "We yield." or,
   with Ireena along or held, "Take her, then. Let us go." (ireena).

A bot that skips ahead can set `strahd_watcher_seen` and the party level directly, then arrive anywhere outdoors.

## Balance

The test of strength comes at level 7 or later, at night, on the road. Since 2026-10-13 (owner: "let him fight till
his HP goes to 0, but that's his signal to flee") he fights every visit until he's beaten, then goes with a parting
line (`withdraw.say`, in his own voice), and the fight waits for the line before it ends. Each is tuned so the sharp
test party, without the Sunsword, wins 5 of 8 at its level: the test of strength at his book 144 HP with two dire
wolves (level 7), the window at the Blue Water Inn at 110 HP (level 5) and at the Krezkovs' at 200 HP (level 7), each
with a swarm of bats (tests/integration/test_scaled_boss_fights.gd). Neither fight gives loot; leaving is not dying. (Retuned again on 2026-10-14: the boss fights are now 3 in 8 for the test party at full ability, so the Hit Points, helpers and win counts in this paragraph are the 5 in 8 ones; the current line-ups are in docs/story/boss_fights.md.)
