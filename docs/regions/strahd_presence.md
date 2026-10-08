# Strahd's presence across the campaign (Phase 6, P6-03)

ADR 0014 "Strahd's presence" and "The parley". Strahd is the campaign's villain long before the party reaches his
castle: he watches, writes, visits at night, tests the party in a fight he leaves, comes for Ireena where she
shelters, and finally sends his black carriage with an invitation to dinner. Few visits, each one memorable, each
reacting to what the party has done. Voice: docs/voice/strahd.md (courteous, patient, amused, menacing). All text is
our own words.

## Files

| File | What |
|---|---|
| `data/strahd/visits.json` (schema `data/schemas/strahd_visits.schema.json`) | The visits: trigger, condition, once / cooldown / max, steps |
| `story/strahd_presence.gd` (`StrahdPresence`) | Pure logic: which visit is due, its steps in order, where its foes stand |
| `narrative/strahd/visits.dialogue` | The watcher, the night visit, the test of strength and its parting words |
| `narrative/strahd/letters.dialogue` | The first letter, the invitation and the black carriage |
| `narrative/strahd/ireena.dialogue` | The move against Ireena: the inn, Krezk, St. Andral's |
| `narrative/strahd/final.dialogue` | `strahd/final:parley`, the price he names before the final battle |
| `data/flags/strahd.json` | The flags below |
| `tests/unit/test_strahd_presence.gd` | Triggers, steps, placement, the conversations, the withdraw, the game's hooks |

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
`strahd_after_rest` when a Long Rest is done). A visit on the road stops the journey like a road event; the journey
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

### The parley (strahd/final:parley)

Played by the engine before a final battle (ADR 0014). He greets the party and reacts to what they carry (the
Sunsword, the Holy Symbol, the Tome), to a fight he left (`strahd_withdrew`), the window fight, and Ireena (with them,
or upstairs dressing for dinner when he holds her). His price: Ireena given freely (only while she travels with the
party or he holds her), or kneel and serve, or fight. The answer is `strahd_parley`: `fight` (the battle starts),
`yield` (Strahd triumphant) or `ireena` (the bride). Optional lines: "You can't leave this valley either"
(`strahd_seen_trapped`), Insight DC 18 (spent on failure; never needed).

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

The test of strength comes at level 7 or later, at night, on the road; he leaves at 100 of 144 Hit Points or when his
turn comes in round 4. The window fight is shorter (he leaves at 120 HP or in round 3) and has a swarm of bats rather
than wolves, since a party in Vallaki or Krezk may be level 5. Tuned with the autopilot (four pregens, eight seeds, before the
withdraw): over his rounds a level 6 party lost two or three members to him and two dire wolves, a level 7 party
none to two; a level 5 party at the window lost one or two in two rounds. Neither fight gives loot; leaving is not
dying.
