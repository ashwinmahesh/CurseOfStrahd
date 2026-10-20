# Ireena's check-in (Story Allies Presence Plan, package I1)

Owner's ask (2026-10-18): Ireena is a major character who is barely noticeable once the party has left her at the temple in
Vallaki; there should be reasons to check in with her. The plan's first answer is a hub, `allies/ireena:checkin`
(`narrative/allies/ireena.dialogue`), that opens from wherever she is. The packages after it (I2 errands, I3 letters, I4
camp talks, I5 the chapel, F1 the finale) hang their parts on this hub and on its flag file.

## Where it opens

| Where she is | The party is offered | Notes |
|---|---|---|
| Blue Water Inn (`ireena_sanctuary == "inn"`) | "How are you holding up under the Martikovs' roof?" in `vallaki/ireena:inn_menu` | beside the existing rejoin, the Izek options and "Rest well" |
| St. Andral's (`ireena_sanctuary == "st_andrals"`) | "How are you holding up here at the church?" in `church_menu` | |
| The Krezkovs' house (`ireena_in_krezk`) | "How are they treating you behind Krezk's wall?" in `krezk/ireena:at_krezk` | |
| The mansion, once the party declined to take her (`ireena_escort == "declined"`) | "How are you holding up in the old house?" in `village_of_barovia/ireena:declined` | the `later` state and the parlour menu have no hub |
| On the road (`guest:ireena`) | a click on her (`data/npcs/ireena.json` `guest_talk`, npc-lead's GuestTalk) | no greeting, no way to "take her along" |

Each of the three existing menus gains one option, placed just before the last (goodbye) option so the others keep their
places. The existing rejoin nodes (`vallaki/ireena:rejoin`, `krezk/ireena:rejoin`, the declined-escort question) are not
touched; the hub jumps to them.

## What a check-in plays (in this order)

1. `checkin`: counts it (`ireena_checkins`), resets the visit's news counter.
2. `greet` (refuges only): the first, second and later check-ins each have a line.
3. `life`: one line of her days where she is, a stage per visit to that place (`ireena_visits_<place>`: 1, 2, then 3 and
   later): the inn (the night watches, the feathers, what the family are; one line for a party the Keepers have met),
   St. Andral's (the bell, the quiet, the posts), Krezk (the wall, Ilya well or still ill, the pool unknown or known), the
   mansion (Ismark's stew, Father's chair, his ledgers), the road. The first visit to each place adds 1 to `ireena_trust`.
4. `news` (`n_*` nodes): her reaction to what the party has done, **at most three a visit, the later parts of the story first,
   each once** (`ireena_heard_<topic>`; `ireena_news_now` counts the visit's). The chain's order is the order of the nodes
   in the file: the dinner invitation, Strahd's attention at its top tier, a dark gift, Mordenkainen, Berez, the Sunsword,
   the Holy Symbol, the Tome, the beacon, the Abbot (four ends), Van Richten and Ezmerelda, Old Bonegrinder (three), the
   den (three), the freed children, Yester Hill, the wine, Izek (told; dead and known as her brother; dead), the festival
   (three), St. Andral's bones, Madam Eva's reading. Every line is written to read right whether she saw it or only heard
   of it. Add a topic by putting a node in the chain (before `-> menu`) with `flag.ireena_news_now < 3` and its own
   `ireena_heard_` flag.
5. `menu` / `menu_show`: "Is something on your mind?" (only while a topic is on offer), the existing way to take her along
   (not on the road), and the goodbye. Before the menu, `offer_*` choose **at most three of her topics, the later first**
   (`ireena_offer_<topic>`, recomputed every time; `ireena_topics_now`): the pool (needs `ireena_pool_vision`; three ends by
   `ireena_pool_choice`), Izek (afraid, her brother, gone), the dream of the lake, the marks and her nights, her father (by
   `burial_method`). Each plays once (`ireena_heard_<topic>`) and goes back to `menu`. `topics` is the small menu.
6. `bye`: her goodbye for the place, then the conversation ends. Every path ends: a state with no known place still has the
   goodbye option and `bye` falls through to `END`.

I2 to I5 add their options at the marked line in `menu_show` (her asks, the Strahd letters as a topic) and their counters
in `checkin` (`ireena_letters_unanswered` is reset there by I3, which also opens the check-in cold when two or three
letters went unanswered: docs/story/ireena_letters.md).

## Rules it keeps

- Only the side flags in `data/flags/allies_ireena.json` are set here; story flags are only read (the existing rejoin nodes,
  when the party takes her along, set their own).
- Nothing rolls: no skill option in the hub, so nothing can be spent by a failure. `tests/integration/test_ireena_checkin.gd`
  checks that no `DC` appears in the file.
- She never says Strahd's name; she is not glass (the phrase is not used); she judges the party by how her father was
  buried (the father topic reads `burial_method`).
- Ireena is a non-combatant (E3): nothing here puts her in a fight or asks for one.
- Lines are unvoiced: the hub is the voice thread's to record after hand-off (126 lines, plus the party's option texts,
  which are never voiced). Every line is Gemini's draft, edited: `docs/plans/gemini_allies/I1/`.

## Flags (all in `data/flags/allies_ireena.json`)

| Flag | Kind | Meaning |
|---|---|---|
| `ireena_checkins` | int | check-ins held, anywhere; picks the greeting; I3 may read it |
| `ireena_trust` | int | +1 for the first check-in at each place (max 5 in I1); read only by her own new lines, F1 and the epilogues |
| `ireena_visits_inn` / `_church` / `_krezk` / `_mansion` / `_road` | int | visits to that place; the stage of `life` |
| `ireena_news_now`, `ireena_topics_now` | int | per-visit counters, reset every time |
| `ireena_heard_<topic>` | bool | 20 news topics and 5 of her own topics, each told once |
| `ireena_offer_<topic>` | bool | her topic is on offer in this menu |

## Tests

`tests/integration/test_ireena_checkin.gd` plays the hub at the five places for four visits each (stages, counters, trust,
greetings, goodbyes), the news (three at a time, newest first, once; every item and variant has its line), her topics (the
three newest, each once, running out, each variant by what happened), the way along (the existing rejoin nodes), a state
with no place, and that only side flags move.
