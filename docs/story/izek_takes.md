# Izek comes for Ireena (Story Allies Presence Plan, package Z1)

Owner's ask (2026-10-18): Izek Strazni is a major character who barely shows after the festival, and Ireena is left at the
inn or the church with nothing happening to her. The plan's answer for as long as Izek does not know she is his sister:
the book's Izek takes what he wants, so he takes her. The party can rescue her; if nobody comes, she gets out alone, which
costs her trust and his pride. **No story flag moves** beyond what the old scenes already move: the whole thing is side flags
(`data/flags/allies_izek.json`, `ireena_trust`), one ally visit, one dialogue file, and a few `when`s.

## What the player sees

| Night | What happens | Who tells the party |
|---|---|---|
| 1. The omen | Izek stands motionless outside the place where she sleeps, staring at her window. Nothing else happens. | The innkeeper (Urwin) at the inn, Father Lucian at the church, a watchman anywhere else in Vallaki; the Narrator's line before them says which refuge it is |
| 2. The taking | At least two days later he carried her off to his room in the Baron's mansion (the inn's door off a hinge, the church's gate open). Unhurt; nobody stopped him. Ismark, if he was guarding her, was turned back at the mansion gate. | the same three |
| 3. The escape | If nobody has freed her two days after the taking, she hit him with a brass candlestick in front of six of the watch, broke his nose, walked out of the front door and is back at her refuge, colder. `ireena_trust -= 2`. | the same three |

The plan's timing was "three days after he first saw her". Nothing in the story records the day Izek first saw her, so the
omen is the first night in Vallaki after he has (`izek_saw_ireena`), and the taking comes 48 hours after it. On the Baron's
path, after the festival (`festival_over`, `vallaki_backed == "baron"`; Izek has asked for her and been refused), there is no
omen: the first night in Vallaki he takes her.

## The visit (`data/visits/izek.json`, `izek_takes_ireena`)

One ally visit, played three times: `trigger` on `arrive` or `rest`, at night, at the square, the inn or the church (the church
is holy ground, which Strahd's visits keep quiet, and the visit names it in `at`); `max: 3` and `cooldown_hours: 48`, so each
stage comes at least two days after the last (the engine measures a visit's cooldown from its own last time, so this is the
one way to say "two days after the taking" without a stored day). The conversation, `allies/izek_takes:night`, reads which
stage it is from the flags: `izek_holds_ireena` (the escape), `izek_watching` or the Baron's post-festival state (the taking),
else the omen.

Its `when` is "Izek has seen her, is alive and untold, she shelters at the inn or the church (not with the party, not
taken by Strahd), she hasn't been taken before, and it is not the festival, or she is held now". So it comes only while he does
not know the truth, only once, never during the festival (the festival's own dais scene has Izek ask the Baron for her, and
that must not meet an Ireena he is already holding), and the escape still comes if the festival has begun. It is words only:
`StrahdPresence.may_fight` is false, so a Long Rest's benefits are never held for it.

## Held

`izek_holds_ireena` plus: Izek is alive, he has not been told the truth, she does not travel with the party. Written out in
every place that reads it:

`flag.izek_holds_ireena and not flag.izek_dead and not flag.izek_told_truth and not guest:ireena`

so a death or a telling somewhere else (the festival's duel, the square) frees her with no word: she is back at her refuge.

| Where | While held |
|---|---|
| `vallaki_blue_water_inn`, `vallaki_st_andrals` | Ireena's entry, and Ismark's, do not stand (their `when`s end in `and not (held)`) |
| `data/strahd/visits.json` | `ireena_at_the_inn`, `ireena_at_the_church`, `ireena_in_krezk` skip her (the last can never meet the flag; the plan names all three) |
| `vallaki_burgomaster_mansion` | Izek by night: `allies/izek_takes:room`, he speaks first (`approach: 5`). Ireena, by day with `approach: 5` and by night without: `allies/izek_takes:ireena_room`, at (4, 12). The old `vallaki/izek:at_home` entry gains `not flag.izek_holds_ireena` |

Izek by day is still in the square (`vallaki.json` is not this package's); his room by day holds only her, the door shut and
not locked, the watch down the hall not asking.

## In the room (`narrative/allies/izek_takes.dialogue`)

**By night** (`room`): the party opens the door on both of them. Ways out:

- **Ask whether she is hurt** (`room_hurt`): no; he has been monstrously polite. Back to the menu.
- **Threaten him** (Intimidation DC 16, `room_threat_ok`): he lets her go and keeps the grudge (`attitude izek hostile`).
  A failure is the old `home_threat_fail` line and the fight (`room_threat_fail`).
- **Tell him the truth** (offered when `izek_sister_truth` and not `izek_told_truth`): Persuasion DC 14, or *let Ireena tell him
  herself*, which has no check and so always works. The success is the old `truth_ok`'s flags and lines (`izek_told_truth`,
  quest `izek_obsession truth_told`, the `izek_truth` cutscene), then he stands out of the doorway and she goes. A failed
  Persuasion is spent (the engine removes it) and Ireena offers to speak herself.
- **Draw steel** (`room_fight`): she says she will wait on the stairs and slips out first (`izek_holds_ireena` cleared, so she
  is not in the room for the fight and the encounter has no one to hurt), then the old fight
  (`vallaki/izek:fight`, encounter `izek_confrontation`). She keeps out of fights.
- **We'll go**: leaves her where she is.

**By day**, Izek out (`ireena_room`, `alone_*`): she is alone in the chair, sleepless and angry; the party can walk her out
(`alone_rescue`), ask whether she was hurt, or tell her to wait. At night, if the party speaks to her instead of him, she
whispers: talk to him, not me (`watched`).

**Out** (`freed`, `freed_menu`): after a threat or a walk out she thanks them once; after the truth she has already spoken, so
it goes straight to the menu. *Come with us again* is the existing `vallaki/ireena:rejoin` (she joins; Ismark joins if he
was guarding), or the party takes her back to her refuge. Every party-driven end adds one to `ireena_trust` and sets
`izek_hold_ended`.

**Afterwards** (`after_hold`, Izek's entry by night once the hold has ended, he is alive and untold): his room again, but the
nose and the tin splint after the escape, or the counted dolls and the empty chair after a rescue or a threat; then the old
`at_home` menu's own option texts and nodes (the truth, a threat, steel, go). This is where `izek_hold_ended` is read.

## Flags (`data/flags/allies_izek.json`)

| Flag | Kind | Meaning |
|---|---|---|
| `izek_watching` | bool | the omen has played; the taking may come two days on |
| `izek_took_ireena` | bool | he has taken her, once; never cleared, so he doesn't take her twice |
| `izek_holds_ireena` | bool | she is in his room (see Held for when that counts) |
| `izek_hold_ended` | string | `rescued`, `threatened`, `truth`, `fought`, `escaped`; empty if he died or was told elsewhere |
| `izek_room_met` | bool | the party has found her in his room (first sight, then a shorter return) |

`ireena_trust` is Ireena's own counter (`data/flags/allies_ireena.json`, I1): +1 for any end the party brought about, -2 for the
escape. Nothing else is moved: the test checks each path's changed flags (the truth's are the old scene's `izek_told_truth` and
quest stage, the rejoin's `ireena_sanctuary` and `join`, as when a player picks those options).

## What this leaves for the other packages

- **Z2** (Izek, her brother): a `izek_hold_ended == "truth"` or a held-then-freed Ireena has no new check-in line yet; her hub
  (`narrative/allies/ireena.dialogue`, I1's) does not read `izek_took_ireena` or `izek_hold_ended`. Z2 or a later I1 pass may.
- The journal (`izek_obsession`, `sanctuary_for_ireena`) has no stage for "taken", since the quest files are not this package's.
  The news says where she is and in which room.
- `izek_hold_ended == "escaped"` is the plan's "Izek is humiliated"; F1 may read it for an epilogue.
- By day Izek is in the square (`data/locations/vallaki.json`) as before, whatever he did the night before.
- The festival's dais scene (`narrative/vallaki/aftermath.dialogue`, `izek_claim`) assumes Ireena is a guest or sheltered; the
  visit keeps clear of the festival, so it can only meet a held Ireena if the festival begins while she is held (the party
  away from Vallaki for the nights in between).

## Lines

65 new spoken lines, all unvoiced (Narrator 15, Ireena 19, Izek 10, Urwin 7, Father Lucian 7, Town Guard 7), plus the party's option
texts, which are never voiced. Eleven lines in the file are copied word for word from `narrative/vallaki/izek.dialogue` and
`narrative/vallaki/ireena.dialogue` (their voices exist already): "You're in my room.", the truth scene's lines, the failed
plea, the failed threat. Every new line is Gemini's draft, edited: `docs/plans/gemini_allies/z1/`.

## Tests

`tests/unit/test_izek_takes.gd`: the three nights and their two-day spacing; what the visit waits for; the Baron's post-festival
taking with no omen; who brings the news and which refuge it names; Ismark in the news; each stage's flags; the story bot's exit
from each stage; where Ireena and Izek stand (refuge, room by day and night, aftermath, freed however it ended); Strahd's three
visits skipping her while held; her and his squares on open floor with Izek speaking first; the room (menu, first and return, the
threat, the fight with her already out, the truth, the failed plea); the day scene and the walk out; Izek afterwards; and that
every node of the file reaches its end.
